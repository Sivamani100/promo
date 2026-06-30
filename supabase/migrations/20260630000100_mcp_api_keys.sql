-- V4.1 Migration: AI Agent (MCP) API Keys Schema & Postgres Gateways
-- This migration sets up the public.mcp_keys and public.mcp_key_logs tables
-- with Row Level Security (RLS) policies and transaction helper functions.

-- Ensure pgcrypto extension is active for digest() hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Create mcp_keys Table
CREATE TABLE IF NOT EXISTS public.mcp_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  key_hash TEXT UNIQUE NOT NULL, -- SHA-256 hash of the raw token
  scopes TEXT[] DEFAULT '{"read_only"}'::TEXT[] NOT NULL, -- Supports 'read_only' and 'full_access'
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ, -- Null if never expires
  revoked_at TIMESTAMPTZ, -- Null if active
  last_used_at TIMESTAMPTZ,
  rate_limit_counter INT DEFAULT 0,
  rate_limit_reset_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Create mcp_key_logs Table (Append-only)
CREATE TABLE IF NOT EXISTS public.mcp_key_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key_id UUID NOT NULL REFERENCES public.mcp_keys(id) ON DELETE CASCADE,
  action_name TEXT NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT now(),
  success BOOLEAN NOT NULL,
  description TEXT
);

-- 3. Enable RLS on both tables
ALTER TABLE public.mcp_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mcp_key_logs ENABLE ROW LEVEL SECURITY;

-- 4. Set up mcp_keys policies
DROP POLICY IF EXISTS "mcp_keys_select" ON public.mcp_keys;
DROP POLICY IF EXISTS "mcp_keys_insert" ON public.mcp_keys;
DROP POLICY IF EXISTS "mcp_keys_update" ON public.mcp_keys;
DROP POLICY IF EXISTS "mcp_keys_delete" ON public.mcp_keys;

CREATE POLICY "mcp_keys_select" ON public.mcp_keys FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "mcp_keys_insert" ON public.mcp_keys FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "mcp_keys_update" ON public.mcp_keys FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "mcp_keys_delete" ON public.mcp_keys FOR DELETE
  USING (auth.uid() = user_id);

-- 5. Set up mcp_key_logs policies
DROP POLICY IF EXISTS "mcp_key_logs_select" ON public.mcp_key_logs;

CREATE POLICY "mcp_key_logs_select" ON public.mcp_key_logs FOR SELECT
  USING (auth.uid() = (SELECT user_id FROM public.mcp_keys WHERE id = key_id));

-- 6. RPC: generate_mcp_key (creates and hashes token internally in one transaction)
CREATE OR REPLACE FUNCTION public.generate_mcp_key(p_name TEXT, p_expires_at TIMESTAMPTZ, p_scopes TEXT[])
RETURNS TABLE (raw_key TEXT, key_id UUID) AS $$
DECLARE
  v_raw TEXT;
  v_hash TEXT;
  v_key_id UUID;
BEGIN
  -- Generate cryptographically secure random token (64 hex characters prefix with mcp_live_)
  v_raw := 'mcp_live_' || encode(gen_random_bytes(32), 'hex');
  -- Compute SHA-256 hash of the raw token
  v_hash := encode(digest(v_raw, 'sha256'), 'hex');

  INSERT INTO public.mcp_keys (user_id, name, key_hash, scopes, expires_at)
  VALUES (auth.uid(), p_name, v_hash, p_scopes, p_expires_at)
  RETURNING id INTO v_key_id;

  RETURN QUERY SELECT v_raw, v_key_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: validate_and_increment_mcp_key (validates, checks rate limits, and updates counter)
CREATE OR REPLACE FUNCTION public.validate_and_increment_mcp_key(p_key_hash TEXT)
RETURNS TABLE (
  valid BOOLEAN,
  key_id UUID,
  user_id UUID,
  role TEXT,
  scopes TEXT[],
  error_message TEXT
) AS $$
DECLARE
  v_key_id UUID;
  v_user_id UUID;
  v_role TEXT;
  v_scopes TEXT[];
  v_expires_at TIMESTAMPTZ;
  v_revoked_at TIMESTAMPTZ;
  v_counter INT;
  v_reset_at TIMESTAMPTZ;
BEGIN
  SELECT id, user_id, expires_at, revoked_at, rate_limit_counter, rate_limit_reset_at, scopes
  INTO v_key_id, v_user_id, v_expires_at, v_revoked_at, v_counter, v_reset_at, v_scopes
  FROM public.mcp_keys
  WHERE key_hash = p_key_hash;

  IF v_key_id IS NULL THEN
    RETURN QUERY SELECT FALSE, NULL::UUID, NULL::UUID, NULL::TEXT, NULL::TEXT[], 'Key not found'::TEXT;
    RETURN;
  END IF;

  IF v_revoked_at IS NOT NULL THEN
    RETURN QUERY SELECT FALSE, v_key_id, NULL::UUID, NULL::TEXT, NULL::TEXT[], 'Key has been revoked'::TEXT;
    RETURN;
  END IF;

  IF v_expires_at IS NOT NULL AND v_expires_at < now() THEN
    RETURN QUERY SELECT FALSE, v_key_id, NULL::UUID, NULL::TEXT, NULL::TEXT[], 'Key has expired'::TEXT;
    RETURN;
  END IF;

  -- Rate limit check (60 requests per hour)
  IF v_reset_at IS NULL OR now() > v_reset_at THEN
    v_counter := 1;
    v_reset_at := now() + interval '1 hour';
  ELSE
    IF v_counter >= 60 THEN
      RETURN QUERY SELECT FALSE, v_key_id, NULL::UUID, NULL::TEXT, NULL::TEXT[], 'Rate limit exceeded (max 60 requests per hour)'::TEXT;
      RETURN;
    END IF;
    v_counter := v_counter + 1;
  END IF;

  -- Update key stats
  UPDATE public.mcp_keys
  SET rate_limit_counter = v_counter,
      rate_limit_reset_at = v_reset_at,
      last_used_at = now()
  WHERE id = v_key_id;

  -- Get user role
  SELECT role INTO v_role FROM public.profiles WHERE id = v_user_id;

  RETURN QUERY SELECT TRUE, v_key_id, v_user_id, v_role, v_scopes, NULL::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
