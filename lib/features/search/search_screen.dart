import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/data_services.dart';
import '../../shared/widgets/shared_widgets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;
  Map<String, List<Map<String, dynamic>>> _results = {'cards': [], 'brands': [], 'influencers': []};
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
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
    if (mounted) setState(() { _results = results; _loading = false; });
  }

  @override
  void dispose() { _searchCtrl.dispose(); _tabCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  int get _totalCount => _results.values.fold(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: AppTextStyles.body,
          decoration: const InputDecoration(
            hintText: 'Search cards, brands, influencers...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(icon: const Icon(Iconsax.close_circle), onPressed: () { _searchCtrl.clear(); }),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: AppTextStyles.labelSm,
          tabs: [
            Tab(text: 'All ($_totalCount)'),
            Tab(text: 'Cards (${_results['cards']?.length ?? 0})'),
            Tab(text: 'Brands (${_results['brands']?.length ?? 0})'),
            Tab(text: 'Influencers (${_results['influencers']?.length ?? 0})'),
          ],
        ),
      ),
      body: _loading
          ? const ShimmerSearchResults()
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (_results['cards']!.isNotEmpty) ...[
          SectionHeader(title: 'Campaigns', actionLabel: '${_results['cards']!.length}'),
          ...List.generate(_results['cards']!.take(3).length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CampaignCardWidget(card: _results['cards']![i], onTap: () => context.push('/influencer/discover/${_results['cards']![i]['id']}')),
          )),
        ],
        if (_results['brands']!.isNotEmpty) ...[
          SectionHeader(title: 'Brands', actionLabel: '${_results['brands']!.length}'),
          ...List.generate(_results['brands']!.take(5).length, (i) => _buildProfileTile(_results['brands']![i])),
        ],
        if (_results['influencers']!.isNotEmpty) ...[
          SectionHeader(title: 'Influencers', actionLabel: '${_results['influencers']!.length}'),
          ...List.generate(_results['influencers']!.take(5).length, (i) => _buildProfileTile(_results['influencers']![i])),
        ],
      ],
    );
  }

  Widget _buildCardsTab() {
    final cards = _results['cards']!;
    if (cards.isEmpty) return const AppEmptyState(icon: Iconsax.cards, title: 'No campaigns found');
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => CampaignCardWidget(card: cards[i], onTap: () => context.push('/influencer/discover/${cards[i]['id']}')),
    );
  }

  Widget _buildBrandsTab() {
    final brands = _results['brands']!;
    if (brands.isEmpty) return const AppEmptyState(icon: Iconsax.briefcase, title: 'No brands found');
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: brands.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildProfileTile(brands[i]),
    );
  }

  Widget _buildInfluencersTab() {
    final infs = _results['influencers']!;
    if (infs.isEmpty) return const AppEmptyState(icon: Iconsax.profile_2user, title: 'No influencers found');
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: infs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildProfileTile(infs[i]),
    );
  }

  Widget _buildProfileTile(Map<String, dynamic> p) {
    final authState = ref.read(authProvider);
    final userId = authState.user?.id;
    final userRole = authState.role;

    return GestureDetector(
      onTap: () {
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
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusMd), border: Border.all(color: AppColors.borderSubtle)),
        child: Row(
          children: [
            AppAvatar(
              url: p['avatar_url'],
              fallbackText: p['display_name'] ?? '?',
              size: 40,
              onTap: () {
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
              },
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(p['display_name'] ?? '', style: AppTextStyles.label.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis)),
                if (p['is_verified'] == true) ...[const SizedBox(width: 4), const VerificationBadge(size: 12)],
              ]),
              Text(p['role'] == 'brand' ? (p['company_name'] ?? p['industry'] ?? '') : (p['niche'] as List?)?.take(2).join(' · ') ?? '', style: AppTextStyles.captionSm),
            ])),
          ],
        ),
      ),
    );
  }
}