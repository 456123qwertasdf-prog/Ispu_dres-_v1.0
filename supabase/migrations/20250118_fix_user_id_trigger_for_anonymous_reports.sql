-- Fix the set_user_role trigger to handle anonymous reports
-- When auth.uid() is null (anonymous users), use reporter_uid as fallback for user_id

CREATE OR REPLACE FUNCTION set_user_role()
RETURNS TRIGGER AS $$
BEGIN
    -- Set user_id: use auth.uid() if available, otherwise use reporter_uid::uuid as fallback
    -- This allows anonymous reports from mobile app to work
    NEW.user_id := COALESCE(
        auth.uid(),
        CASE 
            WHEN NEW.reporter_uid IS NOT NULL AND NEW.reporter_uid ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' 
            THEN NEW.reporter_uid::uuid
            ELSE gen_random_uuid()
        END
    );
    
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

