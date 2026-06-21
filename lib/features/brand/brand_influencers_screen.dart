import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/profile_service.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/shared_widgets.dart';

class BrandInfluencersScreen extends ConsumerStatefulWidget {
  const BrandInfluencersScreen({super.key});
  @override
  ConsumerState<BrandInfluencersScreen> createState() => _BrandInfluencersScreenState();
}

class _BrandInfluencersScreenState extends ConsumerState<BrandInfluencersScreen> {
  List<Map<String, dynamic>> _influencers = [];
  bool _loading = true;
  String? _nicheFilter;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await ProfileService().getInfluencers(niche: _nicheFilter, limit: 50);
    if (mounted) setState(() { _influencers = data; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _influencers;
    return _influencers.where((i) => (i['display_name'] ?? '').toString().toLowerCase().contains(q) || (i['bio'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
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
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_left),
              onPressed: () => context.go('/brand/home'),
            ),
            centerTitle: false,
            titleSpacing: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Influencers',
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
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.notification, size: 20),
                    onPressed: () => context.push('/brand/notifications'),
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
                onPressed: () => context.push('/brand/settings'),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const ShimmerGenericListTile(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: AppTextStyles.body,
                      decoration: InputDecoration(hintText: 'Search influencers...', prefixIcon: Icon(Iconsax.search_normal, color: AppColors.textMuted)),
                    ),
                  ),
                  // Niche filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(children: [null, 'Fashion', 'Tech', 'Food', 'Fitness', 'Beauty', 'Travel', 'Gaming', 'Lifestyle'].map((n) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppChip(label: n ?? 'All', selected: _nicheFilter == n, onTap: () { setState(() => _nicheFilter = n); _load(); }),
                    )).toList()),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? const AppEmptyState(icon: Iconsax.profile_2user, title: 'No influencers found')
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.pageMarginHorizontal,
                              AppSpacing.pageMarginVertical,
                              AppSpacing.pageMarginHorizontal,
                              AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                            ),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final inf = _filtered[i];
                              final niches = (inf['niche'] as List<dynamic>?)?.cast<String>() ?? [];
                              return GestureDetector(
                                onTap: () => context.push('/brand/influencers/${inf['id']}'),
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusXl), border: Border.all(color: AppColors.border)),
                                  child: Row(children: [
                                    AppAvatar(
                                      url: inf['avatar_url'],
                                      fallbackText: inf['display_name'] ?? 'I',
                                      size: 48,
                                      onTap: () => context.push('/brand/influencers/${inf['id']}'),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Flexible(child: Text(inf['display_name'] ?? '', style: AppTextStyles.label, overflow: TextOverflow.ellipsis)),
                                        if (inf['is_verified'] == true) ...[const SizedBox(width: 4), const VerificationBadge(size: 14)],
                                      ]),
                                      const SizedBox(height: 2),
                                      Text(niches.take(2).join(' · '), style: AppTextStyles.captionSm),
                                      const SizedBox(height: 4),
                                      Text('${((inf['follower_count'] ?? 0) / 1000).toStringAsFixed(0)}K followers · ${inf['location'] ?? 'Global'}', style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted)),
                                    ])),
                                    Icon(Iconsax.arrow_right_3, color: AppColors.textMuted),
                                  ]),
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
}