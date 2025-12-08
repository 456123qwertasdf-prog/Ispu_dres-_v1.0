-- Add new tables: reporter, responder, assignment, audit_log
-- Migration: 20250113000000_add_new_tables.sql

-- Enable PostGIS extension for geometry support
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Enable pgcrypto extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create reports table first (needed for foreign key references)
CREATE TABLE IF NOT EXISTS public.reports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_uid text,
    reporter_name text,
    message text,
    location jsonb,
    image_path text,
    type text,
    confidence double precision,
    status text DEFAULT 'pending',
    created_at timestamptz DEFAULT now(),
    ai_labels jsonb,
    ai_timestamp timestamptz
);
ALTER TABLE public.reports REPLICA IDENTITY FULL;

-- Create enum for assignment status
CREATE TYPE assignment_status AS ENUM (
    'assigned',
    'accepted', 
    'enroute',
    'on_scene',
    'resolved',
    'cancelled'
);

-- Create reporter table
CREATE TABLE IF NOT EXISTS public.reporter (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    phone text NOT NULL,
    verified boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create responder table
CREATE TABLE IF NOT EXISTS public.responder (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    phone text NOT NULL,
    role text NOT NULL,
    status text DEFAULT 'active',
    last_location geometry(POINT, 4326),
    is_available boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create assignment table
CREATE TABLE IF NOT EXISTS public.assignment (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id uuid NOT NULL REFERENCES public.reports(id) ON DELETE CASCADE,
    responder_id uuid NOT NULL REFERENCES public.responder(id) ON DELETE CASCADE,
    status assignment_status DEFAULT 'assigned',
    assigned_at timestamptz DEFAULT now(),
    accepted_at timestamptz,
    completed_at timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create audit_log table
CREATE TABLE IF NOT EXISTS public.audit_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    action text NOT NULL,
    user_id uuid,
    details jsonb,
    created_at timestamptz DEFAULT now()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_reporter_phone ON public.reporter(phone);
CREATE INDEX IF NOT EXISTS idx_reporter_verified ON public.reporter(verified);

CREATE INDEX IF NOT EXISTS idx_responder_phone ON public.responder(phone);
CREATE INDEX IF NOT EXISTS idx_responder_role ON public.responder(role);
CREATE INDEX IF NOT EXISTS idx_responder_status ON public.responder(status);
CREATE INDEX IF NOT EXISTS idx_responder_available ON public.responder(is_available);
CREATE INDEX IF NOT EXISTS idx_responder_location ON public.responder USING GIST(last_location);

CREATE INDEX IF NOT EXISTS idx_assignment_report_id ON public.assignment(report_id);
CREATE INDEX IF NOT EXISTS idx_assignment_responder_id ON public.assignment(responder_id);
CREATE INDEX IF NOT EXISTS idx_assignment_status ON public.assignment(status);
CREATE INDEX IF NOT EXISTS idx_assignment_assigned_at ON public.assignment(assigned_at);

CREATE INDEX IF NOT EXISTS idx_audit_log_entity ON public.audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_user_id ON public.audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON public.audit_log(created_at);

-- Add unique constraints
ALTER TABLE public.reporter ADD CONSTRAINT unique_reporter_phone UNIQUE (phone);
ALTER TABLE public.responder ADD CONSTRAINT unique_responder_phone UNIQUE (phone);

-- Enable Row Level Security on all new tables
ALTER TABLE public.reporter ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.responder ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies for reporter table
CREATE POLICY "Allow authenticated users to insert reporters" ON public.reporter
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

CREATE POLICY "Allow authenticated users to select reporters" ON public.reporter
    FOR SELECT 
    TO authenticated 
    USING (true);

CREATE POLICY "Allow authenticated users to update reporters" ON public.reporter
    FOR UPDATE 
    TO authenticated 
    USING (true);

CREATE POLICY "Allow service role full access to reporters" ON public.reporter
    FOR ALL 
    TO service_role 
    USING (true);

-- RLS Policies for responder table
CREATE POLICY "Allow authenticated users to insert responders" ON public.responder
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

CREATE POLICY "Allow authenticated users to select responders" ON public.responder
    FOR SELECT 
    TO authenticated 
    USING (true);

CREATE POLICY "Allow authenticated users to update responders" ON public.responder
    FOR UPDATE 
    TO authenticated 
    USING (true);

CREATE POLICY "Allow service role full access to responders" ON public.responder
    FOR ALL 
    TO service_role 
    USING (true);

-- RLS Policies for assignment table
CREATE POLICY "Allow authenticated users to insert assignments" ON public.assignment
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

CREATE POLICY "Allow authenticated users to select assignments" ON public.assignment
    FOR SELECT 
    TO authenticated 
    USING (true);

CREATE POLICY "Allow authenticated users to update assignments" ON public.assignment
    FOR UPDATE 
    TO authenticated 
    USING (true);

CREATE POLICY "Allow service role full access to assignments" ON public.assignment
    FOR ALL 
    TO service_role 
    USING (true);

-- RLS Policies for audit_log table
CREATE POLICY "Allow authenticated users to insert audit logs" ON public.audit_log
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

CREATE POLICY "Allow authenticated users to select audit logs" ON public.audit_log
    FOR SELECT 
    TO authenticated 
    USING (true);

CREATE POLICY "Allow service role full access to audit logs" ON public.audit_log
    FOR ALL 
    TO service_role 
    USING (true);

-- Create updated_at trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers
CREATE TRIGGER update_reporter_updated_at 
    BEFORE UPDATE ON public.reporter 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_responder_updated_at 
    BEFORE UPDATE ON public.responder 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_assignment_updated_at 
    BEFORE UPDATE ON public.assignment 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comments for documentation
COMMENT ON TABLE public.reporter IS 'Stores information about people who report incidents';
COMMENT ON TABLE public.responder IS 'Stores information about emergency responders and their availability';
COMMENT ON TABLE public.assignment IS 'Tracks assignments of responders to reports';
COMMENT ON TABLE public.audit_log IS 'Logs all changes to entities for audit trail';

COMMENT ON COLUMN public.reporter.verified IS 'Whether the reporter has been verified';
COMMENT ON COLUMN public.responder.last_location IS 'Last known GPS location of the responder';
COMMENT ON COLUMN public.responder.is_available IS 'Whether the responder is currently available for assignments';
COMMENT ON COLUMN public.assignment.status IS 'Current status of the assignment';
COMMENT ON COLUMN public.audit_log.entity_type IS 'Type of entity being audited (e.g., reporter, responder, assignment)';
COMMENT ON COLUMN public.audit_log.details IS 'Additional details about the action in JSON format';
