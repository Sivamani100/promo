import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/data_services.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/social_agent.dart';
import '../../shared/widgets/shared_widgets.dart';

class BrandInfluencerDetailScreen extends ConsumerStatefulWidget {
  final String influencerId;
  const BrandInfluencerDetailScreen({super.key, required this.influencerId});

  @override
  ConsumerState<BrandInfluencerDetailScreen> createState() => _BrandInfluencerDetailScreenState();
}

class _BrandInfluencerDetailScreenState extends ConsumerState<BrandInfluencerDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  bool _isCollapsed = false;
  double _headerOpacity = 1.0;
  Map<String, dynamic>? _influencer;
  List<Map<String, dynamic>> _portfolio = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  final _analyticsService = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadAll();
  }

  void _onScroll() {
    final collapsed = _scrollController.hasClients && _scrollController.offset > 80;
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final double opacity = (1.0 - (offset / 80.0)).clamp(0.0, 1.0);
    if (collapsed != _isCollapsed || opacity != _headerOpacity) {
      setState(() {
        _isCollapsed = collapsed;
        _headerOpacity = opacity;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final user = ref.read(authProvider).user;
    try {
      final results = await Future.wait([
        ProfileService().getProfile(widget.influencerId),
        PortfolioService().getPortfolioItems(widget.influencerId),
        _analyticsService.getReviews(widget.influencerId),
        if (user != null) _analyticsService.recordProfileView(user.id, widget.influencerId) else Future.value(null),
      ]);

      if (mounted) {
        setState(() {
          _influencer = results[0] as Map<String, dynamic>?;
          _portfolio = results[1] as List<Map<String, dynamic>>;
          _reviews = results[2] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[INFLUENCER_DETAIL] Error loading details: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _startChat() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final room = await ChatService().getOrCreate1to1Room(
        brandId: user.id,
        influencerId: widget.influencerId,
      );
      if (mounted) {
        Navigator.pop(context); // close loader
        context.push('/brand/chats/${room['id']}');
      }
    } catch (err) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open chat: $err')),
        );
      }
    }
  }

  Future<void> _showSaveToListSheet() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bctx) {
        return _SaveToListSheet(
          brandId: user.id,
          influencerId: widget.influencerId,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Creator Profile',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        body: const ShimmerProfileDetail(),
      );
    }

    if (_influencer == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Creator Profile',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        body: const AppEmptyState(icon: Icons.error_rounded, title: 'Creator profile not found'),
      );
    }

    final inf = _influencer!;
    final niches = (inf['niche'] as List?)?.cast<String>() ?? [];
    final platforms = (inf['platforms'] as List?)?.cast<String>() ?? [];
    final location = inf['location'] ?? 'Global';

    final followersCount = inf['follower_count'] ?? 0;
    String followersText = '$followersCount';
    if (followersCount >= 1000000) {
      followersText = '${(followersCount / 1000000).toStringAsFixed(1)}M';
    } else if (followersCount >= 1000) {
      followersText = '${(followersCount / 1000).toStringAsFixed(1)}K';
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image & Overlay avatar stack
          SizedBox(
            height: 160.0 + MediaQuery.of(context).padding.top,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/Logo.png',
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              AppColors.accent.withValues(alpha: 0.25),
                              AppColors.purple.withValues(alpha: 0.15),
                              Colors.transparent,
                            ]
                          : [
                              AppColors.accent.withValues(alpha: 0.2),
                              AppColors.purple.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                // Archive/save to list
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 12,
                  child: GestureDetector(
                    onTap: _showSaveToListSheet,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Iconsax.archive_add,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -36, // overlap cover by 36 (half of 72 avatar size)
                  left: AppSpacing.pageMarginHorizontal,
                  right: AppSpacing.pageMarginHorizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Avatar with border
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AppAvatar(
                          url: inf['avatar_url'],
                          fallbackText: inf['display_name'] ?? 'I',
                          size: 72,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      inf['display_name'] ?? 'Creator',
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (inf['is_verified'] == true) ...[
                                    const SizedBox(width: 5),
                                    const VerificationBadge(size: 17),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Creator · $location',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36), // spacing for avatar bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Stats row
                Row(
                  children: [
                    _buildStatPill(Iconsax.people, followersText, 'Followers'),
                    const SizedBox(width: 10),
                    _buildStatPill(Iconsax.gallery, '${_portfolio.length}', 'Portfolio'),
                    const SizedBox(width: 10),
                    _buildStatPill(Iconsax.star, _reviews.isEmpty ? '—' : ((_reviews.map((r) => (r['rating'] as num?)?.toDouble() ?? 0.0).fold(0.0, (a, b) => a + b) / _reviews.length).toStringAsFixed(1)), 'Rating'),
                  ],
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _startChat,
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : const Color(0xFF0F0F11),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.message,
                                size: 18,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Message',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _showSaveToListSheet,
                      child: Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Iconsax.archive_add,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Container(
            color: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.accent,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'About'),
                Tab(text: 'Portfolio'),
                Tab(text: 'Reviews'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAboutTab(inf, niches, platforms, followersText),
                _buildPortfolioTab(),
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String value, String label) {
    final isDark = AppColors.isDarkMode;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F11) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppColors.textMuted),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab(Map<String, dynamic> inf, List<String> niches, List<String> platforms, String followersText) {
    final prefs = inf['preferences'] as Map<String, dynamic>? ?? {};
    final handles = prefs['platform_handles'] as Map<String, dynamic>? ?? {};
    final connectedHandles = handles.entries.where((e) => e.value.toString().trim().isNotEmpty).toList();
    final isDark = AppColors.isDarkMode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMarginHorizontal,
        AppSpacing.md,
        AppSpacing.pageMarginHorizontal,
        AppSpacing.bottomScreenPadding + AppSpacing.lg,
      ),
      children: [
        // Bio section
        if (inf['bio'] != null && (inf['bio'] as String).trim().isNotEmpty) ...[
          _buildSectionCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.edit, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Bio',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  inf['bio'],
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 12),
        ],

        // Niches section
        if (niches.isNotEmpty) ...[
          _buildSectionCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.category, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Niches',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: niches.map((n) {
                    final nColor = AppColors.getCategoryColor(n);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: nColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: nColor.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        n,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: nColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 50.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 12),
        ],

        // Connected Platforms section
        if (connectedHandles.isNotEmpty) ...[
          _buildSectionCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.global, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Connected Platforms',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...connectedHandles.asMap().entries.map((mapEntry) {
                  final entry = mapEntry.value;
                  final platform = entry.key;
                  final handle = entry.value.toString();

                  IconData icon;
                  Color brandColor;
                  if (platform.toLowerCase() == 'instagram') {
                    icon = Iconsax.instagram;
                    brandColor = const Color(0xFFE1306C);
                  } else if (platform.toLowerCase() == 'youtube') {
                    icon = Iconsax.video_play;
                    brandColor = const Color(0xFFFF0000);
                  } else if (platform.toLowerCase() == 'tiktok') {
                    icon = Iconsax.music;
                    brandColor = AppColors.textPrimary;
                  } else if (platform.toLowerCase().contains('twitter') || platform.toLowerCase() == 'x') {
                    icon = Iconsax.global;
                    brandColor = const Color(0xFF1DA1F2);
                  } else {
                    icon = Iconsax.global;
                    brandColor = AppColors.accent;
                  }

                  return Padding(
                    padding: EdgeInsets.only(top: mapEntry.key > 0 ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => SocialAgent.launchSocialUrl(platform, handle),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: brandColor.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: brandColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: brandColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    platform,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '@${SocialAgent.normalizeHandle(platform, handle)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: brandColor.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 12),
        ] else if (platforms.isNotEmpty) ...[
          _buildSectionCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.global, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Platforms',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: platforms.map((p) => AppChip(label: p)).toList(),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 12),
        ],

        // Creator Details section
        _buildSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Iconsax.personalcard, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    'Creator Details',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildDetailRow(Iconsax.location, 'Location', inf['location'] ?? 'N/A'),
              _buildThinDivider(isDark),
              _buildDetailRow(Iconsax.people, 'Followers', followersText),
              _buildThinDivider(isDark),
              _buildDetailRow(Iconsax.calendar_1, 'Joined', _formatDate(inf['created_at'])),
              if (niches.isNotEmpty) ...[
                _buildThinDivider(isDark),
                _buildDetailRow(Iconsax.tag, 'Niche', niches.take(2).join(', ')),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 300.ms, delay: 150.ms).slideY(begin: 0.05, end: 0),
      ],
    );
  }

  Widget _buildSectionCard({required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildThinDivider(bool isDark) {
    return Divider(
      height: 20,
      thickness: 0.5,
      color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioTab() {
    final isDark = AppColors.isDarkMode;

    if (_portfolio.isEmpty) {
      return const AppEmptyState(
        icon: Iconsax.gallery,
        title: 'No Portfolio Items',
        subtitle: 'This creator has not added any portfolio items yet.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.pageMarginHorizontal),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: _portfolio.length,
      itemBuilder: (context, i) {
        final item = _portfolio[i];
        final postUrl = item['post_url'] as String?;
        return GestureDetector(
          onTap: () => PortfolioItemDetailSheet.show(context, item),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0F11) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: isDark ? const Color(0xFF1A1A1E) : const Color(0xFFF3F4F6),
                    child: AppImage(
                      url: item['media_url'],
                      fit: BoxFit.cover,
                      fallback: Icon(Iconsax.image, size: 32, color: AppColors.textMuted),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] ?? 'Untitled',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item['platform'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (postUrl != null && postUrl.trim().isNotEmpty)
                            Icon(Iconsax.link, size: 12, color: AppColors.accent),
                        ],
                      ),
                      if (item['engagement_rate'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Iconsax.trend_up, size: 11, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              '${item['engagement_rate']}% ER',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(
          duration: 300.ms,
          delay: Duration(milliseconds: 40 * i),
        ).slideY(begin: 0.08, end: 0, duration: 300.ms, delay: Duration(milliseconds: 40 * i));
      },
    );
  }

  void _showWriteReviewSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bctx) {
        return _WriteReviewSheet(
          influencerId: widget.influencerId,
          onSuccess: () {
            _loadAll(); // Reload reviews and ratings
          },
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    final isDark = AppColors.isDarkMode;
    final isBrand = ref.read(authProvider).role == 'brand';

    Widget? writeReviewButton;
    if (isBrand) {
      writeReviewButton = Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: _showWriteReviewSheet,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : const Color(0xFF0F0F11),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.edit,
                  size: 18,
                  color: isDark ? Colors.black : Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  'Write a Review',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_reviews.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMarginHorizontal,
          AppSpacing.md,
          AppSpacing.pageMarginHorizontal,
          AppSpacing.bottomScreenPadding + AppSpacing.lg,
        ),
        children: [
          if (writeReviewButton != null) writeReviewButton,
          const AppEmptyState(
            icon: Iconsax.star,
            title: 'No Reviews Yet',
            subtitle: 'Brands haven\'t left any reviews for this creator yet. Be the first to write one!',
          ),
        ],
      );
    }

    final double avgRating = _reviews.map((r) => (r['rating'] as num?)?.toDouble() ?? 0.0).fold(0.0, (a, b) => a + b) / _reviews.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMarginHorizontal,
        AppSpacing.md,
        AppSpacing.pageMarginHorizontal,
        AppSpacing.bottomScreenPadding + AppSpacing.lg,
      ),
      children: [
        if (writeReviewButton != null) writeReviewButton,
        // Summary Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0F11) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < avgRating.round() ? Iconsax.star1 : Iconsax.star,
                        color: const Color(0xFFF59E0B),
                        size: 16,
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Based on ${_reviews.length} review${_reviews.length > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                Iconsax.award,
                size: 56,
                color: AppColors.accent.withValues(alpha: 0.15),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: 16),

        // List of reviews
        ..._reviews.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final reviewer = r['reviewer'] as Map<String, dynamic>? ?? {};
          final display = reviewer['display_name'] ?? 'Verified Brand';
          final rating = (r['rating'] as num?)?.toDouble() ?? 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppAvatar(
                        url: reviewer['avatar_url'],
                        fallbackText: display,
                        size: 34,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              display,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: List.generate(5, (index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Icon(
                                    index < rating ? Iconsax.star1 : Iconsax.star,
                                    color: const Color(0xFFF59E0B),
                                    size: 12,
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatDate(r['created_at']),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (r['comment'] != null && (r['comment'] as String).trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      r['comment'],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(
              duration: 300.ms,
              delay: Duration(milliseconds: 40 * (i + 1)),
            ).slideY(begin: 0.05, end: 0, duration: 300.ms, delay: Duration(milliseconds: 40 * (i + 1))),
          );
        }),
      ],
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final dt = DateTime.parse(isoString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'N/A';
    }
  }
}

class _SliverTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;
  _SliverTabHeaderDelegate(this.tabBar, {required this.isDark});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabHeaderDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar || isDark != oldDelegate.isDark;
  }
}

class _SaveToListSheet extends ConsumerStatefulWidget {
  final String brandId;
  final String influencerId;
  const _SaveToListSheet({required this.brandId, required this.influencerId});
  @override
  ConsumerState<_SaveToListSheet> createState() => _SaveToListSheetState();
}

class _SaveToListSheetState extends ConsumerState<_SaveToListSheet> {
  List<Map<String, dynamic>> _lists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await SavedService().getSavedLists(widget.brandId);
    if (mounted) {
      setState(() {
        _lists = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Save to List',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final name = await _showCreateDialog(context);
                  if (name != null && name.isNotEmpty) {
                    await SavedService().createList(widget.brandId, name);
                    _load();
                  }
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded, size: 20, color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_lists.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No lists created yet. Tap + to create one.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _lists.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                ),
                itemBuilder: (context, i) {
                  final list = _lists[i];
                  final items = list['items'] as List? ?? [];
                  final isSaved = items.any((item) => item['influencer_id'] == widget.influencerId);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSaved ? Iconsax.folder_favorite5 : Iconsax.folder,
                      color: isSaved ? AppColors.accent : AppColors.textMuted,
                    ),
                    title: Text(
                      list['name'] ?? 'List',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    trailing: isSaved
                        ? Icon(Icons.check_circle_rounded, color: AppColors.success)
                        : null,
                    onTap: () async {
                      if (isSaved) {
                        await SavedService().removeFromList(list['id'], widget.influencerId);
                      } else {
                        await SavedService().addToList(list['id'], widget.influencerId);
                      }
                      _load();
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<String?> _showCreateDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    return showPremiumDialog<String>(
      context: context,
      title: 'New List',
      icon: Iconsax.folder_add,
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: 'List name',
          hintStyle: AppTextStyles.caption,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: const Text('Create'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  final String influencerId;
  final VoidCallback onSuccess;

  const _WriteReviewSheet({
    required this.influencerId,
    required this.onSuccess,
  });

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a comment for your review.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // 1. Get/create 1-to-1 chat room to satisfy PostgreSQL RLS participant constraint
      final room = await ChatService().getOrCreate1to1Room(
        brandId: user.id,
        influencerId: widget.influencerId,
      );
      final roomId = room['id'] as String;

      // 2. Submit review to reviews table
      await AnalyticsService().submitReview(
        reviewerId: user.id,
        reviewedId: widget.influencerId,
        rating: _rating,
        comment: comment,
        roomId: roomId,
      );

      if (mounted) {
        Navigator.pop(context); // Close sheet
        widget.onSuccess(); // Trigger UI reload
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grab Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Write a Review',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Rating stars selection
          Text(
            'Rating',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final starVal = index + 1;
              final isSelected = starVal <= _rating;
              return GestureDetector(
                onTap: _submitting ? null : () => setState(() => _rating = starVal),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    isSelected ? Iconsax.star1 : Iconsax.star,
                    color: const Color(0xFFF59E0B),
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Comment
          Text(
            'Review Comment',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            enabled: !_submitting,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Describe your experience collaborating with this creator...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
              fillColor: isDark ? const Color(0xFF1A1A1E) : const Color(0xFFF3F4F6),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? Colors.white : const Color(0xFF0F0F11),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: BorderSide(color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _submitting ? null : _submit,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _submitting
                          ? AppColors.textMuted
                          : (isDark ? Colors.white : const Color(0xFF0F0F11)),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Center(
                      child: _submitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            )
                          : Text(
                              'Submit',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
