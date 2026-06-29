import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_card.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllNotifications();
  }

  Future<void> _loadAllNotifications() async {
    setState(() => _loading = true);
    try {
      final sb = SupabaseService.client;
      
      // 1. Fetch pending verification requests
      final verifications = await sb
          .from('verification_requests')
          .select('*, profile:profiles!verification_requests_user_id_fkey(*)')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      // 2. Fetch soft deletion requests
      final deletions = await sb
          .from('profiles')
          .select()
          .not('deleted_at', 'is', null)
          .order('deleted_at', ascending: false);

      // 3. Fetch recent user registrations (last 7 days)
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final newRegistrations = await sb
          .from('profiles')
          .select()
          .gte('created_at', sevenDaysAgo)
          .order('created_at', ascending: false)
          .limit(20);

      // 4. Fetch standard database notifications
      final user = sb.auth.currentUser;
      List<dynamic> dbNotifs = [];
      if (user != null) {
        dbNotifs = await sb
            .from('notifications')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
      }

      // Merge and map to common structure
      final List<Map<String, dynamic>> merged = [];

      for (var r in newRegistrations) {
        final displayName = r['display_name'] ?? 'User';
        final roleName = r['role'] ?? 'influencer';
        merged.add({
          'type': 'registration',
          'title': 'New Platform Signup',
          'message': '$displayName joined as a ${roleName.toUpperCase()}.',
          'time': DateTime.parse(r['created_at']),
          'icon': Iconsax.user_add,
          'color': Colors.green,
          'route': '/admin/users',
        });
      }

      for (var v in verifications) {
        final profile = v['profile'] as Map<String, dynamic>? ?? {};
        final displayName = profile['display_name'] ?? 'User';
        merged.add({
          'type': 'verification',
          'title': 'Verification Request',
          'message': '$displayName has applied for a verification badge.',
          'time': DateTime.parse(v['created_at']),
          'icon': Iconsax.teacher,
          'color': AppColors.purple,
          'route': '/admin/verification',
        });
      }

      for (var d in deletions) {
        final displayName = d['display_name'] ?? 'User';
        merged.add({
          'type': 'deletion',
          'title': 'Account Deletion Requested',
          'message': '$displayName has requested account deletion.',
          'time': DateTime.parse(d['deleted_at']),
          'icon': Iconsax.trash,
          'color': Colors.red,
          'route': '/admin/deletions',
        });
      }

      for (var n in dbNotifs) {
        merged.add({
          'type': 'system',
          'title': n['title'] ?? 'System Alert',
          'message': n['message'] ?? '',
          'time': DateTime.parse(n['created_at']),
          'icon': Iconsax.notification,
          'color': Colors.amber,
          'route': null,
        });
      }

      // Sort by time descending
      merged.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));

      setState(() {
        _items = merged;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ADMIN NOTIFS] Error loading notifications: $e');
      setState(() => _loading = false);
    }
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
              'Notifications',
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
                icon: const Icon(Iconsax.refresh),
                onPressed: _loadAllNotifications,
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const AppEmptyState(icon: Iconsax.notification, title: 'No notifications yet')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _items.length,
                  itemBuilder: (context, idx) {
                    final item = _items[idx];
                    final date = DateFormat('MMM d, h:mm a').format(item['time'] as DateTime);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        onTap: item['route'] != null
                            ? () => context.push(item['route'] as String)
                            : null,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (item['color'] as Color).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: item['color'] as Color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item['title'] as String,
                                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      Text(date, style: AppTextStyles.captionSm),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['message'] as String,
                                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
