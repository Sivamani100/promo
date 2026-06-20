import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _category = 'General';
  bool _submitting = false;
  List<Map<String, dynamic>> _tickets = [];
  bool _loadingTickets = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final data = await SupabaseService.client
          .from('support_tickets')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() { _tickets = List<Map<String, dynamic>>.from(data); _loadingTickets = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.isEmpty || _messageCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final user = ref.read(authProvider).user!;
      await SupabaseService.client.from('support_tickets').insert({
        'user_id': user.id,
        'subject': _subjectCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'category': _category,
        'status': 'open',
      });
      _subjectCtrl.clear();
      _messageCtrl.clear();
      _tabCtrl.animateTo(1);
      _loadTickets();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket submitted!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  void dispose() { _tabCtrl.dispose(); _subjectCtrl.dispose(); _messageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && _loadingTickets) {
        _loadTickets();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          tabs: const [Tab(text: 'New Ticket'), Tab(text: 'My Tickets')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // New ticket
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Submit a support ticket and we\'ll get back to you within 24 hours.', style: AppTextStyles.caption),
                const SizedBox(height: 24),
                Text('CATEGORY', style: AppTextStyles.overline),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: ['General', 'Bug Report', 'Account Issue', 'Feature Request', 'Billing'].map((c) => AppChip(
                    label: c,
                    selected: _category == c,
                    onTap: () => setState(() => _category = c),
                  )).toList(),
                ),
                const SizedBox(height: 20),
                AppTextField(label: 'Subject', hint: 'Brief description of the issue', controller: _subjectCtrl),
                const SizedBox(height: 16),
                AppTextField(label: 'Message', hint: 'Describe your issue in detail...', controller: _messageCtrl, maxLines: 6),
                const SizedBox(height: 24),
                AppButton(label: 'Submit Ticket', onTap: _submit, isLoading: _submitting),
              ],
            ),
          ),

          // My tickets
          _loadingTickets
              ? ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, __) => const ShimmerGenericListTile(),
                )
              : RefreshIndicator(
                  onRefresh: _loadTickets,
                  child: _tickets.isEmpty
                      ? const AppEmptyState(icon: Iconsax.message_question, title: 'No tickets', subtitle: 'Your support tickets will appear here')
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: _tickets.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final t = _tickets[i];
                            final statusColor = t['status'] == 'open' ? AppColors.warning : t['status'] == 'resolved' ? AppColors.success : AppColors.textMuted;
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusLg), border: Border.all(color: AppColors.border)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Expanded(child: Text(t['subject'] ?? '', style: AppTextStyles.label)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(100)),
                                    child: Text(t['status'] ?? 'open', style: AppTextStyles.captionSm.copyWith(color: statusColor, fontWeight: FontWeight.w700, fontSize: 10)),
                                  ),
                                ]),
                                const SizedBox(height: 6),
                                Text(t['message'] ?? '', style: AppTextStyles.caption.copyWith(height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Text(t['category'] ?? '', style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted)),
                              ]),
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }
}