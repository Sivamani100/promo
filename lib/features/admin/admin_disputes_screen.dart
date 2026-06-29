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

class AdminDisputesScreen extends StatefulWidget {
  const AdminDisputesScreen({super.key});

  @override
  State<AdminDisputesScreen> createState() => _AdminDisputesScreenState();
}

class _AdminDisputesScreenState extends State<AdminDisputesScreen> {
  List<Map<String, dynamic>> _disputes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('disputes')
          .select('*, raiser:profiles!disputes_raised_by_fkey(*), target:profiles!disputes_against_fkey(*)')
          .order('created_at', ascending: false);

      setState(() {
        _disputes = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[DISPUTES] Error loading: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _resolveDispute(String id, String resolution, String note, bool isDismissal) async {
    try {
      final sb = SupabaseService.client;
      await sb.from('disputes').update({
        'status': isDismissal ? 'dismissed' : 'resolved',
        'resolution': resolution,
        'admin_note': note,
        'resolved_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // Add to audit logs
      final user = sb.auth.currentUser;
      if (user != null) {
        await sb.from('audit_logs').insert({
          'actor_id': user.id,
          'actor_role': 'admin',
          'action': isDismissal ? 'dispute.dismiss' : 'dispute.resolve',
          'target_type': 'dispute',
          'target_id': id,
          'metadata': {'resolution': resolution, 'note': note},
        });
      }

      _loadDisputes();
    } catch (e) {
      debugPrint('[DISPUTES] Error updating: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update dispute: $e')),
        );
      }
    }
  }

  void _showResolutionDialog(String id, bool isDismissal) {
    final TextEditingController resolutionController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDismissal ? 'Dismiss Dispute' : 'Resolve Dispute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDismissal) ...[
              TextField(
                controller: resolutionController,
                decoration: const InputDecoration(
                  labelText: 'Resolution Outcome',
                  hintText: 'e.g., Refund brand, Transfer escrow',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Admin Internals Note',
                hintText: 'Internal details regarding this action...',
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
              _resolveDispute(
                id,
                resolutionController.text,
                noteController.text,
                isDismissal,
              );
            },
            child: Text(isDismissal ? 'Confirm Dismissal' : 'Mark Resolved'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
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
              'PLATFORM DISPUTES',
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
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDisputes,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _disputes.isEmpty
                ? const Center(
                    child: AppEmptyState(
                      icon: Iconsax.shield_security,
                      title: 'No disputes registered',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _disputes.length,
                    itemBuilder: (context, i) {
                      final d = _disputes[i];
                      final id = d['id'] as String;
                      final category = d['category'] as String? ?? 'General Dispute';
                      final desc = d['description'] as String? ?? '';
                      final status = d['status'] as String? ?? 'pending';
                      final note = d['admin_note'] as String? ?? '';
                      final resolution = d['resolution'] as String? ?? '';
                      final createdAt = d['created_at'] != null
                          ? DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(d['created_at']))
                          : '';

                      final raiser = d['raiser'] as Map<String, dynamic>?;
                      final target = d['target'] as Map<String, dynamic>?;

                      final raiserName = raiser?['display_name'] ?? 'User';
                      final targetName = target?['display_name'] ?? 'User';

                      Color statusColor = Colors.amber;
                      if (status == 'resolved') {
                        statusColor = Colors.green;
                      } else if (status == 'dismissed') {
                        statusColor = Colors.grey;
                      }

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
                                  Expanded(
                                    child: Text(
                                      category.toUpperCase(),
                                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Raised by $raiserName against $targetName',
                                style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const Divider(height: 24),
                              Text(
                                desc,
                                style: AppTextStyles.body.copyWith(fontSize: 13),
                              ),
                              if (status != 'pending') ...[
                                const Divider(height: 24),
                                if (resolution.isNotEmpty) ...[
                                  Text(
                                    'Resolution:',
                                    style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(resolution, style: AppTextStyles.caption),
                                  const SizedBox(height: 6),
                                ],
                                if (note.isNotEmpty) ...[
                                  Text(
                                    'Admin Note:',
                                    style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(note, style: AppTextStyles.caption),
                                ],
                              ],
                              if (status == 'pending') ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _showResolutionDialog(id, true),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey,
                                          side: const BorderSide(color: Colors.grey),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Dismiss'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _showResolutionDialog(id, false),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.purple,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Resolve'),
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
                  ),
      ),
    );
  }
}
