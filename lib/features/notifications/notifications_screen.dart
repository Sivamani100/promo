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
import '../../core/services/application_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/screen_skeletons.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/app_skeleton.dart';
import '../../core/network/connectivity_service.dart';
import '../../shared/widgets/app_refresh_indicator.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String _activeTab = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final data = await NotificationService().getNotifications(user.id);
    if (mounted) {
      setState(() {
        _notifications = data;
        _loading = false;
      });
    }
    ref.read(unreadNotificationCountProvider.notifier).updateCount(data.where((n) => n['is_read'] == false).length);
  }

  Future<void> _markAllRead() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    await NotificationService().markAllAsRead(user.id);
    _load();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.trash, color: AppColors.error, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Clear All Notifications?',
                        style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to delete all notifications? This action cannot be undone.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(sheetCtx, true),
                        child: const Text('Clear All'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      final user = ref.read(authProvider).user;
      if (user == null) return;
      setState(() => _loading = true);
      await NotificationService().clearAll(user.id);
      _load();
    }
  }

  Future<void> _handleInlineAction(Map<String, dynamic> n, String action) async {
    final refId = n['reference_id'] as String?;
    if (refId == null) return;

    setState(() => _loading = true);
    try {
      final apps = await ApplicationService().getApplicationsForCard(refId);
      final pendingApps = apps.where((a) => a['status'] == 'pending').toList();
      if (pendingApps.isEmpty) {
        if (mounted) AppSnackbar.show(context, 'No pending applications found.');
        setState(() => _loading = false);
        return;
      }

      final app = pendingApps.first;
      final appId = app['id'] as String;
      final influencerId = app['influencer_id'] as String;

      if (action == 'view_profile') {
        context.push('/brand/influencers/$influencerId');
      } else if (action == 'accept') {
        await ApplicationService().updateApplicationStatus(appId, 'accepted');
        if (mounted) AppSnackbar.show(context, 'Application accepted!');
        await NotificationService().markAsRead(n['id']);
        _load();
      } else if (action == 'reject') {
        await ApplicationService().updateApplicationStatus(appId, 'rejected');
        if (mounted) AppSnackbar.show(context, 'Application rejected.');
        await NotificationService().markAsRead(n['id']);
        _load();
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Action failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_activeTab == 'All') return _notifications;
    if (_activeTab == 'Messages') return _notifications.where((n) => n['type'] == 'new_message').toList();
    if (_activeTab == 'Applications') return _notifications.where((n) => n['type']?.startsWith('application_') == true).toList();
    if (_activeTab == 'System') return _notifications.where((n) => n['type'] != 'new_message' && n['type']?.startsWith('application_') != true).toList();
    return _notifications;
  }

  Map<String, List<Map<String, dynamic>>> _groupNotifications(List<Map<String, dynamic>> list) {
    final Map<String, List<Map<String, dynamic>>> grouped = {
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Earlier': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    for (final item in list) {
      final createdAtStr = item['created_at'];
      if (createdAtStr == null) {
        grouped['Earlier']!.add(item);
        continue;
      }
      final date = DateTime.tryParse(createdAtStr) ?? now;
      final compareDate = DateTime(date.year, date.month, date.day);

      if (compareDate.isAtSameMomentAs(today)) {
        grouped['Today']!.add(item);
      } else if (compareDate.isAtSameMomentAs(yesterday)) {
        grouped['Yesterday']!.add(item);
      } else if (compareDate.isAfter(startOfWeek)) {
        grouped['This Week']!.add(item);
      } else {
        grouped['Earlier']!.add(item);
      }
    }

    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  Widget _buildFilterTabs() {
    final categories = ['All', 'Messages', 'Applications', 'System'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final selected = _activeTab == cat;
          return ChoiceChip(
            label: Text(cat),
            labelStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              color: selected ? AppColors.accentOnDark : AppColors.textSecondary,
            ),
            selected: selected,
            selectedColor: AppColors.accent,
            backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF3F3F5),
            checkmarkColor: Colors.black,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
              side: BorderSide(
                color: selected 
                    ? AppColors.accent 
                    : (isDark ? const Color(0xFF1F1F24) : const Color(0xFFE2E2E6)),
                width: 1.2,
              ),
            ),
            onSelected: (val) {
              if (val) {
                setState(() {
                  _activeTab = cat;
                });
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> n, String role) {
    final isRead = n['is_read'] == true;
    final createdAt = n['created_at'] != null ? DateTime.tryParse(n['created_at']) : null;
    final iconColor = _getIconColor(n['type']);
    final iconData = _getIcon(n['type']);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey(n['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Iconsax.trash, color: AppColors.error, size: 22),
      ),
      onDismissed: (direction) async {
        final id = n['id'];
        setState(() {
          _notifications.removeWhere((item) => item['id'] == id);
        });
        try {
          await NotificationService().deleteNotification(id);
        } catch (e) {
          print('Error deleting notification: $e');
        }
      },
      child: Material(
        color: isRead
            ? (isDark ? const Color(0xFF08080A) : const Color(0xFFF3F3F5))
            : (isDark ? const Color(0xFF0F0F12) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRead
                  ? (isDark ? const Color(0xFF141418) : const Color(0xFFEAEAEE))
                  : (isDark ? const Color(0xFF1F1F24) : const Color(0xFFE2E2E6)),
              width: 1.2,
            ),
          ),
          child: InkWell(
            onTap: () async {
              if (!isRead) {
                await NotificationService().markAsRead(n['id']);
                _load();
              }
              if (!mounted) return;

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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                                  color: AppColors.textMuted),
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
                  if (n['type'] == 'application_received' && role == 'brand' && !isRead) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => _handleInlineAction(n, 'accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          child: Text('Accept', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _handleInlineAction(n, 'reject'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.error),
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          child: Text('Reject', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => _handleInlineAction(n, 'view_profile'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text('View Profile', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && _loading) {
        _load();
      }
    });

    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (next == true && previous == false) {
        debugPrint('[NOTIFICATIONS] Back online, reloading...');
        _load();
      }
    });

    final role = ref.watch(authProvider).role ?? 'influencer';
    final hasNotifications = _notifications.isNotEmpty;
    final filtered = _filteredNotifications;
    final grouped = _groupNotifications(filtered);
    final groupKeys = grouped.keys.toList();

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
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
              if (hasNotifications) ...[
                TextButton(
                  onPressed: _markAllRead,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
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
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Iconsax.trash, color: AppColors.error, size: 20),
                  onPressed: _confirmClearAll,
                ),
              ],
            ],
          ),
        ),
      ),
      body: _loading
          ? Column(
              children: [
                _buildFilterTabs(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageMarginHorizontal,
                      0,
                      AppSpacing.pageMarginHorizontal,
                      AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                    ),
                    children: [
                      const SkeletonShimmer(
                        child: Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 12),
                          child: SkeletonText(width: 80, height: 11),
                        ),
                      ),
                      const NotificationTileSkeleton(),
                      const SizedBox(height: 12),
                      const NotificationTileSkeleton(),
                      const SizedBox(height: 16),
                      const SkeletonShimmer(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: SkeletonText(width: 80, height: 11),
                        ),
                      ),
                      const NotificationTileSkeleton(),
                      const SizedBox(height: 12),
                      const NotificationTileSkeleton(),
                      const SizedBox(height: 12),
                      const NotificationTileSkeleton(),
                    ],
                  ),
                ),
              ],
            )
          : AppRefreshIndicator(
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? const AppEmptyState(icon: Iconsax.notification, title: "You're all caught up!", subtitle: "")
                  : Column(
                      children: [
                        _buildFilterTabs(),
                        Expanded(
                          child: filtered.isEmpty
                              ? const AppEmptyState(icon: Iconsax.notification, title: "You're all caught up!", subtitle: "")
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.pageMarginHorizontal,
                                    0,
                                    AppSpacing.pageMarginHorizontal,
                                    AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                                  ),
                                  itemCount: groupKeys.length,
                                  itemBuilder: (context, groupIndex) {
                                    final groupKey = groupKeys[groupIndex];
                                    final groupItems = grouped[groupKey]!;

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(top: 20, bottom: 10, left: 4),
                                          child: Text(
                                            groupKey.toUpperCase(),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textMuted,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          padding: EdgeInsets.zero,
                                          itemCount: groupItems.length,
                                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            final n = groupItems[index];
                                            return _buildNotificationTile(n, role);
                                          },
                                        ),
                                      ],
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