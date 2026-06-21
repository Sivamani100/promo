import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/card_service.dart';
import '../../core/services/application_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'discover_map_view.dart';

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
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  // Primary filters
  String? _categoryFilter;
  _SortOption _sortOption = _SortOption.newest;
  bool _showMap = false;
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

  Future<void> _load() async {
    final data = await CardService().getActiveCards(limit: 50);
    final user = ref.read(authProvider).user;
    Set<String> applied = {};
    if (user != null) {
      final appliedIds = await ApplicationService().getAppliedCardIds(user.id);
      applied = appliedIds.toSet();
    }
    if (mounted) {
      setState(() {
        _cards = data;
        _appliedCardIds = applied;
        _loading = false;
      });
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
                  Text('MINIMUM COMPENSATION (INR)', style: AppTextStyles.overline),
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
    final filtered = _filtered;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '.',
                  style: GoogleFonts.inter(
                    fontSize: 20,
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
                icon: Icon(_showMap ? Iconsax.menu : Iconsax.map, color: _showMap ? AppColors.accent : AppColors.textPrimary),
                onPressed: () => setState(() => _showMap = !_showMap),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.notification, size: 20),
                    onPressed: () => context.push('/influencer/notifications'),
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      right: 8,
                      top: 8,
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
                icon: const Icon(Iconsax.setting_2, size: 20),
                onPressed: () => context.push('/influencer/settings'),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: AppSpacing.pageMarginVertical),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, __) => const ShimmerCampaignCard(),
            )
          : _showMap
              ? const DiscoverMapView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    children: [
                      // Search and Filter Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (val) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Search campaigns...',
                                  prefixIcon: const Icon(Iconsax.search_normal_1, size: 18),
                                  suffixIcon: _searchCtrl.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 16),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(100),
                                    borderSide: BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(100),
                                    borderSide: BorderSide(color: AppColors.border),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                ),
                                style: AppTextStyles.bodySm,
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _hasAnyFilterActive ? AppColors.accent.withOpacity(0.1) : AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _hasAnyFilterActive ? AppColors.accent : AppColors.border,
                                  ),
                                ),
                                child: Icon(
                                  Iconsax.filter_search,
                                  size: 18,
                                  color: _hasAnyFilterActive ? AppColors.accent : AppColors.textPrimary,
                                ),
                              ),
                              onPressed: _showAdvancedFiltersBottomSheet,
                            ),
                          ],
                        ),
                      ),

                      // Category chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AppChip(
                                label: '✨ Matched Only',
                                selected: _matchedOnly,
                                color: _matchedOnly ? AppColors.accent : null,
                                onTap: () => setState(() => _matchedOnly = !_matchedOnly),
                              ),
                            ),
                            ...[null, 'Fashion', 'Tech', 'Food', 'Fitness', 'Beauty', 'Travel', 'Gaming', 'Lifestyle'].map((c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AppChip(
                                label: c ?? 'All',
                                selected: !_matchedOnly && _categoryFilter == c,
                                color: c != null ? AppColors.getCategoryColor(c) : null,
                                onTap: () => setState(() {
                                  _categoryFilter = c;
                                  _matchedOnly = false;
                                }),
                              ),
                            )).toList(),
                          ],
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
                      
                      // Card list
                      Expanded(
                        child: filtered.isEmpty
                            ? const AppEmptyState(icon: Icons.campaign_rounded, title: 'No campaigns found')
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.pageMarginHorizontal,
                                  AppSpacing.pageMarginVertical,
                                  AppSpacing.pageMarginHorizontal,
                                  AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 16),
                                itemBuilder: (_, i) => CampaignCardWidget(
                                  card: filtered[i],
                                  isApplied: _appliedCardIds.contains(filtered[i]['id']),
                                  onTap: () => context.push('/influencer/discover/${filtered[i]['id']}'),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}