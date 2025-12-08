-- Add HTML content column to learning_modules
-- Migration: 20251031_add_content_html_to_learning_modules.sql

ALTER TABLE public.learning_modules
ADD COLUMN IF NOT EXISTS content_html text;

-- Optional: update replica identity remains FULL (already set in create migration)


