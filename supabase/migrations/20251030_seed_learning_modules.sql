-- Seed initial emergency-related learning modules
-- Migration: 20251030_seed_learning_modules.sql

-- Only seed when table is empty
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.learning_modules) THEN
    INSERT INTO public.learning_modules ("order", title, description, pdf_url, pdf_path, active)
    VALUES
      (1, 'Reporting an Emergency', 'How to quickly report emergencies using the Kapiyu system, with tips on providing accurate details.', NULL, NULL, true),
      (2, 'Earthquake Safety: Drop, Cover, Hold', 'Step-by-step guidance for earthquake situations, including safe evacuation and assembly points.', NULL, NULL, true),
      (3, 'Fire Safety and Evacuation', 'Recognizing fire hazards, using alarms/extinguishers, and orderly evacuation procedures.', NULL, NULL, true),
      (4, 'Flood Preparedness and Response', 'Understanding flood warnings, go-bag essentials, and safe routes to evacuation centers.', NULL, NULL, true),
      (5, 'Emergency Communication Protocols', 'Receiving alerts, staying informed, and communicating effectively during incidents.', NULL, NULL, true);
  END IF;
END $$;


