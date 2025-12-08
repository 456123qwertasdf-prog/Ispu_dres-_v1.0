-- Seed a default course and attach existing modules; seed a sample quiz
-- Migration: 20251031_seed_lms_default.sql

-- Create course if none exists
INSERT INTO public.lms_courses (title, description)
SELECT 'Emergency Preparedness 101', 'Core modules for reporting and safety basics'
WHERE NOT EXISTS (SELECT 1 FROM public.lms_courses);

-- Attach all active learning_modules to the first course if not set
UPDATE public.learning_modules lm
SET course_id = (SELECT id FROM public.lms_courses ORDER BY created_at LIMIT 1)
WHERE lm.course_id IS NULL;

-- Ensure the first module requires quiz (Reporting an Emergency)
UPDATE public.learning_modules
SET quiz_required = true, pass_score = 70
WHERE title = 'Reporting an Emergency' AND active = true;

-- Create quiz for Reporting an Emergency if missing
INSERT INTO public.lms_quizzes (module_id, pass_score)
SELECT lm.id, 70
FROM public.learning_modules lm
LEFT JOIN public.lms_quizzes q ON q.module_id = lm.id
WHERE lm.title = 'Reporting an Emergency' AND q.id IS NULL;

-- Add two sample questions if none exist yet
INSERT INTO public.lms_questions (quiz_id, question_text, question_type)
SELECT q.id, 'Which item is REQUIRED before submitting an emergency report?', 'mcq'
FROM public.lms_quizzes q
JOIN public.learning_modules lm ON lm.id = q.module_id
LEFT JOIN public.lms_questions qq ON qq.quiz_id = q.id
WHERE lm.title = 'Reporting an Emergency' AND qq.id IS NULL;

INSERT INTO public.lms_questions (quiz_id, question_text, question_type)
SELECT q.id, 'True or False: You should use the Get Location button to include your location.', 'tf'
FROM public.lms_quizzes q
JOIN public.learning_modules lm ON lm.id = q.module_id
LEFT JOIN public.lms_questions qq ON qq.quiz_id = q.id
WHERE lm.title = 'Reporting an Emergency' AND qq.id IS NULL;

-- Options for Q1
INSERT INTO public.lms_options (question_id, option_text, is_correct)
SELECT q1.id, 'A clear photo of the incident', true
FROM public.lms_questions q1
JOIN public.lms_quizzes q ON q1.quiz_id = q.id
JOIN public.learning_modules lm ON lm.id = q.module_id
LEFT JOIN public.lms_options o ON o.question_id = q1.id
WHERE lm.title = 'Reporting an Emergency' AND q1.question_text LIKE 'Which item is REQUIRED%' AND o.id IS NULL;

INSERT INTO public.lms_options (question_id, option_text, is_correct)
SELECT q1.id, 'A long story about your day', false
FROM public.lms_questions q1
JOIN public.lms_quizzes q ON q1.quiz_id = q.id
JOIN public.learning_modules lm ON lm.id = q.module_id
WHERE lm.title = 'Reporting an Emergency' AND q1.question_text LIKE 'Which item is REQUIRED%';

INSERT INTO public.lms_options (question_id, option_text, is_correct)
SELECT q1.id, 'A selfie unrelated to the incident', false
FROM public.lms_questions q1
JOIN public.lms_quizzes q ON q1.quiz_id = q.id
JOIN public.learning_modules lm ON lm.id = q.module_id
WHERE lm.title = 'Reporting an Emergency' AND q1.question_text LIKE 'Which item is REQUIRED%';

-- Options for Q2 (True/False)
INSERT INTO public.lms_options (question_id, option_text, is_correct)
SELECT q2.id, 'True', true
FROM public.lms_questions q2
JOIN public.lms_quizzes q ON q2.quiz_id = q.id
JOIN public.learning_modules lm ON lm.id = q.module_id
LEFT JOIN public.lms_options o ON o.question_id = q2.id
WHERE lm.title = 'Reporting an Emergency' AND q2.question_text LIKE 'True or False:%' AND o.id IS NULL;

INSERT INTO public.lms_options (question_id, option_text, is_correct)
SELECT q2.id, 'False', false
FROM public.lms_questions q2
JOIN public.lms_quizzes q ON q2.quiz_id = q.id
JOIN public.learning_modules lm ON lm.id = q.module_id
WHERE lm.title = 'Reporting an Emergency' AND q2.question_text LIKE 'True or False:%';


