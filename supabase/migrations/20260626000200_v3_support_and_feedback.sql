-- Supabase Migration: v3_support_and_feedback
-- Adds support for in-app help articles, feedback/NPS surveys, and referral tracking.

-- 1. Create help_articles table
CREATE TABLE IF NOT EXISTS help_articles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,       -- Markdown formatted content
  category TEXT NOT NULL,      -- 'getting_started' | 'brands' | 'influencers' | 'payments' | 'account'
  target_role TEXT,            -- NULL = both, 'brand', 'influencer'
  is_published BOOLEAN DEFAULT true,
  view_count INT DEFAULT 0,
  helpful_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for help_articles
ALTER TABLE help_articles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select for authenticated users"
ON help_articles
FOR SELECT
TO authenticated
USING (is_published = true);

-- 2. Create feedback table
CREATE TABLE IF NOT EXISTS feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,          -- 'nps' | 'article_feedback' | 'ticket'
  score INT,                   -- 0-10 for NPS, 1/0 for helpful/not helpful
  comment TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for feedback
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow insert for users own feedback"
ON feedback
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow select for users own feedback"
ON feedback
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 3. Add referral column to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES auth.users(id);

-- Seed some help articles for demonstration
INSERT INTO help_articles (title, content, category, target_role)
VALUES 
  ('How do I apply to a brand card?', 'To apply to a brand campaign:\n\n1. Go to the **Discover** tab.\n2. Tap on any campaign card that interests you.\n3. Read the requirements carefully.\n4. Tap **Apply Now** at the bottom.\n5. Customize your pitch message and submit.', 'getting_started', 'influencer'),
  ('How do I create my first card?', 'To publish a brand campaign:\n\n1. Tap the **+** button in the bottom navigation bar or go to your dashboard.\n2. Fill in the title, description, category, and minimum follower requirements.\n3. Input budget terms and define deliverables.\n4. Tap **Publish**.', 'getting_started', 'brand'),
  ('Why hasn''t a brand responded?', 'Brands typically review applications within 3-5 business days. If they accept, you will receive a notification and a chat room will be opened automatically. You can always check the status of your applications in the **Applications** tab.', 'getting_started', 'influencer'),
  ('How do I connect my Instagram?', 'To connect social profiles:\n\n1. Go to **Settings** -> **Linked Accounts**.\n2. Tap **Connect** next to Instagram.\n3. Input your handle and verified follower count.\n4. Save changes. Our system will periodically verify data.', 'account', 'influencer'),
  ('What happens after I accept an application?', 'When you accept a creator''s application:\n\n1. A dedicated collaboration room is created.\n2. You can chat, negotiate milestones, and review deliverables.\n3. Once deliverables are uploaded, you can release payment.', 'getting_started', 'brand')
ON CONFLICT DO NOTHING;
