-- V4.0 Migration: Admin Dashboard Consoles & RLS Policy Adjustments
-- This migration ensures administrators can bypass standard user-level RLS policies 
-- to view chat histories, audit logs, campaign details, profile views, and moderate campaigns.

-- 1. Create is_admin helper function (SECURITY DEFINER to prevent recursion on profiles)
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = user_id AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 1.5 Update cards status check constraint to include 'suspended' status
ALTER TABLE public.cards DROP CONSTRAINT IF EXISTS cards_status_check;
ALTER TABLE public.cards ADD CONSTRAINT cards_status_check CHECK (status = ANY (ARRAY['active'::text, 'paused'::text, 'closed'::text, 'draft'::text, 'suspended'::text]));

-- 2. Drop old policies if they exist to prevent conflicts
DROP POLICY IF EXISTS "audit_logs_admin_select" ON public.audit_logs;
DROP POLICY IF EXISTS "audit_logs_authenticated_insert" ON public.audit_logs;
DROP POLICY IF EXISTS "profiles_admin_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_update" ON public.profiles;
DROP POLICY IF EXISTS "cards_admin_select" ON public.cards;
DROP POLICY IF EXISTS "cards_admin_update" ON public.cards;
DROP POLICY IF EXISTS "applications_admin_select" ON public.applications;
DROP POLICY IF EXISTS "rooms_admin_select" ON public.rooms;
DROP POLICY IF EXISTS "messages_admin_select" ON public.messages;
DROP POLICY IF EXISTS "profile_views_admin_select" ON public.profile_views;

-- 3. AUDIT_LOGS policies
CREATE POLICY "audit_logs_admin_select" ON public.audit_logs FOR SELECT
  USING (is_admin(auth.uid()));

CREATE POLICY "audit_logs_authenticated_insert" ON public.audit_logs FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- 4. PROFILES policies
CREATE POLICY "profiles_admin_select" ON public.profiles FOR SELECT
  USING (is_admin(auth.uid()));

CREATE POLICY "profiles_admin_update" ON public.profiles FOR UPDATE
  USING (is_admin(auth.uid()))
  WITH CHECK (is_admin(auth.uid()));

-- 5. CARDS policies
CREATE POLICY "cards_admin_select" ON public.cards FOR SELECT
  USING (is_admin(auth.uid()));

CREATE POLICY "cards_admin_update" ON public.cards FOR UPDATE
  USING (is_admin(auth.uid()))
  WITH CHECK (is_admin(auth.uid()));

-- 6. APPLICATIONS policies
CREATE POLICY "applications_admin_select" ON public.applications FOR SELECT
  USING (is_admin(auth.uid()));

-- 7. ROOMS policies
CREATE POLICY "rooms_admin_select" ON public.rooms FOR SELECT
  USING (is_admin(auth.uid()));

-- 8. MESSAGES policies
CREATE POLICY "messages_admin_select" ON public.messages FOR SELECT
  USING (is_admin(auth.uid()));

-- 9. PROFILE_VIEWS policies
CREATE POLICY "profile_views_admin_select" ON public.profile_views FOR SELECT
  USING (is_admin(auth.uid()));
