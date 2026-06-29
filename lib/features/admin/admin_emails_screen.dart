import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_spacing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_card.dart';

class AdminEmailsScreen extends ConsumerStatefulWidget {
  const AdminEmailsScreen({super.key});

  @override
  ConsumerState<AdminEmailsScreen> createState() => _AdminEmailsScreenState();
}

class _AdminEmailsScreenState extends ConsumerState<AdminEmailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _broadcasts = [];
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final sb = SupabaseService.client;
      final futures = await Future.wait([
        sb.from('broadcast_emails').select().order('created_at', ascending: false),
        sb.from('email_templates').select().order('name'),
      ]);

      setState(() {
        _broadcasts = List<Map<String, dynamic>>.from(futures[0]);
        _templates = List<Map<String, dynamic>>.from(futures[1]);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ADMIN EMAILS] Error: $e');
      setState(() => _loading = false);
    }
  }

  void _showComposeBroadcastSheet() {
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String audience = 'all'; // all, brand, influencer
    bool sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Text('Compose Email Broadcast', style: AppTextStyles.h2.copyWith(fontSize: 18)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: audience,
                      decoration: const InputDecoration(labelText: 'Target Audience'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Users')),
                        DropdownMenuItem(value: 'brand', child: Text('Brands Only')),
                        DropdownMenuItem(value: 'influencer', child: Text('Influencers Only')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateBuilder(() => audience = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email Subject',
                        hintText: 'Enter subject line...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'HTML / Body Content',
                        hintText: 'Type email content or HTML template here...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    sending
                        ? const Center(child: CircularProgressIndicator())
                        : AppButton(
                            label: 'Send Broadcast Now',
                            icon: Iconsax.direct_send,
                            onTap: () async {
                              final subject = subjectCtrl.text.trim();
                              final body = bodyCtrl.text.trim();
                              if (subject.isEmpty || body.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please fill in all fields.')),
                                );
                                return;
                              }

                              setStateBuilder(() => sending = true);
                              try {
                                final adminId = ref.read(authProvider).user?.id;
                                if (adminId == null) return;

                                // Fetch target count
                                final countQuery = SupabaseService.client.from('profiles').select('id');
                                if (audience != 'all') {
                                  countQuery.eq('role', audience);
                                }
                                final countRes = await countQuery.count(CountOption.exact);
                                final targetCount = countRes.count;

                                await SupabaseService.client.from('broadcast_emails').insert({
                                  'subject': subject,
                                  'html_body': body,
                                  'target_audience': audience,
                                  'sent_count': targetCount,
                                  'status': 'sent',
                                  'sent_at': DateTime.now().toIso8601String(),
                                  'created_by': adminId,
                                });

                                Navigator.pop(sheetCtx);
                                _loadData();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Broadcast sent successfully to $targetCount users!')),
                                  );
                                }
                              } catch (e) {
                                debugPrint('[ADMIN EMAILS] Error sending: $e');
                                setStateBuilder(() => sending = false);
                              }
                            },
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditTemplateSheet(Map<String, dynamic> template) {
    final subjectCtrl = TextEditingController(text: template['subject']);
    final bodyCtrl = TextEditingController(text: template['html_body']);
    final variables = (template['variables'] as List?)?.cast<String>() ?? [];
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Text('Edit Template: ${template['name']}', style: AppTextStyles.h2.copyWith(fontSize: 18)),
                    const SizedBox(height: 8),
                    if (variables.isNotEmpty) ...[
                      Text('AVAILABLE DYNAMIC VARIABLES:', style: AppTextStyles.overline),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: variables.map((v) => Chip(
                          label: Text('{{$v}}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(labelText: 'Email Subject'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'HTML Template Body',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    saving
                        ? const Center(child: CircularProgressIndicator())
                        : AppButton(
                            label: 'Save Changes',
                            onTap: () async {
                              final subject = subjectCtrl.text.trim();
                              final body = bodyCtrl.text.trim();
                              if (subject.isEmpty || body.isEmpty) return;

                              setStateBuilder(() => saving = true);
                              try {
                                final adminId = ref.read(authProvider).user?.id;
                                await SupabaseService.client.from('email_templates').update({
                                  'subject': subject,
                                  'html_body': body,
                                  'updated_by': adminId,
                                  'updated_at': DateTime.now().toIso8601String(),
                                }).eq('id', template['id']);

                                Navigator.pop(sheetCtx);
                                _loadData();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Template updated successfully!')),
                                  );
                                }
                              } catch (e) {
                                debugPrint('[ADMIN EMAILS] Error updating: $e');
                                setStateBuilder(() => saving = false);
                              }
                            },
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF9FAFB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56 + 48 + AppSpacing.pageMarginVertical),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.appBarMarginHorizontal,
            right: AppSpacing.appBarMarginHorizontal,
            top: AppSpacing.pageMarginVertical,
          ),
          child: AppBar(
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              'Email Communications',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Iconsax.notification, size: 22),
                onPressed: () => context.push('/admin/notifications'),
              ),
              IconButton(
                icon: const Icon(Iconsax.setting_2, size: 22),
                onPressed: () => context.push('/admin/settings'),
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(text: 'Broadcasts'),
                Tab(text: 'Templates'),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildBroadcastsTab(isDark),
                _buildTemplatesTab(isDark),
              ],
            ),
    );
  }

  Widget _buildBroadcastsTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: AppButton(
            label: 'Compose New Broadcast',
            icon: Iconsax.add,
            onTap: _showComposeBroadcastSheet,
          ),
        ),
        Expanded(
          child: _broadcasts.isEmpty
              ? const AppEmptyState(icon: Iconsax.direct_send, title: 'No broadcast history')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _broadcasts.length,
                  itemBuilder: (context, i) {
                    final b = _broadcasts[i];
                    final subject = b['subject'] ?? 'No Subject';
                    final audience = b['target_audience'] ?? 'all';
                    final sentCount = b['sent_count'] ?? 0;
                    final sentAt = b['sent_at'] != null 
                        ? DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(b['sent_at'])) 
                        : 'Draft';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject,
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Audience: ${audience.toUpperCase()}  ($sentCount sent)',
                                  style: AppTextStyles.captionSm,
                                ),
                                Text(
                                  sentAt,
                                  style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTemplatesTab(bool isDark) {
    if (_templates.isEmpty) {
      return const AppEmptyState(icon: Iconsax.document, title: 'No email templates found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      itemBuilder: (context, i) {
        final t = _templates[i];
        final name = t['name'] ?? 'Template';
        final subject = t['subject'] ?? 'No Subject';
        final variables = (t['variables'] as List?)?.cast<String>() ?? [];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Iconsax.document_text, color: AppColors.purple, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Subject: $subject', style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Iconsax.edit, color: AppColors.textSecondary, size: 20),
                  onPressed: () => _showEditTemplateSheet(t),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
