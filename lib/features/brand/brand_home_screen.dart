import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/chat_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class BrandHomeScreen extends ConsumerStatefulWidget {
  const BrandHomeScreen({super.key});
  @override
  ConsumerState<BrandHomeScreen> createState() => _BrandHomeScreenState();
}

class _BrandHomeScreenState extends ConsumerState<BrandHomeScreen> {
  bool _loading = true;
  int _activeCards = 0, _totalApps = 0, _activeChats = 0, _acceptedDeals = 0;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _bestCreators = [];

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final sb = SupabaseService.client;

    try {
      final futures = await Future.wait([
        sb.from('cards').select('id').eq('brand_id', user.id).eq('status', 'active').count(CountOption.exact).timeout(const Duration(seconds: 15)),
        sb.from('applications').select('*, cards!inner(*)').eq('cards.brand_id', user.id).count(CountOption.exact).timeout(const Duration(seconds: 15)),
        sb.from('rooms').select('id').eq('brand_id', user.id).count(CountOption.exact).timeout(const Duration(seconds: 15)),
        sb.from('applications').select('*, cards!inner(*)').eq('cards.brand_id', user.id).eq('status', 'accepted').count(CountOption.exact).timeout(const Duration(seconds: 15)),
        sb.from('notifications').select().eq('user_id', user.id).order('created_at', ascending: false).limit(10).timeout(const Duration(seconds: 15)),
        ProfileService().getInfluencers(limit: 10).timeout(const Duration(seconds: 15)),
      ]);

      if (mounted) {
        setState(() {
          _activeCards = (futures[0] as PostgrestResponse).count;
          _totalApps = (futures[1] as PostgrestResponse).count;
          _activeChats = (futures[2] as PostgrestResponse).count;
          _acceptedDeals = (futures[3] as PostgrestResponse).count;
          _activities = List<Map<String, dynamic>>.from(futures[4] as List);
          _bestCreators = List<Map<String, dynamic>>.from(futures[5] as List);
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading brand dashboard data: $e');
      if (mounted) {
        setState(() {
          _activeCards = 0;
          _totalApps = 0;
          _activeChats = 0;
          _acceptedDeals = 0;
          _activities = [];
          _bestCreators = [];
          _loading = false;
        });
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
      if (next.user != null && _loading) {
        _loadData();
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
              title: const AppShimmer(child: ShimmerBox(width: 80, height: 24)),
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
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Grid of metric tiles
            GridView.count(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: List.generate(4, (_) => AppShimmer(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 28),
            // Featured Creators
            const AppShimmer(child: ShimmerBox(width: 140, height: 18)),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                itemBuilder: (_, __) => AppShimmer(
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Container(width: 66, height: 66, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        const SizedBox(height: 8),
                        const ShimmerBox(width: 60, height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Recent Activity Feed
            const AppShimmer(child: ShimmerBox(width: 140, height: 18)),
            const SizedBox(height: 12),
            ...List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppShimmer(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
              ),
            )),
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
                  'Promo',
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
              IconButton(
                icon: const Icon(Iconsax.search_normal, size: 20),
                onPressed: () => context.push('/search'),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.notification, size: 20),
                    onPressed: () => context.push('/brand/notifications'),
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
                onPressed: () => context.push('/brand/settings'),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.go('/brand/profile'),
                child: AppAvatar(
                  url: profile?['avatar_url'],
                  fallbackText: profile?['display_name'] ?? 'P',
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMarginHorizontal,
            AppSpacing.pageMarginVertical,
            AppSpacing.pageMarginHorizontal,
            AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
          ),
          children: [
            // Greeting
            Text('${_greeting()}, ${profile?['display_name'] ?? 'Partner'}', style: AppTextStyles.h1.copyWith(fontSize: 26)),
            const SizedBox(height: 4),
            Text(DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()), style: AppTextStyles.caption),
            const SizedBox(height: 24),
  
            // Stats
            GridView.count(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                StatCard(
                  label: 'Active Cards',
                  value: '$_activeCards',
                  icon: Iconsax.cards,
                  preset: StatCardPreset.indigo,
                  onTap: () => context.go('/brand/cards'),
                ),
                StatCard(
                  label: 'Applications',
                  value: '$_totalApps',
                  icon: Iconsax.profile_2user,
                  preset: StatCardPreset.rose,
                  onTap: () => context.go('/brand/applications'),
                ),
                StatCard(
                  label: 'Active Chats',
                  value: '$_activeChats',
                  icon: Iconsax.message,
                  preset: StatCardPreset.emerald,
                  onTap: () => context.go('/brand/chats'),
                ),
                StatCard(
                  label: 'Accepted Deals',
                  value: '$_acceptedDeals',
                  icon: Iconsax.tick_circle,
                  preset: StatCardPreset.amber,
                  onTap: () => context.go('/brand/campaigns'),
                ),
              ],
            ),
            const SizedBox(height: 16),
  
            // Quick Actions
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.isDarkMode 
                      ? [const Color(0xFF0F0F12), const Color(0xFF16161C)] 
                      : [const Color(0xFFFFFFFF), const Color(0xFFF9FAFB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.border.withOpacity(AppColors.isDarkMode ? 0.4 : 0.8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(AppColors.isDarkMode ? 0.3 : 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Iconsax.flash, size: 16, color: AppColors.accent),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Quick Actions',
                        style: AppTextStyles.h4.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Post a New Card',
                    icon: Iconsax.add_circle,
                    onTap: () => context.push('/brand/cards/new'),
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: 'View Applications',
                    icon: Iconsax.receive_square,
                    isPrimary: false,
                    onTap: () => context.go('/brand/applications'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Featured Creators (Spotify Artist Style)
            if (_bestCreators.isNotEmpty) ...[
              SectionHeader(
                title: 'Featured Creators',
                icon: Iconsax.star5,
                actionLabel: 'See All',
                onAction: () => context.go('/brand/influencers'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 135,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _bestCreators.length,
                  itemBuilder: (context, i) {
                    final creator = _bestCreators[i];
                    final followerCount = creator['follower_count'] ?? 0;
                    String followerText = '${followerCount}';
                    if (followerCount >= 1000) {
                      followerText = '${(followerCount / 1000).toStringAsFixed(1)}K';
                    }
                    return GestureDetector(
                      onTap: () => _showCreatorDetails(creator),
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
                                  url: creator['avatar_url'],
                                  fallbackText: creator['display_name'] ?? 'C',
                                  size: 60,
                                  onTap: () => context.push('/brand/influencers/${creator['id']}'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    creator['display_name'] ?? 'Creator',
                                    style: AppTextStyles.labelSm.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (creator['is_verified'] == true) ...[
                                  const SizedBox(width: 4),
                                  const VerificationBadge(size: 11),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$followerText followers',
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

            // Creator Academy / Tip of the Day Slide
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.isDarkMode
                      ? [const Color(0xFF1A1A24).withOpacity(0.95), const Color(0xFF12121A).withOpacity(0.95)]
                      : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.isDarkMode 
                      ? const Color(0xFF3B0764).withOpacity(0.2) 
                      : const Color(0xFFC084FC).withOpacity(0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.isDarkMode 
                        ? Colors.black.withOpacity(0.35) 
                        : const Color(0xFFC084FC).withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA855F7).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFA855F7).withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Iconsax.lamp_on,
                      color: Color(0xFFA855F7),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Brand Tip of the Day',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.isDarkMode ? Colors.white : const Color(0xFF6B21A8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Keeping milestones clear and verifying submissions within 24 hours boosts creator performance by 85%.',
                          style: AppTextStyles.captionSm.copyWith(
                            fontSize: 11,
                            height: 1.45,
                            color: AppColors.isDarkMode 
                                ? Colors.white.withOpacity(0.7) 
                                : const Color(0xFF701A75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
  
            // Activity Timeline
            SectionHeader(title: 'Recent Activity', icon: Iconsax.notification),
            if (_activities.isEmpty)
              const AppEmptyState(icon: Iconsax.document_text, title: 'No recent activity')
            else
              ...List.generate(_activities.length, (i) {
                final a = _activities[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 0),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline line and glowing indicator node
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              const SizedBox(height: 4),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accent.withOpacity(0.2),
                                  border: Border.all(color: AppColors.accent, width: 2),
                                ),
                              ),
                              if (i < _activities.length - 1)
                                Expanded(
                                  child: Container(
                                    width: 1.5,
                                    color: AppColors.border,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Activity contents
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a['title'] ?? '',
                                  style: AppTextStyles.label.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (a['body'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    a['body'],
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.45,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  a['created_at'] != null 
                                      ? DateFormat('MMM d, h:mm a').format(DateTime.parse(a['created_at'])) 
                                      : '',
                                  style: AppTextStyles.captionSm.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
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
              }),

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

  void _showCreatorDetails(Map<String, dynamic> creator) {
    final user = ref.read(authProvider).user;
    final niches = (creator['niche'] as List?)?.cast<String>() ?? [];
    final platforms = (creator['platforms'] as List?)?.cast<String>() ?? [];
    
    final followersCount = creator['follower_count'] ?? 0;
    String followersText = '${followersCount}';
    if (followersCount >= 1000) {
      followersText = '${(followersCount / 1000).toStringAsFixed(1)}K';
    }

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
                url: creator['avatar_url'],
                fallbackText: creator['display_name'] ?? 'C',
                size: 80,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/brand/influencers/${creator['id']}');
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    creator['display_name'] ?? 'Creator',
                    style: AppTextStyles.h3,
                  ),
                  if (creator['is_verified'] == true) ...[
                    const SizedBox(width: 4),
                    const VerificationBadge(size: 20),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$followersText followers', style: AppTextStyles.labelSm),
                  const SizedBox(width: 8),
                  Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Text(creator['location'] ?? 'Global', style: AppTextStyles.captionSm),
                ],
              ),
              const SizedBox(height: 16),
              if (niches.isNotEmpty || platforms.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ...niches.take(2).map((n) => AppChip(label: n)),
                    ...platforms.take(2).map((p) => AppChip(label: p)),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (creator['bio'] != null && (creator['bio'] as String).isNotEmpty) ...[
                Text(
                  creator['bio'],
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
                            brandId: user.id,
                            influencerId: creator['id'],
                          );
                          if (context.mounted) {
                            Navigator.pop(context); // Close loading dialog
                            Navigator.pop(context); // Close bottom sheet
                            context.push('/brand/chats/${room['id']}');
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
                        context.push('/brand/influencers/${creator['id']}');
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

}