import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/card_service.dart';
import '../../core/services/application_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class InfluencerCardDetailScreen extends ConsumerStatefulWidget {
  final String cardId;
  const InfluencerCardDetailScreen({super.key, required this.cardId});
  @override
  ConsumerState<InfluencerCardDetailScreen> createState() => _InfluencerCardDetailScreenState();
}

class _InfluencerCardDetailScreenState extends ConsumerState<InfluencerCardDetailScreen> {
  Map<String, dynamic>? _card;
  bool _loading = true;
  bool _applied = false;
  bool _applying = false;
  final _pitchCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await CardService().getCardById(widget.cardId);
    final user = ref.read(authProvider).user;
    if (user != null) {
      final appliedIds = await ApplicationService().getAppliedCardIds(user.id);
      _applied = appliedIds.contains(widget.cardId);
    }
    if (mounted) setState(() { _card = data; _loading = false; });
  }

  Future<void> _apply() async {
    if (_pitchCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a pitch message.')));
      return;
    }
    setState(() => _applying = true);
    try {
      final user = ref.read(authProvider).user!;
      await ApplicationService().createApplication({
        'card_id': widget.cardId,
        'influencer_id': user.id,
        'pitch_message': _pitchCtrl.text.trim(),
        'proposed_rate': _rateCtrl.text.trim().isEmpty ? null : _rateCtrl.text.trim(),
        'status': 'pending',
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted!'))); setState(() => _applied = true); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => _applying = false);
  }

  @override
  void dispose() { _pitchCtrl.dispose(); _rateCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(), body: const ShimmerCardDetail());
    if (_card == null) return Scaffold(appBar: AppBar(), body: const AppEmptyState(icon: Icons.error_rounded, title: 'Campaign not found'));

    final c = _card!;
    final brand = c['brand'] as Map<String, dynamic>?;
    final nicheTags = (c['niche_tags'] as List?)?.cast<String>() ?? [];
    final deliverables = (c['deliverables'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Campaign Details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (c['cover_image_url'] != null)
            ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 16 / 9, child: Image.network(c['cover_image_url'], fit: BoxFit.cover))),
          const SizedBox(height: 16),

          // Brand info
          if (brand != null)
            GestureDetector(
              onTap: () {
                if (brand['id'] != null) {
                  context.push('/influencer/brands/${brand['id']}');
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  AppAvatar(
                    url: brand['avatar_url'],
                    fallbackText: brand['display_name'] ?? 'B',
                    size: 40,
                    onTap: () {
                      if (brand['id'] != null) {
                        context.push('/influencer/brands/${brand['id']}');
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(brand['display_name'] ?? '', style: AppTextStyles.label, overflow: TextOverflow.ellipsis)),
                      if (brand['is_verified'] == true) ...[
                        const SizedBox(width: 4),
                        const VerificationBadge(size: 14),
                      ]
                    ]),
                    Text(brand['industry'] ?? '', style: AppTextStyles.captionSm),
                  ]),
                ]),
              ),
            ),
          const SizedBox(height: 16),

          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppColors.getCategoryColor(c['category'] ?? ''), borderRadius: BorderRadius.circular(100)), child: Text(c['category'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black))),
          ]),
          const SizedBox(height: 12),
          Text(c['title'] ?? '', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          Text(c['description'] ?? '', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: 20),

          // Details
          _detail('Budget', c['budget_range'] ?? 'Open'),
          _detail('Timeline', c['timeline'] ?? 'Flexible'),
          if (deliverables.isNotEmpty) _detail('Deliverables', deliverables.join(', ')),
          const SizedBox(height: 16),

          if (nicheTags.isNotEmpty) ...[
            Text('NICHE TAGS', style: AppTextStyles.overline),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: nicheTags.map((t) => AppChip(label: '#$t')).toList()),
            const SizedBox(height: 24),
          ],

          // Apply section
          if (_applied)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.success.withOpacity(0.3))),
              child: Row(children: [Icon(Icons.check_circle_rounded, color: AppColors.success), SizedBox(width: 12), Text('You\'ve already applied!', style: AppTextStyles.label.copyWith(color: AppColors.success))]),
            )
          else ...[
            const Divider(height: 32),
            Text('Apply Now', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            AppTextField(label: 'Pitch Message', hint: 'Why are you a great fit for this campaign?', controller: _pitchCtrl, maxLines: 4),
            const SizedBox(height: 12),
            AppTextField(label: 'Proposed Rate (Optional)', hint: 'e.g. ₹25,000', controller: _rateCtrl),
            const SizedBox(height: 20),
            AppButton(label: 'Submit Application', onTap: _apply, isLoading: _applying),
          ],
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: AppTextStyles.caption), Flexible(child: Text(value, style: AppTextStyles.label, textAlign: TextAlign.end))]),
  );
}