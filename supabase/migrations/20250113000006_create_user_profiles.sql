-- Create user profiles table for authentication
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('citizen', 'responder', 'admin')),
    name TEXT NOT NULL,
    department TEXT,
    phone TEXT,
    badge_number TEXT, -- For responders
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can read own profile" ON public.user_profiles
    FOR SELECT 
    TO authenticated 
    USING (user_id = auth.uid());

CREATE POLICY "Users can update own profile" ON public.user_profiles
    FOR UPDATE 
    TO authenticated 
    USING (user_id = auth.uid());

CREATE POLICY "Service role can manage all profiles" ON public.user_profiles
    FOR ALL 
    TO service_role 
    USING (true);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON public.user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON public.user_profiles(role);
CREATE INDEX IF NOT EXISTS idx_user_profiles_active ON public.user_profiles(is_active);

-- Add updated_at trigger
CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON public.user_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE public.user_profiles IS 'User profiles with roles for the emergency response system';
COMMENT ON COLUMN public.user_profiles.role IS 'User role: citizen, responder, or admin';
COMMENT ON COLUMN public.user_profiles.department IS 'Department for responders and admins';
COMMENT ON COLUMN public.user_profiles.badge_number IS 'Badge number for responders';
COMMENT ON COLUMN public.user_profiles.is_active IS 'Whether the user account is active';
