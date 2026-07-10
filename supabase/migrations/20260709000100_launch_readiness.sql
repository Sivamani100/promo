-- ===========================================================================
-- Migration: 20260709000100_launch_readiness.sql
-- Play Store Launch Readiness: platform_config, bug_reports, idea_submissions
-- + Admin maintenance mode RPC
-- ===========================================================================

-- ─── 1. platform_config ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.platform_config (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  key        TEXT        UNIQUE NOT NULL,
  value      JSONB       NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.platform_config ENABLE ROW LEVEL SECURITY;

-- Allow public anon + authenticated reads (app needs this on cold start)
DROP POLICY IF EXISTS "platform_config_public_read" ON public.platform_config;
CREATE POLICY "platform_config_public_read" ON public.platform_config
  FOR SELECT USING (true);

-- Only service_role writes (admin actions use SECURITY DEFINER RPC below)
DROP POLICY IF EXISTS "platform_config_service_write" ON public.platform_config;
CREATE POLICY "platform_config_service_write" ON public.platform_config
  FOR ALL USING (auth.role() = 'service_role');

-- Seed default rows; safe to re-run
INSERT INTO public.platform_config (key, value)
VALUES
  ('maintenance_mode',  'false'::jsonb),
  ('min_app_version',   '"1.0.0"'::jsonb),
  ('store_url_android', '"https://play.google.com/store/apps/details?id=com.brand.promo"'::jsonb),
  ('store_url_ios',     '"https://apps.apple.com/app/promo/id0000000000"'::jsonb)
ON CONFLICT (key) DO NOTHING;


-- ─── 2. feedback ───────────────────────────────────────────────────────────
-- Table may already exist from v3 migration; add missing constraints safely.
DO $$
BEGIN
  -- Add type constraint if not already present
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'feedback_type_check' AND conrelid = 'public.feedback'::regclass
  ) THEN
    ALTER TABLE public.feedback
      ADD CONSTRAINT feedback_type_check
      CHECK (type IN ('nps', 'general', 'rating', 'article_feedback', 'ticket'));
  END IF;

  -- Add score constraint if not already present
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'feedback_score_check' AND conrelid = 'public.feedback'::regclass
  ) THEN
    ALTER TABLE public.feedback
      ADD CONSTRAINT feedback_score_check
      CHECK (score IS NULL OR (score >= 1 AND score <= 10));
  END IF;

  -- Make user_id NOT NULL if not already (backfill nulls first)
  UPDATE public.feedback SET user_id = gen_random_uuid() WHERE user_id IS NULL;
  BEGIN
    ALTER TABLE public.feedback ALTER COLUMN user_id SET NOT NULL;
  EXCEPTION WHEN OTHERS THEN NULL; END;
END$$;

-- Ensure both policies exist
DROP POLICY IF EXISTS "feedback_insert" ON public.feedback;
CREATE POLICY "feedback_insert" ON public.feedback
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "feedback_select_own" ON public.feedback;
CREATE POLICY "feedback_select_own" ON public.feedback
  FOR SELECT USING (auth.uid() = user_id);

-- Allow service_role to read all feedback (for admin dashboard)
DROP POLICY IF EXISTS "feedback_admin_select" ON public.feedback;
CREATE POLICY "feedback_admin_select" ON public.feedback
  FOR SELECT USING (auth.role() = 'service_role');


-- ─── 3. bug_reports ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.bug_reports (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  title              TEXT        NOT NULL CHECK (char_length(title) <= 100),
  description        TEXT        NOT NULL,
  steps_to_reproduce TEXT,
  screen_or_feature  TEXT,
  severity           TEXT        NOT NULL DEFAULT 'medium'
                                 CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  device_type        TEXT        NOT NULL DEFAULT 'Android'
                                 CHECK (device_type IN ('Android', 'iOS', 'Web')),
  submitter_name     TEXT,
  submitter_email    TEXT,
  status             TEXT        NOT NULL DEFAULT 'received'
                                 CHECK (status IN ('received', 'investigating', 'resolved', 'wont_fix')),
  created_at         TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bug_reports_insert" ON public.bug_reports;
CREATE POLICY "bug_reports_insert" ON public.bug_reports
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "bug_reports_admin_select" ON public.bug_reports;
CREATE POLICY "bug_reports_admin_select" ON public.bug_reports
  FOR SELECT USING (auth.role() = 'service_role');


-- ─── 4. idea_submissions ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.idea_submissions (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  title            TEXT        NOT NULL CHECK (char_length(title) <= 100),
  description      TEXT        NOT NULL,
  problem_it_solves TEXT,
  category         TEXT        NOT NULL DEFAULT 'other'
                               CHECK (category IN ('discovery', 'chat', 'profile', 'cards', 'analytics', 'other')),
  submitter_name   TEXT,
  submitter_email  TEXT,
  upvotes          INT         DEFAULT 0,
  status           TEXT        NOT NULL DEFAULT 'submitted'
                               CHECK (status IN ('submitted', 'under_review', 'planned', 'shipped', 'declined')),
  created_at       TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.idea_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "idea_submissions_insert" ON public.idea_submissions;
CREATE POLICY "idea_submissions_insert" ON public.idea_submissions
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "idea_submissions_admin_select" ON public.idea_submissions;
CREATE POLICY "idea_submissions_admin_select" ON public.idea_submissions
  FOR SELECT USING (auth.role() = 'service_role');


-- ─── 5. Admin RPC: set_maintenance_mode ────────────────────────────────────
-- SECURITY DEFINER allows anon-level Flutter code signed as admin to call
-- this and have it run as service_role (bypass RLS write restriction).
CREATE OR REPLACE FUNCTION public.set_maintenance_mode(p_enabled BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.platform_config (key, value)
    VALUES ('maintenance_mode', to_jsonb(p_enabled))
  ON CONFLICT (key)
    DO UPDATE SET value = to_jsonb(p_enabled), updated_at = now();
END;
$$;

-- ─── 6. Admin RPC: set_min_app_version ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_min_app_version(p_version TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.platform_config (key, value)
    VALUES ('min_app_version', to_jsonb(p_version))
  ON CONFLICT (key)
    DO UPDATE SET value = to_jsonb(p_version), updated_at = now();
END;
$$;

-- ─── 7. Indexes for performance ────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_feedback_user_id    ON public.feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_feedback_type        ON public.feedback(type);
CREATE INDEX IF NOT EXISTS idx_bug_reports_status   ON public.bug_reports(status);
CREATE INDEX IF NOT EXISTS idx_bug_reports_severity ON public.bug_reports(severity);
CREATE INDEX IF NOT EXISTS idx_idea_status          ON public.idea_submissions(status);
