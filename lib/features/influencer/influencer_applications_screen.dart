import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/application_service.dart';
import '../../core/services/chat_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class InfluencerApplicationsScreen extends ConsumerStatefulWidget {
  const InfluencerApplicationsScreen({super.key});
  @override
  ConsumerState<InfluencerApplicationsScreen> createState() => _InfluencerApplicationsScreenState();
}

class _InfluencerApplicationsScreenState extends ConsumerState<InfluencerApplicationsScreen> {
  List<Map<String, dynamic>> _apps = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final data = await ApplicationService().getApplicationsForInfluencer(user.id);
    if (mounted) setState(() { _apps = data; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered => _filter == 'all' ? _apps : _apps.where((a) => a['status'] == _filter).toList();

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted': return AppColors.success;
      case 'shortlisted': return AppColors.info;
      case 'rejected': return AppColors.error;
      case 'pending': return AppColors.warning;
      default: return AppColors.textMuted;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted': return Icons.check_circle_rounded;
      case 'shortlisted': return Icons.star_rounded;
      case 'rejected': return Icons.cancel_rounded;
      case 'pending': return Icons.schedule_rounded;
      default: return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && _loading) {
        _load();
      }
    });

    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56 + AppSpacing.pageMarginVertical),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.appBarMarginHorizontal,
            right: AppSpacing.appBarMarginHorizontal,
            top: AppSpacing.pageMarginVertical,
          ),
          child: AppBar(
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_left),
              onPressed: () => context.go('/influencer/home'),
            ),
            centerTitle: false,
            titleSpacing: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Applied',
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
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.notification, size: 20),
                    onPressed: () => context.push('/influencer/notifications'),
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Iconsax.setting_2, size: 20),
                onPressed: () => context.push('/influencer/settings'),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, __) => const ShimmerApplicationCard(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: ['all', 'pending', 'shortlisted', 'accepted', 'rejected'].map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AppChip(
                          label: f[0].toUpperCase() + f.substring(1),
                          selected: _filter == f,
                          onTap: () => setState(() => _filter = f),
                        ),
                      )).toList(),
                    ),
                  ),
                  // Stats row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Row(
                      children: [
                        _miniStat('Total', '${_apps.length}', AppColors.textPrimary),
                        const SizedBox(width: 8),
                        _miniStat('Pending', '${_apps.where((a) => a['status'] == 'pending').length}', AppColors.warning),
                        const SizedBox(width: 8),
                        _miniStat('Accepted', '${_apps.where((a) => a['status'] == 'accepted').length}', AppColors.success),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _filtered.isEmpty
                        ? const AppEmptyState(icon: Icons.assignment_rounded, title: 'No applications', subtitle: 'Your submitted applications will appear here')
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.pageMarginHorizontal,
                              AppSpacing.pageMarginVertical,
                              AppSpacing.pageMarginHorizontal,
                              AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                            ),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final app = _filtered[i];
                              final card = app['card'] as Map<String, dynamic>?;
                              final brand = card?['brand'] as Map<String, dynamic>?;
                              final status = app['status'] ?? 'pending';

                              return Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Brand + status row
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              final bId = brand?['id'];
                                              if (bId != null) {
                                                context.push('/influencer/brands/$bId');
                                              }
                                            },
                                            behavior: HitTestBehavior.opaque,
                                            child: Row(
                                              children: [
                                                AppAvatar(
                                                  url: brand?['avatar_url'],
                                                  fallbackText: brand?['display_name'] ?? 'B',
                                                  size: 36,
                                                  onTap: () {
                                                    final bId = brand?['id'];
                                                    if (bId != null) {
                                                      context.push('/influencer/brands/$bId');
                                                    }
                                                  },
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(brand?['display_name'] ?? 'Brand', style: AppTextStyles.labelSm),
                                                      Text(card?['category'] ?? '', style: AppTextStyles.captionSm),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(_statusIcon(status), size: 12, color: _statusColor(status)),
                                              const SizedBox(width: 4),
                                              Text(status[0].toUpperCase() + status.substring(1), style: AppTextStyles.captionSm.copyWith(color: _statusColor(status), fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Card title
                                    Text(card?['title'] ?? 'Campaign', style: AppTextStyles.label.copyWith(fontSize: 15)),
                                    const SizedBox(height: 6),
                                    // Pitch preview
                                    Text(
                                      app['pitch_message'] ?? '',
                                      style: AppTextStyles.caption.copyWith(height: 1.5),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (app['proposed_rate'] != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.payments_rounded, size: 14, color: AppColors.textMuted),
                                          const SizedBox(width: 4),
                                          Text('Rate: ${app['proposed_rate']}', style: AppTextStyles.captionSm.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ],
                                    if (app['brand_note'] != null && app['brand_note'].isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(AppSpacing.md),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface2,
                                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('BRAND NOTE', style: AppTextStyles.overline),
                                            const SizedBox(height: 4),
                                            Text(app['brand_note'], style: AppTextStyles.captionSm),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (status == 'accepted') ...[
                                      _MilestoneTrackerWidget(
                                        brandId: brand?['id'] ?? '',
                                        cardId: card?['id'] ?? '',
                                      ),
                                    ],
                                  ],
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

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.h4.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.captionSm),
          ],
        ),
      ),
    );
  }
}

class _MilestoneTrackerWidget extends ConsumerStatefulWidget {
  final String brandId;
  final String cardId;

  const _MilestoneTrackerWidget({required this.brandId, required this.cardId});

  @override
  ConsumerState<_MilestoneTrackerWidget> createState() => _MilestoneTrackerWidgetState();
}

class _MilestoneTrackerWidgetState extends ConsumerState<_MilestoneTrackerWidget> {
  List<Map<String, dynamic>> _milestones = [];
  bool _loading = true;
  String? _roomId;
  final _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _loadMilestones();
  }

  Future<void> _loadMilestones() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final room = await _chatService.getOrCreate1to1Room(
        brandId: widget.brandId,
        influencerId: user.id,
        cardId: widget.cardId,
      );
      _roomId = room['id'];
      final data = await _chatService.getMilestones(_roomId!);
      if (mounted) {
        setState(() {
          _milestones = data;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading milestones: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleMilestone(Map<String, dynamic> m) async {
    final done = m['status'] == 'completed';
    final newStatus = done ? 'pending' : 'completed';
    
    setState(() {
      m['status'] = newStatus;
    });

    try {
      await _chatService.updateMilestoneStatus(m['id'] as String, newStatus);
    } catch (e) {
      setState(() {
        m['status'] = done ? 'completed' : 'pending';
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update milestone')));
    }
  }

  Future<void> _addMilestone() async {
    if (_roomId == null) return;
    final ctrl = TextEditingController();
    DateTime? selectedDate;

    final result = await showPremiumDialog<Map<String, dynamic>>(
      context: context,
      title: 'Add Deliverable',
      icon: Iconsax.calendar_add,
      content: StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: 'e.g. Draft Content for review',
                  labelText: 'Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
              Text('DUE DATE', style: AppTextStyles.overline),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: dialogCtx,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setDialogState(() {
                      selectedDate = date;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedDate == null
                            ? 'Select date...'
                            : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                        style: AppTextStyles.body.copyWith(
                          color: selectedDate == null ? AppColors.textMuted : AppColors.textPrimary,
                        ),
                      ),
                      const Icon(Icons.calendar_today_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actionsBuilder: (dialogCtx) => [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(dialogCtx),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: Text('Cancel', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final t = ctrl.text.trim();
                  if (t.isEmpty) return;
                  Navigator.pop(dialogCtx, {
                    'title': t,
                    'due_date': selectedDate?.toIso8601String(),
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentOnDark,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  elevation: 0,
                ),
                child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );

    if (result != null) {
      final title = result['title'] as String;
      final dueDate = result['due_date'] as String?;
      setState(() => _loading = true);
      try {
        await _chatService.createMilestone({
          'room_id': _roomId,
          'title': title,
          'status': 'pending',
          'due_date': dueDate,
        });
        await _loadMilestones();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
        setState(() => _loading = false);
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'No due date';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final completedCount = _milestones.where((m) => m['status'] == 'completed').length;
    final totalCount = _milestones.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Deliverables & Progress', style: AppTextStyles.overline),
              Text(
                '$completedCount / $totalCount complete',
                style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 12),
          if (_milestones.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('No deliverables set yet.', style: AppTextStyles.captionSm.copyWith(fontStyle: FontStyle.italic)),
                  TextButton.icon(
                    onPressed: _addMilestone,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            )
          else ...[
            ..._milestones.map((m) {
              final done = m['status'] == 'completed';
              final rawTitle = m['title'] as String? ?? '';
              final displayTitle = MilestoneHelper.getDisplayTitle(rawTitle);
              final ext = MilestoneHelper.getExtension(rawTitle);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleMilestone(m),
                          child: Icon(
                            done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 20,
                            color: done ? AppColors.success : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                style: AppTextStyles.bodySm.copyWith(
                                  decoration: done ? TextDecoration.lineThrough : null,
                                  color: done ? AppColors.textMuted : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Due: ${_formatDate(m['due_date'])}',
                                style: AppTextStyles.captionSm.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (ext != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 28.0),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: ext.status == 'pending'
                                ? AppColors.warning.withValues(alpha: 0.1)
                                : ext.status == 'approved'
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            ext.status == 'pending'
                                ? '⏳ Extension Requested: ${_formatDate(ext.newDueDate.toIso8601String())}'
                                : ext.status == 'approved'
                                    ? '✅ Extension Approved: ${_formatDate(ext.newDueDate.toIso8601String())}'
                                    : '❌ Extension Rejected',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: ext.status == 'pending'
                                  ? AppColors.warning
                                  : ext.status == 'approved'
                                      ? AppColors.success
                                      : AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addMilestone,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Deliverable', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 24)),
              ),
            )
          ]
        ],
      ),
    );
  }
}