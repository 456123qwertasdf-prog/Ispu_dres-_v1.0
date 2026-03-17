-- Responder last location: dedicated table so map always has a consistent, saved location per responder.
-- Migration: 20260317000001_responder_last_location.sql

-- 1) Add last_location_updated_at to responder (when was last_location last changed)
ALTER TABLE public.responder
ADD COLUMN IF NOT EXISTS last_location_updated_at timestamptz;

COMMENT ON COLUMN public.responder.last_location_updated_at IS 'When last_location was last updated (set by trigger).';

-- 2) Table: one row per responder with explicit lat/lng and updated_at (single source of truth for map)
CREATE TABLE IF NOT EXISTS public.responder_last_location (
    responder_id uuid PRIMARY KEY REFERENCES public.responder(id) ON DELETE CASCADE,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_responder_last_location_updated_at
ON public.responder_last_location(updated_at DESC);

COMMENT ON TABLE public.responder_last_location IS 'Last known GPS location per responder; kept in sync with responder.last_location for consistent map display.';

-- 3a) BEFORE trigger: set last_location_updated_at when last_location changes (no extra UPDATE)
CREATE OR REPLACE FUNCTION public.set_responder_last_location_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.last_location IS DISTINCT FROM NEW.last_location THEN
        IF NEW.last_location IS NULL THEN
            NEW.last_location_updated_at := NULL;
        ELSE
            NEW.last_location_updated_at := now();
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_set_responder_last_location_updated_at ON public.responder;
CREATE TRIGGER trigger_set_responder_last_location_updated_at
    BEFORE UPDATE OF last_location ON public.responder
    FOR EACH ROW
    WHEN (OLD.last_location IS DISTINCT FROM NEW.last_location)
    EXECUTE FUNCTION public.set_responder_last_location_updated_at();

-- 3b) AFTER trigger: sync responder.last_location into responder_last_location (SECURITY DEFINER so trigger can write)
CREATE OR REPLACE FUNCTION public.sync_responder_last_location()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_lat double precision;
    v_lng double precision;
BEGIN
    IF NEW.last_location IS NULL THEN
        DELETE FROM public.responder_last_location WHERE responder_id = NEW.id;
        RETURN NEW;
    END IF;

    v_lat := ST_Y(NEW.last_location::geometry);
    v_lng := ST_X(NEW.last_location::geometry);

    INSERT INTO public.responder_last_location (responder_id, latitude, longitude, updated_at)
    VALUES (NEW.id, v_lat, v_lng, now())
    ON CONFLICT (responder_id)
    DO UPDATE SET
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        updated_at = EXCLUDED.updated_at;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.sync_responder_last_location() IS 'Syncs responder.last_location into responder_last_location for consistent map display.';

DROP TRIGGER IF EXISTS trigger_sync_responder_last_location ON public.responder;
CREATE TRIGGER trigger_sync_responder_last_location
    AFTER UPDATE OF last_location ON public.responder
    FOR EACH ROW
    WHEN (OLD.last_location IS DISTINCT FROM NEW.last_location)
    EXECUTE FUNCTION public.sync_responder_last_location();

-- 4) Backfill: populate responder_last_location and last_location_updated_at from existing responder.last_location
UPDATE public.responder r
SET last_location_updated_at = r.updated_at
WHERE r.last_location IS NOT NULL
  AND r.last_location_updated_at IS NULL;

INSERT INTO public.responder_last_location (responder_id, latitude, longitude, updated_at)
SELECT r.id, ST_Y(r.last_location::geometry), ST_X(r.last_location::geometry), COALESCE(r.last_location_updated_at, r.updated_at)
FROM public.responder r
WHERE r.last_location IS NOT NULL
ON CONFLICT (responder_id)
DO UPDATE SET
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    updated_at = EXCLUDED.updated_at;

-- 5) RLS: allow authenticated to read (map and dashboards)
ALTER TABLE public.responder_last_location ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated to read responder_last_location" ON public.responder_last_location;
CREATE POLICY "Allow authenticated to read responder_last_location"
    ON public.responder_last_location
    FOR SELECT
    TO authenticated
    USING (true);

-- Writes are done only by the trigger (SECURITY DEFINER), so no INSERT/UPDATE policy for users.
