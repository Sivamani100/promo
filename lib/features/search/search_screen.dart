import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/data_services.dart';
import '../../core/services/application_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_skeleton.dart';
import '../../shared/widgets/screen_skeletons.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;
  Map<String, List<Map<String, dynamic>>> _results = {'cards': [], 'brands': [], 'influencers': []};
  Set<String> _appliedCardIds = {};
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      setState(() {});
    });
    _searchCtrl.addListener(_onSearchChanged);
    _doSearch(''); // Load initial data
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(_searchCtrl.text));
  }

  Future<void> _doSearch(String query) async {
    setState(() => _loading = true);
    final results = await SearchService().search(query);
    final user = ref.read(authProvider).user;
    Set<String> applied = {};
    if (user != null) {
      final appliedIds = await ApplicationService().getAppliedCardIds(user.id);
      applied = appliedIds.toSet();
    }
    if (mounted) {
      setState(() {
        _results = results;
        _appliedCardIds = applied;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  int get _totalCount => _results.values.fold(0, (sum, list) => sum + list.length);

  void _navigateToProfile(Map<String, dynamic> p) {
    final authState = ref.read(authProvider);
    final userId = authState.user?.id;
    final userRole = authState.role;
    final id = p['id'];
    if (id == null) return;
    if (id == userId) {
      if (userRole == 'brand') {
        context.push('/brand/profile');
      } else {
        context.push('/influencer/profile');
      }
    } else {
      if (p['role'] == 'brand') {
        context.push('/influencer/brands/$id');
      } else {
        context.push('/brand/influencers/$id');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56 + 48 + AppSpacing.pageMarginVertical),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.pageMarginHorizontal,
            right: AppSpacing.pageMarginHorizontal,
            top: AppSpacing.pageMarginVertical,
          ),
          child: AppBar(
            leading: IconButton(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.pop(),
            ),
            leadingWidth: 30,
            centerTitle: false,
            titleSpacing: 0,
            title: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search cards, brands, influencers...',
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.clear_rounded, size: 16, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0, left: 6.0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF101012) : const Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Iconsax.search_status,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            actions: const [],
            bottom: _ChipTabBar(
              controller: _tabCtrl,
              totalCount: _totalCount,
              cardsCount: _results['cards']?.length ?? 0,
              brandsCount: _results['brands']?.length ?? 0,
              influencersCount: _results['influencers']?.length ?? 0,
              onTap: (index) {
                _tabCtrl.animateTo(index);
              },
            ),
          ),
        ),
      ),
      body: _loading
          ? const SkeletonShimmer(child: SearchResultsSkeleton())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildAllTab(),
                _buildCardsTab(),
                _buildBrandsTab(),
                _buildInfluencersTab(),
              ],
            ),
    );
  }

  Widget _buildAllTab() {
    if (_totalCount == 0) return const AppEmptyState(icon: Iconsax.search_status, title: 'No results found');
    final cards = _results['cards'] ?? [];
    final brands = _results['brands'] ?? [];
    final influencers = _results['influencers'] ?? [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
      children: [
        if (cards.isNotEmpty) ...[
          SectionHeader(title: 'Campaigns', actionLabel: '${cards.length}'),
          ...List.generate(cards.take(3).length, (i) {
            final card = cards[i];
            return _BentoCampaignSearchCard(
              card: card,
              onTap: () => context.push('/influencer/discover/${card['id']}'),
            );
          }),
          const SizedBox(height: 12),
        ],
        if (brands.isNotEmpty) ...[
          SectionHeader(title: 'Brands', actionLabel: '${brands.length}'),
          ...List.generate(brands.take(5).length, (i) {
            final brand = brands[i];
            return _BentoSearchProfileCard(
              profile: brand,
              onTap: () => _navigateToProfile(brand),
            );
          }),
          const SizedBox(height: 12),
        ],
        if (influencers.isNotEmpty) ...[
          SectionHeader(title: 'Influencers', actionLabel: '${influencers.length}'),
          ...List.generate(influencers.take(5).length, (i) {
            final influencer = influencers[i];
            return _BentoSearchProfileCard(
              profile: influencer,
              onTap: () => _navigateToProfile(influencer),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildCardsTab() {
    final cards = _results['cards']!;
    if (cards.isEmpty) return const AppEmptyState(icon: Iconsax.cards, title: 'No campaigns found');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
      itemCount: cards.length,
      itemBuilder: (_, i) => _BentoCampaignSearchCard(
        card: cards[i],
        onTap: () => context.push('/influencer/discover/${cards[i]['id']}'),
      ),
    );
  }

  Widget _buildBrandsTab() {
    final brands = _results['brands']!;
    if (brands.isEmpty) return const AppEmptyState(icon: Iconsax.briefcase, title: 'No brands found');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
      itemCount: brands.length,
      itemBuilder: (_, i) => _BentoSearchProfileCard(
        profile: brands[i],
        onTap: () => _navigateToProfile(brands[i]),
      ),
    );
  }

  Widget _buildInfluencersTab() {
    final infs = _results['influencers']!;
    if (infs.isEmpty) return const AppEmptyState(icon: Iconsax.profile_2user, title: 'No influencers found');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
      itemCount: infs.length,
      itemBuilder: (_, i) => _BentoSearchProfileCard(
        profile: infs[i],
        onTap: () => _navigateToProfile(infs[i]),
      ),
    );
  }
}

class _BentoSearchProfileCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onTap;

  const _BentoSearchProfileCard({
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final displayName = profile['display_name'] ?? 'User';
    final avatarUrl = profile['avatar_url'];
    final isVerified = profile['is_verified'] == true;
    final role = profile['role'] ?? 'influencer';
    final isBrand = role == 'brand';

    final niches = (profile['niche'] as List<dynamic>?)?.cast<String>() ?? [];
    final companyOrIndustry = profile['company_name'] ?? profile['industry'] ?? '';
    
    // Followers & location
    final followerCount = profile['follower_count'] as int? ?? 0;
    final location = profile['location'] as String? ?? 'Global';

    String followerStr = '';
    if (followerCount > 0) {
      if (followerCount >= 1000000) {
        followerStr = '${(followerCount / 1000000).toStringAsFixed(1)}M';
      } else if (followerCount >= 1000) {
        followerStr = '${(followerCount / 1000).toStringAsFixed(0)}K';
      } else {
        followerStr = '$followerCount';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  AppAvatar(
                    url: avatarUrl,
                    fallbackText: displayName.isNotEmpty ? displayName[0] : '?',
                    size: 48,
                    onTap: onTap,
                  ),
                  const SizedBox(width: 12),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              const VerificationBadge(size: 12),
                            ],
                            const SizedBox(width: 6),
                            // Role Badge (BRAND or CREATOR)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isBrand 
                                    ? AppColors.info.withValues(alpha: 0.1)
                                    : AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isBrand ? 'BRAND' : 'CREATOR',
                                style: GoogleFonts.inter(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w800,
                                  color: isBrand ? AppColors.info : AppColors.accent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (isBrand)
                          Text(
                            companyOrIndustry.isNotEmpty ? companyOrIndustry : 'Brand Partner',
                            style: AppTextStyles.captionSm.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else ...[
                          if (niches.isNotEmpty) ...[
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: niches.take(2).map((n) {
                                final nColor = AppColors.getCategoryColor(n);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                                      fontSize: 7,
                                      fontWeight: FontWeight.w800,
                                      color: nColor,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            children: [
                              if (followerStr.isNotEmpty) ...[
                                Icon(Iconsax.people, size: 11, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  '$followerStr followers',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Icon(Iconsax.location, size: 11, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
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
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textMuted,
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
          duration: const Duration(milliseconds: 300),
        )
        .slideY(
          begin: 0.05,
          end: 0.0,
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 300),
        );
  }
}

class _BentoCampaignSearchCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final VoidCallback onTap;

  const _BentoCampaignSearchCard({
    required this.card,
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
    final status = card['status'] as String? ?? 'active';
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 68,
                      height: 68,
                      color: AppColors.surface2,
                      child: AppImage(
                        url: card['cover_image_url'],
                        fit: BoxFit.cover,
                        fallback: Icon(Iconsax.image, color: AppColors.textMuted, size: 24),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                          maxLines: 1,
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
                                fontSize: 11.5,
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
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (platforms.isNotEmpty) ...[
                              const SizedBox(width: 10),
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
          duration: const Duration(milliseconds: 300),
        )
        .slideY(
          begin: 0.05,
          end: 0.0,
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 300),
        );
  }
}

class _ChipTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final int totalCount;
  final int cardsCount;
  final int brandsCount;
  final int influencersCount;
  final ValueChanged<int> onTap;

  const _ChipTabBar({
    required this.controller,
    required this.totalCount,
    required this.cardsCount,
    required this.brandsCount,
    required this.influencersCount,
    required this.onTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final selectedIndex = controller.index;

    Widget buildChip(int index, String label, int count) {
      final isSelected = selectedIndex == index;
      final activeColor = AppColors.textPrimary; // Black in light mode, White in dark mode
      final activeTextColor = isDark ? Colors.black : Colors.white;

      return GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? activeTextColor : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.black.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.15))
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
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

    return Container(
      height: 48,
      padding: const EdgeInsets.only(top: 12),
      alignment: Alignment.centerLeft,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          buildChip(0, 'All', totalCount),
          const SizedBox(width: 8),
          buildChip(1, 'Cards', cardsCount),
          const SizedBox(width: 8),
          buildChip(2, 'Brands', brandsCount),
          const SizedBox(width: 8),
          buildChip(3, 'Influencers', influencersCount),
        ],
      ),
    );
  }
}