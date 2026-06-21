import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final data = await CardService().getBrandCards(user.id);
    if (mounted) setState(() { _cards = data; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _cards;
    return _cards.where((c) => c['status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && _loading) {
        _load();
      }
    });

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
                  'My Cards',
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
                icon: const Icon(Iconsax.add_circle),
                onPressed: () => context.push('/brand/cards/new'),
              ),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: AppSpacing.pageMarginVertical),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, __) => const ShimmerCampaignCard(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  // Filter tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    child: Row(
                      children: ['all', 'active', 'paused', 'closed'].map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AppChip(label: f[0].toUpperCase() + f.substring(1), selected: _filter == f, onTap: () => setState(() => _filter = f)),
                      )).toList(),
                    ),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? AppEmptyState(icon: Iconsax.cards, title: 'No cards found', subtitle: 'Create your first campaign card', actionLabel: 'Create Card', onAction: () => context.push('/brand/cards/new'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.pageMarginHorizontal,
                              AppSpacing.pageMarginVertical,
                              AppSpacing.pageMarginHorizontal,
                              AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                            ),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 16),
                            itemBuilder: (_, i) {
                              final card = _filtered[i];
                              return GestureDetector(
                                onTap: () => context.push('/brand/cards/${card['id']}'),
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusXl), border: Border.all(color: AppColors.border)),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 60, height: 60,
                                        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                                        clipBehavior: Clip.antiAlias,
                                        child: AppImage(
                                          url: card['cover_image_url'],
                                          fit: BoxFit.cover,
                                          fallback: Icon(Iconsax.volume_high, color: AppColors.textMuted),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(card['title'] ?? '', style: AppTextStyles.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: card['status'] == 'active' ? AppColors.success.withOpacity(0.2) : AppColors.surface2, borderRadius: BorderRadius.circular(100)),
                                            child: Text(card['status'] ?? 'draft', style: AppTextStyles.captionSm.copyWith(fontSize: 10, color: card['status'] == 'active' ? AppColors.success : AppColors.textMuted)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(card['category'] ?? '', style: AppTextStyles.captionSm),
                                        ]),
                                        const SizedBox(height: 4),
                                        Text(card['budget_range'] ?? 'No budget set', style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.w600)),
                                      ])),
                                      Icon(Iconsax.arrow_right_3, color: AppColors.textMuted),
                                    ],
                                  ),
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