import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/card_service.dart';
import '../../shared/widgets/app_skeleton.dart';
import '../../shared/widgets/screen_skeletons.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../core/cache/app_cache.dart';
import '../../core/network/connectivity_service.dart';

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

  Future<void> _load({bool background = false}) async {
    // HARDENING: devops-agent 2026-06-25
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final cacheKey = 'brand_cards_screen_${user.id}';

    if (!background) {
      final cached = AppCache().get<List<Map<String, dynamic>>>(cacheKey);
      if (cached != null) {
        setState(() {
          _cards = cached;
          _loading = false;
        });
      } else {
        setState(() => _loading = true);
      }
    }

    try {
      final data = await CardService().getBrandCards(user.id);
      AppCache().set(cacheKey, data, ttl: const Duration(minutes: 5));
      if (mounted) {
        setState(() {
          _cards = data;
          _loading = false;
        });
      }

      if (!background && AppCache().get(cacheKey) != null) {
        _load(background: true);
      }
    } catch (e) {
      print('Error loading brand cards: $e');
      if (mounted && !background && _cards.isEmpty) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _toggleCardStatus(Map<String, dynamic> card) async {
    final cardId = card['id']?.toString() ?? '';
    final isActive = (card['status'] ?? '') == 'active';
    final newStatus = isActive ? 'paused' : 'active';
    try {
      await CardService().updateCard(cardId, {'status': newStatus});
      AppSnackbar.success(context, isActive ? 'Card paused' : 'Card is now active');
      _load();
    } catch (e) {
      AppSnackbar.error(context, 'Failed to update status');
    }
    return false; // Don't dismiss the item
  }

  Future<bool> _deleteCard(Map<String, dynamic> card) async {
    final cardId = card['id']?.toString() ?? '';
    final confirmed = await showPremiumConfirmDialog(
      context: context,
      title: 'Delete Campaign Card',
      message: 'Are you sure you want to delete this campaign card? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Iconsax.trash,
    );
    if (confirmed == true) {
      try {
        await CardService().deleteCard(cardId);
        AppSnackbar.success(context, 'Card deleted');
        _load();
      } catch (e) {
        AppSnackbar.error(context, 'Failed to delete card');
      }
    }
    return false; // Don't dismiss the item
  }

  void _showCardActions(Map<String, dynamic> card) {
    final isDark = AppColors.isDarkMode;
    final isActive = (card['status'] ?? '') == 'active';
    final title = card['title'] as String? ?? 'Card';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F0F11) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: Icon(
                    Iconsax.eye,
                    color: isActive ? const Color(0xFF10B981) : AppColors.textMuted,
                  ),
                  title: Text(
                    'Visible to Influencers',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isActive
                        ? 'Card is live and discoverable'
                        : 'Card is hidden from everyone',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: SizedBox(
                    height: 28,
                    width: 46,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch.adaptive(
                        value: isActive,
                        onChanged: (val) {
                          Navigator.pop(ctx);
                          _toggleCardStatus(card);
                        },
                        activeColor: const Color(0xFF10B981),
                        activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                        inactiveThumbColor: isDark ? const Color(0xFF4B4B50) : const Color(0xFF9CA3AF),
                        inactiveTrackColor: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Iconsax.edit_2, color: Color(0xFF6366F1)),
                  title: Text(
                    'Edit Card',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/brand/cards/new', extra: card);
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Iconsax.trash, color: Color(0xFFF43F5E)),
                  title: Text(
                    'Delete Card',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF43F5E),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteCard(card);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _cards;
    return _cards.where((c) => c['status'] == _filter).toList();
  }

  Widget _buildFilterChip(String filterKey, String label, int count) {
    final isSelected = _filter == filterKey;
    final isDark = AppColors.isDarkMode;

    Color activeColor = AppColors.accent;
    Color activeTextColor = isDark ? Colors.black : Colors.white;

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

    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (next == true && previous == false) {
        debugPrint('[CARDS] Back online, reloading...');
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
          ? Column(
              children: [
                // Skeleton Filter Chips
                Container(
                  height: 38,
                  margin: const EdgeInsets.only(bottom: 8, top: 12),
                  child: SkeletonShimmer(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pageMarginHorizontal,
                      ),
                      children: List.generate(4, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            width: index == 0 ? 80 : (index == 1 ? 100 : (index == 2 ? 100 : 90)),
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageMarginHorizontal,
                      AppSpacing.xs,
                      AppSpacing.pageMarginHorizontal,
                      AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                    ),
                    itemCount: 5,
                    separatorBuilder: (_, index) => const SizedBox(height: 16),
                    itemBuilder: (_, index) => const BentoBrandCardSkeleton(),
                  ),
                ),
              ],
            )
          : RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.lightImpact();
                await _load();
              },
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
                              title: "No cards yet. Create your first campaign!",
                              subtitle: "",
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
                        final cardId = card['id']?.toString() ?? '';
                        final isActive = (card['status'] ?? '') == 'active';
                        return Dismissible(
                          key: Key('card_$cardId'),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              // Toggle status
                              return await _toggleCardStatus(card);
                            } else {
                              // Delete
                              return await _deleteCard(card);
                            }
                          },
                          background: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                                  : const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 24),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActive ? Iconsax.pause_circle : Iconsax.play_circle,
                                  color: isActive ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isActive ? 'Pause' : 'Activate',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isActive ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          secondaryBackground: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Delete',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF43F5E),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Iconsax.trash,
                                  color: Color(0xFFF43F5E),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                          child: _BentoBrandCard(
                            card: card,
                            animationDelayIndex: i,
                            onTap: () => context.push('/brand/cards/${card['id']}'),
                            onLongPress: () => _showCardActions(card),
                          ),
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
  final VoidCallback? onLongPress;

  const _BentoBrandCard({
    required this.card,
    required this.animationDelayIndex,
    required this.onTap,
    this.onLongPress,
  });

  Widget _buildPlatformIcon(String platform) {
    final p = platform.toLowerCase();
    String? assetPath;
    if (p.contains('instagram')) {
      assetPath = 'assets/Social media icons/Instagram logo.png';
    } else if (p.contains('youtube')) {
      assetPath = 'assets/Social media icons/youtube logo.png';
    } else if (p.contains('tiktok')) {
      assetPath = 'assets/Social media icons/Tiktok logo.png';
    } else if (p.contains('twitter') || p.contains('x')) {
      assetPath = 'assets/Social media icons/x logo.png';
    } else if (p.contains('linkedin')) {
      assetPath = 'assets/Social media icons/LinkedIn.png';
    } else if (p.contains('github')) {
      assetPath = 'assets/Social media icons/GitHub.png';
    } else if (p.contains('behance')) {
      assetPath = 'assets/Social media icons/Behance.png';
    }

    if (assetPath != null) {
      return Image.asset(assetPath, width: 14, height: 14);
    }
    return Icon(Iconsax.global, size: 14, color: AppColors.textMuted);
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
            onLongPress: onLongPress,
            child: Stack(
              children: [
                Padding(
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
                            // Category tag
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
                            const SizedBox(height: 6),
                            // Title
                            Padding(
                              padding: const EdgeInsets.only(right: 60),
                              child: Text(
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
                // Status pill at top-right
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.toLowerCase() == 'active'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF43F5E),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
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