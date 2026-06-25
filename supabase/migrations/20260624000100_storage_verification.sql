-- HARDENING: sec-agent 2026-06-24
-- Storage verification bucket and RLS policies

INSERT INTO storage.buckets (id, name, public)
VALUES ('verification', 'verification', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users can upload own verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can read own verification documents" ON storage.objects;

CREATE POLICY "Users can upload own verification documents" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'verification' AND (auth.uid())::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can read own verification documents" ON storage.objects FOR SELECT
  USING (bucket_id = 'verification' AND ((auth.uid())::text = (storage.foldername(name))[1] OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'));
