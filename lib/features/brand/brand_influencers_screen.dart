import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/profile_service.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_skeleton.dart';
import '../../shared/widgets/screen_skeletons.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../core/services/block_service.dart';
import '../../core/network/connectivity_service.dart';

class BrandInfluencersScreen extends ConsumerStatefulWidget {
  const BrandInfluencersScreen({super.key});
  @override
  ConsumerState<BrandInfluencersScreen> createState() => _BrandInfluencersScreenState();
}

class _BrandInfluencersScreenState extends ConsumerState<BrandInfluencersScreen> {
  List<Map<String, dynamic>> _influencers = [];
  Set<String> _blockedUserIds = {};
  bool _loading = true;
  String? _nicheFilter;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    final results = await Future.wait([
      ProfileService().getInfluencers(limit: 100),
      if (user != null) BlockService().getAllBlockedUserIds(user.id) else Future.value(<String>{}),
    ]);
    if (mounted) {
      setState(() {
        _influencers = results[0] as List<Map<String, dynamic>>;
        _blockedUserIds = results[1] as Set<String>;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _influencers;

    if (_blockedUserIds.isNotEmpty) {
      list = list.where((i) => !_blockedUserIds.contains(i['id'])).toList();
    }

    if (_nicheFilter != null) {
      list = list.where((i) {
        final niches = (i['niche'] as List<dynamic>?)?.cast<String>() ?? [];
        return niches.contains(_nicheFilter);
      }).toList();
    }
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return list;
    return list.where((i) =>
        (i['display_name'] ?? '').toString().toLowerCase().contains(q) ||
        (i['bio'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _countForNiche(String? nicheKey) {
    if (nicheKey == null) return _influencers.length;
    return _influencers.where((i) {
      final niches = (i['niche'] as List<dynamic>?)?.cast<String>() ?? [];
      return niches.contains(nicheKey);
    }).length;
  }

  Widget _buildNicheChip(String? nicheKey, String label, int count) {
    final isSelected = _nicheFilter == nicheKey;
    final isDark = AppColors.isDarkMode;

    Color activeColor = AppColors.accent;
    Color activeTextColor = isDark ? Colors.black : Colors.white;

    if (isSelected) {
      if (nicheKey == null) {
        activeColor = AppColors.accent;
        activeTextColor = isDark ? Colors.black : Colors.white;
      } else {
        activeColor = AppColors.getCategoryColor(nicheKey);
        if (nicheKey == 'Travel' || (nicheKey == 'Lifestyle' && isDark)) {
          activeTextColor = Colors.black;
        } else {
          activeTextColor = Colors.white;
        }
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _nicheFilter = nicheKey;
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
                    ? Colors.white.withValues(alpha: 0.15)
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

  Widget _buildNicheChips() {
    final categories = [
      {'key': null, 'label': 'All Categories'},
      {'key': 'Fashion', 'label': 'Fashion'},
      {'key': 'Tech', 'label': 'Tech'},
      {'key': 'Food', 'label': 'Food'},
      {'key': 'Fitness', 'label': 'Fitness'},
      {'key': 'Beauty', 'label': 'Beauty'},
      {'key': 'Travel', 'label': 'Travel'},
      {'key': 'Gaming', 'label': 'Gaming'},
      {'key': 'Lifestyle', 'label': 'Lifestyle'},
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageMarginHorizontal,
        ),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final key = cat['key'];
          final label = cat['label'] as String;
          final count = _countForNiche(key);
          return _buildNicheChip(key, label, count);
        },
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search influencers...',
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
          prefixIcon: Icon(Iconsax.search_normal_1, size: 18, color: AppColors.textSecondary),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchCtrl.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear_rounded, size: 16, color: AppColors.textSecondary),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF101012) : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Iconsax.profile_2user, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
              width: 1.2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide(
              color: AppColors.accent,
              width: 1.5,
            ),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F0F11) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (next == true && previous == false) {
        debugPrint('[BRAND DISCOVER] Back online, reloading creators...');
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
                  'Influencers',
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
                icon: const Icon(
                  Iconsax.map,
                  size: 24,
                ),
                onPressed: () => context.push('/brand/map'),
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
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageMarginHorizontal,
                  ),
                  child: _buildSearchBar(isDark),
                ),
                const SizedBox(height: 12),
                // Skeleton Niche Chips
                Container(
                  height: 38,
                  margin: const EdgeInsets.only(bottom: 8),
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
                            width: index == 0 ? 110 : (index == 1 ? 80 : (index == 2 ? 70 : 80)),
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
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (_, index) => const BentoInfluencerCardSkeleton(),
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
                  // Bento Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageMarginHorizontal,
                    ),
                    child: _buildSearchBar(isDark),
                  ),
                  const SizedBox(height: 12),
                  // Bento Niche filter chips with counts
                  _buildNicheChips(),
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
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (_filtered.isEmpty) {
                          if (i == 0) {
                            return const AppEmptyState(
                              icon: Iconsax.profile_2user,
                              title: 'No influencers found',
                            );
                          } else {
                            return _buildFooter();
                          }
                        }
                        if (i == _filtered.length) {
                          return _buildFooter();
                        }
                        final inf = _filtered[i];
                        return _BentoInfluencerCard(
                          influencer: inf,
                          animationDelayIndex: i,
                          onTap: () => context.push('/brand/influencers/${inf['id']}'),
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
            'Finding your',
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
            'next partner.',
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

class _BentoInfluencerCard extends StatelessWidget {
  final Map<String, dynamic> influencer;
  final int animationDelayIndex;
  final VoidCallback onTap;

  const _BentoInfluencerCard({
    required this.influencer,
    required this.animationDelayIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final displayName = influencer['display_name'] ?? 'Influencer';
    final avatarUrl = influencer['avatar_url'];
    final isVerified = influencer['is_verified'] == true;
    final niches = (influencer['niche'] as List<dynamic>?)?.cast<String>() ?? [];
    final followerCount = influencer['follower_count'] as int? ?? 0;
    final location = influencer['location'] as String? ?? 'Global';

    String followerStr;
    if (followerCount >= 1000000) {
      followerStr = '${(followerCount / 1000000).toStringAsFixed(1)}M';
    } else if (followerCount >= 1000) {
      followerStr = '${(followerCount / 1000).toStringAsFixed(0)}K';
    } else {
      followerStr = '$followerCount';
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
                  // Avatar
                  AppAvatar(
                    url: avatarUrl,
                    fallbackText: displayName.isNotEmpty ? displayName[0] : 'I',
                    size: 54,
                    onTap: onTap,
                  ),
                  const SizedBox(width: 14),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              const VerificationBadge(size: 13),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Niches as mini capsules
                        if (niches.isNotEmpty) ...[
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: niches.take(2).map((n) {
                              final nColor = AppColors.getCategoryColor(n);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: nColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: nColor.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  n.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w800,
                                    color: nColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 6),
                        ],
                        // Metrics
                        Row(
                          children: [
                            Icon(
                              Iconsax.people,
                              size: 12,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$followerStr followers',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Iconsax.location,
                              size: 12,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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