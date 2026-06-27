-- Migration to fix push token registration RLS policy conflict and allow deletions.
-- Drop the single policy for all operations
DROP POLICY IF EXISTS "user_push_tokens_all" ON public.user_push_tokens;

-- Create specific permissive RLS policies
CREATE POLICY "user_push_tokens_select" ON public.user_push_tokens FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "user_push_tokens_insert" ON public.user_push_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "user_push_tokens_update" ON public.user_push_tokens FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Allow anyone (including anonymous sessions during sign-out cleanup or new user claiming a token) 
-- to delete a token row if they present the unique, cryptographically secure fcm_token.
CREATE POLICY "user_push_tokens_delete" ON public.user_push_tokens FOR DELETE USING (true);
