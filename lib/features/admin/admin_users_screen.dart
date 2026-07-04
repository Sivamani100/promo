import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_spacing.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_card.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedRole = 'all';
  String _selectedStatus = 'all';
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ADMIN USERS] Error loading users: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _updateUserField(String userId, Map<String, dynamic> updates) async {
    try {
      await SupabaseService.client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
      _loadUsers();
    } catch (e) {
      debugPrint('[ADMIN USERS] Error updating user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user: $e')),
        );
      }
    }
  }

  void _showUserActionMenu(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final isVerified = user['is_verified'] as bool? ?? false;
    final currentRole = user['role'] as String? ?? 'influencer';
    final status = user['account_status'] as String? ?? 'active';
    final warningCount = user['warning_count'] as int? ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          padding: const EdgeInsets.all(24),
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
              Row(
                children: [
                  AppAvatar(
                    url: user['avatar_url'],
                    fallbackText: user['display_name'] ?? 'U',
                    size: 50,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['display_name'] ?? 'User', style: AppTextStyles.h3),
                        Text('Role: ${currentRole.toUpperCase()}', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Bento details card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).brightness == Brightness.dark ? const Color(0xFF16161A) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('WARNINGS', style: AppTextStyles.overline.copyWith(fontSize: 9)),
                        const SizedBox(height: 4),
                        Text('$warningCount', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('STATUS', style: AppTextStyles.overline.copyWith(fontSize: 9)),
                        const SizedBox(height: 4),
                        Text(status.toUpperCase(), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: status == 'active' ? Colors.green : Colors.red)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('VERIFIED', style: AppTextStyles.overline.copyWith(fontSize: 9)),
                        const SizedBox(height: 4),
                        Text(isVerified ? 'YES' : 'NO', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: isVerified ? Colors.blue : Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('USER ACTIONS', style: AppTextStyles.overline),
              const SizedBox(height: 12),

              // View Activity Logs & Report Action
              ListTile(
                leading: Icon(Iconsax.document_text, color: AppColors.purple),
                title: const Text('View Activity Logs & Report'),
                subtitle: const Text('Inspect chats, activity history, profile views, and download reports'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.push('/admin/users/logs', extra: user);
                },
              ),
              const Divider(),

              // Verification Badge Action
              ListTile(
                leading: Icon(Iconsax.teacher, color: AppColors.purple),
                title: Text(isVerified ? 'Remove Verification Badge' : 'Grant Verification Badge'),
                subtitle: Text(isVerified ? 'Remove verified blue tick status' : 'Add verified blue tick status to profile'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _updateUserField(userId, {'is_verified': !isVerified});
                },
              ),
              const Divider(),

              // Change user role
              ListTile(
                leading: const Icon(Iconsax.profile_2user),
                title: const Text('Change User Role'),
                subtitle: Text('Currently: ${currentRole.toUpperCase()}'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showRoleSelectionDialog(user);
                },
              ),
              const Divider(),

              // Warning Action
              ListTile(
                leading: const Icon(Iconsax.info_circle, color: Colors.orange),
                title: Text('Warn User ($warningCount warnings)'),
                subtitle: const Text('Issue a new warning with reason'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showWarnDialog(user);
                },
              ),
              const Divider(),

              // Manage Warnings
              if (warningCount > 0) ...[
                ListTile(
                  leading: const Icon(Iconsax.shield_tick, color: Colors.teal),
                  title: Text('Manage Warnings ($warningCount active)'),
                  subtitle: const Text('View, review, or remove warnings'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showManageWarningsDialog(user);
                  },
                ),
                const Divider(),
              ],

              // Suspension / Ban
              ListTile(
                leading: const Icon(Iconsax.shield_security, color: Colors.red),
                title: Text(status == 'banned' || status == 'suspended' ? 'Activate / Unban Account' : 'Suspend or Ban Account'),
                subtitle: Text('Current status: ${status.toUpperCase()}'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  if (status == 'banned' || status == 'suspended') {
                    _updateUserField(userId, {'account_status': 'active', 'suspension_reason': null, 'suspension_until': null});
                  } else {
                    _showModerationDialog(user);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showRoleSelectionDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select User Role'),
        children: ['brand', 'influencer', 'admin'].map((role) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _updateUserField(user['id'], {'role': role});
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(role.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showModerationDialog(Map<String, dynamic> user) {
    final reasonCtrl = TextEditingController();
    String type = 'suspended'; // or banned

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateBuilder) {
          return AlertDialog(
            title: Text('Moderate ${user['display_name'] ?? 'User'}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'suspended', child: Text('Suspend (7 Days)')),
                    DropdownMenuItem(value: 'banned', child: Text('Ban Permanently')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setStateBuilder(() => type = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Action',
                    hintText: 'Enter reason...',
                  ),
                  maxLines: 2,
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
                  final updates = <String, dynamic>{
                    'account_status': type,
                    'suspension_reason': reasonCtrl.text.trim(),
                  };
                  if (type == 'suspended') {
                    updates['suspension_until'] = DateTime.now().add(const Duration(days: 7)).toIso8601String();
                  } else {
                    updates['suspension_until'] = null;
                  }
                  _updateUserField(user['id'], updates);
                },
                child: const Text('Apply', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dialog to issue a new warning with a reason.
  void _showWarnDialog(Map<String, dynamic> user) {
    final reasonCtrl = TextEditingController();
    final userId = user['id'] as String;
    final warningCount = user['warning_count'] as int? ?? 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Iconsax.info_circle, color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Text('Warn ${user['display_name'] ?? 'User'}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current warnings: $warningCount',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for Warning *',
                  hintText: 'e.g. Posting misleading content...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
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
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason for the warning')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _issueWarning(userId, reason, warningCount);
              },
              child: const Text('Issue Warning', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Issues a warning: inserts a record into user_warnings AND updates profiles.
  Future<void> _issueWarning(String userId, String reason, int currentCount) async {
    try {
      final adminId = SupabaseService.client.auth.currentUser?.id;
      if (adminId == null) return;

      // Insert warning record
      await SupabaseService.client.from('user_warnings').insert({
        'user_id': userId,
        'issued_by': adminId,
        'reason': reason,
        'status': 'active',
      });

      // Update profile warning count and status
      await SupabaseService.client.from('profiles').update({
        'warning_count': currentCount + 1,
        'account_status': 'warned',
      }).eq('id', userId);

      _loadUsers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warning issued successfully')),
        );
      }
    } catch (e) {
      debugPrint('[ADMIN] Error issuing warning: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to issue warning: $e')),
        );
      }
    }
  }

  /// Shows a dialog listing all active warnings with the ability to remove them.
  void _showManageWarningsDialog(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    final displayName = user['display_name'] ?? 'User';

    // Fetch all warnings for this user
    List<Map<String, dynamic>> warnings = [];
    try {
      final data = await SupabaseService.client
          .from('user_warnings')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      warnings = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[ADMIN] Error fetching warnings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load warnings: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final activeWarnings = warnings.where((w) => w['status'] == 'active').toList();
            final removedWarnings = warnings.where((w) => w['status'] == 'removed').toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        const Icon(Iconsax.shield_tick, color: Colors.teal, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Warnings for $displayName',
                            style: AppTextStyles.h3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${activeWarnings.length} active \u00b7 ${removedWarnings.length} removed',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),

                  // Warnings list
                  Flexible(
                    child: warnings.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text('No warnings found.', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shrinkWrap: true,
                            itemCount: warnings.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final w = warnings[idx];
                              final isActive = w['status'] == 'active';
                              final createdAt = DateTime.tryParse(w['created_at'] ?? '');
                              final dateStr = createdAt != null
                                  ? DateFormat('MMM dd, yyyy \u00b7 hh:mm a').format(createdAt.toLocal())
                                  : 'Unknown date';
                              final removedAt = DateTime.tryParse(w['removed_at'] ?? '');
                              final removedDateStr = removedAt != null
                                  ? DateFormat('MMM dd, yyyy \u00b7 hh:mm a').format(removedAt.toLocal())
                                  : null;

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.orange.withValues(alpha: 0.06)
                                      : AppColors.textMuted.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isActive
                                        ? Colors.orange.withValues(alpha: 0.2)
                                        : AppColors.border.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isActive ? Iconsax.warning_2 : Iconsax.tick_circle,
                                          size: 16,
                                          color: isActive ? Colors.orange : Colors.green,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isActive ? 'ACTIVE' : 'REMOVED',
                                          style: AppTextStyles.overline.copyWith(
                                            color: isActive ? Colors.orange : Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(dateStr, style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      w['reason'] ?? 'No reason provided',
                                      style: AppTextStyles.bodySm.copyWith(
                                        fontWeight: FontWeight.w600,
                                        decoration: isActive ? null : TextDecoration.lineThrough,
                                        color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                                      ),
                                    ),
                                    if (!isActive && w['removed_reason'] != null) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Iconsax.message_text, size: 13, color: Colors.green.withValues(alpha: 0.6)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Removal reason: ${w['removed_reason']}',
                                              style: AppTextStyles.captionSm.copyWith(color: Colors.green.shade700),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (removedDateStr != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Removed on $removedDateStr',
                                          style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted, fontSize: 10),
                                        ),
                                      ],
                                    ],
                                    if (isActive) ...[
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          icon: const Icon(Iconsax.close_circle, size: 16, color: Colors.teal),
                                          label: const Text('Remove', style: TextStyle(color: Colors.teal, fontSize: 12)),
                                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                                          onPressed: () {
                                            _showRemoveWarningDialog(w, userId, user, () {
                                              // Refresh warnings list
                                              SupabaseService.client
                                                  .from('user_warnings')
                                                  .select()
                                                  .eq('user_id', userId)
                                                  .order('created_at', ascending: false)
                                                  .then((data) {
                                                setSheetState(() {
                                                  warnings = List<Map<String, dynamic>>.from(data);
                                                });
                                              });
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Dialog to confirm removing a specific warning with a removal reason.
  void _showRemoveWarningDialog(
    Map<String, dynamic> warning,
    String userId,
    Map<String, dynamic> user,
    VoidCallback onRemoved,
  ) {
    final removalReasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Iconsax.close_circle, color: Colors.teal, size: 22),
              SizedBox(width: 8),
              Text('Remove Warning'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ORIGINAL WARNING:', style: AppTextStyles.overline.copyWith(color: Colors.orange)),
                    const SizedBox(height: 4),
                    Text(
                      warning['reason'] ?? 'No reason',
                      style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: removalReasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for Removal *',
                  hintText: 'e.g. Warning was issued in error...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
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
                final reason = removalReasonCtrl.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason for removing this warning')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _removeWarning(warning['id'], userId, user, reason, onRemoved);
              },
              child: const Text('Remove Warning', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Removes a warning: marks as removed in user_warnings, decrements warning_count.
  Future<void> _removeWarning(
    String warningId,
    String userId,
    Map<String, dynamic> user,
    String removalReason,
    VoidCallback onRemoved,
  ) async {
    try {
      final adminId = SupabaseService.client.auth.currentUser?.id;
      if (adminId == null) return;

      // Mark warning as removed
      await SupabaseService.client.from('user_warnings').update({
        'status': 'removed',
        'removed_by': adminId,
        'removed_at': DateTime.now().toUtc().toIso8601String(),
        'removed_reason': removalReason,
      }).eq('id', warningId);

      // Count remaining active warnings
      final activeData = await SupabaseService.client
          .from('user_warnings')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'active');
      final activeCount = (activeData as List).length;

      // Update profile
      final updates = <String, dynamic>{
        'warning_count': activeCount,
      };
      if (activeCount == 0) {
        updates['account_status'] = 'active';
      }
      await SupabaseService.client.from('profiles').update(updates).eq('id', userId);

      _loadUsers();
      onRemoved();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warning removed successfully')),
        );
      }
    } catch (e) {
      debugPrint('[ADMIN] Error removing warning: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove warning: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter and search
    final filteredUsers = _users.where((user) {
      final name = (user['display_name'] ?? '').toString().toLowerCase();
      final bio = (user['bio'] ?? '').toString().toLowerCase();
      final location = (user['location'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();
      final status = (user['account_status'] ?? 'active').toString().toLowerCase();
      
      final matchesQuery = name.contains(_query) || bio.contains(_query) || location.contains(_query);
      final matchesRole = _selectedRole == 'all' || role == _selectedRole;
      final matchesStatus = _selectedStatus == 'all' || status == _selectedStatus;

      return matchesQuery && matchesRole && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF9FAFB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56 + AppSpacing.pageMarginVertical),
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
              'User Management',
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
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search users by name, bio, location...',
                      prefixIcon: const Icon(Iconsax.search_normal),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['all', 'brand', 'influencer', 'admin'].map((role) {
                        final isSelected = _selectedRole == role;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(role.toUpperCase()),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() => _selectedRole = role);
                            },
                            selectedColor: AppColors.purple.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.purple,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.purple : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['all', 'active', 'warned', 'suspended', 'banned'].map((status) {
                        final isSelected = _selectedStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(status.toUpperCase()),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() => _selectedStatus = status);
                            },
                            selectedColor: AppColors.accent.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.accent,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.accent : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Directory List
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? const AppEmptyState(icon: Iconsax.profile_2user, title: 'No users found')
                        : ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, idx) {
                              final user = filteredUsers[idx];
                              final displayName = user['display_name'] ?? 'Anonymous';
                              final role = user['role'] as String? ?? 'user';
                              final isVerified = user['is_verified'] as bool? ?? false;
                              final status = user['account_status'] as String? ?? 'active';

                              Color statusColor;
                              switch (status) {
                                case 'banned':
                                  statusColor = Colors.red;
                                  break;
                                case 'suspended':
                                  statusColor = Colors.orange;
                                  break;
                                case 'warned':
                                  statusColor = Colors.yellow.shade700;
                                  break;
                                default:
                                  statusColor = Colors.green;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  onTap: () => _showUserActionMenu(user),
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      AppAvatar(
                                        url: user['avatar_url'],
                                        fallbackText: displayName,
                                        size: 46,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    displayName,
                                                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isVerified) ...[
                                                  const SizedBox(width: 4),
                                                  const VerificationBadge(size: 16),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  role.toUpperCase(),
                                                  style: AppTextStyles.captionSm.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.purple,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey)),
                                                const SizedBox(width: 8),
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: statusColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(status.toUpperCase(), style: AppTextStyles.captionSm),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Iconsax.more, color: AppColors.textMuted, size: 20),
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
