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
  bool _loading = true;
  String? _categoryFilter;
  _SortOption _sortOption = _SortOption.newest;
  bool _showMap = false;
  bool _matchedOnly = false;

  @override
  void initState() {
    super.initState();
    _matchedOnly = widget.filter == 'matched';
    _load();
  }

  Future<void> _load() async {
    final data = await CardService().getActiveCards(limit: 50);
    if (mounted) setState(() { _cards = data; _loading = false; });
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

  List<Map<String, dynamic>> get _filtered {
    var results = List<Map<String, dynamic>>.from(_cards);

    if (_matchedOnly) {
      final profile = ref.read(authProvider).profile;
      final userNiches = (profile?['niche'] as List?)?.cast<String>() ?? [];
      results = results.where((c) {
        final cardNiches = (c['niche_tags'] as List?)?.cast<String>() ?? [];
        return cardNiches.any((n) => userNiches.contains(n));
      }).toList();
    }

    if (_categoryFilter != null) {
      results = results.where((c) => c['category'] == _categoryFilter).toList();
    }

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
                                itemBuilder: (_, i) => CampaignCardWidget(card: filtered[i], onTap: () => context.push('/influencer/discover/${filtered[i]['id']}')),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}