import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/notification_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final data = await NotificationService().getNotifications(user.id);
    if (mounted) setState(() { _notifications = data; _loading = false; });
    ref.read(unreadNotificationCountProvider.notifier).state = data.where((n) => n['is_read'] == false).length;
  }

  Future<void> _markAllRead() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    await NotificationService().markAllAsRead(user.id);
    _load();
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'application_received': return Iconsax.receive_square;
      case 'application_accepted': return Iconsax.tick_circle;
      case 'application_rejected': return Iconsax.close_circle;
      case 'new_message': return Iconsax.message;
      case 'milestone_completed': return Iconsax.flag;
      case 'profile_view': return Iconsax.eye;
      default: return Iconsax.notification;
    }
  }

  Color _getIconColor(String? type) {
    switch (type) {
      case 'application_received': return AppColors.info;
      case 'application_accepted': return AppColors.success;
      case 'application_rejected': return AppColors.error;
      case 'new_message': return AppColors.accent;
      case 'milestone_completed': return AppColors.warning;
      case 'profile_view': return AppColors.purpleLight;
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && _loading) {
        _load();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((n) => n['is_read'] == false))
            TextButton(
              onPressed: _markAllRead,
              child: Text('Mark all read', style: AppTextStyles.labelSm.copyWith(color: AppColors.textSecondary)),
            ),
        ],
      ),
      body: _loading
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const ShimmerNotificationTile(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? const AppEmptyState(icon: Iconsax.notification, title: 'No notifications', subtitle: 'You\'re all caught up!')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical,
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                      ),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final n = _notifications[i];
                        final isRead = n['is_read'] == true;
                        final createdAt = n['created_at'] != null ? DateTime.tryParse(n['created_at']) : null;

                        return GestureDetector(
                          onTap: () async {
                            if (!isRead) {
                              await NotificationService().markAsRead(n['id']);
                              _load();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: isRead ? Colors.transparent : AppColors.surface,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              border: isRead ? null : Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getIconColor(n['type']).withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_getIcon(n['type']), size: 18, color: _getIconColor(n['type'])),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n['title'] ?? '', style: AppTextStyles.label.copyWith(fontWeight: isRead ? FontWeight.w400 : FontWeight.w700, fontSize: 13)),
                                      if (n['body'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(n['body'], style: AppTextStyles.captionSm, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(createdAt != null ? timeago.format(createdAt) : '', style: AppTextStyles.captionSm.copyWith(fontSize: 10, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8, height: 8,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                                  ),
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