-- App version config for update checks (min/latest version, force update, download URL)
CREATE TABLE IF NOT EXISTS public.app_version (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    platform text NOT NULL UNIQUE CHECK (platform IN ('android', 'ios')),
    min_version text NOT NULL,
    latest_version text NOT NULL,
    force_update boolean NOT NULL DEFAULT false,
    download_url text,
    release_notes text,
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.app_version ENABLE ROW LEVEL SECURITY;

-- Allow anyone (including anon) to read app version for update check
CREATE POLICY "Allow public read app_version" ON public.app_version
    FOR SELECT TO anon, authenticated USING (true);

-- Seed Android row (update min_version/latest_version when releasing new builds)
INSERT INTO public.app_version (platform, min_version, latest_version, force_update, download_url, release_notes)
VALUES (
    'android',
    '1.1.0',
    '1.1.0',
    false,
    'https://github.com/456123qwertasdf-prog/lspu_dres/raw/master/public/lspu-emergency-response.apk',
    'Initial version. Report emergencies, view alerts, and stay connected.'
)
ON CONFLICT (platform) DO NOTHING;

COMMENT ON TABLE public.app_version IS 'Minimum and latest app versions per platform for in-app update checks';
