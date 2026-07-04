-- Warning Management: Individual warning records with reasons & removal tracking
-- Adds user_warnings table for full audit trail of admin warnings

-- ============================================================
-- 1. USER WARNINGS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_warnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  issued_by UUID NOT NULL REFERENCES public.profiles(id),
  reason TEXT NOT NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'removed')),
  removed_by UUID REFERENCES public.profiles(id),
  removed_at TIMESTAMPTZ,
  removed_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_warnings ENABLE ROW LEVEL SECURITY;

-- Users can read their own warnings
CREATE POLICY "user_warnings_select_own" ON public.user_warnings FOR SELECT
  USING (
    auth.uid() = user_id
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- Only admins can insert warnings
CREATE POLICY "user_warnings_insert_admin" ON public.user_warnings FOR INSERT
  WITH CHECK (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- Only admins can update warnings (for removal)
CREATE POLICY "user_warnings_update_admin" ON public.user_warnings FOR UPDATE
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- Index for fast lookups by user
CREATE INDEX IF NOT EXISTS idx_user_warnings_user_id ON public.user_warnings(user_id);
CREATE INDEX IF NOT EXISTS idx_user_warnings_status ON public.user_warnings(user_id, status);
