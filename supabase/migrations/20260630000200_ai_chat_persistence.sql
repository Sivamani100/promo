-- V4.2 Migration: AI Assistant Chat History Persistence
-- This migration creates the public.ai_assistant_chats table
-- and secures it via Row Level Security (RLS).

-- 1. Create ai_assistant_chats Table
CREATE TABLE IF NOT EXISTS public.ai_assistant_chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  is_user BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Enable Row Level Security (RLS)
ALTER TABLE public.ai_assistant_chats ENABLE ROW LEVEL SECURITY;

-- 3. Set up RLS policies
DROP POLICY IF EXISTS "ai_assistant_chats_select" ON public.ai_assistant_chats;
DROP POLICY IF EXISTS "ai_assistant_chats_insert" ON public.ai_assistant_chats;
DROP POLICY IF EXISTS "ai_assistant_chats_delete" ON public.ai_assistant_chats;

CREATE POLICY "ai_assistant_chats_select" ON public.ai_assistant_chats FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "ai_assistant_chats_insert" ON public.ai_assistant_chats FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "ai_assistant_chats_delete" ON public.ai_assistant_chats FOR DELETE
  USING (auth.uid() = user_id);
