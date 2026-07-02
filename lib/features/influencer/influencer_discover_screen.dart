import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/media/image_cache_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/card_service.dart';
import '../../core/services/application_service.dart';
import '../../shared/widgets/app_skeleton.dart';
import '../../shared/widgets/screen_skeletons.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'discover_map_view.dart';
import '../../core/cache/app_cache.dart';
import '../../core/services/block_service.dart';
import '../../core/network/connectivity_service.dart';
import '../../shared/widgets/app_refresh_indicator.dart';

class InfluencerDiscoverScreen extends ConsumerStatefulWidget {
  final String? filter;
  const InfluencerDiscoverScreen({super.key, this.filter});

  @override
  ConsumerState<InfluencerDiscoverScreen> createState() => _InfluencerDiscoverScreenState();
}

enum _SortOption { newest, budgetHigh, budgetLow, deadline }

class _InfluencerDiscoverScreenState extends ConsumerState<InfluencerDiscoverScreen> {
  List<Map<String, dynamic>> _cards = [];
  Set<String> _appliedCardIds = {};
  Set<String> _blockedUserIds = {};
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  // Primary filters
  String? _categoryFilter;
  _SortOption _sortOption = _SortOption.newest;
  bool _matchedOnly = false;

  // Advanced filters state
  String? _platformFilter;
  String? _locationFilter;
  bool _hideUnqualified = false;
  int? _minBudgetFilter;
  final _minBudgetCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _matchedOnly = widget.filter == 'matched';
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _minBudgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool background = false}) async {
    // HARDENING: devops-agent 2026-06-25
    final user = ref.read(authProvider).user;
    final cacheKey = 'influencer_discover_${user?.id}';

    if (!background) {
      final cached = AppCache().get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        setState(() {
          _cards = List<Map<String, dynamic>>.from(cached['cards']);
          _appliedCardIds = Set<String>.from(cached['appliedCardIds']);
          _loading = false;
        });
      } else {
        setState(() => _loading = true);
      }
    }

    try {
      final futures = await Future.wait([
        CardService().getActiveCards(limit: 50),
        if (user != null)
          ApplicationService().getAppliedCardIds(user.id)
        else
          Future.value(<String>[]),
        if (user != null)
          BlockService().getAllBlockedUserIds(user.id)
        else
          Future.value(<String>{}),
      ]);

      final data = futures[0] as List<Map<String, dynamic>>;
      final applied = (futures[1] as List).cast<String>().toSet();
      final blocked = futures[2] as Set<String>;

      // Save to cache
      AppCache().set(cacheKey, {
        'cards': data,
        'appliedCardIds': applied.toList(),
      }, ttl: const Duration(minutes: 5));

      if (mounted) {
        setState(() {
          _cards = data;
          _appliedCardIds = applied;
          _blockedUserIds = blocked;
          _loading = false;
        });
      }

      if (!background && AppCache().get(cacheKey) != null) {
        _load(background: true);
      }
    } catch (e) {
      print('Error loading discover data: $e');
      if (mounted && !background && _cards.isEmpty) {
        setState(() => _loading = false);
      }
    }
  }

  int _parseBudgetValue(String? range) {
    if (range == null) return 0;
    final clean = range.replaceAll(',', '');
    final match = RegExp(r'\d+').firstMatch(clean);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  bool get _hasAnyFilterActive =>
      _platformFilter != null ||
      _locationFilter != null ||
      _hideUnqualified ||
      _minBudgetFilter != null;

  List<Map<String, dynamic>> get _filtered {
    var results = List<Map<String, dynamic>>.from(_cards);

    if (_blockedUserIds.isNotEmpty) {
      results = results.where((c) {
        final brandId = c['brand_id'] as String?;
        return brandId == null || !_blockedUserIds.contains(brandId);
      }).toList();
    }

    // Text Search query
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      results = results.where((c) {
        final title = (c['title'] as String? ?? '').toLowerCase();
        final desc = (c['description'] as String? ?? '').toLowerCase();
        final cat = (c['category'] as String? ?? '').toLowerCase();
        return title.contains(query) || desc.contains(query) || cat.contains(query);
      }).toList();
    }

    // Matched Only (Niches)
    if (_matchedOnly) {
      final profile = ref.read(authProvider).profile;
      final userNiches = (profile?['niche'] as List?)?.cast<String>() ?? [];
      results = results.where((c) {
        final cardNiches = (c['niche_tags'] as List?)?.cast<String>() ?? [];
        return cardNiches.any((n) => userNiches.contains(n));
      }).toList();
    }

    // Category filter
    if (_categoryFilter != null) {
      results = results.where((c) => c['category'] == _categoryFilter).toList();
    }

    // Platform requirements filter
    if (_platformFilter != null) {
      results = results.where((c) {
        final cardPlatforms = (c['platform_requirements'] as List?)?.cast<String>() ?? [];
        return cardPlatforms.contains(_platformFilter);
      }).toList();
    }

    // Location filter
    if (_locationFilter != null && _locationFilter != 'Anywhere') {
      results = results.where((c) => c['preferred_location'] == _locationFilter).toList();
    }

    // Follower qualification filter
    if (_hideUnqualified) {
      final profile = ref.read(authProvider).profile;
      final followers = profile?['follower_count'] as int? ?? 0;
      results = results.where((c) {
        final reqFollowers = c['min_followers'] as int? ?? 0;
        return followers >= reqFollowers;
      }).toList();
    }

    // Budget minimum filter
    if (_minBudgetFilter != null) {
      results = results.where((c) {
        final budgetVal = _parseBudgetValue(c['budget_range'] as String?);
        return budgetVal >= _minBudgetFilter!;
      }).toList();
    }

    // Sorting
    switch (_sortOption) {
      case _SortOption.newest:
        results.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        break;
      case _SortOption.budgetHigh:
        results.sort((a, b) => _parseBudgetValue(b['budget_range'] as String?).compareTo(_parseBudgetValue(a['budget_range'] as String?)));
        break;
      case _SortOption.budgetLow:
        results.sort((a, b) => _parseBudgetValue(a['budget_range'] as String?).compareTo(_parseBudgetValue(b['budget_range'] as String?)));
        break;
      case _SortOption.deadline:
        results.sort((a, b) => (a['application_deadline'] ?? '9999-12-31').compareTo(b['application_deadline'] ?? '9999-12-31'));
        break;
    }
    return results;
  }

  String get _sortLabel {
    switch (_sortOption) {
      case _SortOption.newest: return 'Newest';
      case _SortOption.budgetHigh: return 'Budget ↓';
      case _SortOption.budgetLow: return 'Budget ↑';
      case _SortOption.deadline: return 'Deadline';
    }
  }

  void _showAdvancedFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Container(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.of(dialogCtx).viewInsets.bottom),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.borderSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Advanced Filters', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _platformFilter = null;
                            _locationFilter = null;
                            _hideUnqualified = false;
                            _minBudgetFilter = null;
                            _minBudgetCtrl.clear();
                          });
                        },
                        child: Text('Reset All', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  // Platform filter
                  Text('PLATFORM REQUIREMENT', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [null, 'Instagram', 'YouTube', 'TikTok', 'Twitter/X', 'LinkedIn'].map((p) {
                      final isSelected = _platformFilter == p;
                      return AppChip(
                        label: p ?? 'Any Platform',
                        selected: isSelected,
                        onTap: () => setDialogState(() => _platformFilter = p),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Location filter
                  Text('PREFERRED LOCATION', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [null, 'India', 'United States', 'United Kingdom', 'Canada', 'Australia', 'Europe'].map((loc) {
                      final isSelected = _locationFilter == loc;
                      return AppChip(
                        label: loc ?? 'Anywhere',
                        selected: isSelected,
                        onTap: () => setDialogState(() => _locationFilter = loc),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Budget range
                  Text('MINIMUM BUDGET (INR)', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _minBudgetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g. 15000',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      prefixText: '₹ ',
                    ),
                    style: AppTextStyles.body,
                    onChanged: (val) {
                      setDialogState(() {
                        _minBudgetFilter = int.tryParse(val);
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Eligibility switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Only Show Eligible Campaigns', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                          Text('Hide campaigns where you do not meet follower counts', style: AppTextStyles.captionSm),
                        ],
                      ),
                      Switch(
                        value: _hideUnqualified,
                        activeColor: AppColors.accent,
                        onChanged: (val) {
                          setDialogState(() {
                            _hideUnqualified = val;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentOnDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      elevation: 0,
                    ),
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (next == true && previous == false) {
        debugPrint('[DISCOVER] Back online, reloading campaigns...');
        _load();
      }
    });

    final filtered = _filtered;
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
                  'Discover',
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
                onPressed: () => context.push('/influencer/map'),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.notification, size: 24),
                    onPressed: () => context.push('/influencer/notifications'),
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
                onPressed: () => context.push('/influencer/settings'),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const InfluencerDiscoverSkeleton()
          : AppRefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    children: [
                      // Combined Search and Filter Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 8),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search campaigns...',
                            hintStyle: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
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
                                  child: GestureDetector(
                                    onTap: _showAdvancedFiltersBottomSheet,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _hasAnyFilterActive 
                                            ? AppColors.accent.withOpacity(0.1) 
                                            : AppColors.surface2,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _hasAnyFilterActive 
                                              ? AppColors.accent 
                                              : AppColors.border,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Icon(
                                        Iconsax.filter_search,
                                        size: 16,
                                        color: _hasAnyFilterActive 
                                            ? AppColors.accent 
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.border, width: 1.2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.border, width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.accent, width: 1.2),
                            ),
                          ),
                          style: AppTextStyles.bodySm,
                        ),
                      ),

                      // Sort & count row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.pageMarginHorizontal, 10, AppSpacing.pageMarginHorizontal, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${filtered.length} campaign${filtered.length == 1 ? '' : 's'}',
                              style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted),
                            ),
                            PopupMenuButton<_SortOption>(
                              onSelected: (v) => setState(() => _sortOption = v),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              color: AppColors.surface,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Iconsax.sort, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(_sortLabel, style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 2),
                                    Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                              itemBuilder: (_) => [
                                PopupMenuItem(value: _SortOption.newest, child: Text('Newest First', style: AppTextStyles.labelSm)),
                                PopupMenuItem(value: _SortOption.budgetHigh, child: Text('Budget: High → Low', style: AppTextStyles.labelSm)),
                                PopupMenuItem(value: _SortOption.budgetLow, child: Text('Budget: Low → High', style: AppTextStyles.labelSm)),
                                PopupMenuItem(value: _SortOption.deadline, child: Text('Deadline Soonest', style: AppTextStyles.labelSm)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Bento List Card list
                      Expanded(
                        child: AppRefreshIndicator(
                          onRefresh: () async {
                            HapticFeedback.lightImpact();
                            await _load();
                          },
                          child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageMarginHorizontal,
                            AppSpacing.pageMarginVertical,
                            AppSpacing.pageMarginHorizontal,
                            AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                          ),
                          itemCount: filtered.isEmpty ? 2 : filtered.length + 1,
                          separatorBuilder: (context, i) {
                            if (filtered.isEmpty) return const SizedBox.shrink();
                            if (i == filtered.length - 1) return const SizedBox.shrink();
                            return const SizedBox(height: 12);
                          },
                          itemBuilder: (context, i) {
                            if (filtered.isEmpty) {
                              if (i == 0) {
                                final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkMode;
                                return _buildDiscoverEmptyState(isDark);
                              } else {
                                return _buildFooter();
                              }
                            }
                            if (i == filtered.length) {
                              return _buildFooter();
                            }
                            return _BentoCampaignListCard(
                              card: filtered[i],
                              isApplied: _appliedCardIds.contains(filtered[i]['id']),
                              onTap: () => context.push('/influencer/discover/${filtered[i]['id']}'),
                              animationDelayIndex: i,
                            );
                          },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDiscoverEmptyState(bool isDark) {
    final imagePath = isDark 
        ? 'assets/illustrations/Discover Cards Dark.png' 
        : 'assets/illustrations/Discover Cards Light.png';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            fit: BoxFit.contain,
            height: 240,
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
          const SizedBox(height: 24),
          Text(
            'No cards available right now. Check back soon!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
        ],
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
            'next match.',
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

// ---------- _BentoCampaignListCard ----------
class _BentoCampaignListCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final bool isApplied;
  final VoidCallback? onTap;
  final int animationDelayIndex;

  const _BentoCampaignListCard({
    required this.card,
    required this.isApplied,
    this.onTap,
    this.animationDelayIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final brand = card['brand'] as Map<String, dynamic>?;
    final category = card['category'] as String? ?? '';
    final categoryColor = AppColors.getCategoryColor(category);
    final budgetRange = card['budget_range'] as String? ?? 'Open';
    final preferredLocation = card['preferred_location'] as String? ?? 'Anywhere';
    final isDark = AppColors.isDarkMode;

    // Platform requirements icon
    final platforms = (card['platform_requirements'] as List?)?.cast<String>() ?? [];
    Widget platformIcon = const SizedBox.shrink();
    if (platforms.isNotEmpty) {
      final p = platforms.first.toLowerCase();
      if (p.contains('instagram')) {
        platformIcon = Icon(Iconsax.instagram, size: 13, color: AppColors.textSecondary);
      } else if (p.contains('youtube')) {
        platformIcon = Icon(Icons.video_library_outlined, size: 13, color: AppColors.textSecondary);
      } else if (p.contains('tiktok')) {
        platformIcon = Icon(Icons.music_note_outlined, size: 13, color: AppColors.textSecondary);
      } else if (p.contains('twitter') || p.contains('x')) {
        platformIcon = Icon(Icons.close_rounded, size: 13, color: AppColors.textSecondary);
      } else {
        platformIcon = Icon(Iconsax.global, size: 13, color: AppColors.textSecondary);
      }
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
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.02),
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
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 88,
                          height: 88,
                          color: AppColors.surface2,
                          child: isValidImageUrl(card['cover_image_url'])
                              ? CachedNetworkImage(
                                  cacheManager: AppCacheManager.instance,
                                  imageUrl: card['cover_image_url'],
                                  fit: BoxFit.cover,
                                  memCacheWidth: 176,
                                  memCacheHeight: 176,
                                )
                              : Center(
                                  child: Icon(Iconsax.image, size: 24, color: AppColors.textMuted),
                                ),
                        ),
                      ),
                      if (isApplied)
                        Positioned(
                          top: -4,
                          left: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'APPLIED',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Details on right
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand and category row
                        Row(
                          children: [
                            if (brand != null) ...[
                              AppAvatar(
                                url: brand['avatar_url'],
                                fallbackText: brand['display_name'] ?? 'B',
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        brand['display_name'] ?? 'Brand',
                                        style: AppTextStyles.captionSm.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (brand['is_verified'] == true) ...[
                                      const SizedBox(width: 3),
                                      const VerificationBadge(size: 9),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: categoryColor.withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: categoryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Title
                        Text(
                          card['title'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Location, Platform & Budget
                        Row(
                          children: [
                            Icon(
                              Iconsax.location,
                              size: 11,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                preferredLocation,
                                style: AppTextStyles.captionSm.copyWith(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (platforms.isNotEmpty) ...[
                              platformIcon,
                              const SizedBox(width: 8),
                            ],
                            Text(
                              budgetRange,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
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