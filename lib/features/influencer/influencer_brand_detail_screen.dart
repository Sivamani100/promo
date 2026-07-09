import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/card_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/data_services.dart';
import '../../core/services/application_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_skeleton.dart';
import '../../shared/widgets/screen_skeletons.dart';
import '../trust/report_sheet.dart';
import '../../core/services/block_service.dart';

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
  double _headerOpacity = 1.0;
  Map<String, dynamic>? _brand;
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _reviews = [];
  Set<String> _appliedCardIds = {};
  bool _loading = true;
  bool _following = false;
  bool _togglingFollow = false;
  final _followService = FollowService();
  final _analyticsService = AnalyticsService();

  // Trust metrics
  double _responseRate = 100.0;
  Duration? _avgResponseTime;
  int _collaborationsCount = 0;

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
        ProfileService().getProfile(widget.brandId),
        CardService().getBrandCards(widget.brandId),
        _analyticsService.getReviews(widget.brandId),
        if (user != null) _followService.isFollowing(user.id, widget.brandId) else Future.value(false),
        if (user != null) ApplicationService().getAppliedCardIds(user.id) else Future.value(<String>[]),
        ApplicationService().getBrandTrustMetrics(widget.brandId),
      ]);

      if (mounted) {
        final metrics = results[5] as Map<String, dynamic>;
        final totalApps = metrics['total_applications'] as int? ?? 0;
        final respondedApps = metrics['responded_applications'] as int? ?? 0;
        final acceptedApps = metrics['accepted_applications'] as int? ?? 0;
        final avgResponseTimeSec = metrics['avg_response_time_seconds'] as int? ?? 0;

        setState(() {
          _brand = results[0] as Map<String, dynamic>?;
          _campaigns = results[1] as List<Map<String, dynamic>>;
          _reviews = results[2] as List<Map<String, dynamic>>;
          _following = results[3] as bool;
          _appliedCardIds = (results[4] as List<String>).toSet();
          _responseRate = totalApps > 0 ? (respondedApps / totalApps) * 100.0 : 100.0;
          _avgResponseTime = avgResponseTimeSec > 0 ? Duration(seconds: avgResponseTimeSec) : null;
          _collaborationsCount = acceptedApps; // Wait, acceptedApps is count of accepted apps
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[BRAND_DETAIL] Error loading details: $e');
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
      AppSnackbar.show(context, 'Please log in to follow brands.');
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
      if (mounted) {
        AppSnackbar.show(context, 'Failed to update follow status: $e');
      }
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
        AppSnackbar.show(context, 'Failed to open chat: $err');
      }
    }
  }

  Future<void> _confirmBlockUser() async {
    final user = ref.read(authProvider).user;
    if (user == null || _brand == null) return;
    final displayName = _brand!['display_name'] ?? 'Brand';

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.user_minus, color: AppColors.error, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Block $displayName?',
                        style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Blocking this brand will prevent them from sending you messages or viewing your profile.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(sheetCtx, true),
                        child: const Text('Block'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final blocked = await BlockService().blockUser(user.id, widget.brandId);
        if (mounted) {
          Navigator.pop(context); // close loader
          if (blocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$displayName has been blocked.')),
            );
            Navigator.pop(context); // Go back from detail screen
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User is already blocked.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // close loader
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to block user: $e')),
          );
        }
      }
    }
  }

  void _showWriteReviewSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bctx) {
        return _WriteReviewSheet(
          brandId: widget.brandId,
          onSuccess: () {
            _loadAll(); // Reload reviews and ratings
          },
        );
      },
    );
  }

  Widget _buildStatPill(IconData icon, String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Brand Profile')),
        body: const CreatorBrandDetailSkeleton(),
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
    final double avgRating = _reviews.isEmpty ? 0.0 : (_reviews.map((r) => (r['rating'] as num?)?.toDouble() ?? 0.0).fold(0.0, (a, b) => a + b) / _reviews.length);
    final currentUserRole = ref.watch(authProvider).role;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image & Overlay avatar stack
          SizedBox(
            height: 140.0 + MediaQuery.of(context).padding.top,
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
                      colors: [
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
                // 3-dot Actions Menu (Report/Block)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 12,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      cardColor: isDark ? const Color(0xFF141416) : Colors.white,
                    ),
                    child: PopupMenuButton<String>(
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'report') {
                          ReportSheet.show(
                            context,
                            reportedId: widget.brandId,
                            contentTypeName: 'User',
                          );
                        } else if (value == 'block') {
                          _confirmBlockUser();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Iconsax.danger, color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              const Text('Report Brand'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              Icon(Iconsax.user_remove, color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              const Text('Block Brand'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: -45, // half of avatar size (80 + 8 border/padding) to overlap cover
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
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AppAvatar(
                          url: b['avatar_url'],
                          fallbackText: b['display_name'] ?? 'B',
                          size: 80,
                          heroTag: 'brand_avatar_${b['id']}',
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
          ),
          const SizedBox(height: 45), // spacing for avatar bottom
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMarginHorizontal,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Brand details row (Location & Industry Tags)
                Row(
                  children: [
                    Icon(Iconsax.location, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(location, style: AppTextStyles.captionSm.copyWith(fontSize: 11.5)),
                    const SizedBox(width: 16),
                    Icon(Iconsax.tag, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(industry, style: AppTextStyles.captionSm.copyWith(fontSize: 11.5)),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Stats row (matching Creator profile look)
                Row(
                  children: [
                    _buildStatPill(Iconsax.briefcase, '${_campaigns.length}', 'Campaigns'),
                    const SizedBox(width: 10),
                    _buildStatPill(Iconsax.award, '$_collaborationsCount', 'Collabs'),
                    const SizedBox(width: 10),
                    _buildStatPill(
                      Iconsax.star,
                      _reviews.isEmpty
                          ? '—'
                          : (avgRating.toStringAsFixed(1)),
                      'Rating',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action buttons (Follow & Message)
                if (currentUserRole == 'influencer') ...[
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
              ],
            ),
          ),
          Container(
            color: isDark ? const Color(0xFF0F0F16) : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: isDark ? Colors.white : Colors.black,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: isDark ? Colors.white : Colors.black,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 3.0,
              dividerColor: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'About'),
                Tab(text: 'Campaigns'),
                Tab(text: 'Reviews'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAboutTab(b, website),
                _buildCampaignsTab(),
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTab(Map<String, dynamic> b, String website) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Trust Signals Card
        _buildSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.shield_security, size: 14, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(
                    'TRUST & VERIFICATION',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Member since
                  _buildTrustBadge(
                    icon: Iconsax.calendar,
                    label: 'Member since ${b['created_at'] != null ? DateFormat('MMMM yyyy').format(DateTime.parse(b['created_at']).toLocal()) : 'Recent'}',
                  ),
                  // New Brand Badge
                  if (b['created_at'] != null &&
                      DateTime.now().difference(DateTime.parse(b['created_at'])).inDays < 7)
                    _buildTrustBadge(
                      icon: Iconsax.award,
                      label: 'New Brand',
                      color: AppColors.warning,
                    ),
                  // Response rate
                  _buildTrustBadge(
                    icon: Iconsax.message_programming,
                    label: 'Response rate: ${_responseRate.toStringAsFixed(0)}%',
                    color: _responseRate >= 80
                        ? AppColors.success
                        : (_responseRate >= 50 ? AppColors.warning : AppColors.error),
                  ),
                  // Avg response time
                  if (_avgResponseTime != null)
                    _buildTrustBadge(
                      icon: Iconsax.timer_1,
                      label: 'Avg response time: ${_formatResponseTime(_avgResponseTime)}',
                    ),
                  // Completed collaborations count
                  _buildTrustBadge(
                    icon: Iconsax.briefcase,
                    label: '$_collaborationsCount collaboration${_collaborationsCount != 1 ? 's' : ''} completed',
                  ),
                  // Warning Flags
                  if (b['account_status'] == 'warned' || (b['warning_count'] ?? 0) > 0)
                    _buildTrustBadge(
                      icon: Iconsax.danger,
                      label: 'Account Warning',
                      color: AppColors.error,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

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
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final card = _campaigns[i];
        return CampaignCardWidget(
          card: card,
          isApplied: _appliedCardIds.contains(card['id']),
          onTap: () => context.push('/influencer/discover/${card['id']}'),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInfluencer = ref.read(authProvider).role == 'influencer';

    Widget? writeReviewButton;
    if (isInfluencer) {
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (writeReviewButton != null) writeReviewButton,
          const AppEmptyState(
            icon: Iconsax.star,
            title: 'No Reviews Yet',
            subtitle: 'Creators haven\'t left any reviews for this brand yet. Be the first to write one!',
          ),
        ],
      );
    }

    final double avgRating = _reviews.map((r) => (r['rating'] as num?)?.toDouble() ?? 0.0).fold(0.0, (a, b) => a + b) / _reviews.length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (writeReviewButton != null) writeReviewButton,
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
              Icon(Iconsax.award, size: 64, color: AppColors.accent.withValues(alpha: 0.2)),
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

  String _formatResponseTime(Duration? duration) {
    if (duration == null) return '—';
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h';
    } else {
      return '${duration.inDays}d';
    }
  }

  Widget _buildTrustBadge({required IconData icon, required String label, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
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

class _WriteReviewSheet extends ConsumerStatefulWidget {
  final String brandId;
  final VoidCallback onSuccess;

  const _WriteReviewSheet({
    required this.brandId,
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
      AppSnackbar.show(context, 'Please write a comment for your review.');
      return;
    }

    setState(() => _submitting = true);

    try {
      // 1. Get/create 1-to-1 chat room to satisfy PostgreSQL RLS participant constraint
      final room = await ChatService().getOrCreate1to1Room(
        brandId: widget.brandId,
        influencerId: user.id,
      );
      final roomId = room['id'] as String;

      // 2. Submit review to reviews table
      await AnalyticsService().submitReview(
        reviewerId: user.id,
        reviewedId: widget.brandId,
        rating: _rating,
        comment: comment,
        roomId: roomId,
      );

      if (mounted) {
        Navigator.pop(context); // Close sheet
        widget.onSuccess(); // Trigger UI reload
        AppSnackbar.show(context, 'Review submitted successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to submit review: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              hintText: 'Describe your experience collaborating with this brand...',
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
