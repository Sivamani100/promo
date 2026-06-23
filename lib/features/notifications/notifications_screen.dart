import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    ref.read(unreadNotificationCountProvider.notifier).updateCount(data.where((n) => n['is_read'] == false).length);
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnread = _notifications.any((n) => n['is_read'] == false);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56 + AppSpacing.pageMarginVertical),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.pageMarginHorizontal,
            right: AppSpacing.pageMarginHorizontal,
            top: AppSpacing.pageMarginVertical,
          ),
          child: AppBar(
            leading: IconButton(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.pop(),
            ),
            leadingWidth: 30,
            centerTitle: false,
            titleSpacing: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '.',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              if (hasUnread)
                TextButton(
                  onPressed: _markAllRead,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    'Mark all read',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
              color: AppColors.accent,
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
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final n = _notifications[i];
                        final isRead = n['is_read'] == true;
                        final createdAt = n['created_at'] != null ? DateTime.tryParse(n['created_at']) : null;
                        final iconColor = _getIconColor(n['type']);
                        final iconData = _getIcon(n['type']);

                        return Material(
                          color: isRead
                              ? (isDark ? const Color(0xFF08080A) : const Color(0xFFF3F3F5))
                              : (isDark ? const Color(0xFF0F0F12) : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () async {
                              if (!isRead) {
                                await NotificationService().markAsRead(n['id']);
                                _load();
                              }
                              if (!mounted) return;
                              final role = ref.read(authProvider).role;
                              if (role == null) return;

                              final type = n['type'] as String?;
                              final refId = n['reference_id'] as String?;

                              if (type == 'new_message' && refId != null) {
                                context.push('/$role/chats/$refId');
                              } else if (type == 'application_received' && refId != null && role == 'brand') {
                                context.push('/brand/cards/$refId');
                              } else if (type == 'application_accepted' && refId != null && role == 'influencer') {
                                context.push('/influencer/discover/$refId');
                              } else if (type == 'application_rejected' && role == 'influencer') {
                                context.push('/influencer/my-applications');
                              } else if (type == 'milestone_completed' && refId != null) {
                                context.push('/$role/chats/$refId');
                              } else if (type == 'profile_view' && role == 'influencer') {
                                context.push('/influencer/profile-views');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isRead
                                      ? (isDark ? const Color(0xFF141418) : const Color(0xFFEAEAEE))
                                      : (isDark ? const Color(0xFF1F1F24) : const Color(0xFFE2E2E6)),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      iconData,
                                      size: 20,
                                      color: iconColor,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n['title'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (n['body'] != null && (n['body'] as String).isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            n['body'],
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: AppColors.textSecondary,
                                              height: 1.4,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          createdAt != null ? timeago.format(createdAt) : '',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isRead) ...[
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(top: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.accent.withValues(alpha: 0.4),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}