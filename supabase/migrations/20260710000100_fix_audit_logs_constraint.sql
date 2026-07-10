-- Migration: 20260710000100_fix_audit_logs_constraint.sql
-- Fix audit_logs action_category check constraint to allow user_profile and system_config actions

ALTER TABLE public.audit_logs DROP CONSTRAINT IF EXISTS audit_logs_action_category_check;
ALTER TABLE public.audit_logs ADD CONSTRAINT audit_logs_action_category_check 
  CHECK (action_category IN ('auth', 'push', 'admin', 'moderation', 'data', 'payment', 'trust', 'user_profile', 'system_config', 'authenticated'));
