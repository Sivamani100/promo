import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_card.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('user_reports')
          .select('*, reporter:profiles!user_reports_reporter_id_fkey(*), reported:profiles!user_reports_reported_id_fkey(*), card:cards!user_reports_reported_card_id_fkey(*)')
          .order('created_at', ascending: false);

      setState(() {
        _reports = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[REPORTS] Error loading reports: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _resolveReport(String id, String reportedUserId, String actionType, String adminNote) async {
    try {
      final sb = SupabaseService.client;
      
      // Update report status
      await sb.from('user_reports').update({
        'status': 'resolved',
        'admin_note': adminNote,
        'resolved_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // Perform moderation action on the reported user if chosen
      if (actionType == 'warn') {
        // Fetch current warning count first
        final res = await sb.from('profiles').select('warning_count').eq('id', reportedUserId).maybeSingle();
        final currentCount = (res?['warning_count'] as int?) ?? 0;
        await sb.from('profiles').update({
          'warning_count': currentCount + 1,
          'account_status': 'warned',
        }).eq('id', reportedUserId);
      } else if (actionType == 'suspend') {
        await sb.from('profiles').update({
          'account_status': 'suspended',
        }).eq('id', reportedUserId);
      } else if (actionType == 'ban') {
        await sb.from('profiles').update({
          'account_status': 'banned',
        }).eq('id', reportedUserId);
      }

      // Add audit log entry
      final currentUser = sb.auth.currentUser;
      if (currentUser != null) {
        await sb.from('audit_logs').insert({
          'actor_id': currentUser.id,
          'actor_role': 'admin',
          'action': 'report.resolve',
          'target_type': 'user_report',
          'target_id': id,
          'metadata': {
            'action_type': actionType,
            'admin_note': adminNote,
            'reported_user_id': reportedUserId,
          },
        });
      }

      _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report resolved successfully: ${actionType.toUpperCase()}')),
        );
      }
    } catch (e) {
      debugPrint('[REPORTS] Error resolving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve report: $e')),
        );
      }
    }
  }

  void _showResolveDialog(String reportId, String reportedUserId, String reportedName) {
    final TextEditingController noteCtrl = TextEditingController();
    String selectedAction = 'dismiss'; // dismiss, warn, suspend, ban

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Resolve Moderation Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reported User: $reportedName', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Select Action:'),
              DropdownButton<String>(
                value: selectedAction,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'dismiss', child: Text('Dismiss Report (No action)')),
                  DropdownMenuItem(value: 'warn', child: Text('Warn User (Increment warning count)')),
                  DropdownMenuItem(value: 'suspend', child: Text('Suspend Account')),
                  DropdownMenuItem(value: 'ban', child: Text('Permanently Ban Account')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedAction = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Admin Notes',
                  hintText: 'Internal details of resolution decision...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resolveReport(reportId, reportedUserId, selectedAction, noteCtrl.text);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pendingReports = _reports.where((r) => r['status'] == 'pending' || r['status'] == null).toList();
    final resolvedReports = _reports.where((r) => r['status'] == 'resolved').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.background : const Color(0xFFF9FAFB),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leadingWidth: 40,
              leading: IconButton(
                icon: Icon(Iconsax.arrow_left, color: isDark ? Colors.white : Colors.black),
                onPressed: () => context.pop(),
              ),
              title: Text(
                'MODERATION QUEUE',
                style: AppTextStyles.h3.copyWith(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              actions: [
                IconButton(
                  icon: Icon(Iconsax.notification, color: AppColors.textSecondary),
                  onPressed: () => context.push('/admin/notifications'),
                ),
                IconButton(
                  icon: Icon(Iconsax.setting, color: AppColors.textSecondary),
                  onPressed: () => context.push('/admin/settings'),
                ),
              ],
              bottom: TabBar(
                indicatorColor: AppColors.purple,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  Tab(text: 'Pending (${pendingReports.length})'),
                  Tab(text: 'Resolved (${resolvedReports.length})'),
                ],
              ),
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildReportList(pendingReports, isPending: true),
                  _buildReportList(resolvedReports, isPending: false),
                ],
              ),
      ),
    );
  }

  Widget _buildReportList(List<Map<String, dynamic>> list, {required bool isPending}) {
    if (list.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Iconsax.shield_security,
          title: 'Queue is clean',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final r = list[i];
        final id = r['id'] as String;
        final reason = r['reason'] as String? ?? 'General Complaint';
        final details = r['details'] as String? ?? 'No extra details supplied.';
        final status = r['status'] as String? ?? 'pending';
        final note = r['admin_note'] as String? ?? '';
        final createdAt = r['created_at'] != null
            ? DateFormat('MMM d, h:mm a').format(DateTime.parse(r['created_at']))
            : '';

        final reporter = r['reporter'] as Map<String, dynamic>?;
        final reported = r['reported'] as Map<String, dynamic>?;
        final card = r['card'] as Map<String, dynamic>?;

        final reporterName = reporter?['display_name'] ?? 'Anonymous';
        final reportedName = reported?['display_name'] ?? 'User';
        final reportedUserId = reported?['id'] as String? ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        reason.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    Text(createdAt, style: AppTextStyles.captionSm),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Reported By: $reporterName',
                  style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Target Account: $reportedName',
                  style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.bold, color: AppColors.purple),
                ),
                const Divider(height: 24),
                Text(
                  'Complaint details:',
                  style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(details, style: AppTextStyles.body.copyWith(fontSize: 13)),
                if (card != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.card, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Reported Card: ${card['title'] ?? 'Untitled'}',
                            style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!isPending) ...[
                  const Divider(height: 24),
                  Text('Resolution notes:', style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.bold)),
                  Text(note.isNotEmpty ? note : 'No resolution notes left.', style: AppTextStyles.caption),
                ],
                if (isPending && reportedUserId.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showResolveDialog(id, reportedUserId, reportedName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Moderate / Resolve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
