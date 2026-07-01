-- Migration: Promo Page Analytics
-- Adds granular link-click tracking and analytics RPC functions.

-- 1. Create promo_page_link_clicks table for granular click tracking
CREATE TABLE IF NOT EXISTS public.promo_page_link_clicks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  link_id UUID NOT NULL REFERENCES public.promo_page_links(id) ON DELETE CASCADE,
  page_id UUID NOT NULL REFERENCES public.promo_pages(id) ON DELETE CASCADE,
  referrer TEXT,
  clicked_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_promo_link_clicks_link_id ON public.promo_page_link_clicks(link_id);
CREATE INDEX IF NOT EXISTS idx_promo_link_clicks_page_id ON public.promo_page_link_clicks(page_id);
CREATE INDEX IF NOT EXISTS idx_promo_link_clicks_clicked_at ON public.promo_page_link_clicks(clicked_at);

-- Enable RLS
ALTER TABLE public.promo_page_link_clicks ENABLE ROW LEVEL SECURITY;

-- Owner can read their click data
DROP POLICY IF EXISTS "link_clicks_owner_read" ON public.promo_page_link_clicks;
CREATE POLICY "link_clicks_owner_read" ON public.promo_page_link_clicks FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.promo_pages
      WHERE promo_pages.id = promo_page_link_clicks.page_id
        AND promo_pages.user_id = auth.uid()
    )
  );

-- Anyone can insert click records (public tracking)
DROP POLICY IF EXISTS "link_clicks_public_insert" ON public.promo_page_link_clicks;
CREATE POLICY "link_clicks_public_insert" ON public.promo_page_link_clicks FOR INSERT
  WITH CHECK (true);


-- 2. RPC: Get analytics summary for a promo page
CREATE OR REPLACE FUNCTION public.get_promo_analytics_summary(p_page_id UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
  v_total_views BIGINT;
  v_unique_views BIGINT;
  v_views_today BIGINT;
  v_views_this_week BIGINT;
  v_views_this_month BIGINT;
  v_total_clicks BIGINT;
  v_clicks_today BIGINT;
  v_top_referrers JSON;
  v_views_by_day JSON;
BEGIN
  -- Total views
  SELECT COALESCE(view_count, 0) INTO v_total_views
  FROM public.promo_pages WHERE id = p_page_id;

  -- Unique views (distinct visitor hashes)
  SELECT COUNT(DISTINCT viewer_ip_hash) INTO v_unique_views
  FROM public.promo_page_views WHERE page_id = p_page_id;

  -- Views today
  SELECT COUNT(*) INTO v_views_today
  FROM public.promo_page_views
  WHERE page_id = p_page_id AND viewed_at >= CURRENT_DATE;

  -- Views this week
  SELECT COUNT(*) INTO v_views_this_week
  FROM public.promo_page_views
  WHERE page_id = p_page_id AND viewed_at >= (CURRENT_DATE - INTERVAL '7 days');

  -- Views this month
  SELECT COUNT(*) INTO v_views_this_month
  FROM public.promo_page_views
  WHERE page_id = p_page_id AND viewed_at >= (CURRENT_DATE - INTERVAL '30 days');

  -- Total link clicks
  SELECT COUNT(*) INTO v_total_clicks
  FROM public.promo_page_link_clicks WHERE page_id = p_page_id;

  -- Clicks today
  SELECT COUNT(*) INTO v_clicks_today
  FROM public.promo_page_link_clicks
  WHERE page_id = p_page_id AND clicked_at >= CURRENT_DATE;

  -- Top referrers (top 10 domains)
  SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_top_referrers
  FROM (
    SELECT
      CASE
        WHEN referrer IS NULL OR referrer = '' THEN 'Direct'
        ELSE SPLIT_PART(SPLIT_PART(referrer, '://', 2), '/', 1)
      END AS source,
      COUNT(*) AS count
    FROM public.promo_page_views
    WHERE page_id = p_page_id
    GROUP BY source
    ORDER BY count DESC
    LIMIT 10
  ) r;

  -- Views by day (last 30 days)
  SELECT COALESCE(json_agg(row_to_json(d)), '[]'::json) INTO v_views_by_day
  FROM (
    SELECT
      TO_CHAR(day_date, 'YYYY-MM-DD') AS date,
      COALESCE(view_count, 0) AS views
    FROM generate_series(
      CURRENT_DATE - INTERVAL '29 days',
      CURRENT_DATE,
      INTERVAL '1 day'
    ) AS day_date
    LEFT JOIN (
      SELECT DATE(viewed_at) AS view_date, COUNT(*) AS view_count
      FROM public.promo_page_views
      WHERE page_id = p_page_id AND viewed_at >= (CURRENT_DATE - INTERVAL '30 days')
      GROUP BY view_date
    ) vd ON vd.view_date = day_date::date
    ORDER BY day_date
  ) d;

  -- Build result
  result := json_build_object(
    'total_views', v_total_views,
    'unique_views', v_unique_views,
    'views_today', v_views_today,
    'views_this_week', v_views_this_week,
    'views_this_month', v_views_this_month,
    'total_clicks', v_total_clicks,
    'clicks_today', v_clicks_today,
    'top_referrers', v_top_referrers,
    'views_by_day', v_views_by_day
  );

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. RPC: Get per-link analytics
CREATE OR REPLACE FUNCTION public.get_promo_link_analytics(p_page_id UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT COALESCE(json_agg(row_to_json(la)), '[]'::json) INTO result
  FROM (
    SELECT
      l.id AS link_id,
      l.title,
      l.url,
      l.icon,
      l.click_count AS total_clicks,
      COALESCE(today.clicks_today, 0) AS clicks_today,
      COALESCE(week.clicks_this_week, 0) AS clicks_this_week
    FROM public.promo_page_links l
    LEFT JOIN (
      SELECT link_id, COUNT(*) AS clicks_today
      FROM public.promo_page_link_clicks
      WHERE page_id = p_page_id AND clicked_at >= CURRENT_DATE
      GROUP BY link_id
    ) today ON today.link_id = l.id
    LEFT JOIN (
      SELECT link_id, COUNT(*) AS clicks_this_week
      FROM public.promo_page_link_clicks
      WHERE page_id = p_page_id AND clicked_at >= (CURRENT_DATE - INTERVAL '7 days')
      GROUP BY link_id
    ) week ON week.link_id = l.id
    WHERE l.page_id = p_page_id
    ORDER BY l.click_count DESC
  ) la;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Update increment_promo_link_clicks to also insert into promo_page_link_clicks
CREATE OR REPLACE FUNCTION public.increment_promo_link_clicks(p_link_id UUID, p_referrer TEXT DEFAULT '')
RETURNS VOID AS $$
DECLARE
  v_page_id UUID;
BEGIN
  -- Get page_id from the link
  SELECT page_id INTO v_page_id
  FROM public.promo_page_links WHERE id = p_link_id;

  IF v_page_id IS NULL THEN
    RETURN;
  END IF;

  -- Increment the counter
  UPDATE public.promo_page_links
  SET click_count = click_count + 1
  WHERE id = p_link_id;

  -- Insert granular click record
  INSERT INTO public.promo_page_link_clicks (link_id, page_id, referrer)
  VALUES (p_link_id, v_page_id, p_referrer);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
