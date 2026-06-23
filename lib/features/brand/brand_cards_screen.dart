import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/card_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class BrandCardsScreen extends ConsumerStatefulWidget {
  const BrandCardsScreen({super.key});
  @override
  ConsumerState<BrandCardsScreen> createState() => _BrandCardsScreenState();
}

class _BrandCardsScreenState extends ConsumerState<BrandCardsScreen> {
  List<Map<String, dynamic>> _cards = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final data = await CardService().getBrandCards(user.id);
    if (mounted) {
      setState(() {
        _cards = data;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _cards;
    return _cards.where((c) => c['status'] == _filter).toList();
  }

  Widget _buildFilterChip(String filterKey, String label, int count) {
    final isSelected = _filter == filterKey;
    final isDark = AppColors.isDarkMode;

    Color activeColor = AppColors.accent;
    Color activeTextColor = Colors.white;

    if (filterKey == 'active' && isSelected) {
      activeColor = const Color(0xFF10B981); // Emerald
    } else if (filterKey == 'paused' && isSelected) {
      activeColor = const Color(0xFFF59E0B); // Amber
      activeTextColor = Colors.black;
    } else if (filterKey == 'closed' && isSelected) {
      activeColor = const Color(0xFFF43F5E); // Rose
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = filterKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? const Color(0xFF0F0F11) : Colors.white),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB)),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeTextColor : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (activeTextColor == Colors.black
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.15))
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeTextColor : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final allCount = _cards.length;
    final activeCount = _cards.where((c) => c['status'] == 'active').length;
    final pausedCount = _cards.where((c) => c['status'] == 'paused').length;
    final closedCount = _cards.where((c) => c['status'] == 'closed').length;

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageMarginHorizontal,
        ),
        children: [
          _buildFilterChip('all', 'All', allCount),
          const SizedBox(width: 8),
          _buildFilterChip('active', 'Active', activeCount),
          const SizedBox(width: 8),
          _buildFilterChip('paused', 'Paused', pausedCount),
          const SizedBox(width: 8),
          _buildFilterChip('closed', 'Closed', closedCount),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && _loading) {
        _load();
      }
    });

    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final isDark = AppColors.isDarkMode;

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
            centerTitle: false,
            titleSpacing: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'My Cards',
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
                icon: const Icon(Icons.add_rounded, size: 24),
                onPressed: () => context.push('/brand/cards/new'),
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
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageMarginHorizontal,
                vertical: AppSpacing.pageMarginVertical,
              ),
              itemCount: 4,
              separatorBuilder: (_, index) => const SizedBox(height: 16),
              itemBuilder: (_, index) => const ShimmerCampaignCard(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              backgroundColor: isDark ? const Color(0xFF0F0F11) : Colors.white,
              child: Column(
                children: [
                  // Custom Bento Filter Tabs with counts
                  _buildFilterChips(),
                  Expanded(
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.xs,
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                      ),
                      itemCount: _filtered.isEmpty ? 2 : _filtered.length + 1,
                      separatorBuilder: (context, i) {
                        if (_filtered.isEmpty) return const SizedBox.shrink();
                        if (i == _filtered.length - 1) return const SizedBox.shrink();
                        return const SizedBox(height: 16);
                      },
                      itemBuilder: (context, i) {
                        if (_filtered.isEmpty) {
                          if (i == 0) {
                            return AppEmptyState(
                              icon: Iconsax.cards,
                              title: 'No cards found',
                              subtitle: 'Create your first campaign card',
                              actionLabel: 'Create Card',
                              onAction: () => context.push('/brand/cards/new'),
                            );
                          } else {
                            return _buildFooter();
                          }
                        }
                        if (i == _filtered.length) {
                          return _buildFooter();
                        }
                        final card = _filtered[i];
                        return _BentoBrandCard(
                          card: card,
                          animationDelayIndex: i,
                          onTap: () => context.push('/brand/cards/${card['id']}'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 56, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Launch your',
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
            'next campaign.',
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
    );
  }
}

class _BentoBrandCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final int animationDelayIndex;
  final VoidCallback onTap;

  const _BentoBrandCard({
    required this.card,
    required this.animationDelayIndex,
    required this.onTap,
  });

  Widget _buildPlatformIcon(String platform) {
    final p = platform.toLowerCase();
    IconData iconData;
    Color iconColor;
    if (p.contains('instagram')) {
      iconData = Iconsax.instagram;
      iconColor = const Color(0xFFE1306C);
    } else if (p.contains('youtube')) {
      iconData = Icons.video_library_outlined;
      iconColor = const Color(0xFFFF0000);
    } else if (p.contains('tiktok')) {
      iconData = Icons.music_note_outlined;
      iconColor = const Color(0xFF000000);
    } else if (p.contains('twitter') || p.contains('x')) {
      iconData = Icons.close_rounded;
      iconColor = AppColors.textPrimary;
    } else if (p.contains('linkedin')) {
      iconData = Icons.business_outlined;
      iconColor = const Color(0xFF0077B5);
    } else {
      iconData = Iconsax.global;
      iconColor = AppColors.textMuted;
    }
    return Icon(iconData, size: 14, color: iconColor);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final category = card['category'] as String? ?? 'Other';
    final categoryColor = AppColors.getCategoryColor(category);
    final status = card['status'] as String? ?? 'draft';
    final budget = card['budget_range'] as String? ?? 'Open';
    final title = card['title'] as String? ?? '';
    final openings = card['openings'] as int? ?? 1;
    final platforms = (card['platform_requirements'] as List?)?.cast<String>() ?? [];

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'active':
        statusColor = const Color(0xFF10B981); // Emerald
        break;
      case 'paused':
        statusColor = const Color(0xFFF59E0B); // Amber
        break;
      case 'closed':
        statusColor = const Color(0xFFF43F5E); // Rose
        break;
      default:
        statusColor = const Color(0xFF9CA3AF); // Muted grey
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Cover Image on left
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 68,
                      height: 68,
                      color: AppColors.surface2,
                      child: AppImage(
                        url: card['cover_image_url'],
                        fit: BoxFit.cover,
                        fallback: Icon(Iconsax.image, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Details on right
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category and Status row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: categoryColor.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                category.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: categoryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Title
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Budget, Openings & Platform requirements row
                        Row(
                          children: [
                            Icon(
                              Iconsax.wallet_3,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              budget,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Iconsax.people,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$openings opening${openings > 1 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (platforms.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _buildPlatformIcon(platforms.first),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 400),
          delay: Duration(milliseconds: 30 * animationDelayIndex),
        )
        .slideY(
          begin: 0.1,
          end: 0.0,
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 400),
          delay: Duration(milliseconds: 30 * animationDelayIndex),
        );
  }
}