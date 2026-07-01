import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/chat_service.dart';
import '../../shared/widgets/screen_skeletons.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../core/cache/app_cache.dart';
import '../trust/account_status_screens.dart';
import '../home/profile_nudge_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_queue_service.dart';
import '../../core/services/rate_app_service.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/services/push_notification_manager.dart';

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
  int _profileCompleteness = 0;
  NudgeItem? _activeNudge;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        RateAppService.checkAndShowRatePrompt(context);
        ref.read(pushNotificationManagerProvider).showRationaleDialogIfNeeded(context);
      }
    });
  }

  Future<void> _loadData({bool background = false}) async {
    // HARDENING: devops-agent 2026-06-25
    final user = ref.read(authProvider).user;
    if (user == null) return;
    NotificationQueueService.processQueue(user.id);
    final sb = SupabaseService.client;

    final cacheKey = 'brand_dashboard_${user.id}';

    final profile = ref.read(authProvider).profile;
    int score = 0;
    if (profile != null) {
      if (profile['avatar_url'] != null && (profile['avatar_url'] as String).isNotEmpty) score += 20;
      if (profile['bio'] != null && (profile['bio'] as String).length > 10) score += 20;
      if (profile['location'] != null && (profile['location'] as String).isNotEmpty) score += 15;
      if (profile['industry'] != null && (profile['industry'] as String).isNotEmpty) score += 15;
      if (profile['company_name'] != null && (profile['company_name'] as String).isNotEmpty) score += 15;
      if (profile['website_url'] != null && (profile['website_url'] as String).isNotEmpty) score += 15;
      if (score > 100) score = 100;
    }

    final nudge = await ProfileNudgeService.getActiveNudge(profile, 'brand');

    if (!background) {
      final cached = AppCache().get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        setState(() {
          _activeCards = cached['activeCards'] as int? ?? 0;
          _totalApps = cached['totalApps'] as int? ?? 0;
          _activeChats = cached['activeChats'] as int? ?? 0;
          _acceptedDeals = cached['acceptedDeals'] as int? ?? 0;
          _activities = List<Map<String, dynamic>>.from(cached['activities']);
          _bestCreators = List<Map<String, dynamic>>.from(cached['bestCreators']);
          _profileCompleteness = score;
          _activeNudge = nudge;
          _loading = false;
        });
      } else {
        setState(() => _loading = true);
      }
    }

    try {
      final futures = await Future.wait([
        sb.from('cards').select('id').eq('brand_id', user.id).eq('status', 'active').count(CountOption.exact).timeout(const Duration(seconds: 15)),
        sb.from('applications').select('*, cards!inner(*)').eq('cards.brand_id', user.id).count(CountOption.exact).timeout(const Duration(seconds: 15)),
        sb.from('rooms').select('id').eq('brand_id', user.id).count(CountOption.exact).timeout(const Duration(seconds: 15)),
        sb.from('applications').select('*, cards!inner(*)').eq('cards.brand_id', user.id).eq('status', 'accepted').count(CountOption.exact).timeout(const Duration(seconds: 15)),
        sb.from('notifications').select().eq('user_id', user.id).order('created_at', ascending: false).limit(10).timeout(const Duration(seconds: 15)),
        ProfileService().getInfluencers(limit: 10).timeout(const Duration(seconds: 15)),
      ]);

      final activeCardsVal = (futures[0] as PostgrestResponse).count;
      final totalAppsVal = (futures[1] as PostgrestResponse).count;
      final activeChatsVal = (futures[2] as PostgrestResponse).count;
      final acceptedDealsVal = (futures[3] as PostgrestResponse).count;
      final activitiesList = List<Map<String, dynamic>>.from(futures[4] as List);
      final bestCreatorsList = List<Map<String, dynamic>>.from(futures[5] as List);

      // Save to cache
      AppCache().set(cacheKey, {
        'activeCards': activeCardsVal,
        'totalApps': totalAppsVal,
        'activeChats': activeChatsVal,
        'acceptedDeals': acceptedDealsVal,
        'activities': activitiesList,
        'bestCreators': bestCreatorsList,
      }, ttl: const Duration(minutes: 5));

      if (mounted) {
        setState(() {
          _activeCards = activeCardsVal;
          _totalApps = totalAppsVal;
          _activeChats = activeChatsVal;
          _acceptedDeals = acceptedDealsVal;
          _activities = activitiesList;
          _bestCreators = bestCreatorsList;
          _profileCompleteness = score;
          _activeNudge = nudge;
          _loading = false;
        });
      }

      if (!background && AppCache().get(cacheKey) != null) {
        _loadData(background: true);
      }

      if (!background) {
        final prefs = await SharedPreferences.getInstance();
        final tourKey = 'first_time_tour_shown_${user.id}';
        final shown = prefs.getBool(tourKey) ?? false;
        if (!shown && mounted) {
          context.go('/dashboard-tour');
        }
      }
    } catch (e) {
      print('Error loading brand dashboard data: $e');
      if (mounted && !background && _bestCreators.isEmpty) {
        setState(() {
          _activeCards = 0;
          _totalApps = 0;
          _activeChats = 0;
          _acceptedDeals = 0;
          _activities = [];
          _bestCreators = [];
          _profileCompleteness = 0;
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

    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (next == true && previous == false) {
        debugPrint('[BRAND HOME] Back online, reloading dashboard...');
        _loadData();
      }
    });

    final profile = ref.watch(authProvider).profile;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);



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
                  'Promo',
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
              IconButton(
                icon: const Icon(Iconsax.search_normal, size: 24),
                onPressed: () => context.push('/search'),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.notification, size: 24),
                    onPressed: () => context.push('/brand/notifications'),
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
                onPressed: () => context.push('/brand/settings'),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const BrandHomeBodySkeleton()
          : AppRefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await _loadData();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMarginHorizontal,
            AppSpacing.pageMarginVertical,
            AppSpacing.pageMarginHorizontal,
            AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
          ),
          children: [
            if (_profileCompleteness < 60)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.purple.withValues(alpha: 0.15), AppColors.purple.withValues(alpha: 0.05)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Iconsax.info_circle, color: AppColors.purple, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Complete your profile',
                            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your profile is only $_profileCompleteness% complete. Complete it to unlock campaigns.',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => context.push('/brand/profile?edit=true'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Complete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            if (profile?['account_status'] == 'warned')
              const WarningBanner(
                message: 'Your account has been warned for violating community guidelines. Repeated violations will result in account suspension.',
              ),
            _buildWelcomeBentoBox(profile, 0),
            if (_activeNudge != null) ...[
              const SizedBox(height: 12),
              _buildNudgeCard(_activeNudge!),
            ],
            const SizedBox(height: 20),

            // Stats grid
            Row(
              children: [
                Expanded(
                  child: _statHighlightBento(
                    title: 'Active Cards',
                    value: '$_activeCards',
                    subtitle: 'Visible to creators',
                    icon: Iconsax.cards,
                    color: const Color(0xFF6366F1),
                    onTap: () => context.go('/brand/cards'),
                    delayIndex: 1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statHighlightBento(
                    title: 'Applications',
                    value: '$_totalApps',
                    subtitle: 'Pending review',
                    icon: Iconsax.profile_2user,
                    color: const Color(0xFFF43F5E),
                    onTap: () => context.go('/brand/applications'),
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
                    title: 'Active Chats',
                    value: '$_activeChats',
                    subtitle: 'Influencer threads',
                    icon: Iconsax.message,
                    color: const Color(0xFF10B981),
                    onTap: () => context.go('/brand/chats'),
                    delayIndex: 3,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statHighlightBento(
                    title: 'Accepted Deals',
                    value: '$_acceptedDeals',
                    subtitle: 'Deals in progress',
                    icon: Iconsax.tick_circle,
                    color: const Color(0xFFF59E0B),
                    onTap: () => context.go('/brand/campaigns'),
                    delayIndex: 4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Actions Bento
            _buildQuickActionsBento(5),
            const SizedBox(height: 16),

            // Featured Creators Bento
            _buildFeaturedCreatorsBento(6),
            const SizedBox(height: 16),

            // Tip of the Day Bento
            _buildTipOfTheDayBento(7),
            const SizedBox(height: 16),

            // Recent Activity Bento
            _buildRecentActivityBento(8),

            const SizedBox(height: 16),
            Card(
              color: AppColors.isDarkMode ? const Color(0xFF0F0F11) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.isDarkMode ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                  width: 1.2,
                ),
              ),
              child: InkWell(
                onTap: () => context.push('/brand/settings/promo-page'),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Iconsax.link, color: AppColors.purple, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Promo Page',
                              style: AppTextStyles.h3.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Customize and share your links landing page',
                              style: TextStyle(
                                color: AppColors.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            
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
    final displayName = profile?['display_name'] ?? 'Partner';
    
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
              GestureDetector(
                onTap: () => context.go('/brand/profile'),
                child: AppAvatar(
                  url: avatarUrl,
                  fallbackText: displayName,
                  size: 56,
                ),
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
                        'Complete Your Brand Profile',
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
                          'A complete profile helps creators know you better!',
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
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your brand profile is fully complete and verified!',
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

  void _showCompletenessBottomSheet(BuildContext context, Map<String, dynamic>? profile) {
    if (profile == null) return;
    
    final avatarDone = profile['avatar_url'] != null && (profile['avatar_url'] as String).isNotEmpty;
    final bioDone = profile['bio'] != null && (profile['bio'] as String).length > 10;
    final locationDone = profile['location'] != null && (profile['location'] as String).isNotEmpty;
    final industryDone = profile['industry'] != null && (profile['industry'] as String).isNotEmpty;
    final companyDone = profile['company_name'] != null && (profile['company_name'] as String).isNotEmpty;
    final websiteDone = profile['website_url'] != null && (profile['website_url'] as String).isNotEmpty;

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
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
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
                    color: AppColors.textMuted.withValues(alpha: 0.3),
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
                      color: AppColors.purple.withValues(alpha: 0.1),
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
                'Complete all items to build trust with content creators.',
                style: AppTextStyles.caption.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 24),
              _buildChecklistItem('Logo / Profile Picture', avatarDone, '+20%'),
              _buildChecklistItem('Brand Bio (>10 chars)', bioDone, '+20%'),
              _buildChecklistItem('Location (City, State)', locationDone, '+15%'),
              _buildChecklistItem('Industry / Category', industryDone, '+15%'),
              _buildChecklistItem('Company Name', companyDone, '+15%'),
              _buildChecklistItem('Website URL', websiteDone, '+15%'),
              const SizedBox(height: 24),
              SafeArea(
                child: AppButton(
                  label: 'Edit Profile Now',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/brand/profile?edit=true');
                  },
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
            color: isCompleted ? AppColors.accent : AppColors.textMuted.withValues(alpha: 0.6),
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
    Color bgColor;
    IconData displayIcon;
    Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
    Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    Color iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    if (title == 'Active Cards') {
      bgColor = isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF);
      displayIcon = Iconsax.cards;
    } else if (title == 'Applications') {
      bgColor = isDark ? const Color(0xFF4C0519) : const Color(0xFFFFE4E6);
      displayIcon = Iconsax.profile_2user;
    } else if (title == 'Active Chats') {
      bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      displayIcon = Iconsax.message;
    } else { // Accepted Deals
      bgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      displayIcon = Iconsax.tick_circle;
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

  Widget _buildQuickActionsBento(int delayIndex) {
    final isDark = AppColors.isDarkMode;
    return _BentoBox(
      animationDelayIndex: delayIndex,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
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
    );
  }

  Widget _buildFeaturedCreatorsBento(int delayIndex) {
    if (_bestCreators.isEmpty) return const SizedBox.shrink();
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
                        color: AppColors.warning.withValues(alpha: isDark ? 0.15 : 0.08),
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
                      'Featured Creators',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => context.go('/brand/influencers'),
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
                        AppAvatar(
                          url: creator['avatar_url'],
                          fallbackText: creator['display_name'] ?? 'C',
                          size: 60,
                          onTap: () => context.push('/brand/influencers/${creator['id']}'),
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
                              const SizedBox(width: 3),
                              const VerificationBadge(size: 10),
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
        ],
      ),
    );
  }

  Widget _buildTipOfTheDayBento(int delayIndex) {
    final isDark = AppColors.isDarkMode;
    return _BentoBox(
      animationDelayIndex: delayIndex,
      padding: const EdgeInsets.all(20),
      gradient: isDark
          ? [const Color(0xFF1E1B4B).withValues(alpha: 0.95), const Color(0xFF0F0F17).withValues(alpha: 0.95)]
          : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
      borderColor: isDark 
          ? const Color(0xFF3B0764).withValues(alpha: 0.2) 
          : const Color(0xFFC084FC).withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFA855F7).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFA855F7).withValues(alpha: 0.25),
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
                    color: isDark ? Colors.white : const Color(0xFF6B21A8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keeping milestones clear and verifying submissions within 24 hours boosts creator performance by 85%.',
                  style: AppTextStyles.captionSm.copyWith(
                    fontSize: 11,
                    height: 1.45,
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.7) 
                        : const Color(0xFF701A75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityBento(int delayIndex) {
    final isDark = AppColors.isDarkMode;
    return _BentoBox(
      animationDelayIndex: delayIndex,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Iconsax.notification,
                  color: AppColors.accent,
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Recent Activity',
                style: AppTextStyles.label.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_activities.isEmpty)
            const AppEmptyState(icon: Iconsax.document_text, title: 'No recent activity')
          else
            ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activities.take(5).length,
              itemBuilder: (context, i) {
                final a = _activities[i];
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                color: AppColors.accent.withValues(alpha: 0.2),
                                border: Border.all(color: AppColors.accent, width: 2),
                              ),
                            ),
                            if (i < _activities.take(5).length - 1)
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
                                  fontSize: 10.5,
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
                );
              },
            ),
        ],
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

  Widget _buildNudgeCard(NudgeItem nudge) {
    final isDark = AppColors.isDarkMode;
    return _BentoBox(
      animationDelayIndex: 0,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(nudge.icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nudge.title,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nudge.description,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go(nudge.actionRoute),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentOnDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text('Complete Now', style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: () async {
              final user = ref.read(authProvider).user;
              if (user != null) {
                await ProfileNudgeService.dismissNudge(user.id, nudge.id);
                final nextNudge = await ProfileNudgeService.getActiveNudge(ref.read(authProvider).profile, 'brand');
                setState(() {
                  _activeNudge = nextNudge;
                });
              }
            },
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
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.03),
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