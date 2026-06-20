import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/card_service.dart';
import '../../shared/widgets/shared_widgets.dart';

const _categories = ['Fashion', 'Tech', 'Food', 'Fitness', 'Beauty', 'Travel', 'Gaming', 'Lifestyle'];
const _platforms = ['Instagram', 'YouTube', 'TikTok', 'Twitter/X', 'LinkedIn'];

class BrandCardCreateScreen extends ConsumerStatefulWidget {
  const BrandCardCreateScreen({super.key});
  @override
  ConsumerState<BrandCardCreateScreen> createState() => _BrandCardCreateScreenState();
}

class _BrandCardCreateScreenState extends ConsumerState<BrandCardCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _timelineCtrl = TextEditingController();
  final _deliverablesCtrl = TextEditingController();
  String _category = 'Fashion';
  final List<String> _nicheTags = [];
  final List<String> _platformReqs = [];
  bool _loading = false;

  Future<void> _create() async {
    if (_titleCtrl.text.isEmpty || _descCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in title and description.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final user = ref.read(authProvider).user!;
      await CardService().createCard({
        'brand_id': user.id,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'niche_tags': _nicheTags.isEmpty ? [_category] : _nicheTags,
        'budget_range': _budgetCtrl.text.trim().isEmpty ? null : _budgetCtrl.text.trim(),
        'platform_requirements': _platformReqs.isEmpty ? null : _platformReqs,
        'timeline': _timelineCtrl.text.trim().isEmpty ? null : _timelineCtrl.text.trim(),
        'deliverables': _deliverablesCtrl.text.trim().isEmpty ? null : _deliverablesCtrl.text.trim().split(',').map((e) => e.trim()).toList(),
        'status': 'active',
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card created!'))); context.pop(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() { _titleCtrl.dispose(); _descCtrl.dispose(); _budgetCtrl.dispose(); _timelineCtrl.dispose(); _deliverablesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Card')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(label: 'Title', hint: 'Campaign card title', controller: _titleCtrl),
            const SizedBox(height: 16),
            AppTextField(label: 'Description', hint: 'Describe the collaboration opportunity...', controller: _descCtrl, maxLines: 5),
            const SizedBox(height: 16),
            Text('CATEGORY', style: AppTextStyles.overline),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) => AppChip(label: c, selected: _category == c, color: AppColors.getCategoryColor(c), onTap: () => setState(() => _category = c))).toList()),
            const SizedBox(height: 16),
            Text('NICHE TAGS', style: AppTextStyles.overline),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _categories.map((n) => AppChip(label: n, selected: _nicheTags.contains(n), onTap: () => setState(() => _nicheTags.contains(n) ? _nicheTags.remove(n) : _nicheTags.add(n)))).toList()),
            const SizedBox(height: 16),
            Text('PLATFORM REQUIREMENTS', style: AppTextStyles.overline),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _platforms.map((p) => AppChip(label: p, selected: _platformReqs.contains(p), onTap: () => setState(() => _platformReqs.contains(p) ? _platformReqs.remove(p) : _platformReqs.add(p)))).toList()),
            const SizedBox(height: 16),
            AppTextField(label: 'Budget Range', hint: 'e.g. ₹10,000 - ₹50,000', controller: _budgetCtrl),
            const SizedBox(height: 16),
            AppTextField(label: 'Timeline', hint: 'e.g. 2 weeks', controller: _timelineCtrl),
            const SizedBox(height: 16),
            AppTextField(label: 'Deliverables', hint: 'Comma-separated: e.g. 1 Reel, 2 Stories', controller: _deliverablesCtrl),
            const SizedBox(height: 32),
            AppButton(label: 'Publish Card', onTap: _create, isLoading: _loading),
          ],
        ),
      ),
    );
  }
}