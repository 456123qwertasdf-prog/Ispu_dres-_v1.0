-- Update user flow for simplified emergency reporting
-- This migration updates the database schema to support the new user flow

-- Add user roles table
CREATE TABLE IF NOT EXISTS user_roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    permissions JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default roles
INSERT INTO user_roles (name, description, permissions) VALUES
('citizen', 'Citizen - Can report emergencies', '{"can_report": true, "can_view_own_reports": true}'),
('responder', 'Emergency Responder - Can respond to emergencies', '{"can_respond": true, "can_view_all_reports": true, "can_accept_assignments": true}'),
('admin', 'Administrator - Full system access', '{"can_manage": true, "can_view_all": true, "can_assign": true, "can_configure": true}')
ON CONFLICT (name) DO NOTHING;

-- Update reports table to support new flow
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS user_role VARCHAR(50) DEFAULT 'citizen',
ADD COLUMN IF NOT EXISTS is_photo_required BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS message_optional BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS auto_location BOOLEAN DEFAULT true;

-- Update reports table constraints
-- Note: description column doesn't exist, skipping this constraint change

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_reports_user_role ON reports(user_role);
CREATE INDEX IF NOT EXISTS idx_reports_auto_location ON reports(auto_location);

-- Update RLS policies for role-based access
DROP POLICY IF EXISTS "Users can view own reports" ON reports;
DROP POLICY IF EXISTS "Users can insert own reports" ON reports;
DROP POLICY IF EXISTS "Users can update own reports" ON reports;

-- Citizen policies
CREATE POLICY "Citizens can view own reports" ON reports
    FOR SELECT USING (
        auth.uid()::text = reporter_uid AND 
        user_role = 'citizen'
    );

CREATE POLICY "Citizens can insert own reports" ON reports
    FOR INSERT WITH CHECK (
        auth.uid()::text = reporter_uid AND 
        user_role = 'citizen'
    );

CREATE POLICY "Citizens can update own reports" ON reports
    FOR UPDATE USING (
        auth.uid()::text = reporter_uid AND 
        user_role = 'citizen'
    );

-- Responder policies
CREATE POLICY "Responders can view all reports" ON reports
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND auth.users.raw_user_meta_data->>'role' = 'responder'
        )
    );

CREATE POLICY "Responders can update assigned reports" ON reports
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND auth.users.raw_user_meta_data->>'role' = 'responder'
        )
    );

-- Admin policies
CREATE POLICY "Admins can view all reports" ON reports
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND auth.users.raw_user_meta_data->>'role' = 'admin'
        )
    );

-- Update storage policies for images
DROP POLICY IF EXISTS "Users can upload images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view images" ON storage.objects;

CREATE POLICY "Users can upload emergency images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'reports-images' AND
        auth.uid() IS NOT NULL
    );

CREATE POLICY "Users can view emergency images" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'reports-images' AND
        auth.uid() IS NOT NULL
    );

-- Create function to automatically set user role
CREATE OR REPLACE FUNCTION set_user_role()
RETURNS TRIGGER AS $$
BEGIN
    -- Set user role based on user metadata
    NEW.user_role := COALESCE(
        (auth.jwt() ->> 'user_metadata')::jsonb ->> 'role',
        'citizen'
    );
    
    -- Set auto-location to true by default
    NEW.auto_location := true;
    
    -- Set photo as required by default
    NEW.is_photo_required := true;
    
    -- Set message as optional by default
    NEW.message_optional := true;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically set user role
DROP TRIGGER IF EXISTS set_user_role_trigger ON reports;
CREATE TRIGGER set_user_role_trigger
    BEFORE INSERT ON reports
    FOR EACH ROW
    EXECUTE FUNCTION set_user_role();

-- Create function to get user role
CREATE OR REPLACE FUNCTION get_user_role(user_id UUID)
RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT COALESCE(
            (raw_user_meta_data ->> 'role'),
            'citizen'
        )
        FROM auth.users 
        WHERE id = user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if user can access report
CREATE OR REPLACE FUNCTION can_access_report(report_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
    report_owner UUID;
BEGIN
    -- Get user role
    user_role := get_user_role(user_id);
    
    -- Get report owner
    SELECT reports.reporter_uid INTO report_owner
    FROM reports
    WHERE reports.id = report_id;
    
    -- Check access based on role
    IF user_role = 'admin' OR user_role = 'responder' THEN
        RETURN TRUE;
    ELSIF user_role = 'citizen' AND report_owner = user_id::text THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update existing reports to have default values
UPDATE reports 
SET 
    user_role = 'citizen',
    is_photo_required = true,
    message_optional = true,
    auto_location = true
WHERE user_role IS NULL;

-- Add comments for documentation
COMMENT ON TABLE user_roles IS 'Defines user roles and their permissions';
COMMENT ON COLUMN reports.user_role IS 'Role of the user who created the report';
COMMENT ON COLUMN reports.is_photo_required IS 'Whether a photo is required for this report';
COMMENT ON COLUMN reports.message_optional IS 'Whether the message/description is optional';
COMMENT ON COLUMN reports.auto_location IS 'Whether location was auto-detected';

-- Create view for role-based report access
CREATE OR REPLACE VIEW user_reports AS
SELECT 
    r.*,
    get_user_role(r.reporter_uid::uuid) as reporter_role,
    can_access_report(r.id, auth.uid()) as can_access
FROM reports r;

-- Grant permissions
GRANT SELECT ON user_reports TO authenticated;
GRANT SELECT ON user_roles TO authenticated;
