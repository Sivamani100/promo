import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/application_service.dart';
import '../../core/services/chat_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class BrandApplicationsScreen extends ConsumerStatefulWidget {
  const BrandApplicationsScreen({super.key});
  @override
  ConsumerState<BrandApplicationsScreen> createState() => _BrandApplicationsScreenState();
}

class _BrandApplicationsScreenState extends ConsumerState<BrandApplicationsScreen> {
  List<Map<String, dynamic>> _apps = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final data = await ApplicationService().getApplicationsForBrand(user.id);
    if (mounted) setState(() { _apps = data; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered => _filter == 'all' ? _apps : _apps.where((a) => a['status'] == _filter).toList();

  Future<void> _updateStatus(String id, String status) async {
    await ApplicationService().updateApplicationStatus(id, status);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && _loading) {
        _load();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
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
                    child: Row(children: ['all', 'pending', 'shortlisted', 'accepted', 'rejected'].map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppChip(label: f[0].toUpperCase() + f.substring(1), selected: _filter == f, onTap: () => setState(() => _filter = f)),
                    )).toList()),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? const AppEmptyState(icon: Iconsax.receive_square, title: 'No applications')
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
                              final inf = app['influencer'] as Map<String, dynamic>?;
                              return Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusXl), border: Border.all(color: AppColors.border)),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          final infId = inf?['id'];
                                          if (infId != null) {
                                            context.push('/brand/influencers/$infId');
                                          }
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: Row(
                                          children: [
                                            AppAvatar(
                                              url: inf?['avatar_url'],
                                              fallbackText: inf?['display_name'] ?? 'I',
                                              size: 40,
                                              onTap: () {
                                                final infId = inf?['id'];
                                                if (infId != null) {
                                                  context.push('/brand/influencers/$infId');
                                                }
                                              },
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(inf?['display_name'] ?? 'Influencer', style: AppTextStyles.label),
                                                  Text((inf?['niche'] as List?)?.take(2).join(' · ') ?? '', style: AppTextStyles.captionSm),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    _statusBadge(app['status'] ?? 'pending'),
                                  ]),
                                  const SizedBox(height: 12),
                                   Text(app['pitch_message'] ?? '', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
                                   if (app['proposed_rate'] != null) ...[
                                     const SizedBox(height: 8),
                                     Text('Proposed Rate: ${app['proposed_rate']}', style: AppTextStyles.labelSm.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold)),
                                   ],
                                   if (app['portfolio_links'] != null && (app['portfolio_links'] as List).isNotEmpty) ...[
                                     const SizedBox(height: 12),
                                     Text('PORTFOLIO ATTACHMENTS', style: AppTextStyles.overline),
                                     const SizedBox(height: 6),
                                     Wrap(
                                       spacing: 8,
                                       runSpacing: 8,
                                       children: (app['portfolio_links'] as List).map((link) {
                                         return InkWell(
                                           onTap: () async {
                                             final uri = Uri.parse(link.toString().startsWith('http') ? link.toString() : 'https://${link.toString()}');
                                             try {
                                               await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
                                             } catch (e) {
                                               print('Error launching portfolio url: $e');
                                             }
                                           },
                                           child: Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                             decoration: BoxDecoration(
                                               color: AppColors.accent.withOpacity(0.06),
                                               border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                                               borderRadius: BorderRadius.circular(8),
                                             ),
                                             child: Row(
                                               mainAxisSize: MainAxisSize.min,
                                               children: [
                                                 Icon(Iconsax.link, size: 12, color: AppColors.accent),
                                                 const SizedBox(width: 6),
                                                 Text(
                                                   link.toString().length > 25 ? '${link.toString().substring(0, 22)}...' : link.toString(),
                                                   style: TextStyle(
                                                     fontSize: 11,
                                                     fontWeight: FontWeight.bold,
                                                     color: AppColors.accent,
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ),
                                         );
                                       }).toList(),
                                     ),
                                   ],
                                   if (app['status'] == 'pending') ...[
                                    const SizedBox(height: 12),
                                    Row(children: [
                                      Expanded(
                                        child: AppButton(
                                          label: 'Accept',
                                          onTap: () async {
                                            final confirmed = await showPremiumConfirmDialog(
                                              context: context,
                                              title: 'Accept Application',
                                              message: 'Are you sure you want to accept this application? This will create a milestone agreement.',
                                              confirmLabel: 'Accept',
                                            );
                                            if (confirmed == true) {
                                              _updateStatus(app['id'], 'accepted');
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: AppButton(
                                          label: 'Shortlist',
                                          isPrimary: false,
                                          onTap: () async {
                                            final confirmed = await showPremiumConfirmDialog(
                                              context: context,
                                              title: 'Shortlist Application',
                                              message: 'Are you sure you want to shortlist this application?',
                                              confirmLabel: 'Shortlist',
                                            );
                                            if (confirmed == true) {
                                              _updateStatus(app['id'], 'shortlisted');
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(Iconsax.close_circle, color: AppColors.error),
                                        onPressed: () async {
                                          final confirmed = await showPremiumConfirmDialog(
                                            context: context,
                                            title: 'Reject Application',
                                            message: 'Are you sure you want to reject this application? This action cannot be undone.',
                                            confirmLabel: 'Reject',
                                            isDestructive: true,
                                          );
                                          if (confirmed == true) {
                                            _updateStatus(app['id'], 'rejected');
                                          }
                                        },
                                      ),
                                    ]),
                                  ],
                                  if (app['status'] == 'accepted') ...[
                                    BrandMilestoneTrackerWidget(
                                      influencerId: inf?['id'] ?? '',
                                      cardId: app['card_id'] ?? '',
                                    ),
                                  ],
                                ]),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
  Widget _statusBadge(String status) {
    final color = status == 'accepted' ? AppColors.success : status == 'shortlisted' ? AppColors.info : status == 'rejected' ? AppColors.error : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(100)),
      child: Text(status, style: AppTextStyles.captionSm.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class BrandMilestoneTrackerWidget extends ConsumerStatefulWidget {
  final String influencerId;
  final String cardId;

  const BrandMilestoneTrackerWidget({required this.influencerId, required this.cardId});

  @override
  ConsumerState<BrandMilestoneTrackerWidget> createState() => _BrandMilestoneTrackerWidgetState();
}

class _BrandMilestoneTrackerWidgetState extends ConsumerState<BrandMilestoneTrackerWidget> {
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
        brandId: user.id,
        influencerId: widget.influencerId,
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
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
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
                  Navigator.pop(context, {
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

  Future<void> _handleExtensionApproval(Map<String, dynamic> m, MilestoneExtension ext, bool approve) async {
    final displayTitle = MilestoneHelper.getDisplayTitle(m['title']);
    final newStatus = approve ? 'approved' : 'rejected';
    final updatedExt = MilestoneExtension(
      newDueDate: ext.newDueDate,
      status: newStatus,
      reason: ext.reason,
    );
    final newRawTitle = MilestoneHelper.buildRawTitle(displayTitle, updatedExt);

    setState(() => _loading = true);
    try {
      if (approve) {
        await _chatService.updateMilestoneTitle(m['id'] as String, newRawTitle);
        await _chatService.updateMilestoneDueDate(m['id'] as String, ext.newDueDate.toIso8601String());
      } else {
        await _chatService.updateMilestoneTitle(m['id'] as String, newRawTitle);
      }
      await _loadMilestones();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Extension request approved!' : 'Extension request rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update extension: $e')),
        );
      }
      setState(() => _loading = false);
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
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 28.0),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: ext.status == 'pending'
                                ? AppColors.warning.withValues(alpha: 0.1)
                                : ext.status == 'approved'
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: ext.status == 'pending'
                                  ? AppColors.warning.withValues(alpha: 0.2)
                                  : ext.status == 'approved'
                                      ? AppColors.success.withValues(alpha: 0.2)
                                      : AppColors.error.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      ext.status == 'pending'
                                          ? '⏳ Extension Requested to: ${_formatDate(ext.newDueDate.toIso8601String())}'
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
                                  if (ext.status == 'pending') ...[
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _handleExtensionApproval(m, ext, true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.success,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('Approve', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () => _handleExtensionApproval(m, ext, false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.error,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('Reject', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Reason: "${ext.reason}"',
                                style: AppTextStyles.captionSm.copyWith(fontSize: 9, fontStyle: FontStyle.italic),
                              ),
                            ],
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