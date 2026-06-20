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
import '../../core/services/card_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/data_services.dart';
import '../../shared/widgets/shared_widgets.dart';

class InfluencerBrandDetailScreen extends ConsumerStatefulWidget {
  final String brandId;
  const InfluencerBrandDetailScreen({super.key, required this.brandId});

  @override
  ConsumerState<InfluencerBrandDetailScreen> createState() => _InfluencerBrandDetailScreenState();
}

class _InfluencerBrandDetailScreenState extends ConsumerState<InfluencerBrandDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  bool _isCollapsed = false;
  Map<String, dynamic>? _brand;
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  bool _following = false;
  bool _togglingFollow = false;
  final _followService = FollowService();
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
        ProfileService().getProfile(widget.brandId),
        CardService().getBrandCards(widget.brandId),
        _analyticsService.getReviews(widget.brandId),
        if (user != null) _followService.isFollowing(user.id, widget.brandId) else Future.value(false),
      ]);

      if (mounted) {
        setState(() {
          _brand = results[0] as Map<String, dynamic>?;
          _campaigns = results[1] as List<Map<String, dynamic>>;
          _reviews = results[2] as List<Map<String, dynamic>>;
          _following = results[3] as bool;
          _loading = false;
        });
      }
    } catch (e) {
      print('[BRAND_DETAIL] Error loading details: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to follow brands.')),
      );
      return;
    }

    setState(() => _togglingFollow = true);
    try {
      if (_following) {
        await _followService.unfollow(user.id, widget.brandId);
        setState(() {
          _following = false;
        });
      } else {
        await _followService.follow(user.id, widget.brandId);
        setState(() {
          _following = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update follow status: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingFollow = false);
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
        brandId: widget.brandId,
        influencerId: user.id,
      );
      if (mounted) {
        Navigator.pop(context); // close loader
        context.push('/influencer/chats/${room['id']}');
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Brand Profile')),
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (_brand == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Brand Profile')),
        body: const AppEmptyState(icon: Icons.error_rounded, title: 'Brand profile not found'),
      );
    }

    final b = _brand!;
    final industry = b['industry'] ?? 'Industry Partner';
    final location = b['location'] ?? 'Global';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preferences = b['preferences'] as Map<String, dynamic>? ?? {};
    final website = b['website_url'] ?? preferences['website'] ?? '';

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
              title: AnimatedOpacity(
                opacity: _isCollapsed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  children: [
                    AppAvatar(
                      url: b['avatar_url'],
                      fallbackText: b['display_name'] ?? 'B',
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      b['display_name'] ?? 'Brand Name',
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (b['is_verified'] == true) ...[
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
                    // Glassmorphic layer at bottom
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
                  // Overlapping avatar & display details Stack
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
                                url: b['avatar_url'],
                                fallbackText: b['display_name'] ?? 'B',
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
                                            b['display_name'] ?? 'Brand Name',
                                            style: AppTextStyles.h4.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (b['is_verified'] == true) ...[
                                          const SizedBox(width: 4),
                                          const VerificationBadge(size: 18),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      b['company_name'] ?? industry,
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
                        // Brand details row (Location & Industry Tags)
                        Row(
                          children: [
                            Icon(Iconsax.location, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(location, style: AppTextStyles.captionSm),
                        const SizedBox(width: 16),
                        Icon(Iconsax.tag, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(industry, style: AppTextStyles.captionSm),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Action buttons (Follow & Message)
                    Row(
                      children: [
                        Expanded(
                          child: _following
                              ? OutlinedButton.icon(
                                  onPressed: _togglingFollow ? null : _toggleFollow,
                                  icon: _togglingFollow
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Iconsax.user_minus, size: 16),
                                  label: const Text('Following'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.accent,
                                    side: BorderSide(color: AppColors.accent),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                    ),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: _togglingFollow ? null : _toggleFollow,
                                  icon: _togglingFollow
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(Colors.white),
                                          ),
                                        )
                                      : const Icon(Iconsax.user_add, size: 16),
                                  label: const Text('Follow'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: AppColors.accentOnDark,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            label: 'Message',
                            icon: Iconsax.message,
                            isPrimary: false,
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
                    Tab(text: 'Campaigns'),
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
            _buildAboutTab(b, website),
            _buildCampaignsTab(),
            _buildReviewsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab(Map<String, dynamic> b, String website) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (b['bio'] != null && (b['bio'] as String).trim().isNotEmpty) ...[
          Text('Company Bio', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Text(
            b['bio'],
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (website.isNotEmpty) ...[
          Text('Website', style: AppTextStyles.label),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final uri = Uri.parse(website.startsWith('http') ? website : 'https://$website');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Row(
              children: [
                Icon(Iconsax.global, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    website,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Company Details / Preferences
        Text('Preferences & Targets', style: AppTextStyles.label),
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
              _buildDetailRow('Industry', b['industry'] ?? 'N/A'),
              const Divider(height: 20),
              _buildDetailRow('Headquarters', b['location'] ?? 'N/A'),
              const Divider(height: 20),
              _buildDetailRow('Member Since', _formatDate(b['created_at'])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCampaignsTab() {
    if (_campaigns.isEmpty) {
      return const AppEmptyState(
        icon: Iconsax.briefcase,
        title: 'No Active Campaigns',
        subtitle: 'This brand has no active campaign cards posted right now.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _campaigns.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final card = _campaigns[i];
        return CampaignCardWidget(
          card: card,
          onTap: () => context.push('/influencer/discover/${card['id']}'),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return const AppEmptyState(
        icon: Iconsax.star,
        title: 'No Reviews Yet',
        subtitle: 'Creators haven\'t left any reviews for this brand yet.',
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
          final display = reviewer['display_name'] ?? 'Verified Creator';
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
