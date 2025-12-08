-- Add quiz_url column to learning_modules for Google Forms integration
-- Migration: 20251031_add_quiz_url_to_learning_modules.sql

ALTER TABLE public.learning_modules
ADD COLUMN IF NOT EXISTS quiz_url text;

-- Optional: Add comment for documentation
COMMENT ON COLUMN public.learning_modules.quiz_url IS 'URL to Google Form or external quiz for this module';

        