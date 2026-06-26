// HARDENING-V2: trust-agent 2026-06-26
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/block_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/shared_widgets.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final BlockService _blockService = BlockService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'You must be logged in to view blocked users';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _blockService.getBlockedUsers(userId);
      if (mounted) {
        setState(() {
          _blockedUsers = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load blocked users: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unblockUser(String blockedId) async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    // Show optimistic UI update
    final originalList = List<Map<String, dynamic>>.from(_blockedUsers);
    setState(() {
      _blockedUsers.removeWhere((item) {
        final blockedData = item['blocked'] as Map<String, dynamic>?;
        return blockedData?['id'] == blockedId;
      });
    });

    try {
      await _blockService.unblockUser(userId, blockedId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked successfully.')),
        );
      }
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _blockedUsers = originalList;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to unblock user: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Blocked Users'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.danger, color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Try Again',
                      onTap: _loadBlockedUsers,
                      width: 150,
                    ),
                  ],
                ),
              ),
            );
          }

          if (_blockedUsers.isEmpty) {
            return const AppEmptyState(
              icon: Iconsax.user_tick,
              title: 'No Blocked Users',
              subtitle: 'Users you block will appear here. Blocking prevents them from contacting you or seeing your profile and campaigns.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: _blockedUsers.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final item = _blockedUsers[index];
              final blockedData = item['blocked'] as Map<String, dynamic>?;
              if (blockedData == null) return const SizedBox.shrink();

              final displayName = blockedData['display_name'] as String? ?? 'User';
              final avatarUrl = blockedData['avatar_url'] as String?;
              final blockedId = blockedData['id'] as String;
              final role = blockedData['role'] as String? ?? 'User';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    AppAvatar(
                      url: avatarUrl,
                      fallbackText: displayName,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role.toUpperCase(),
                            style: AppTextStyles.overline.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    AppButton(
                      label: 'Unblock',
                      isPrimary: false,
                      width: 100,
                      onTap: () => _unblockUser(blockedId),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
