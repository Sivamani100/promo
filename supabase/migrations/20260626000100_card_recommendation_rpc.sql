-- V2.0 Migration: Card Recommendation RPC
-- Creates a SQL function/RPC `get_recommended_cards(influencer_id)` that returns active campaign cards scored by relevance to a given influencer.

CREATE OR REPLACE FUNCTION public.get_recommended_cards(p_influencer_id UUID)
RETURNS TABLE (
  id UUID,
  brand_id UUID,
  title TEXT,
  description TEXT,
  category TEXT,
  niche_tags TEXT[],
  platform_requirements TEXT[],
  min_followers INT,
  budget_range TEXT,
  deliverables TEXT[],
  timeline TEXT,
  cover_image_url TEXT,
  status TEXT,
  application_deadline TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  preferred_location TEXT,
  deleted_at TIMESTAMPTZ,
  openings INT,
  recommendation_score FLOAT8
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_niche TEXT[];
  v_location TEXT;
  v_follower_count INT;
  v_platforms TEXT[];
BEGIN
  -- Fetch influencer profile details
  SELECT niche, location, follower_count, platforms
  INTO v_niche, v_location, v_follower_count, v_platforms
  FROM public.profiles
  WHERE profiles.id = p_influencer_id;

  RETURN QUERY
  SELECT 
    c.id,
    c.brand_id,
    c.title,
    c.description,
    c.category,
    c.niche_tags,
    c.platform_requirements,
    c.min_followers,
    c.budget_range,
    c.deliverables,
    c.timeline,
    c.cover_image_url,
    c.status,
    c.application_deadline,
    c.created_at,
    c.updated_at,
    c.preferred_location,
    c.deleted_at,
    c.openings,
    (
      -- Niche/Category Alignment Score
      COALESCE(
        CASE 
          WHEN c.category = ANY(v_niche) THEN 30.0 
          ELSE 0.0 
        END, 0.0
      ) +
      COALESCE(
        (
          SELECT COUNT(*)::FLOAT8 * 10.0
          FROM unnest(c.niche_tags) ct
          WHERE ct = ANY(v_niche)
        ), 0.0
      ) +
      -- Platform Requirements Score
      COALESCE(
        CASE 
          WHEN c.platform_requirements && v_platforms THEN 20.0 
          ELSE 0.0 
        END, 0.0
      ) +
      -- Preferred Location Score
      COALESCE(
        CASE 
          WHEN c.preferred_location IS NOT NULL AND v_location IS NOT NULL AND 
               (c.preferred_location ILIKE '%' || v_location || '%' OR v_location ILIKE '%' || c.preferred_location || '%') THEN 25.0
          WHEN c.preferred_location IS NOT NULL AND c.preferred_location ILIKE 'global' THEN 10.0
          ELSE 0.0
        END, 0.0
      ) +
      -- Follower Count Score
      COALESCE(
        CASE 
          WHEN c.min_followers IS NULL OR c.min_followers = 0 THEN 15.0
          WHEN v_follower_count >= c.min_followers THEN 15.0
          ELSE 0.0
        END, 0.0
      )
    )::FLOAT8 AS recommendation_score
  FROM public.cards c
  WHERE c.status = 'active' 
    AND c.deleted_at IS NULL
  ORDER BY recommendation_score DESC, c.created_at DESC;
END;
$$;
