import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../core/utils/error_handler.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  
  String _category = 'General';
  bool _submitting = false;
  List<Map<String, dynamic>> _tickets = [];
  bool _loadingTickets = true;
  String _searchQuery = '';

  // Curated FAQ List
  final List<Map<String, String>> _faqs = [
    {
      'category': 'Account',
      'question': 'How do I customize my digital card?',
      'answer': 'Go to your Profile tab, click "Edit Card" or "Edit Profile", and modify your branding details, social media links, templates, and portfolios. Changes are updated in real-time.'
    },
    {
      'category': 'Account',
      'question': 'Can I change my username or display handle?',
      'answer': 'Yes, you can edit your public handle and display name in Profile Settings. Ensure your handle is unique as it determines your digital card URL.'
    },
    {
      'category': 'Campaigns',
      'question': 'How do I apply to a brand campaign?',
      'answer': 'Open the Discover tab, select an active Brand Card, read the deliverables, and click "Apply". You can enter a customized pitch and rates before submitting.'
    },
    {
      'category': 'Campaigns',
      'question': 'What happens when a milestone is completed?',
      'answer': 'Once you complete a milestone, mark it as completed in the chat room. The brand will be notified to review the deliverables. When approved, escrow funds are automatically released.'
    },
    {
      'category': 'Payments',
      'question': 'When do I receive payment for milestones?',
      'answer': 'Milestone funds are held securely in escrow. They are released immediately to your wallet balance once the brand signs off on the milestone deliverables.'
    },
    {
      'category': 'Payments',
      'question': 'How do I withdraw my earnings?',
      'answer': 'Go to settings, navigate to Wallet / Bank Settings, and link your banking credentials or Stripe account. Once linked, you can withdraw your wallet balance at any time.'
    },
    {
      'category': 'General',
      'question': 'How long does support response take?',
      'answer': 'Our dedicated support team reviews every ticket and responds within 24 hours. You will receive updates in real-time on your ticket status in the "My Tickets" tab.'
    },
    {
      'category': 'General',
      'question': 'How do I report a bug or suggest a feature?',
      'answer': 'File a ticket using the "New Ticket" form. Choose the "Bug Report" or "Feature Request" category so it gets routed to the appropriate engineering team.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase().trim();
      });
    });
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
      if (mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(data);
          _loadingTickets = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      AppToast.show(context, 'Please fill in all fields.', icon: Iconsax.info_circle, iconColor: AppColors.error);
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
      _tabCtrl.animateTo(2); // Switch to My Tickets
      _loadTickets();
      if (mounted) {
        AppToast.show(context, 'Support ticket submitted!');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, AppErrorHandler.toUserMessage(e), icon: Iconsax.info_circle, iconColor: AppColors.error);
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;

    ref.listen(authProvider, (previous, next) {
      if (next.user != null && _loadingTickets) {
        _loadTickets();
      }
    });

    // Filter FAQs
    final filteredFaqs = _faqs.where((faq) {
      final q = faq['question']!.toLowerCase();
      final a = faq['answer']!.toLowerCase();
      final cat = faq['category']!.toLowerCase();
      return q.contains(_searchQuery) || a.contains(_searchQuery) || cat.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Help & Support',
          style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          indicatorWeight: 2,
          dividerColor: AppColors.borderSubtle,
          labelStyle: AppTextStyles.label.copyWith(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle: AppTextStyles.label.copyWith(fontSize: 13),
          tabs: const [
            Tab(text: 'FAQs'),
            Tab(text: 'New Ticket'),
            Tab(text: 'My Tickets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // 1. FAQs Tab
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageMarginHorizontal,
                vertical: AppSpacing.pageMarginVertical,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Frequently Asked Questions',
                    style: AppTextStyles.h4.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Find quick answers to common questions, or submit a ticket if you still need help.',
                    style: AppTextStyles.caption.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Search questions or keywords...',
                        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                        prefixIcon: Icon(Iconsax.search_normal, color: AppColors.textMuted, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  FocusScope.of(context).unfocus();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // FAQs List
                  filteredFaqs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: AppEmptyState(
                              icon: Iconsax.search_status,
                              title: 'No FAQ matches',
                              subtitle: 'Try searching for other terms like "payment" or "profile".',
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredFaqs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final faq = filteredFaqs[i];
                            return Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border, width: 1.2),
                                ),
                                child: ExpansionTile(
                                  collapsedIconColor: AppColors.textMuted,
                                  iconColor: AppColors.accent,
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface2,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      faq['category'] == 'Payments'
                                          ? Iconsax.wallet
                                          : faq['category'] == 'Campaigns'
                                              ? Iconsax.flag
                                              : Iconsax.user,
                                      size: 16,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  title: Text(
                                    faq['question']!,
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      child: Text(
                                        faq['answer']!,
                                        style: AppTextStyles.bodySm.copyWith(
                                          color: AppColors.textSecondary,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),

          // 2. New Ticket Tab
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageMarginHorizontal,
                vertical: AppSpacing.pageMarginVertical,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submit a support ticket and we\'ll get back to you within 24 hours.',
                    style: AppTextStyles.caption.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Text('CATEGORY', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['General', 'Bug Report', 'Account Issue', 'Feature Request', 'Billing'].map((c) => AppChip(
                      label: c,
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Subject',
                    hint: 'Brief description of the issue',
                    controller: _subjectCtrl,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Message',
                    hint: 'Describe your issue in detail...',
                    controller: _messageCtrl,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Submit Ticket',
                    onTap: _submit,
                    isLoading: _submitting,
                  ),
                ],
              ),
            ),
          ),

          // 3. My Tickets Tab
          _loadingTickets
              ? ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, __) => const ShimmerGenericListTile(),
                )
              : RefreshIndicator(
                  onRefresh: _loadTickets,
                  color: AppColors.accent,
                  child: _tickets.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 80),
                              child: AppEmptyState(
                                icon: Iconsax.message_question,
                                title: 'No tickets',
                                subtitle: 'Your support tickets will appear here.',
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: _tickets.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final t = _tickets[i];
                            final status = (t['status'] ?? 'open').toString().toLowerCase();
                            
                            Color statusColor;
                            switch (status) {
                              case 'resolved':
                                statusColor = AppColors.success;
                                break;
                              case 'in_progress':
                              case 'progress':
                                statusColor = AppColors.info;
                                break;
                              case 'closed':
                                statusColor = AppColors.textMuted;
                                break;
                              case 'open':
                              default:
                                statusColor = AppColors.warning;
                                break;
                            }

                            final dateText = t['created_at'] != null
                                ? DateFormat('MMM d, yyyy').format(DateTime.parse(t['created_at']).toLocal())
                                : '';

                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.border, width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t['subject'] ?? '',
                                          style: AppTextStyles.label.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: AppTextStyles.captionSm.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t['message'] ?? '',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        t['category'] ?? 'General',
                                        style: AppTextStyles.captionSm.copyWith(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        dateText,
                                        style: AppTextStyles.captionSm.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }
}