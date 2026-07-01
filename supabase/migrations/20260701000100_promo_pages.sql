-- Migration: Promo Pages & Links Setup
-- Additive change only. No existing tables modified.

-- 1. Create public.promo_pages Table
CREATE TABLE IF NOT EXISTS public.promo_pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  username TEXT NOT NULL UNIQUE,
  display_name TEXT,
  bio TEXT,
  avatar_url TEXT,
  theme TEXT NOT NULL DEFAULT 'dark',
  background_color TEXT,
  accent_color TEXT,
  show_social_platforms BOOLEAN DEFAULT TRUE,
  show_promo_badge BOOLEAN DEFAULT TRUE,
  is_published BOOLEAN DEFAULT FALSE,
  username_changed_at TIMESTAMPTZ,
  view_count BIGINT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  -- Username format check: only lowercase alphanumeric and underscores, length 3-30
  CONSTRAINT username_check CHECK (username ~ '^[a-z0-9_]{3,30}$'),
  
  -- Reserved word check
  CONSTRAINT username_reserved_check CHECK (
    username NOT IN (
      'admin', 'api', 'app', 'settings', 'login', 'signup', 'register', 
      'promo', 'support', 'help', 'www', 'mail', 'static', 'assets', 
      'public', 'private', 'internal', 'dashboard', 'brand', 'influencer',
      'explore', 'discover', 'search', 'map', 'chat', 'notification',
      'terms', 'privacy', 'delete', 'account', 'profile', 'about', 'contact'
    )
  ),
  
  -- Length constraints
  CONSTRAINT bio_length_check CHECK (char_length(bio) <= 300),
  CONSTRAINT display_name_length_check CHECK (char_length(display_name) <= 60)
);

-- Case-insensitive unique index for username
CREATE UNIQUE INDEX IF NOT EXISTS idx_promo_pages_username ON public.promo_pages(LOWER(username));
CREATE INDEX IF NOT EXISTS idx_promo_pages_user_id ON public.promo_pages(user_id);
CREATE INDEX IF NOT EXISTS idx_promo_pages_published ON public.promo_pages(is_published) WHERE is_published = TRUE;

-- Enable RLS on promo_pages
ALTER TABLE public.promo_pages ENABLE ROW LEVEL SECURITY;

-- promo_pages RLS Policies
DROP POLICY IF EXISTS "promo_pages_owner_all" ON public.promo_pages;
CREATE POLICY "promo_pages_owner_all" ON public.promo_pages
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "promo_pages_public_read" ON public.promo_pages;
CREATE POLICY "promo_pages_public_read" ON public.promo_pages FOR SELECT
  USING (is_published = TRUE);


-- 2. Create public.promo_page_links Table
CREATE TABLE IF NOT EXISTS public.promo_page_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  page_id UUID NOT NULL REFERENCES public.promo_pages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  icon TEXT,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_enabled BOOLEAN DEFAULT TRUE,
  click_count BIGINT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  -- Links constraints
  CONSTRAINT title_length_check CHECK (char_length(title) <= 60),
  CONSTRAINT url_https_check CHECK (url LIKE 'https://%'),
  CONSTRAINT icon_length_check CHECK (char_length(icon) <= 10),
  CONSTRAINT display_order_check CHECK (display_order >= 0)
);

CREATE INDEX IF NOT EXISTS idx_promo_page_links_page_id ON public.promo_page_links(page_id);
CREATE INDEX IF NOT EXISTS idx_promo_page_links_user_id ON public.promo_page_links(user_id);

-- Enforce maximum of 20 links per page at database level
CREATE OR REPLACE FUNCTION public.check_promo_page_links_limit()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT count(*) FROM public.promo_page_links WHERE page_id = NEW.page_id) >= 20 THEN
    RAISE EX TRIGGER_LIMIT_EXCEPTION; -- will be raised in plpgsql below
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Correct Exception Raising in check_promo_page_links_limit
CREATE OR REPLACE FUNCTION public.check_promo_page_links_limit()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT count(*) FROM public.promo_page_links WHERE page_id = NEW.page_id) >= 20 THEN
    RAISE EXCEPTION 'Maximum limit of 20 links per page reached.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_links_limit_trigger ON public.promo_page_links;
CREATE TRIGGER check_links_limit_trigger
BEFORE INSERT ON public.promo_page_links
FOR EACH ROW
EXECUTE FUNCTION public.check_promo_page_links_limit();

-- Enable RLS on promo_page_links
ALTER TABLE public.promo_page_links ENABLE ROW LEVEL SECURITY;

-- promo_page_links RLS Policies
DROP POLICY IF EXISTS "page_links_owner_all" ON public.promo_page_links;
CREATE POLICY "page_links_owner_all" ON public.promo_page_links
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "page_links_public_read" ON public.promo_page_links;
CREATE POLICY "page_links_public_read" ON public.promo_page_links FOR SELECT
  USING (
    is_enabled = TRUE AND
    EXISTS (
      SELECT 1 FROM public.promo_pages
      WHERE promo_pages.id = promo_page_links.page_id
        AND promo_pages.is_published = TRUE
    )
  );


-- 3. Create public.promo_page_views Table
CREATE TABLE IF NOT EXISTS public.promo_page_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  page_id UUID NOT NULL REFERENCES public.promo_pages(id) ON DELETE CASCADE,
  viewer_ip_hash TEXT,
  referrer TEXT,
  viewed_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_promo_page_views_page_id ON public.promo_page_views(page_id);

-- Enable RLS on promo_page_views
ALTER TABLE public.promo_page_views ENABLE ROW LEVEL SECURITY;

-- promo_page_views RLS Policies
DROP POLICY IF EXISTS "page_views_owner_read" ON public.promo_page_views;
CREATE POLICY "page_views_owner_read" ON public.promo_page_views FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.promo_pages
      WHERE promo_pages.id = promo_page_views.page_id
        AND promo_pages.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "page_views_public_insert" ON public.promo_page_views;
CREATE POLICY "page_views_public_insert" ON public.promo_page_views FOR INSERT
  WITH CHECK (true);


-- 4. RPC Function to increment view_count on page visit
CREATE OR REPLACE FUNCTION public.increment_promo_page_views(p_page_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.promo_pages
  SET view_count = view_count + 1
  WHERE id = p_page_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC Function to increment link click_count
CREATE OR REPLACE FUNCTION public.increment_promo_link_clicks(p_link_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.promo_page_links
  SET click_count = click_count + 1
  WHERE id = p_link_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
