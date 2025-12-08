-- Add image_url column to announcements table for weather images
-- Migration: 20250116000004_add_image_url_to_announcements.sql

-- Add image_url column (nullable, for weather announcements)
ALTER TABLE public.announcements 
ADD COLUMN IF NOT EXISTS image_url text;

-- Add comment
COMMENT ON COLUMN public.announcements.image_url IS 'Optional image URL for weather announcements (e.g., radar, satellite, forecast maps)';

