-- HARDENING: sec-agent 2026-06-24
-- RLS Audit Script
-- Execute these queries to audit and verify that row-level security is active and functioning correctly.

-- 1. Check if RLS is enabled on all tables
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- 2. Verify profiles policies (should return user's own profile and only active profiles for others)
SELECT id, display_name, is_active, preferences FROM public.profiles LIMIT 5;

-- 3. Verify cards policies (only active or own cards should be visible to auth users)
SELECT id, brand_id, title, status, deleted_at FROM public.cards LIMIT 5;

-- 4. Verify applications policies (influencer see own, brand see apps for their cards)
SELECT id, card_id, influencer_id, status FROM public.applications LIMIT 5;

-- 5. Verify rooms policies (participants only)
SELECT id, brand_id, influencer_id, title FROM public.rooms LIMIT 5;

-- 6. Verify messages policies (participants only)
SELECT id, room_id, sender_id, content FROM public.messages LIMIT 5;

-- 7. Verify milestones policies (participants only)
SELECT id, room_id, title, status FROM public.milestones LIMIT 5;

-- 8. Verify group members policies (participants/admin)
SELECT id, room_id, user_id, status FROM public.group_members LIMIT 5;

-- 9. Verify notifications policies (own notifications only)
SELECT id, user_id, title, is_read FROM public.notifications LIMIT 5;

-- 10. Verify user push tokens policies (own only)
SELECT id, user_id, fcm_token FROM public.user_push_tokens LIMIT 5;

-- 11. Verify profile views policies (own only)
SELECT id, profile_id, viewer_id FROM public.profile_views LIMIT 5;

-- 12. Verify reviews policies
SELECT id, room_id, reviewer_id, rating, comment FROM public.reviews LIMIT 5;

-- 13. Verify follows policies
SELECT id, follower_id, following_id FROM public.follows LIMIT 5;

-- 14. Verify saved cards policies (own only)
SELECT id, influencer_id, card_id FROM public.saved_cards LIMIT 5;

-- 15. Verify influencer lists policies (own only)
SELECT id, brand_id, name FROM public.influencer_lists LIMIT 5;

-- 16. Verify influencer list items policies (own only)
SELECT id, list_id, influencer_id FROM public.influencer_list_items LIMIT 5;

-- 17. Verify portfolio items policies (auth only)
SELECT id, owner_id, title, media_url FROM public.portfolio_items LIMIT 5;

-- 18. Verify verification requests policies (own/admin only)
SELECT id, user_id, status, notes FROM public.verification_requests LIMIT 5;

-- 19. Verify audit logs policies (admin only, no public reads)
SELECT id, actor_id, action, target_type FROM public.audit_logs LIMIT 5;
