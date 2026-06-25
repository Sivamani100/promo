import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
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
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/cache/app_cache.dart';

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

  Future<void> _load({bool background = false}) async {
    // HARDENING: devops-agent 2026-06-25
    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null || profile == null) return;

    final cacheKey = 'influencer_dashboard_${user.id}';

    // Calculate profile completeness
    int score = 0;
    if (profile['avatar_url'] != null) score += 15;
    if (profile['bio'] != null && (profile['bio'] as String).length > 10) score += 15;
    if (profile['location'] != null) score += 10;
    if (profile['niche'] != null && (profile['niche'] as List).isNotEmpty) score += 20;
    if (profile['platforms'] != null && (profile['platforms'] as List).isNotEmpty) score += 20;
    if (profile['follower_count'] != null && profile['follower_count'] > 0) score += 20;

    if (!background) {
      final cached = AppCache().get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        setState(() {
          _profileCompleteness = score;
          _matchedCards = List<Map<String, dynamic>>.from(cached['matchedCards']);
          _bestBrands = List<Map<String, dynamic>>.from(cached['bestBrands']);
          _profileViews = cached['profileViews'] as int? ?? 0;
          _upcomingMilestones = List<Map<String, dynamic>>.from(cached['upcomingMilestones']);
          _completedMilestonesCount = cached['completedMilestonesCount'] as int? ?? 0;
          _loading = false;
        });
      } else {
        setState(() => _loading = true);
      }
    }

    try {
      // Concurrent fetching of all main dashboard sections
      final futures = await Future.wait([
        CardService().getActiveCards(limit: 20),
        ProfileService().getBrands(limit: 10),
        AnalyticsService().getProfileViewCount(user.id),
        ChatService().getRooms(user.id, 'influencer'),
      ]);

      final allCards = futures[0] as List<Map<String, dynamic>>;
      final brands = futures[1] as List<Map<String, dynamic>>;
      final viewsCount = futures[2] as int;
      final rooms = futures[3] as List<Map<String, dynamic>>;

      // Sort matched cards by user niches match
      final userNiches = (profile['niche'] as List?)?.cast<String>() ?? [];
      allCards.sort((a, b) {
        final aNiche = (a['niche_tags'] as List?)?.cast<String>() ?? [];
        final bNiche = (b['niche_tags'] as List?)?.cast<String>() ?? [];
        final aMatch = aNiche.where((n) => userNiches.contains(n)).length;
        final bMatch = bNiche.where((n) => userNiches.contains(n)).length;
        return bMatch.compareTo(aMatch);
      });

      List<Map<String, dynamic>> milestones = [];
      int completedMilestonesCount = 0;

      final roomIds = rooms.map((r) => r['id'] as String).toList();
      if (roomIds.isNotEmpty) {
        // Fetch milestones and completed count concurrently
        final milestonesResults = await Future.wait([
          SupabaseService.client
              .from('milestones')
              .select()
              .inFilter('room_id', roomIds)
              .eq('status', 'pending')
              .order('due_date', ascending: true),
          SupabaseService.client
              .from('milestones')
              .select('id')
              .inFilter('room_id', roomIds)
              .inFilter('status', ['completed', 'done']),
        ]);

        final rawMilestones = List<Map<String, dynamic>>.from(milestonesResults[0] as List);
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
        completedMilestonesCount = (milestonesResults[1] as List).length;
      }

      // Save complete payload to cache
      AppCache().set(cacheKey, {
        'matchedCards': allCards,
        'bestBrands': brands,
        'profileViews': viewsCount,
        'upcomingMilestones': milestones,
        'completedMilestonesCount': completedMilestonesCount,
      }, ttl: const Duration(minutes: 5));

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
      
      // Perform background validation if we used cached data
      if (!background && AppCache().get(cacheKey) != null) {
        _load(background: true);
      }
    } catch (e) {
      print('Error loading dashboard: $e');
      if (mounted && !background && _matchedCards.isEmpty) {
        setState(() => _loading = false);
      }
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
      final isDark = AppColors.isDarkMode;
      final shimmerBg = isDark ? const Color(0xFF0F0F11) : Colors.white;
      final borderCol = isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB);

      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
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
            // Welcome & Profile Shimmer
            AppShimmer(
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: shimmerBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderCol, width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Analytics Grid Shimmer
            AppShimmer(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 135,
                      decoration: BoxDecoration(
                        color: shimmerBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderCol, width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 135,
                      decoration: BoxDecoration(
                        color: shimmerBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderCol, width: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppShimmer(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 135,
                      decoration: BoxDecoration(
                        color: shimmerBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderCol, width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 135,
                      decoration: BoxDecoration(
                        color: shimmerBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderCol, width: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Deliverables Shimmer
            AppShimmer(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: shimmerBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderCol, width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Featured Partners Shimmer
            AppShimmer(
              child: Container(
                height: 190,
                decoration: BoxDecoration(
                  color: shimmerBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderCol, width: 1.2),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.isDarkMode ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
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
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '.',
                  style: GoogleFonts.inter(
                    fontSize: 24,
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
                    icon: const Icon(Iconsax.notification, size: 24),
                    onPressed: () => context.push('/influencer/notifications'),
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      right: 6,
                      top: 6,
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
                icon: const Icon(Iconsax.setting_2, size: 24),
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
            _buildWelcomeBentoBox(profile, 0),
            const SizedBox(height: 20),
            
            // Analytics Grid (Bento style)
            Row(
              children: [
                Expanded(
                  child: _statHighlightBento(
                    title: 'Total Matches',
                    value: '${_matchedCards.length}',
                    subtitle: 'Opportunities found',
                    icon: Iconsax.flash,
                    color: const Color(0xFF0EA5E9),
                    onTap: () => context.go('/influencer/discover?filter=matched'),
                    delayIndex: 1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statHighlightBento(
                    title: 'Engagement Rate',
                    value: '${profile?['follower_count'] != null && profile!['follower_count'] > 5000 ? "5.4%" : "4.8%"}',
                    subtitle: 'Average organic',
                    icon: Iconsax.activity,
                    color: const Color(0xFF10B981),
                    onTap: () => context.push('/influencer/engagement-rate'),
                    delayIndex: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statHighlightBento(
                    title: 'Profile Views',
                    value: '$_profileViews',
                    subtitle: 'Views this week',
                    icon: Iconsax.eye,
                    color: const Color(0xFFEC4899),
                    onTap: () => context.push('/influencer/profile-views'),
                    delayIndex: 3,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statHighlightBento(
                    title: 'Completed Milestones',
                    value: '$_completedMilestonesCount',
                    subtitle: 'Campaigns on track',
                    icon: Iconsax.crown,
                    color: const Color(0xFFF59E0B),
                    onTap: () => context.go('/influencer/milestones'),
                    delayIndex: 4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Upcoming deliverables Bento
            _buildDeliverablesBento(5),
            const SizedBox(height: 16),
            
            // Featured Partners Bento
            _buildFeaturedBrandsBento(6),
            const SizedBox(height: 16),
            
            // Campaign opportunities Bento
            _buildCampaignOpportunitiesBento(profile, 7),
            
            // Footer (Jio Style)
            const SizedBox(height: 56),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'With love,',
                    style: GoogleFonts.inter(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      color: AppColors.isDarkMode 
                          ? const Color(0xFF3F3F46) 
                          : const Color(0xFFD4D4D8),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'from Promo.',
                    style: GoogleFonts.inter(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      color: AppColors.isDarkMode 
                          ? const Color(0xFF3F3F46) 
                          : const Color(0xFFD4D4D8),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBentoBox(Map<String, dynamic>? profile, int delayIndex) {
    final isDark = AppColors.isDarkMode;
    final avatarUrl = profile?['avatar_url'];
    final displayName = profile?['display_name'] ?? 'Creator';
    
    return _BentoBox(
      animationDelayIndex: delayIndex,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()},',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: AppTextStyles.h2.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile?['is_verified'] == true) ...[
                          const SizedBox(width: 6),
                          const VerificationBadge(size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMMM d').format(DateTime.now()),
                      style: AppTextStyles.captionSm.copyWith(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AppAvatar(
                url: avatarUrl,
                fallbackText: displayName,
                size: 56,
              ),
            ],
          ),
          if (_profileCompleteness < 100) ...[
            const SizedBox(height: 18),
            Container(
              height: 1,
              color: isDark ? const Color(0xFF1C1C21) : const Color(0xFFF1F1F5),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showCompletenessBottomSheet(context, profile),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Complete Your Profile',
                        style: AppTextStyles.label.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
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
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: _profileCompleteness / 100,
                      backgroundColor: isDark ? const Color(0xFF1C1C21) : const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation(AppColors.purple),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'A complete profile gets 3x more matches!',
                          style: AppTextStyles.captionSm.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your creator profile is fully complete and verified!',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statHighlightBento({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int delayIndex,
  }) {
    final isDark = AppColors.isDarkMode;
    
    // Determine colors and icons based on title
    Color bgColor;
    IconData displayIcon;
    Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
    Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    Color iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    if (title == 'Total Matches') {
      bgColor = isDark ? const Color(0xFF0C243C) : const Color(0xFFD0ECFC);
      displayIcon = Iconsax.flash;
    } else if (title == 'Engagement Rate') {
      bgColor = isDark ? const Color(0xFF0D3E26) : const Color(0xFFC1F0D5);
      displayIcon = Icons.check_circle_outline_rounded;
    } else if (title == 'Profile Views') {
      bgColor = isDark ? const Color(0xFF481030) : const Color(0xFFFCD3E6);
      displayIcon = Iconsax.eye;
    } else { // Completed Milestones
      bgColor = isDark ? const Color(0xFF482B08) : const Color(0xFFFDE2B5);
      displayIcon = Iconsax.book;
    }

    return AspectRatio(
      aspectRatio: 1.0,
      child: _BentoBox(
        animationDelayIndex: delayIndex,
        onTap: onTap,
        color: bgColor,
        borderColor: Colors.transparent,
        borderRadius: 28.0,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top Row: Title & Outline Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  displayIcon,
                  color: iconColor,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Value & Subtitle
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -1.2,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: subTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverablesBento(int delayIndex) {
    final isDark = AppColors.isDarkMode;
    return _BentoBox(
      animationDelayIndex: delayIndex,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Iconsax.calendar_15,
                      color: AppColors.accent,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Upcoming Deliverables',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (_upcomingMilestones.isNotEmpty)
                GestureDetector(
                  onTap: () => context.go('/influencer/milestones'),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C21) : const Color(0xFFF1F1F5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Milestones',
                      style: AppTextStyles.labelSm.copyWith(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_upcomingMilestones.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141416) : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF1F1F24) : const Color(0xFFF1F1F5),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Iconsax.emoji_happy5,
                    size: 32,
                    color: AppColors.textMuted.withOpacity(0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All Caught Up!',
                    style: AppTextStyles.label.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No pending deliverables at the moment.',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () => context.go('/influencer/discover'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.accentOnDark,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Find Campaigns',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _upcomingMilestones.take(4).length,
              separatorBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF1F1F24) : const Color(0xFFF1F1F5),
                ),
              ),
              itemBuilder: (context, idx) {
                final m = _upcomingMilestones[idx];
                final brand = m['brand'] as Map<String, dynamic>?;
                final card = m['card'] as Map<String, dynamic>?;
                final cardId = card?['id'];

                return GestureDetector(
                  onTap: () {
                    if (cardId != null) {
                      context.push('/influencer/my-applications?cardId=$cardId');
                    } else {
                      context.push('/influencer/my-applications');
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      AppAvatar(
                        url: brand?['avatar_url'],
                        fallbackText: brand?['display_name'] ?? 'B',
                        size: 38,
                        onTap: () {
                          final bId = brand?['id'];
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
                              style: AppTextStyles.label.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              card?['title'] ?? 'Campaign',
                              style: AppTextStyles.captionSm.copyWith(
                                fontSize: 10.5,
                                color: AppColors.textMuted,
                              ),
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
          ],
        ],
      ),
    );
  }

  Widget _buildFeaturedBrandsBento(int delayIndex) {
    if (_bestBrands.isEmpty) return const SizedBox.shrink();
    final isDark = AppColors.isDarkMode;

    return _BentoBox(
      animationDelayIndex: delayIndex,
      padding: const EdgeInsets.only(top: 18, bottom: 18, left: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Iconsax.star5,
                        color: AppColors.warning,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Featured Partners',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => context.go('/influencer/brands'),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C21) : const Color(0xFFF1F1F5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'See All',
                      style: AppTextStyles.labelSm.copyWith(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        AppAvatar(
                          url: brand['avatar_url'],
                          fallbackText: brand['display_name'] ?? 'B',
                          size: 58,
                          onTap: () => context.push('/influencer/brands/${brand['id']}'),
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
                              const SizedBox(width: 3),
                              const VerificationBadge(size: 10),
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
        ],
      ),
    );
  }

  Widget _buildCampaignOpportunitiesBento(Map<String, dynamic>? profile, int delayIndex) {
    final isDark = AppColors.isDarkMode;
    return _BentoBox(
      animationDelayIndex: delayIndex,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF10B981),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Campaign Matches',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.go('/influencer/discover'),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C21) : const Color(0xFFF1F1F5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See All',
                        style: AppTextStyles.labelSm.copyWith(
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 9,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_matchedCards.isEmpty)
            const AppEmptyState(icon: Icons.campaign_rounded, title: 'No campaigns yet')
          else
            ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _matchedCards.take(5).length,
              separatorBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF1F1F24) : const Color(0xFFF1F1F5),
                ),
              ),
              itemBuilder: (context, index) {
                final card = _matchedCards[index];
                final userNiches = (profile?['niche'] as List?)?.cast<String>() ?? [];
                final cardNiches = (card['niche_tags'] as List?)?.cast<String>() ?? [];
                final matchScore = cardNiches.where((n) => userNiches.contains(n)).length;
                return _buildBentoCampaignRow(card, matchScore);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBentoCampaignRow(Map<String, dynamic> card, int matchScore) {
    final brand = card['brand'] as Map<String, dynamic>?;
    final category = card['category'] as String? ?? '';
    final categoryColor = AppColors.getCategoryColor(category);
    final budgetRange = card['budget_range'] as String?;

    return GestureDetector(
      onTap: () => context.push('/influencer/discover/${card['id']}'),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 72,
                  color: AppColors.surface2,
                  child: isValidImageUrl(card['cover_image_url'])
                      ? CachedNetworkImage(
                          imageUrl: card['cover_image_url'],
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Icon(Iconsax.image, size: 20, color: AppColors.textMuted),
                        ),
                ),
              ),
              if (matchScore > 0)
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      '${matchScore}x Niche',
                      style: const TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card['title'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                if (brand != null)
                  Row(
                    children: [
                      Text(
                        brand['display_name'] ?? 'Brand',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (brand['is_verified'] == true)
                        const VerificationBadge(size: 10),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: categoryColor.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (budgetRange != null)
                      Text(
                        budgetRange,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
                            AppSnackbar.show(context, 'Error starting chat: $e');
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
                    child: isValidImageUrl(card['cover_image_url'])
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
  }
}

class _BentoBox extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry padding;
  final List<Color>? gradient;
  final Color? color;
  final Color? borderColor;
  final int animationDelayIndex;
  final double borderRadius;

  const _BentoBox({
    required this.child,
    this.onTap,
    this.height,
    this.width,
    this.padding = const EdgeInsets.all(18),
    this.gradient,
    this.color,
    this.borderColor,
    this.animationDelayIndex = 0,
    this.borderRadius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final boxColor = color ?? (isDark ? const Color(0xFF0F0F11) : Colors.white);
    final borderCol = borderColor ?? (isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB));

    Widget content = Container(
      height: height,
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? boxColor : null,
        gradient: gradient != null ? LinearGradient(
          colors: gradient!,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderCol,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    return content
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 500),
          delay: Duration(milliseconds: 50 * animationDelayIndex),
        )
        .slideY(
          begin: 0.15,
          end: 0.0,
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 500),
          delay: Duration(milliseconds: 50 * animationDelayIndex),
        );
  }
}