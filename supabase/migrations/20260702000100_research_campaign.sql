-- Migration: Promo Beta Research Campaign
-- Description: Creates public.bug_reports, public.idea_submissions, public.internship_applications, and public.token_validations.

-- 1. Table: public.bug_reports
CREATE TABLE IF NOT EXISTS public.bug_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL CHECK (char_length(title) <= 100),
  description TEXT NOT NULL CHECK (char_length(description) <= 2000),
  steps_to_reproduce TEXT CHECK (char_length(steps_to_reproduce) <= 1000),
  screen_or_feature TEXT CHECK (char_length(screen_or_feature) <= 100),
  severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  device_type TEXT CHECK (device_type IN ('Android', 'iOS', 'Web', 'Desktop')),
  submitter_name TEXT CHECK (char_length(submitter_name) <= 60),
  submitter_email TEXT NOT NULL CHECK (submitter_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  token TEXT UNIQUE DEFAULT ('BUG-' || UPPER(SUBSTRING(gen_random_uuid()::TEXT, 1, 8))),
  is_duplicate BOOLEAN DEFAULT FALSE,
  similarity_note TEXT,
  status TEXT DEFAULT 'received' CHECK (status IN ('received', 'reviewing', 'confirmed', 'duplicate', 'rewarded')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Table: public.idea_submissions
CREATE TABLE IF NOT EXISTS public.idea_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL CHECK (char_length(title) <= 100),
  description TEXT NOT NULL CHECK (char_length(description) <= 3000),
  problem_it_solves TEXT CHECK (char_length(problem_it_solves) <= 1000),
  category TEXT NOT NULL CHECK (category IN ('discovery', 'chat', 'profile', 'cards', 'analytics', 'map', 'onboarding', 'other')),
  submitter_name TEXT CHECK (char_length(submitter_name) <= 60),
  submitter_email TEXT NOT NULL CHECK (submitter_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  token TEXT UNIQUE DEFAULT ('IDEA-' || UPPER(SUBSTRING(gen_random_uuid()::TEXT, 1, 8))),
  is_duplicate BOOLEAN DEFAULT FALSE,
  similarity_note TEXT,
  status TEXT DEFAULT 'received' CHECK (status IN ('received', 'reviewing', 'selected', 'duplicate', 'rewarded')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Table: public.internship_applications
CREATE TABLE IF NOT EXISTS public.internship_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL CHECK (char_length(full_name) <= 60),
  email TEXT NOT NULL CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  phone TEXT CHECK (char_length(phone) <= 15),
  college_or_company TEXT CHECK (char_length(college_or_company) <= 100),
  year_of_study TEXT CHECK (char_length(year_of_study) <= 20),
  skills TEXT CHECK (char_length(skills) <= 500),
  why_promo TEXT NOT NULL CHECK (char_length(why_promo) <= 1000),
  role_interest TEXT NOT NULL CHECK (role_interest IN ('flutter_developer', 'ui_ux_designer', 'marketing', 'content_creator', 'business_development', 'other')),
  resume_url TEXT NOT NULL CHECK (resume_url ~* '^https?://.+'),
  linkedin_url TEXT CHECK (linkedin_url IS NULL OR linkedin_url ~* '^https?://.+'),
  portfolio_url TEXT CHECK (portfolio_url IS NULL OR portfolio_url ~* '^https?://.+'),
  status TEXT DEFAULT 'applied' CHECK (status IN ('applied', 'shortlisted', 'interview_scheduled', 'accepted', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Table: public.token_validations
CREATE TABLE IF NOT EXISTS public.token_validations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token TEXT NOT NULL,
  full_name TEXT NOT NULL CHECK (char_length(full_name) <= 60),
  email TEXT NOT NULL CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  phone TEXT CHECK (char_length(phone) <= 15),
  payment_info TEXT NOT NULL CHECK (char_length(payment_info) <= 200),
  message TEXT CHECK (char_length(message) <= 1000),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS Enforcement
ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.idea_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.internship_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.token_validations ENABLE ROW LEVEL SECURITY;

-- Insert-only policies for public (anon role)
DROP POLICY IF EXISTS "public_insert_bug_reports" ON public.bug_reports;
CREATE POLICY "public_insert_bug_reports" ON public.bug_reports
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "public_insert_idea_submissions" ON public.idea_submissions;
CREATE POLICY "public_insert_idea_submissions" ON public.idea_submissions
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "public_insert_internship_applications" ON public.internship_applications;
CREATE POLICY "public_insert_internship_applications" ON public.internship_applications
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "public_insert_token_validations" ON public.token_validations;
CREATE POLICY "public_insert_token_validations" ON public.token_validations
  FOR INSERT WITH CHECK (true);
