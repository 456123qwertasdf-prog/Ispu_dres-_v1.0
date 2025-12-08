-- Fix RLS policies to allow admin and responder to see all reports
-- This migration updates the Row Level Security policies for the reports table

-- Drop existing policies first
DROP POLICY IF EXISTS "Users can view own reports" ON reports;
DROP POLICY IF EXISTS "Users can insert own reports" ON reports;
DROP POLICY IF EXISTS "Users can update own reports" ON reports;
DROP POLICY IF EXISTS "Admins can view all reports" ON reports;
DROP POLICY IF EXISTS "Responders can view all reports" ON reports;
DROP POLICY IF EXISTS "Admins can update all reports" ON reports;
DROP POLICY IF EXISTS "Responders can update all reports" ON reports;

-- Create new policies that properly handle role-based access

-- Allow users to view their own reports
CREATE POLICY "Users can view own reports" ON reports
  FOR SELECT USING (auth.uid() = reporter_uid);

-- Allow users to insert their own reports
CREATE POLICY "Users can insert own reports" ON reports
  FOR INSERT WITH CHECK (auth.uid() = reporter_uid);

-- Allow users to update their own reports
CREATE POLICY "Users can update own reports" ON reports
  FOR UPDATE USING (auth.uid() = reporter_uid);

-- Allow admins to view all reports
CREATE POLICY "Admins can view all reports" ON reports
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM auth.users 
      WHERE auth.users.id = auth.uid() 
      AND (auth.users.raw_user_meta_data->>'role' = 'admin' OR auth.users.raw_user_meta_data->>'role' = 'Admin')
    )
  );

-- Allow responders to view all reports
CREATE POLICY "Responders can view all reports" ON reports
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM auth.users 
      WHERE auth.users.id = auth.uid() 
      AND (auth.users.raw_user_meta_data->>'role' = 'responder' OR auth.users.raw_user_meta_data->>'role' = 'Responder')
    )
  );

-- Allow admins to update all reports
CREATE POLICY "Admins can update all reports" ON reports
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM auth.users 
      WHERE auth.users.id = auth.uid() 
      AND (auth.users.raw_user_meta_data->>'role' = 'admin' OR auth.users.raw_user_meta_data->>'role' = 'Admin')
    )
  );

-- Allow responders to update all reports
CREATE POLICY "Responders can update all reports" ON reports
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM auth.users 
      WHERE auth.users.id = auth.uid() 
      AND (auth.users.raw_user_meta_data->>'role' = 'responder' OR auth.users.raw_user_meta_data->>'role' = 'Responder')
    )
  );

-- Ensure RLS is enabled on the reports table
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
