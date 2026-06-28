-- HARDENING-V2: trust-agent 2026-06-26
-- V2.0 Migration: Trust & Safety, Agreements, Payments, Onboarding Intelligence,
-- Notification Queue, Platform Config, Admin Enhancements

-- ============================================================
-- 1. PROFILES TABLE EXTENSIONS
-- ============================================================
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS account_status TEXT DEFAULT 'active'
  CHECK (account_status IN ('active', 'warned', 'suspended', 'banned', 'under_review'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS suspension_reason TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS suspension_until TIMESTAMPTZ;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS warning_count INT DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS ab_variant TEXT DEFAULT 'A';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- ============================================================
-- 2. AUDIT_LOGS TABLE EXTENSIONS
-- ============================================================
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS action_category TEXT
  CHECK (action_category IN ('auth', 'push', 'admin', 'moderation', 'data', 'payment', 'trust'));
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS target_user_id UUID;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS before_state JSONB;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS after_state JSONB;

-- ============================================================
-- 3. USER REPORTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES public.profiles(id),
  reported_id UUID REFERENCES public.profiles(id),
  reported_card_id UUID REFERENCES public.cards(id),
  reported_message_id UUID REFERENCES public.messages(id),
  reason TEXT NOT NULL CHECK (reason IN (
    'spam', 'scam', 'fake_profile', 'inappropriate_content',
    'harassment', 'hate_speech', 'misleading_information',
    'underage_user', 'other'
  )),
  details TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'actioned', 'dismissed')),
  admin_note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

-- Reporter can insert their own reports
CREATE POLICY "user_reports_insert" ON public.user_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

-- Reporter can read their own reports
CREATE POLICY "user_reports_select_own" ON public.user_reports FOR SELECT
  USING (auth.uid() = reporter_id
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- Admin can update reports
CREATE POLICY "user_reports_update_admin" ON public.user_reports FOR UPDATE
  USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- ============================================================
-- 4. USER BLOCKS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES public.profiles(id),
  blocked_id UUID NOT NULL REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(blocker_id, blocked_id)
);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

-- Users can manage their own blocks
CREATE POLICY "user_blocks_select" ON public.user_blocks FOR SELECT
  USING (auth.uid() = blocker_id);
CREATE POLICY "user_blocks_insert" ON public.user_blocks FOR INSERT
  WITH CHECK (auth.uid() = blocker_id AND blocker_id != blocked_id);
CREATE POLICY "user_blocks_delete" ON public.user_blocks FOR DELETE
  USING (auth.uid() = blocker_id);

-- ============================================================
-- 5. COLLABORATION AGREEMENTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.collaboration_agreements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL,
  card_id UUID NOT NULL REFERENCES public.cards(id),
  brand_id UUID NOT NULL REFERENCES public.profiles(id),
  influencer_id UUID NOT NULL REFERENCES public.profiles(id),

  deliverables JSONB NOT NULL DEFAULT '[]',
  total_budget TEXT NOT NULL,
  payment_terms TEXT NOT NULL CHECK (payment_terms IN ('upfront', 'on_delivery', 'milestone_based')),
  timeline_days INT NOT NULL DEFAULT 30,
  revision_rounds INT DEFAULT 2,
  usage_rights TEXT NOT NULL CHECK (usage_rights IN ('one_time', 'perpetual', 'limited')),
  exclusivity_days INT DEFAULT 0,

  brand_accepted_at TIMESTAMPTZ,
  influencer_accepted_at TIMESTAMPTZ,

  status TEXT DEFAULT 'draft' CHECK (status IN (
    'draft', 'sent_to_influencer', 'negotiating', 'both_accepted',
    'completed', 'disputed', 'cancelled'
  )),

  dispute_reason TEXT,
  dispute_raised_by UUID REFERENCES public.profiles(id),
  dispute_raised_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.collaboration_agreements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "agreements_select" ON public.collaboration_agreements FOR SELECT
  USING (auth.uid() = brand_id OR auth.uid() = influencer_id
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY "agreements_insert" ON public.collaboration_agreements FOR INSERT
  WITH CHECK (auth.uid() = brand_id);
CREATE POLICY "agreements_update" ON public.collaboration_agreements FOR UPDATE
  USING (auth.uid() = brand_id OR auth.uid() = influencer_id);

-- ============================================================
-- 6. PAYMENT RECORDS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.payment_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agreement_id UUID NOT NULL REFERENCES public.collaboration_agreements(id),
  room_id UUID NOT NULL,
  brand_id UUID NOT NULL REFERENCES public.profiles(id),
  influencer_id UUID NOT NULL REFERENCES public.profiles(id),

  amount TEXT NOT NULL,
  currency TEXT DEFAULT 'USD',

  status TEXT DEFAULT 'pending' CHECK (status IN (
    'pending', 'brand_marked_sent', 'influencer_confirmed', 'disputed', 'completed'
  )),

  payment_method TEXT,
  brand_note TEXT,
  influencer_note TEXT,

  brand_marked_sent_at TIMESTAMPTZ,
  influencer_confirmed_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.payment_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payments_select" ON public.payment_records FOR SELECT
  USING (auth.uid() = brand_id OR auth.uid() = influencer_id
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY "payments_insert" ON public.payment_records FOR INSERT
  WITH CHECK (auth.uid() = brand_id);
CREATE POLICY "payments_update" ON public.payment_records FOR UPDATE
  USING (auth.uid() = brand_id OR auth.uid() = influencer_id);

-- ============================================================
-- 7. DISPUTES TABLE
-- ============================================================
DROP TABLE IF EXISTS public.disputes CASCADE;
CREATE TABLE IF NOT EXISTS public.disputes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agreement_id UUID REFERENCES public.collaboration_agreements(id),
  payment_id UUID REFERENCES public.payment_records(id),
  raised_by UUID NOT NULL REFERENCES public.profiles(id),
  against UUID NOT NULL REFERENCES public.profiles(id),
  category TEXT CHECK (category IN (
    'payment_not_received', 'content_not_delivered', 'content_quality',
    'agreement_violation', 'communication_breakdown', 'other'
  )),
  description TEXT NOT NULL,
  evidence_urls TEXT[],
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'resolved', 'escalated')),
  resolution TEXT,
  admin_note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "disputes_select" ON public.disputes FOR SELECT
  USING (auth.uid() = raised_by OR auth.uid() = against
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY "disputes_insert" ON public.disputes FOR INSERT
  WITH CHECK (auth.uid() = raised_by);
CREATE POLICY "disputes_update" ON public.disputes FOR UPDATE
  USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- ============================================================
-- 8. ONBOARDING EVENTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.onboarding_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id),
  step_number INT NOT NULL,
  step_name TEXT NOT NULL,
  event_type TEXT CHECK (event_type IN ('started', 'completed', 'skipped', 'abandoned')),
  time_spent_seconds INT,
  error_encountered TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.onboarding_events ENABLE ROW LEVEL SECURITY;

-- Users can insert their own events, admin can read all
CREATE POLICY "onboarding_events_insert" ON public.onboarding_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "onboarding_events_select" ON public.onboarding_events FOR SELECT
  USING (auth.uid() = user_id
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- ============================================================
-- 9. NOTIFICATION QUEUE TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notification_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id),
  type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  scheduled_for TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notification_queue ENABLE ROW LEVEL SECURITY;

-- Only service role should insert/read; no user access
-- (Edge functions or service role bypass RLS)

-- ============================================================
-- 10. PLATFORM CONFIG TABLE (Remote Feature Flags)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.platform_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES public.profiles(id)
);

ALTER TABLE public.platform_config ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can read config; only admin can write
CREATE POLICY "platform_config_select" ON public.platform_config FOR SELECT
  USING (auth.role() = 'authenticated');
CREATE POLICY "platform_config_update" ON public.platform_config FOR UPDATE
  USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- Seed initial config values
INSERT INTO public.platform_config (key, value, description) VALUES
  ('max_cards_per_brand_per_day', '10', 'Maximum cards a brand can create per day'),
  ('max_applications_per_influencer_per_day', '20', 'Maximum applications per influencer per day'),
  ('onboarding_required_completion_pct', '60', 'Min profile completeness to post a card'),
  ('auto_suspend_report_threshold', '5', 'Pending reports before auto-suspension'),
  ('featured_categories', '["Fashion","Tech","Food","Travel","Beauty","Fitness","Gaming","Lifestyle"]', 'Categories shown in featured section'),
  ('maintenance_mode', 'false', 'If true, show maintenance screen to all users'),
  ('min_app_version', '"1.0.1"', 'Minimum supported app version'),
  ('max_file_upload_mb', '10', 'Maximum file upload size in MB')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- 11. SEARCH EVENTS TABLE (Analytics)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.search_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id),
  query TEXT NOT NULL,
  result_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.search_events ENABLE ROW LEVEL SECURITY;

-- Users can insert their own search events
CREATE POLICY "search_events_insert" ON public.search_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "search_events_select_admin" ON public.search_events FOR SELECT
  USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- ============================================================
-- 12. SOFT DELETE — Ensure deleted_at exists on key tables
-- (Some already have it from V1.0; this is idempotent)
-- ============================================================
ALTER TABLE public.cards ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS group_count INT DEFAULT 1;
