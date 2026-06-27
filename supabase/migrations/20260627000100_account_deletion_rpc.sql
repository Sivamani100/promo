-- Migration: Create delete_user_account SECURITY DEFINER RPC function
-- Description: Cascades user data deletion across NO ACTION tables and auth.users

CREATE OR REPLACE FUNCTION public.delete_user_account(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update referred_by to null for anyone this user referred
  UPDATE public.profiles SET referred_by = NULL WHERE referred_by = p_user_id;

  -- Delete messages in rooms where the user is brand or influencer
  DELETE FROM public.messages
  WHERE sender_id = p_user_id
     OR room_id IN (
       SELECT id FROM public.rooms 
       WHERE brand_id = p_user_id 
          OR influencer_id = p_user_id
     );

  -- Delete payment records related to agreements of the user
  DELETE FROM public.payment_records
  WHERE brand_id = p_user_id
     OR influencer_id = p_user_id
     OR agreement_id IN (
       SELECT id FROM public.collaboration_agreements
       WHERE brand_id = p_user_id
          OR influencer_id = p_user_id
     );

  -- Delete disputes
  DELETE FROM public.disputes
  WHERE raised_by = p_user_id
     OR against = p_user_id
     OR agreement_id IN (
       SELECT id FROM public.collaboration_agreements
       WHERE brand_id = p_user_id
          OR influencer_id = p_user_id
     );

  -- Delete milestones
  DELETE FROM public.milestones
  WHERE agreement_id IN (
    SELECT id FROM public.collaboration_agreements
    WHERE brand_id = p_user_id
       OR influencer_id = p_user_id
  );

  -- Delete collaboration agreements
  DELETE FROM public.collaboration_agreements
  WHERE brand_id = p_user_id
     OR influencer_id = p_user_id;

  -- Delete group/room members
  DELETE FROM public.group_members
  WHERE user_id = p_user_id
     OR room_id IN (
       SELECT id FROM public.rooms 
       WHERE brand_id = p_user_id 
          OR influencer_id = p_user_id
     );

  -- Delete rooms
  DELETE FROM public.rooms
  WHERE brand_id = p_user_id
     OR influencer_id = p_user_id
     OR card_id IN (
       SELECT id FROM public.cards
       WHERE brand_id = p_user_id
     );

  -- Delete user reports
  DELETE FROM public.user_reports
  WHERE reporter_id = p_user_id
     OR reported_id = p_user_id
     OR reported_card_id IN (
       SELECT id FROM public.cards
       WHERE brand_id = p_user_id
     );

  -- Delete user blocks
  DELETE FROM public.user_blocks
  WHERE blocker_id = p_user_id
     OR blocked_id = p_user_id;

  -- Delete from notifications
  DELETE FROM public.notifications
  WHERE user_id = p_user_id;

  -- Delete from notification_queue
  DELETE FROM public.notification_queue
  WHERE user_id = p_user_id;

  -- Delete from onboarding_events
  DELETE FROM public.onboarding_events
  WHERE user_id = p_user_id;

  -- Delete from search_events
  DELETE FROM public.search_events
  WHERE user_id = p_user_id;

  -- Update updated_by in platform_config & platform_settings to null
  UPDATE public.platform_config SET updated_by = NULL WHERE updated_by = p_user_id;
  UPDATE public.platform_settings SET updated_by = NULL WHERE updated_by = p_user_id;

  -- Delete from legacy reports table
  DELETE FROM public.reports
  WHERE reporter_id = p_user_id
     OR reported_user_id = p_user_id
     OR card_id IN (
       SELECT id FROM public.cards
       WHERE brand_id = p_user_id
     );

  -- Delete portfolio items
  DELETE FROM public.portfolio_items WHERE influencer_id = p_user_id;

  -- Delete saved cards
  DELETE FROM public.saved_cards WHERE influencer_id = p_user_id;

  -- Delete push tokens
  DELETE FROM public.user_push_tokens WHERE user_id = p_user_id;

  -- Delete profile views
  DELETE FROM public.profile_views WHERE viewer_id = p_user_id OR profile_id = p_user_id;

  -- Delete follows
  DELETE FROM public.follows WHERE follower_id = p_user_id OR followed_id = p_user_id;

  -- Delete reviews
  DELETE FROM public.reviews WHERE reviewer_id = p_user_id OR reviewee_id = p_user_id;

  -- Delete influencer list items
  DELETE FROM public.influencer_list_items 
  WHERE list_id IN (SELECT id FROM public.influencer_lists WHERE brand_id = p_user_id);

  -- Delete influencer lists
  DELETE FROM public.influencer_lists WHERE brand_id = p_user_id;

  -- Delete applications
  DELETE FROM public.applications 
  WHERE influencer_id = p_user_id 
     OR card_id IN (
       SELECT id FROM public.cards WHERE brand_id = p_user_id
     );

  -- Delete cards
  DELETE FROM public.cards WHERE brand_id = p_user_id;

  -- Delete profile
  DELETE FROM public.profiles WHERE id = p_user_id;

  -- Delete user from auth.users (requires SECURITY DEFINER)
  DELETE FROM auth.users WHERE id = p_user_id;
END;
$$;
