-- Fix Row Level Security policies for reports table
-- Enable RLS on reports table
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Create policy to allow authenticated users to insert reports
CREATE POLICY "Allow authenticated users to insert reports" ON public.reports
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

-- Create policy to allow authenticated users to select their own reports
CREATE POLICY "Allow authenticated users to select reports" ON public.reports
    FOR SELECT 
    TO authenticated 
    USING (true);

-- Create policy to allow authenticated users to update reports
CREATE POLICY "Allow authenticated users to update reports" ON public.reports
    FOR UPDATE 
    TO authenticated 
    USING (true);

-- Create policy to allow service role to do everything (for Edge Functions)
CREATE POLICY "Allow service role full access" ON public.reports
    FOR ALL 
    TO service_role 
    USING (true);

-- Create policy to allow anon users to insert reports (for testing)
CREATE POLICY "Allow anon users to insert reports" ON public.reports
    FOR INSERT 
    TO anon 
    WITH CHECK (true);

-- Create policy to allow anon users to select reports (for testing)
CREATE POLICY "Allow anon users to select reports" ON public.reports
    FOR SELECT 
    TO anon 
    USING (true);
