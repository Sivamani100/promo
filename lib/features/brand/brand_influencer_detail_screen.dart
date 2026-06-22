import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
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
    if (collapsed != _isCollapsed) {
      setState(() {
        _isCollapsed = collapsed;
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
      print('[INFLUENCER_DETAIL] Error loading details: $e');
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
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Creator Profile')),
        body: const ShimmerProfileDetail(),
      );
    }

    if (_influencer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Creator Profile')),
        body: const AppEmptyState(icon: Icons.error_rounded, title: 'Creator profile not found'),
      );
    }

    final inf = _influencer!;
    final niches = (inf['niche'] as List?)?.cast<String>() ?? [];
    final platforms = (inf['platforms'] as List?)?.cast<String>() ?? [];
    final location = inf['location'] ?? 'Global';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final followersCount = inf['follower_count'] ?? 0;
    String followersText = '${followersCount}';
    if (followersCount >= 1000) {
      followersText = '${(followersCount / 1000).toStringAsFixed(1)}K';
    }

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 140.0,
              floating: false,
              pinned: true,
              backgroundColor: isDark ? const Color(0xFF0F0F16) : Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Iconsax.archive_add),
                  onPressed: _showSaveToListSheet,
                ),
              ],
              title: AnimatedOpacity(
                opacity: _isCollapsed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  children: [
                    AppAvatar(
                      url: inf['avatar_url'],
                      fallbackText: inf['display_name'] ?? 'I',
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      inf['display_name'] ?? 'Creator Name',
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (inf['is_verified'] == true) ...[
                      const SizedBox(width: 4),
                      const VerificationBadge(size: 14),
                    ],
                  ],
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient Cover Background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withOpacity(0.4),
                            AppColors.purple.withOpacity(0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    // Shadow layer at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              isDark ? const Color(0xFF0F0F16) : Colors.white,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overlapping avatar & details Stack
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(height: 45), // spacing for avatar bottom
                      Positioned(
                        top: -45, // half of avatar size (80 + 8 border/padding) to overlap cover
                        left: AppSpacing.pageMarginHorizontal,
                        right: AppSpacing.pageMarginHorizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF0F0F16) : Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: AppAvatar(
                                url: inf['avatar_url'],
                                fallbackText: inf['display_name'] ?? 'I',
                                size: 80,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            inf['display_name'] ?? 'Creator Name',
                                            style: AppTextStyles.h4.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (inf['is_verified'] == true) ...[
                                          const SizedBox(width: 4),
                                          const VerificationBadge(size: 18),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      'Essential Creator · $location',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageMarginHorizontal,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Location & Follower Count Row
                        Row(
                          children: [
                            Icon(Iconsax.location, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(location, style: AppTextStyles.captionSm),
                        const SizedBox(width: 16),
                        Icon(Iconsax.people, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('$followersText followers', style: AppTextStyles.captionSm),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Message Action Button
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Message',
                            icon: Iconsax.message,
                            onTap: _startChat,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabHeaderDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.accent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: AppTextStyles.label,
                  unselectedLabelStyle: AppTextStyles.labelSm,
                  tabs: const [
                    Tab(text: 'About'),
                    Tab(text: 'Portfolio'),
                    Tab(text: 'Reviews'),
                  ],
                ),
                isDark: isDark,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAboutTab(inf, niches, platforms, followersText),
            _buildPortfolioTab(),
            _buildReviewsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab(Map<String, dynamic> inf, List<String> niches, List<String> platforms, String followersText) {
    final prefs = inf['preferences'] as Map<String, dynamic>? ?? {};
    final handles = prefs['platform_handles'] as Map<String, dynamic>? ?? {};
    final connectedHandles = handles.entries.where((e) => e.value.toString().trim().isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (inf['bio'] != null && (inf['bio'] as String).trim().isNotEmpty) ...[
          Text('Bio', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Text(
            inf['bio'],
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (niches.isNotEmpty) ...[
          Text('Niches', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: niches.map((n) => AppChip(label: n)).toList(),
          ),
          const SizedBox(height: 24),
        ],


        if (connectedHandles.isNotEmpty) ...[
          Text('Connected Platforms', style: AppTextStyles.label),
          const SizedBox(height: 12),
          Column(
            children: connectedHandles.map((entry) {
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

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: brandColor, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(platform, style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            '@${SocialAgent.normalizeHandle(platform, handle)}',
                            style: AppTextStyles.captionSm.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => SocialAgent.launchSocialUrl(platform, handle),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Visit Profile', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor.withOpacity(0.1),
                        foregroundColor: brandColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ] else if (platforms.isNotEmpty) ...[
          Text('Platforms', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: platforms.map((p) => AppChip(label: p)).toList(),
          ),
          const SizedBox(height: 24),
        ],

        Text('Creator Details', style: AppTextStyles.label),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildDetailRow('Location', inf['location'] ?? 'N/A'),
              const Divider(height: 20),
              _buildDetailRow('Followers', followersText),
              const Divider(height: 20),
              _buildDetailRow('Joined On', _formatDate(inf['created_at'])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioTab() {
    if (_portfolio.isEmpty) {
      return const AppEmptyState(
        icon: Iconsax.gallery,
        title: 'No Portfolio Items',
        subtitle: 'This creator has not added any portfolio items yet.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _portfolio.length,
      itemBuilder: (context, i) {
        final item = _portfolio[i];
        final postUrl = item['post_url'] as String?;
        return GestureDetector(
          onTap: () async {
            if (postUrl != null && postUrl.trim().isNotEmpty) {
              final uri = Uri.tryParse(postUrl.trim());
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    color: AppColors.surface2,
                    width: double.infinity,
                    child: AppImage(
                      url: item['media_url'],
                      fit: BoxFit.cover,
                      fallback: Icon(Iconsax.image, size: 40, color: AppColors.textMuted),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['title'] ?? 'Untitled', style: AppTextStyles.labelSm, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['platform'] ?? '', style: AppTextStyles.captionSm),
                          if (postUrl != null && postUrl.trim().isNotEmpty)
                            Icon(Iconsax.link, size: 12, color: AppColors.accent),
                        ],
                      ),
                      if (item['engagement_rate'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Iconsax.trend_up, size: 12, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text('${item['engagement_rate']}% ER', style: AppTextStyles.captionSm.copyWith(color: AppColors.success)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return const AppEmptyState(
        icon: Iconsax.star,
        title: 'No Reviews Yet',
        subtitle: 'Brands haven\'t left any reviews for this creator yet.',
      );
    }

    final double avgRating = _reviews.map((r) => (r['rating'] as num?)?.toDouble() ?? 0.0).fold(0.0, (a, b) => a + b) / _reviews.length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: AppTextStyles.h1.copyWith(fontSize: 36, color: AppColors.warning),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < avgRating.round() ? Iconsax.star1 : Iconsax.star,
                        color: AppColors.warning,
                        size: 16,
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Based on ${_reviews.length} reviews',
                    style: AppTextStyles.captionSm,
                  ),
                ],
              ),
              const Spacer(),
              Icon(Iconsax.award, size: 64, color: AppColors.accent.withOpacity(0.2)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // List of reviews
        ..._reviews.map((r) {
          final reviewer = r['reviewer'] as Map<String, dynamic>? ?? {};
          final display = reviewer['display_name'] ?? 'Verified Brand';
          final rating = (r['rating'] as num?)?.toDouble() ?? 0.0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      url: reviewer['avatar_url'],
                      fallbackText: display,
                      size: 32,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(display, style: AppTextStyles.labelSm),
                          const SizedBox(height: 2),
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < rating ? Iconsax.star1 : Iconsax.star,
                                color: AppColors.warning,
                                size: 12,
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatDate(r['created_at']),
                      style: AppTextStyles.captionSm.copyWith(fontSize: 10),
                    ),
                  ],
                ),
                if (r['comment'] != null && (r['comment'] as String).trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    r['comment'],
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.label.copyWith(fontSize: 13),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day}/${dt.month}/${dt.year}';
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
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? const Color(0xFF0F0F16) : Colors.white,
      child: Column(
        children: [
          tabBar,
          const Divider(height: 1, thickness: 1),
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Save to List', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Iconsax.add_circle, size: 24),
                onPressed: () async {
                  final name = await _showCreateDialog(context);
                  if (name != null && name.isNotEmpty) {
                    await SavedService().createList(widget.brandId, name);
                    _load();
                  }
                },
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
                  style: AppTextStyles.caption,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _lists.length,
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
                    title: Text(list['name'] ?? 'List', style: AppTextStyles.label),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
