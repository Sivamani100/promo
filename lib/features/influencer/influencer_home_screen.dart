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
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.purple.withValues(alpha: 0.2), AppColors.indigo.withValues(alpha: 0.1)]),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Complete Your Profile', style: AppTextStyles.label.copyWith(fontSize: 14)),
                    Text('$_profileCompleteness%', style: AppTextStyles.label.copyWith(color: AppColors.purple)),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(value: _profileCompleteness / 100, backgroundColor: AppColors.surface2, valueColor: AlwaysStoppedAnimation(AppColors.purple), minHeight: 6),
                  ),
                  const SizedBox(height: 10),
                  Text('A complete profile gets 3x more matches!', style: AppTextStyles.captionSm),
                ]),
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
                height: 125,
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
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 2,
                                ),
                              ),
                              child: AppAvatar(
                                url: brand['avatar_url'],
                                fallbackText: brand['display_name'] ?? 'B',
                                size: 66,
                                onTap: () => context.push('/influencer/brands/${brand['id']}'),
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
                    gradientColors: [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
                  ),
                ),
                _statHighlightCard(
                  title: 'Engagement Rate',
                  value: '${profile?['follower_count'] != null && profile!['follower_count'] > 5000 ? "5.4%" : "4.8%"}',
                  subtitle: 'Average organic',
                  icon: Iconsax.activity,
                  gradientColors: [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)],
                ),
                GestureDetector(
                  onTap: () => context.push('/influencer/profile-views'),
                  child: _statHighlightCard(
                    title: 'Profile Views',
                    value: '$_profileViews',
                    subtitle: 'Views this week',
                    icon: Iconsax.eye,
                    gradientColors: [const Color(0xFFFCE7F3), const Color(0xFFFBCFE8)],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/influencer/milestones'),
                  child: _statHighlightCard(
                    title: 'Completed Milestones',
                    value: '12',
                    subtitle: 'All campaigns on track',
                    icon: Iconsax.crown,
                    gradientColors: [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
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
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: Colors.black.withOpacity(0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
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
                    color: Colors.black.withOpacity(0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: Colors.black.withOpacity(0.65), size: 14),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.black.withOpacity(0.9),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.black.withOpacity(0.55),
              fontSize: 9,
              fontWeight: FontWeight.w500,
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
}