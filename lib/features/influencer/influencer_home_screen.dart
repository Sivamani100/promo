import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/card_service.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/data_services.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';

class InfluencerHomeScreen extends ConsumerStatefulWidget {
  const InfluencerHomeScreen({super.key});
  @override
  ConsumerState<InfluencerHomeScreen> createState() => _InfluencerHomeScreenState();
}

class _InfluencerHomeScreenState extends ConsumerState<InfluencerHomeScreen> {
  bool _loading = true;
  int _profileCompleteness = 0;
  List<Map<String, dynamic>> _matchedCards = [];
  List<Map<String, dynamic>> _bestBrands = [];
  int _profileViews = 0;
  List<Map<String, dynamic>> _upcomingMilestones = [];
  int _completedMilestonesCount = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null || profile == null) return;

    // Calculate profile completeness
    int score = 0;
    if (profile['avatar_url'] != null) score += 15;
    if (profile['bio'] != null && (profile['bio'] as String).length > 10) score += 15;
    if (profile['location'] != null) score += 10;
    if (profile['niche'] != null && (profile['niche'] as List).isNotEmpty) score += 20;
    if (profile['platforms'] != null && (profile['platforms'] as List).isNotEmpty) score += 20;
    if (profile['follower_count'] != null && profile['follower_count'] > 0) score += 20;

    // Load matching cards
    final allCards = await CardService().getActiveCards(limit: 20);
    final userNiches = (profile['niche'] as List?)?.cast<String>() ?? [];
    allCards.sort((a, b) {
      final aNiche = (a['niche_tags'] as List?)?.cast<String>() ?? [];
      final bNiche = (b['niche_tags'] as List?)?.cast<String>() ?? [];
      final aMatch = aNiche.where((n) => userNiches.contains(n)).length;
      final bMatch = bNiche.where((n) => userNiches.contains(n)).length;
      return bMatch.compareTo(aMatch);
    });

    // Load best brands
    List<Map<String, dynamic>> brands = [];
    try {
      brands = await ProfileService().getBrands(limit: 10);
    } catch (e) {
      print('Error loading best brands: $e');
    }

    // Load profile views count
    int viewsCount = 0;
    try {
      viewsCount = await AnalyticsService().getProfileViewCount(user.id);
    } catch (e) {
      print('Error loading profile view count on home: $e');
    }

    // Load deliverables/milestones
    List<Map<String, dynamic>> milestones = [];
    int completedMilestonesCount = 0;
    try {
      final rooms = await ChatService().getRooms(user.id, 'influencer');
      final roomIds = rooms.map((r) => r['id'] as String).toList();
      if (roomIds.isNotEmpty) {
        final milestonesData = await SupabaseService.client
            .from('milestones')
            .select()
            .inFilter('room_id', roomIds)
            .eq('status', 'pending')
            .order('due_date', ascending: true);
        
        final rawMilestones = List<Map<String, dynamic>>.from(milestonesData);
        for (final m in rawMilestones) {
          final room = rooms.firstWhere((r) => r['id'] == m['room_id'], orElse: () => {});
          if (room.isNotEmpty) {
            milestones.add({
              ...m,
              'brand': room['brand'],
              'card': room['card'],
            });
          }
        }

        // Fetch completed milestones count
        final completedData = await SupabaseService.client
            .from('milestones')
            .select('id')
            .inFilter('room_id', roomIds)
            .inFilter('status', ['completed', 'done']);
        completedMilestonesCount = completedData.length;
      }
    } catch (e) {
      print('Error loading milestones for dashboard: $e');
    }

    if (mounted) {
      setState(() {
        _profileCompleteness = score;
        _matchedCards = allCards;
        _bestBrands = brands;
        _profileViews = viewsCount;
        _upcomingMilestones = milestones;
        _completedMilestonesCount = completedMilestonesCount;
        _loading = false;
      });
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && next.profile != null && _loading) {
        _load();
      }
    });

    final profile = ref.watch(authProvider).profile;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    if (_loading) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56 + AppSpacing.pageMarginVertical),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.appBarMarginHorizontal,
              right: AppSpacing.appBarMarginHorizontal,
              top: AppSpacing.pageMarginVertical,
            ),
            child: AppBar(
              titleSpacing: 0,
              title: const AppShimmer(child: ShimmerBox(width: 100, height: 24)),
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMarginHorizontal,
            AppSpacing.pageMarginVertical,
            AppSpacing.pageMarginHorizontal,
            AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
          ),
          children: [
            const AppShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 120, height: 14),
                  SizedBox(height: 8),
                  ShimmerBox(width: 180, height: 28),
                  SizedBox(height: 6),
                  ShimmerBox(width: 100, height: 12),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppShimmer(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const AppShimmer(child: ShimmerBox(width: 140, height: 18)),
            const SizedBox(height: 12),
            SizedBox(
              height: 125,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                itemBuilder: (_, __) => AppShimmer(
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const ShimmerBox(width: 60, height: 10),
                        const SizedBox(height: 4),
                        const ShimmerBox(width: 40, height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const AppShimmer(child: ShimmerBox(width: 140, height: 18)),
            const SizedBox(height: 12),
            SizedBox(
              height: 95,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (_, __) => AppShimmer(
                  child: Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const AppShimmer(child: ShimmerBox(width: 160, height: 18)),
            const SizedBox(height: 12),
            const ShimmerCampaignCard(),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56 + AppSpacing.pageMarginVertical),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.appBarMarginHorizontal,
            right: AppSpacing.appBarMarginHorizontal,
            top: AppSpacing.pageMarginVertical,
          ),
          child: AppBar(
            centerTitle: false,
            titleSpacing: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Creator',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '.',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.notification, size: 20),
                    onPressed: () => context.push('/influencer/notifications'),
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Iconsax.setting_2, size: 20),
                onPressed: () => context.push('/influencer/settings'),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMarginHorizontal,
            AppSpacing.pageMarginVertical,
            AppSpacing.pageMarginHorizontal,
            AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
          ),
          children: [
            Text('${_greeting()},', style: AppTextStyles.caption),
            Text(profile?['display_name'] ?? 'Creator', style: AppTextStyles.h1.copyWith(fontSize: 26)),
            const SizedBox(height: 4),
            Text(DateFormat('EEEE, MMMM d').format(DateTime.now()), style: AppTextStyles.captionSm),
            const SizedBox(height: 20),
  
            // Profile Completeness
            if (_profileCompleteness < 100)
              GestureDetector(
                onTap: () => _showCompletenessBottomSheet(context, profile),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.purple.withOpacity(0.15),
                        AppColors.indigo.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.purple.withOpacity(0.25), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purple.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Iconsax.profile_add, size: 18, color: AppColors.purple),
                              const SizedBox(width: 8),
                              Text(
                                'Complete Your Profile',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$_profileCompleteness%',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.purple,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: _profileCompleteness / 100,
                          backgroundColor: AppColors.isDarkMode ? const Color(0xFF141414) : const Color(0xFFE5E7EB),
                          valueColor: AlwaysStoppedAnimation(AppColors.purple),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.stars_rounded, size: 14, color: AppColors.purple),
                          const SizedBox(width: 6),
                          Text(
                            'A complete profile gets 3x more matches!',
                            style: AppTextStyles.captionSm.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
  

            // Featured Brands (Spotify Artist Style)
            if (_bestBrands.isNotEmpty) ...[
              SectionHeader(
                title: 'Featured Brands',
                icon: Iconsax.star5,
                actionLabel: 'See All',
                onAction: () => context.go('/influencer/brands'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 135,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _bestBrands.length,
                  itemBuilder: (context, i) {
                    final brand = _bestBrands[i];
                    return GestureDetector(
                      onTap: () => _showBrandDetails(brand),
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accent,
                                    AppColors.accent.withOpacity(0.2),
                                    AppColors.accent,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withOpacity(0.12),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surface,
                                    width: 2,
                                  ),
                                ),
                                child: AppAvatar(
                                  url: brand['avatar_url'],
                                  fallbackText: brand['display_name'] ?? 'B',
                                  size: 60,
                                  onTap: () => context.push('/influencer/brands/${brand['id']}'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    brand['display_name'] ?? 'Brand',
                                    style: AppTextStyles.labelSm.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (brand['is_verified'] == true) ...[
                                  const SizedBox(width: 4),
                                  const VerificationBadge(size: 11),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              brand['industry'] ?? 'Partner',
                              style: AppTextStyles.captionSm.copyWith(
                                fontSize: 9,
                                color: AppColors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            SectionHeader(
              title: 'Weekly Highlights',
              icon: Iconsax.chart_2,
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              padding: EdgeInsets.zero,
              children: [
                GestureDetector(
                  onTap: () => context.go('/influencer/discover?filter=matched'),
                  child: _statHighlightCard(
                    title: 'Total Matches',
                    value: '${_matchedCards.length}',
                    subtitle: 'Opportunities found',
                    icon: Iconsax.flash,
                    lightGradient: [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
                    darkGradient: [const Color(0xFF0C4A6E).withOpacity(0.85), const Color(0xFF075985).withOpacity(0.85)],
                    accentColor: const Color(0xFF38BDF8),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/influencer/engagement-rate'),
                  child: _statHighlightCard(
                    title: 'Engagement Rate',
                    value: '${profile?['follower_count'] != null && profile!['follower_count'] > 5000 ? "5.4%" : "4.8%"}',
                    subtitle: 'Average organic',
                    icon: Iconsax.activity,
                    lightGradient: [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)],
                    darkGradient: [const Color(0xFF064E3B).withOpacity(0.85), const Color(0xFF065F46).withOpacity(0.85)],
                    accentColor: const Color(0xFF4ADE80),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/influencer/profile-views'),
                  child: _statHighlightCard(
                    title: 'Profile Views',
                    value: '$_profileViews',
                    subtitle: 'Views this week',
                    icon: Iconsax.eye,
                    lightGradient: [const Color(0xFFFCE7F3), const Color(0xFFFBCFE8)],
                    darkGradient: [const Color(0xFF500730).withOpacity(0.85), const Color(0xFF700B48).withOpacity(0.85)],
                    accentColor: const Color(0xFFF472B6),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/influencer/milestones'),
                  child: _statHighlightCard(
                    title: 'Completed Milestones',
                    value: '$_completedMilestonesCount',
                    subtitle: 'All campaigns on track',
                    icon: Iconsax.crown,
                    lightGradient: [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
                    darkGradient: [const Color(0xFF451A03).withOpacity(0.85), const Color(0xFF78350F).withOpacity(0.85)],
                    accentColor: const Color(0xFFFBBF24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_upcomingMilestones.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Iconsax.calendar_1, size: 16, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text('Upcoming Deliverables', style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => context.go('/influencer/milestones'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Milestones',
                        style: AppTextStyles.labelSm.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _upcomingMilestones.take(3).length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final m = _upcomingMilestones[idx];
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border.withOpacity(0.6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                         AppAvatar(
                          url: m['brand']?['avatar_url'],
                          fallbackText: m['brand']?['display_name'] ?? 'B',
                          size: 36,
                          onTap: () {
                            final bId = m['brand']?['id'];
                            if (bId != null) {
                              context.push('/influencer/brands/$bId');
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['title'] ?? 'Deliverable',
                                style: AppTextStyles.label.copyWith(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m['card']?['title'] ?? 'Campaign',
                                style: AppTextStyles.captionSm.copyWith(fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildDueDateBadge(m['due_date']),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            // Matched Campaigns
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Text('Matched Campaigns', style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
                GestureDetector(
                  onTap: () => context.go('/influencer/discover'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: AppTextStyles.labelSm.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_matchedCards.isEmpty)
              const AppEmptyState(icon: Icons.campaign_rounded, title: 'No campaigns yet')
            else
              Column(
                children: List.generate(
                  _matchedCards.take(5).length,
                  (index) {
                    final card = _matchedCards[index];
                    final userNiches = (profile?['niche'] as List?)?.cast<String>() ?? [];
                    final cardNiches = (card['niche_tags'] as List?)?.cast<String>() ?? [];
                    final matchScore = cardNiches.where((n) => userNiches.contains(n)).length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildCompactCampaignCard(card, matchScore),
                    );
                  },
                ),
              ),

            // "With love, from Arkio." Footer — Jio style
            const SizedBox(height: 48),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'With ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade500,
                        height: 1,
                      ),
                    ),
                    Icon(
                      Icons.favorite,
                      size: 14,
                      color: Colors.red.shade400,
                    ),
                    Text(
                      ', from ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade500,
                        height: 1,
                      ),
                    ),
                    Text(
                      'Arkio.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBrandDetails(Map<String, dynamic> brand) {
    final user = ref.read(authProvider).user;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              AppAvatar(
                url: brand['avatar_url'],
                fallbackText: brand['display_name'] ?? 'B',
                size: 80,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/influencer/brands/${brand['id']}');
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    brand['display_name'] ?? 'Brand',
                    style: AppTextStyles.h3,
                  ),
                  if (brand['is_verified'] == true) ...[
                    const SizedBox(width: 4),
                    const VerificationBadge(size: 20),
                  ],
                ],
              ),
              if (brand['company_name'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  brand['company_name'],
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (brand['industry'] != null)
                    AppChip(label: brand['industry']),
                  if (brand['location'] != null) ...[
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(Iconsax.location, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(brand['location'], style: AppTextStyles.captionSm),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (brand['bio'] != null && (brand['bio'] as String).isNotEmpty) ...[
                Text(
                  brand['bio'],
                  style: AppTextStyles.caption.copyWith(height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Message',
                      icon: Iconsax.message,
                      onTap: () async {
                        if (user == null) return;
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator()),
                        );
                        try {
                          final room = await ChatService().getOrCreate1to1Room(
                            brandId: brand['id'],
                            influencerId: user.id,
                          );
                          if (context.mounted) {
                            Navigator.pop(context); // Close loading dialog
                            Navigator.pop(context); // Close bottom sheet
                            context.push('/influencer/chats/${room['id']}');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context); // Close loading dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error starting chat: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'View Profile',
                      isPrimary: false,
                      icon: Iconsax.user,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/influencer/brands/${brand['id']}');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactCampaignCard(Map<String, dynamic> card, int matchScore) {
    final brand = card['brand'] as Map<String, dynamic>?;
    final category = card['category'] as String? ?? '';
    final categoryColor = AppColors.getCategoryColor(category);
    final budgetRange = card['budget_range'] as String?;

    return GestureDetector(
      onTap: () => context.push('/influencer/discover/${card['id']}'),
      child: Container(
        width: double.infinity,
        height: 110,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cover image with rounded corners
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 84,
                    height: 90,
                    color: AppColors.surface2,
                    child: card['cover_image_url'] != null
                        ? CachedNetworkImage(
                            imageUrl: card['cover_image_url'],
                            fit: BoxFit.cover,
                            width: 84,
                            height: 90,
                          )
                        : Center(
                            child: Icon(Iconsax.image, size: 24, color: AppColors.textMuted),
                          ),
                  ),
                ),
                // Match badge
                if (matchScore > 0)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${matchScore}x',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                // Brand avatar overlay
                if (brand != null)
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: AppAvatar(
                        url: brand['avatar_url'],
                        fallbackText: brand['display_name'] ?? 'B',
                        size: 22,
                        onTap: () => context.push('/influencer/brands/${brand['id']}'),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    card['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Brand name
                  if (brand != null)
                    Text(
                      brand['display_name'] ?? 'Brand',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    ),
                  const Spacer(),
                  // Bottom row: Category + Budget
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: categoryColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (budgetRange != null)
                        Text(
                          budgetRange,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statHighlightCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> lightGradient,
    required List<Color> darkGradient,
    required Color accentColor,
  }) {
    final isDark = AppColors.isDarkMode;
    final grads = isDark ? darkGradient : lightGradient;
    final textCol = isDark ? Colors.white : Colors.black.withOpacity(0.9);
    final labelCol = isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.65);
    final subCol = isDark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.55);
    final iconCol = isDark ? accentColor : Colors.black.withOpacity(0.65);
    final borderCol = isDark ? accentColor.withOpacity(0.15) : Colors.black.withOpacity(0.04);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: grads,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderCol,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: labelCol,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: iconCol, size: 14),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: textCol,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: subCol,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateBadge(String? dueDateStr) {
    if (dueDateStr == null) return const SizedBox.shrink();
    try {
      final due = DateTime.parse(dueDateStr);
      final now = DateTime.now();
      final difference = due.difference(DateTime(now.year, now.month, now.day)).inDays;
      
      Color color;
      String text;
      if (difference < 0) {
        color = AppColors.error;
        text = 'Overdue';
      } else if (difference == 0) {
        color = AppColors.error;
        text = 'Due Today';
      } else if (difference == 1) {
        color = AppColors.warning;
        text = 'Due Tomorrow';
      } else {
        color = AppColors.success;
        text = 'In $difference days';
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  void _showCompletenessBottomSheet(BuildContext context, Map<String, dynamic>? profile) {
    if (profile == null) return;
    
    final avatarDone = profile['avatar_url'] != null;
    final bioDone = profile['bio'] != null && (profile['bio'] as String).length > 10;
    final locationDone = profile['location'] != null && (profile['location'] as String).isNotEmpty;
    final nicheDone = profile['niche'] != null && (profile['niche'] as List).isNotEmpty;
    final platformsDone = profile['platforms'] != null && (profile['platforms'] as List).isNotEmpty;
    final followersDone = profile['follower_count'] != null && profile['follower_count'] > 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profile Completion Checklist',
                    style: AppTextStyles.h2.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_profileCompleteness%',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.purple,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Complete all items to get 3x more brand matches and build trust.',
                style: AppTextStyles.caption.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 24),
              _buildChecklistItem('Profile Picture', avatarDone, '+15%'),
              _buildChecklistItem('Bio / About Me (>10 chars)', bioDone, '+15%'),
              _buildChecklistItem('Location (City, State)', locationDone, '+10%'),
              _buildChecklistItem('Niches / Categories', nicheDone, '+20%'),
              _buildChecklistItem('Social Media Platforms', platformsDone, '+20%'),
              _buildChecklistItem('Follower Count', followersDone, '+20%'),
              const SizedBox(height: 24),
              SafeArea(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/influencer/profile?edit=true');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Edit Profile Now',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChecklistItem(String title, bool isCompleted, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isCompleted ? AppColors.accent : AppColors.textMuted.withOpacity(0.6),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.label.copyWith(
                fontSize: 14,
                fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
                color: isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.captionSm.copyWith(
              fontWeight: FontWeight.bold,
              color: isCompleted ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }}