import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/screen_skeletons.dart';
import '../../shared/widgets/app_refresh_indicator.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  bool _loading = true;
  int _totalUsers = 0;
  int _pendingVerifications = 0;
  int _activeSupportChats = 0;
  int _deletionRequestsCount = 0;
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final sb = SupabaseService.client;
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final futures = await Future.wait([
        // 1. Total users profiles count
        sb.from('profiles').select('id').count(CountOption.exact).timeout(const Duration(seconds: 10)),
        // 2. Pending verifications count
        sb.from('verification_requests').select('id').eq('status', 'pending').count(CountOption.exact).timeout(const Duration(seconds: 10)),
        // 3. Support chats count (admin is either brand_id or influencer_id)
        sb.from('rooms').select('id').or('brand_id.eq.${user.id},influencer_id.eq.${user.id}').count(CountOption.exact).timeout(const Duration(seconds: 10)),
        // 4. Deletions count (profiles where deleted_at is not null)
        sb.from('profiles').select('id').not('deleted_at', 'is', null).count(CountOption.exact).timeout(const Duration(seconds: 10)),
        // 5. Recent audit logs
        sb.from('audit_logs').select().order('created_at', ascending: false).limit(5).timeout(const Duration(seconds: 10)),
      ]);

      final totalUsersVal = (futures[0] as PostgrestResponse).count;
      final pendingVerificationsVal = (futures[1] as PostgrestResponse).count;
      final activeSupportChatsVal = (futures[2] as PostgrestResponse).count;
      final deletionRequestsVal = (futures[3] as PostgrestResponse).count;
      
      final dynamic logsData = futures[4];
      final List<Map<String, dynamic>> activitiesList = logsData is PostgrestResponse
          ? List<Map<String, dynamic>>.from(logsData.data as List? ?? [])
          : List<Map<String, dynamic>>.from(logsData as List? ?? []);

      if (mounted) {
        setState(() {
          _totalUsers = totalUsersVal;
          _pendingVerifications = pendingVerificationsVal;
          _activeSupportChats = activeSupportChatsVal;
          _deletionRequestsCount = deletionRequestsVal;
          _activities = activitiesList;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[ADMIN DASHBOARD] Error loading data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(authProvider).profile;
    final displayName = profile?['display_name'] ?? 'Admin Staff';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
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
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Promo Admin',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '.',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ],
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
          : AppRefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Bento
                    _buildWelcomeBentoBox(displayName, 0),
                    const SizedBox(height: 16),

                    // Stats Bento Grid
                    Row(
                      children: [
                        Expanded(
                          child: _statHighlightBento(
                            title: 'Total Users',
                            value: '$_totalUsers',
                            subtitle: 'All platform users',
                            icon: Iconsax.profile_2user,
                            color: const Color(0xFF6366F1),
                            onTap: () => context.go('/admin/users'),
                            delayIndex: 1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statHighlightBento(
                            title: 'Verify Requests',
                            value: '$_pendingVerifications',
                            subtitle: 'Pending reviews',
                            icon: Iconsax.teacher,
                            color: const Color(0xFFF43F5E),
                            onTap: () => context.go('/admin/verification'),
                            delayIndex: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _statHighlightBento(
                            title: 'Support Chats',
                            value: '$_activeSupportChats',
                            subtitle: 'Customer threads',
                            icon: Iconsax.message,
                            color: const Color(0xFF10B981),
                            onTap: () => context.go('/admin/chats'),
                            delayIndex: 3,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statHighlightBento(
                            title: 'Pending Deletions',
                            value: '$_deletionRequestsCount',
                            subtitle: 'Deletion requests',
                            icon: Iconsax.trash,
                            color: const Color(0xFFF59E0B),
                            onTap: () => context.push('/admin/deletions'),
                            delayIndex: 4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions Bento
                    _buildQuickActionsBento(5),
                    const SizedBox(height: 16),

                    // Recent Activity Bento
                    _buildRecentActivityBento(6),

                    // Footer
                    const SizedBox(height: 56),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'App Maintenance,',
                            style: GoogleFonts.inter(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                              color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'from Promo Staff.',
                            style: GoogleFonts.inter(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                              color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeBentoBox(String displayName, int delayIndex) {
    return _BentoBox(
      animationDelayIndex: delayIndex,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()},',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: AppTextStyles.captionSm.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Iconsax.shield_security, color: AppColors.purple, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _statHighlightBento({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int delayIndex,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor;
    Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
    Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (title == 'Total Users') {
      bgColor = isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF);
    } else if (title == 'Verify Requests') {
      bgColor = isDark ? const Color(0xFF4C0519) : const Color(0xFFFFE4E6);
    } else if (title == 'Support Chats') {
      bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
    } else {
      bgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
    }

    return AspectRatio(
      aspectRatio: 1.0,
      child: _BentoBox(
        animationDelayIndex: delayIndex,
        onTap: onTap,
        color: bgColor,
        borderColor: Colors.transparent,
        borderRadius: 28.0,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -1.2,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: subTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsBento(int delayIndex) {
    return _BentoBox(
      animationDelayIndex: delayIndex,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Iconsax.flash, size: 16, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Text(
                'System Quick Actions',
                style: AppTextStyles.h4.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Broadcast Email',
                  icon: Iconsax.direct_send,
                  onTap: () => context.push('/admin/emails'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Feature Flags',
                  icon: Iconsax.setting_3,
                  isPrimary: false,
                  onTap: () => _showFeatureFlagsSheet(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Platform Configs',
                  icon: Iconsax.setting_4,
                  onTap: () => _showPlatformConfigSheet(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Resolve Disputes',
                  icon: Iconsax.shield_security,
                  isPrimary: false,
                  onTap: () => context.push('/admin/disputes'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Reports Queue',
                  icon: Iconsax.danger,
                  onTap: () => context.push('/admin/reports'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Help Articles',
                  icon: Iconsax.document_text,
                  isPrimary: false,
                  onTap: () => context.push('/admin/help-articles'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFeatureFlagsSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _FeatureFlagsSheet(),
    );
  }

  void _showPlatformConfigSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlatformConfigSheet(),
    );
  }

  Widget _buildRecentActivityBento(int delayIndex) {
    return _BentoBox(
      animationDelayIndex: delayIndex,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Iconsax.activity,
                  color: AppColors.accent,
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'System Audit Logs',
                style: AppTextStyles.label.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_activities.isEmpty)
            const AppEmptyState(icon: Iconsax.document_text, title: 'No recent events')
          else
            ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activities.length,
              itemBuilder: (context, i) {
                final a = _activities[i];
                final action = a['action'] as String? ?? 'event';
                final targetType = a['target_type'] as String? ?? 'system';
                final createdAt = a['created_at'] != null 
                    ? DateFormat('MMM d, h:mm a').format(DateTime.parse(a['created_at'])) 
                    : '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${action.replaceAll('_', ' ').toUpperCase()} on ${targetType.toUpperCase()}',
                              style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (a['metadata'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                a['metadata'].toString(),
                                style: AppTextStyles.captionSm.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              createdAt,
                              style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BentoBox extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final int animationDelayIndex;
  final double borderRadius;

  const _BentoBox({
    required this.child,
    this.onTap,
    this.height,
    this.width,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.animationDelayIndex = 0,
    this.borderRadius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxColor = color ?? (isDark ? const Color(0xFF0F0F11) : Colors.white);
    final borderCol = borderColor ?? (isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB));

    Widget content = Container(
      height: height,
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderCol,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    return content
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 500),
          delay: Duration(milliseconds: 50 * animationDelayIndex),
        )
        .slideY(
          begin: 0.15,
          end: 0.0,
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 500),
          delay: Duration(milliseconds: 50 * animationDelayIndex),
        );
  }
}

class _FeatureFlagsSheet extends StatefulWidget {
  const _FeatureFlagsSheet();

  @override
  State<_FeatureFlagsSheet> createState() => _FeatureFlagsSheetState();
}

class _FeatureFlagsSheetState extends State<_FeatureFlagsSheet> {
  List<Map<String, dynamic>> _flags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFlags();
  }

  Future<void> _loadFlags() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('feature_flags')
          .select()
          .order('key');
      setState(() {
        _flags = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[FEATURE FLAGS] Error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleFlag(String key, bool currentValue) async {
    try {
      await SupabaseService.client
          .from('feature_flags')
          .update({'enabled': !currentValue, 'updated_at': DateTime.now().toIso8601String()})
          .eq('key', key);
      _loadFlags();
    } catch (e) {
      debugPrint('[FEATURE FLAGS] Error toggling: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Text(
            'System Feature Flags',
            style: AppTextStyles.h2.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Enable or disable runtime app functionalities globally.',
            style: AppTextStyles.caption.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_flags.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No feature flags found.')))
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _flags.length,
                itemBuilder: (context, i) {
                  final flag = _flags[i];
                  final key = flag['key'] as String;
                  final enabled = flag['enabled'] as bool? ?? false;
                  final desc = flag['description'] as String? ?? '';

                  return SwitchListTile(
                    title: Text(key, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text(desc, style: AppTextStyles.caption),
                    value: enabled,
                    activeColor: AppColors.accent,
                    onChanged: (val) => _toggleFlag(key, enabled),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          SafeArea(
            child: AppButton(
              label: 'Done',
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformConfigSheet extends StatefulWidget {
  const _PlatformConfigSheet();

  @override
  State<_PlatformConfigSheet> createState() => _PlatformConfigSheetState();
}

class _PlatformConfigSheetState extends State<_PlatformConfigSheet> {
  bool _loading = true;
  bool _saving = false;

  final TextEditingController _versionController = TextEditingController();
  final TextEditingController _maxCardsController = TextEditingController();
  final TextEditingController _maxAppsController = TextEditingController();
  final TextEditingController _suspendController = TextEditingController();
  final TextEditingController _uploadController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  @override
  void dispose() {
    _versionController.dispose();
    _maxCardsController.dispose();
    _maxAppsController.dispose();
    _suspendController.dispose();
    _uploadController.dispose();
    super.dispose();
  }

  Future<void> _loadConfigs() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client.from('platform_config').select();
      final map = <String, dynamic>{};
      for (var row in data) {
        map[row['key'] as String] = row['value'];
      }
      setState(() {
        _versionController.text = (map['min_app_version'] ?? '1.0.0').toString();
        _maxCardsController.text = (map['max_cards_per_brand_per_day'] ?? '10').toString();
        _maxAppsController.text = (map['max_applications_per_influencer_per_day'] ?? '20').toString();
        _suspendController.text = (map['auto_suspend_report_threshold'] ?? '5').toString();
        _uploadController.text = (map['max_file_upload_mb'] ?? '10').toString();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[PLATFORM CONFIGS] Error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveConfigs() async {
    setState(() => _saving = true);
    try {
      final sb = SupabaseService.client;
      final user = sb.auth.currentUser;
      final updates = [
        {'key': 'min_app_version', 'value': _versionController.text, 'updated_at': DateTime.now().toIso8601String(), 'updated_by': user?.id},
        {'key': 'max_cards_per_brand_per_day', 'value': int.tryParse(_maxCardsController.text) ?? 10, 'updated_at': DateTime.now().toIso8601String(), 'updated_by': user?.id},
        {'key': 'max_applications_per_influencer_per_day', 'value': int.tryParse(_maxAppsController.text) ?? 20, 'updated_at': DateTime.now().toIso8601String(), 'updated_by': user?.id},
        {'key': 'auto_suspend_report_threshold', 'value': int.tryParse(_suspendController.text) ?? 5, 'updated_at': DateTime.now().toIso8601String(), 'updated_by': user?.id},
        {'key': 'max_file_upload_mb', 'value': int.tryParse(_uploadController.text) ?? 10, 'updated_at': DateTime.now().toIso8601String(), 'updated_by': user?.id},
      ];
      for (var update in updates) {
        await sb.from('platform_config').update({
          'value': update['value'],
          'updated_at': update['updated_at'],
          'updated_by': update['updated_by'],
        }).eq('key', update['key'] as String);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Platform configurations updated successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[PLATFORM CONFIGS] Error saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
          Text(
            'Platform Configuration Parameters',
            style: AppTextStyles.h2.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Tweak limits, thresholds, and version parameters globally.',
            style: AppTextStyles.caption.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildInputField('Minimum Supported App Version', _versionController, TextInputType.text),
                    _buildInputField('Max Active Cards per Brand / Day', _maxCardsController, TextInputType.number),
                    _buildInputField('Max Applications per Influencer / Day', _maxAppsController, TextInputType.number),
                    _buildInputField('Auto-Suspension Report Threshold', _suspendController, TextInputType.number),
                    _buildInputField('Max File Upload Limit (MB)', _uploadController, TextInputType.number),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    isPrimary: false,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: _saving ? 'Saving...' : 'Save Changes',
                    onTap: _saving ? null : _saveConfigs,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, TextInputType type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: type,
            style: AppTextStyles.body.copyWith(fontSize: 14),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

