-- HARDENING: sec-agent 2026-06-24
-- Migration to harden Row Level Security (RLS) on all core tables

-- Enable RLS on every table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.influencer_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.influencer_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.portfolio_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Anyone can view active cards" ON public.cards;
DROP POLICY IF EXISTS "Brands can insert their own cards" ON public.cards;
DROP POLICY IF EXISTS "Brands can update their own cards" ON public.cards;
DROP POLICY IF EXISTS "Brands can delete their own cards" ON public.cards;
DROP POLICY IF EXISTS "Users can view relevant applications" ON public.applications;
DROP POLICY IF EXISTS "Influencers can submit applications" ON public.applications;
DROP POLICY IF EXISTS "Users can update relevant applications" ON public.applications;
DROP POLICY IF EXISTS "Influencers can delete own application" ON public.applications;
DROP POLICY IF EXISTS "Participants can view messages" ON public.messages;
DROP POLICY IF EXISTS "Participants can send messages" ON public.messages;
DROP POLICY IF EXISTS "Participants can update messages" ON public.messages;
DROP POLICY IF EXISTS "Participants can view rooms" ON public.rooms;
DROP POLICY IF EXISTS "Rooms can be created by brand participants" ON public.rooms;
DROP POLICY IF EXISTS "Rooms can be created by influencer participants" ON public.rooms;
DROP POLICY IF EXISTS "Brands can update rooms" ON public.rooms;
DROP POLICY IF EXISTS "Participants can view milestones" ON public.milestones;
DROP POLICY IF EXISTS "Participants can create milestones" ON public.milestones;
DROP POLICY IF EXISTS "Participants can update milestones" ON public.milestones;
DROP POLICY IF EXISTS "Participants can delete milestones" ON public.milestones;
DROP POLICY IF EXISTS "Select group members" ON public.group_members;
DROP POLICY IF EXISTS "Insert group members" ON public.group_members;
DROP POLICY IF EXISTS "Update group members" ON public.group_members;
DROP POLICY IF EXISTS "Delete group members" ON public.group_members;
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can select their own push tokens" ON public.user_push_tokens;
DROP POLICY IF EXISTS "Users can insert their own push tokens" ON public.user_push_tokens;
DROP POLICY IF EXISTS "Users can update their own push tokens" ON public.user_push_tokens;
DROP POLICY IF EXISTS "Users can delete their own push tokens" ON public.user_push_tokens;
DROP POLICY IF EXISTS "Anyone can register a profile view" ON public.profile_views;
DROP POLICY IF EXISTS "Users can view own profile views" ON public.profile_views;
DROP POLICY IF EXISTS "Reviews are viewable by everyone" ON public.reviews;
DROP POLICY IF EXISTS "Participants can write reviews" ON public.reviews;
DROP POLICY IF EXISTS "Reviewed party can reply to reviews" ON public.reviews;
DROP POLICY IF EXISTS "Follows are viewable by everyone" ON public.follows;
DROP POLICY IF EXISTS "Influencers can follow brands" ON public.follows;
DROP POLICY IF EXISTS "Influencers can unfollow brands" ON public.follows;
DROP POLICY IF EXISTS "Influencers can view own saved cards" ON public.saved_cards;
DROP POLICY IF EXISTS "Influencers can save cards" ON public.saved_cards;
DROP POLICY IF EXISTS "Influencers can unsave cards" ON public.saved_cards;
DROP POLICY IF EXISTS "Brands can view own lists" ON public.influencer_lists;
DROP POLICY IF EXISTS "Brands can create lists" ON public.influencer_lists;
DROP POLICY IF EXISTS "Brands can update own lists" ON public.influencer_lists;
DROP POLICY IF EXISTS "Brands can delete own lists" ON public.influencer_lists;
DROP POLICY IF EXISTS "Brands can view own list items" ON public.influencer_list_items;
DROP POLICY IF EXISTS "Brands can insert own list items" ON public.influencer_list_items;
DROP POLICY IF EXISTS "Brands can delete own list items" ON public.influencer_list_items;
DROP POLICY IF EXISTS "Portfolio items are viewable by everyone" ON public.portfolio_items;
DROP POLICY IF EXISTS "Users can insert own portfolio items" ON public.portfolio_items;
DROP POLICY IF EXISTS "Users can update own portfolio items" ON public.portfolio_items;
DROP POLICY IF EXISTS "Users can delete own portfolio items" ON public.portfolio_items;
DROP POLICY IF EXISTS "Users can view own verification requests" ON public.verification_requests;
DROP POLICY IF EXISTS "Users can submit verification request" ON public.verification_requests;
DROP POLICY IF EXISTS "Admins can update verification requests" ON public.verification_requests;
DROP POLICY IF EXISTS "audit_logs_select" ON public.audit_logs;
DROP POLICY IF EXISTS "audit_logs_insert" ON public.audit_logs;
DROP POLICY IF EXISTS "audit_logs_admin" ON public.audit_logs;

-- PROFILES POLICIES
-- Anyone can view profiles, but we can filter active ones.
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT 
  USING (is_active = true OR auth.uid() = id);
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE 
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- CARDS POLICIES
CREATE POLICY "cards_select" ON public.cards FOR SELECT 
  USING (auth.role() = 'authenticated' AND status = 'active' AND deleted_at IS NULL OR auth.uid() = brand_id);
CREATE POLICY "cards_insert" ON public.cards FOR INSERT 
  WITH CHECK (auth.uid() = brand_id AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'brand');
CREATE POLICY "cards_update" ON public.cards FOR UPDATE 
  USING (auth.uid() = brand_id)
  WITH CHECK (auth.uid() = brand_id);
CREATE POLICY "cards_delete" ON public.cards FOR DELETE 
  USING (auth.uid() = brand_id);

-- APPLICATIONS POLICIES
CREATE POLICY "applications_select" ON public.applications FOR SELECT 
  USING (deleted_at IS NULL AND (auth.uid() = influencer_id OR EXISTS (SELECT 1 FROM public.cards WHERE cards.id = card_id AND cards.brand_id = auth.uid())));
CREATE POLICY "applications_insert" ON public.applications FOR INSERT 
  WITH CHECK (auth.uid() = influencer_id AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'influencer');
CREATE POLICY "applications_update" ON public.applications FOR UPDATE 
  USING (auth.uid() = influencer_id OR EXISTS (SELECT 1 FROM public.cards WHERE cards.id = card_id AND cards.brand_id = auth.uid()))
  WITH CHECK (auth.uid() = influencer_id OR EXISTS (SELECT 1 FROM public.cards WHERE cards.id = card_id AND cards.brand_id = auth.uid()));
CREATE POLICY "applications_delete" ON public.applications FOR DELETE 
  USING (auth.uid() = influencer_id);

-- ROOMS POLICIES
CREATE POLICY "rooms_select" ON public.rooms FOR SELECT 
  USING (deleted_at IS NULL AND (brand_id = auth.uid() OR influencer_id = auth.uid() OR is_room_participant(id, auth.uid())));
CREATE POLICY "rooms_insert" ON public.rooms FOR INSERT 
  WITH CHECK (brand_id = auth.uid() OR influencer_id = auth.uid());
CREATE POLICY "rooms_update" ON public.rooms FOR UPDATE 
  USING (brand_id = auth.uid() OR influencer_id = auth.uid());

-- MESSAGES POLICIES
CREATE POLICY "messages_select" ON public.messages FOR SELECT 
  USING (deleted_at IS NULL AND is_room_participant(room_id, auth.uid()));
CREATE POLICY "messages_insert" ON public.messages FOR INSERT 
  WITH CHECK (auth.uid() = sender_id AND is_room_participant(room_id, auth.uid()));

-- MILESTONES POLICIES
CREATE POLICY "milestones_select" ON public.milestones FOR SELECT 
  USING (EXISTS (SELECT 1 FROM public.rooms WHERE rooms.id = room_id AND (rooms.brand_id = auth.uid() OR rooms.influencer_id = auth.uid())));
CREATE POLICY "milestones_write" ON public.milestones FOR ALL 
  USING (EXISTS (SELECT 1 FROM public.rooms WHERE rooms.id = room_id AND (rooms.brand_id = auth.uid() OR rooms.influencer_id = auth.uid())))
  WITH CHECK (EXISTS (SELECT 1 FROM public.rooms WHERE rooms.id = room_id AND (rooms.brand_id = auth.uid() OR rooms.influencer_id = auth.uid())));

-- GROUP MEMBERS POLICIES
CREATE POLICY "group_members_select" ON public.group_members FOR SELECT 
  USING (auth.uid() = user_id OR is_room_participant(room_id, auth.uid()));
CREATE POLICY "group_members_modify" ON public.group_members FOR ALL 
  USING (can_manage_group_members(room_id, auth.uid()) OR auth.uid() = user_id)
  WITH CHECK (can_manage_group_members(room_id, auth.uid()) OR auth.uid() = user_id);

-- NOTIFICATIONS POLICIES
CREATE POLICY "notifications_select" ON public.notifications FOR SELECT 
  USING (auth.uid() = user_id);
CREATE POLICY "notifications_delete" ON public.notifications FOR DELETE 
  USING (auth.uid() = user_id);

-- USER PUSH TOKENS POLICIES
CREATE POLICY "user_push_tokens_all" ON public.user_push_tokens FOR ALL 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- PROFILE VIEWS POLICIES
CREATE POLICY "profile_views_insert" ON public.profile_views FOR INSERT 
  WITH CHECK (auth.uid() = viewer_id OR viewer_id IS NULL);
CREATE POLICY "profile_views_select" ON public.profile_views FOR SELECT 
  USING (auth.uid() = profile_id);

-- REVIEWS POLICIES
CREATE POLICY "reviews_select" ON public.reviews FOR SELECT 
  USING (deleted_at IS NULL);
CREATE POLICY "reviews_insert" ON public.reviews FOR INSERT 
  WITH CHECK (auth.uid() = reviewer_id AND EXISTS (SELECT 1 FROM public.rooms WHERE rooms.id = room_id AND (rooms.brand_id = auth.uid() OR rooms.influencer_id = auth.uid())));

-- FOLLOWS POLICIES
CREATE POLICY "follows_select" ON public.follows FOR SELECT 
  USING (true);
CREATE POLICY "follows_insert" ON public.follows FOR INSERT 
  WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "follows_delete" ON public.follows FOR DELETE 
  USING (auth.uid() = follower_id);

-- SAVED CARDS POLICIES
CREATE POLICY "saved_cards_all" ON public.saved_cards FOR ALL 
  USING (auth.uid() = influencer_id)
  WITH CHECK (auth.uid() = influencer_id);

-- INFLUENCER LISTS POLICIES
CREATE POLICY "influencer_lists_all" ON public.influencer_lists FOR ALL 
  USING (auth.uid() = brand_id)
  WITH CHECK (auth.uid() = brand_id);

-- INFLUENCER LIST ITEMS POLICIES
CREATE POLICY "influencer_list_items_all" ON public.influencer_list_items FOR ALL 
  USING (EXISTS (SELECT 1 FROM public.influencer_lists WHERE influencer_lists.id = list_id AND influencer_lists.brand_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.influencer_lists WHERE influencer_lists.id = list_id AND influencer_lists.brand_id = auth.uid()));

-- PORTFOLIO ITEMS POLICIES
CREATE POLICY "portfolio_items_select" ON public.portfolio_items FOR SELECT 
  USING (auth.role() = 'authenticated' AND deleted_at IS NULL);
CREATE POLICY "portfolio_items_write" ON public.portfolio_items FOR ALL 
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- VERIFICATION REQUESTS POLICIES
CREATE POLICY "verification_requests_select" ON public.verification_requests FOR SELECT 
  USING (auth.uid() = user_id OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY "verification_requests_insert" ON public.verification_requests FOR INSERT 
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "verification_requests_update" ON public.verification_requests FOR UPDATE 
  USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- AUDIT LOGS POLICIES
-- Disabled for public select/insert. Service role will bypass RLS.
