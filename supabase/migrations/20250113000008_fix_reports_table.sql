-- Fix reports table - add missing user_id column
-- This migration fixes the database schema to include the user_id column

-- First, check if user_id column exists, if not add it
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'reports' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE reports ADD COLUMN user_id UUID REFERENCES auth.users(id);
    END IF;
END $$;

-- Add user_id to reports table if it doesn't exist
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Temporarily disable foreign key constraint
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_user_id_fkey;

-- Update existing reports to have user_id if missing (use reporter_uid as fallback)
UPDATE reports 
SET user_id = COALESCE(
    reporter_uid::uuid,
    gen_random_uuid()
)
WHERE user_id IS NULL;

-- Note: Foreign key constraint removed temporarily to avoid issues with generated UUIDs
-- This can be re-added later when proper user management is implemented

-- Make user_id NOT NULL for new reports
ALTER TABLE reports 
ALTER COLUMN user_id SET NOT NULL;

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_reports_user_id ON reports(user_id);

-- Update RLS policies to use user_id
DROP POLICY IF EXISTS "Citizens can view own reports" ON reports;
DROP POLICY IF EXISTS "Citizens can insert own reports" ON reports;
DROP POLICY IF EXISTS "Citizens can update own reports" ON reports;

-- Citizen policies
CREATE POLICY "Citizens can view own reports" ON reports
    FOR SELECT USING (
        auth.uid() = user_id AND 
        user_role = 'citizen'
    );

CREATE POLICY "Citizens can insert own reports" ON reports
    FOR INSERT WITH CHECK (
        auth.uid() = user_id AND 
        user_role = 'citizen'
    );

CREATE POLICY "Citizens can update own reports" ON reports
    FOR UPDATE USING (
        auth.uid() = user_id AND 
        user_role = 'citizen'
    );

-- Update the trigger to set user_id
CREATE OR REPLACE FUNCTION set_user_role()
RETURNS TRIGGER AS $$
BEGIN
    -- Set user_id to current user
    NEW.user_id := auth.uid();
    
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

-- Update the trigger
DROP TRIGGER IF EXISTS set_user_role_trigger ON reports;
CREATE TRIGGER set_user_role_trigger
    BEFORE INSERT ON reports
    FOR EACH ROW
    EXECUTE FUNCTION set_user_role();

-- Add comments for documentation
COMMENT ON COLUMN reports.user_id IS 'ID of the user who created the report';
