import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_spacing.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_card.dart';

class AdminDeletionsScreen extends StatefulWidget {
  const AdminDeletionsScreen({super.key});

  @override
  State<AdminDeletionsScreen> createState() => _AdminDeletionsScreenState();
}

class _AdminDeletionsScreenState extends State<AdminDeletionsScreen> {
  List<Map<String, dynamic>> _deletedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDeletions();
  }

  Future<void> _loadDeletions() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .not('deleted_at', 'is', null)
          .order('deleted_at', ascending: false);

      setState(() {
        _deletedUsers = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ADMIN DELETIONS] Error loading soft deleted users: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _restoreUser(String userId) async {
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'deleted_at': null})
          .eq('id', userId);

      _loadDeletions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account has been successfully restored!')),
        );
      }
    } catch (e) {
      debugPrint('[ADMIN DELETIONS] Error restoring account: $e');
    }
  }

  Future<void> _confirmPermanentDeletion(String userId, String displayName) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Permanent Purge', style: TextStyle(color: Colors.red)),
        content: Text(
          'Are you absolutely sure you want to permanently delete $displayName\'s account and ALL associated files, messages, cards, and data? This action uses a secure script and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _loading = true);
              try {
                // Call delete_user_account RPC
                await SupabaseService.client.rpc('delete_user_account', params: {'p_user_id': userId});
                _loadDeletions();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User and all associated data permanently deleted from database.')),
                  );
                }
              } catch (e) {
                debugPrint('[ADMIN DELETIONS] Error hard deleting user: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
                setState(() => _loading = false);
              }
            },
            child: const Text('Confirm Purge', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              'Deletion Requests',
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACCOUNTS PENDING PURGE',
                    style: AppTextStyles.overline,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _deletedUsers.isEmpty
                        ? const AppEmptyState(icon: Iconsax.trash, title: 'No pending deletions')
                        : ListView.builder(
                            itemCount: _deletedUsers.length,
                            itemBuilder: (context, idx) {
                              final user = _deletedUsers[idx];
                              final displayName = user['display_name'] ?? 'User';
                              final role = user['role'] as String? ?? 'user';
                              final deletedAt = user['deleted_at'] != null 
                                  ? DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(user['deleted_at'])) 
                                  : 'Unknown time';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          AppAvatar(
                                            url: user['avatar_url'],
                                            fallbackText: displayName,
                                            size: 40,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(displayName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                                                Text('Role: ${role.toUpperCase()}  • Requested: $deletedAt', style: AppTextStyles.captionSm),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => _restoreUser(user['id']),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green.withValues(alpha: 0.1),
                                              foregroundColor: Colors.green,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                            ),
                                            child: const Text('Restore Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton(
                                            onPressed: () => _confirmPermanentDeletion(user['id'], displayName),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red.withValues(alpha: 0.1),
                                              foregroundColor: Colors.red,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                            ),
                                            child: const Text('Confirm Deletion', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
              ),
            ),
    );
  }
}
