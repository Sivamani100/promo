import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/application_service.dart';
import '../../core/services/chat_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class InfluencerApplicationsScreen extends ConsumerStatefulWidget {
  final String? cardId;
  const InfluencerApplicationsScreen({super.key, this.cardId});
  @override
  ConsumerState<InfluencerApplicationsScreen> createState() => _InfluencerApplicationsScreenState();
}

class _InfluencerApplicationsScreenState extends ConsumerState<InfluencerApplicationsScreen> {
  List<Map<String, dynamic>> _apps = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    if (widget.cardId != null) {
      _filter = 'accepted';
    }
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final data = await ApplicationService().getApplicationsForInfluencer(user.id);
    if (mounted) setState(() { _apps = data; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered => _filter == 'all' ? _apps : _apps.where((a) => a['status'] == _filter).toList();

  int _getCountForFilter(String filterKey) {
    if (filterKey == 'all') return _apps.length;
    return _apps.where((a) => a['status'] == filterKey).length;
  }

  Widget _buildFilterChip(String filterKey) {
    final isSelected = _filter == filterKey;
    final count = _getCountForFilter(filterKey);
    final isDark = AppColors.isDarkMode;
    
    String label = filterKey[0].toUpperCase() + filterKey.substring(1);
    
    Color activeColor = AppColors.accent;
    Color activeTextColor = AppColors.accentOnDark;
    if (filterKey == 'pending' && isSelected) {
      activeColor = AppColors.warning;
      activeTextColor = Colors.black;
    } else if (filterKey == 'shortlisted' && isSelected) {
      activeColor = AppColors.info;
      activeTextColor = Colors.black;
    } else if (filterKey == 'accepted' && isSelected) {
      activeColor = AppColors.success;
      activeTextColor = Colors.black;
    } else if (filterKey == 'rejected' && isSelected) {
      activeColor = AppColors.error;
      activeTextColor = Colors.white;
    }

    return GestureDetector(
      onTap: () => setState(() => _filter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? activeColor 
              : (isDark ? const Color(0xFF0F0F11) : Colors.white),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected 
                ? Colors.transparent 
                : (isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB)),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected 
                    ? activeTextColor 
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? activeTextColor.withValues(alpha: 0.15) 
                    : (isDark ? const Color(0xFF1F1F24) : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? activeTextColor : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarIcon({
    required IconData icon,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 24, color: AppColors.textPrimary),
            if (badgeCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 10,
                    minHeight: 10,
                  ),
                ),
              ),
          ],
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

    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: AppColors.isDarkMode ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
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
                  'Applied',
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
              _buildAppBarIcon(
                icon: Iconsax.notification,
                badgeCount: unreadNotifications,
                onTap: () => context.push('/influencer/notifications'),
              ),
              const SizedBox(width: 8),
              _buildAppBarIcon(
                icon: Iconsax.setting_2,
                onTap: () => context.push('/influencer/settings'),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMarginHorizontal,
                AppSpacing.pageMarginVertical,
                AppSpacing.pageMarginHorizontal,
                AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
              ),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const _ShimmerBentoApplicationCard(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
                    child: Row(
                      children: ['all', 'pending', 'accepted', 'rejected']
                          .map((f) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildFilterChip(f),
                              ))
                          .toList(),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical,
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                      ),
                      itemCount: _filtered.isEmpty ? 2 : _filtered.length + 1,
                      separatorBuilder: (context, i) {
                        if (_filtered.isEmpty) return const SizedBox.shrink();
                        if (i == _filtered.length - 1) return const SizedBox.shrink();
                        return const SizedBox(height: 12);
                      },
                      itemBuilder: (context, i) {
                        if (_filtered.isEmpty) {
                          if (i == 0) {
                            return const AppEmptyState(
                              icon: Icons.assignment_rounded,
                              title: 'No applications',
                              subtitle: 'Your submitted applications will appear here',
                            );
                          } else {
                            return _buildFooter();
                          }
                        }
                        if (i == _filtered.length) {
                          return _buildFooter();
                        }
                        final app = _filtered[i];
                        final card = app['card'] as Map<String, dynamic>?;
                        final brand = card?['brand'] as Map<String, dynamic>?;
                        final status = app['status'] ?? 'pending';
                        final isHighlighted = widget.cardId != null && card?['id'] == widget.cardId;

                        return _BentoApplicationCard(
                          app: app,
                          isHighlighted: isHighlighted,
                          animationDelayIndex: i,
                          milestoneTracker: status == 'accepted'
                              ? _MilestoneTrackerWidget(
                                  brandId: brand?['id'] ?? '',
                                  cardId: card?['id'] ?? '',
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 56, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Every application',
            style: GoogleFonts.inter(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1.2,
              color: AppColors.isDarkMode 
                  ? const Color(0xFF3F3F46) 
                  : const Color(0xFFD4D4D8),
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'counts.',
            style: GoogleFonts.inter(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1.2,
              color: AppColors.isDarkMode 
                  ? const Color(0xFF3F3F46) 
                  : const Color(0xFFD4D4D8),
              letterSpacing: -0.5,
            ),
          ),
        ],
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
      if (mounted) AppSnackbar.show(context, 'Failed to update milestone');
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                    borderRadius: BorderRadius.circular(12),
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
        if (mounted) AppSnackbar.show(context, 'Failed to add: $e');
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

    final isDark = AppColors.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0E) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
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
              backgroundColor: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
              minHeight: 6,
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
                  GestureDetector(
                    onTap: _addMilestone,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 12, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            'Add',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _toggleMilestone(m),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done ? AppColors.success : Colors.transparent,
                              border: Border.all(
                                color: done ? Colors.transparent : (isDark ? const Color(0xFF333336) : const Color(0xFFD1D5DB)),
                                width: 1.5,
                              ),
                            ),
                            child: done 
                                ? const Icon(Icons.check, size: 13, color: Colors.black) 
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  decoration: done ? TextDecoration.lineThrough : null,
                                  color: done ? AppColors.textMuted : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Iconsax.calendar, size: 10, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Due: ${_formatDate(m['due_date'])}',
                                    style: AppTextStyles.captionSm.copyWith(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (ext != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 32.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: ext.status == 'pending'
                                ? AppColors.warning.withValues(alpha: 0.08)
                                : ext.status == 'approved'
                                    ? AppColors.success.withValues(alpha: 0.08)
                                    : AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ext.status == 'pending'
                                  ? AppColors.warning.withValues(alpha: 0.15)
                                  : ext.status == 'approved'
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : AppColors.error.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            ext.status == 'pending'
                                ? '⏳ Extension Requested: ${_formatDate(ext.newDueDate.toIso8601String())}'
                                : ext.status == 'approved'
                                    ? '✅ Extension Approved: ${_formatDate(ext.newDueDate.toIso8601String())}'
                                    : '❌ Extension Rejected',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
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
              child: GestureDetector(
                onTap: _addMilestone,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 12, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Add Deliverable',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }
}

// ---------- _BentoApplicationCard ----------
class _BentoApplicationCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final bool isHighlighted;
  final Widget? milestoneTracker;
  final int animationDelayIndex;

  const _BentoApplicationCard({
    required this.app,
    required this.isHighlighted,
    this.milestoneTracker,
    this.animationDelayIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final card = app['card'] as Map<String, dynamic>?;
    final brand = card?['brand'] as Map<String, dynamic>?;
    final status = app['status'] ?? 'pending';
    final category = card?['category'] as String? ?? '';
    final categoryColor = AppColors.getCategoryColor(category);
    final isDark = AppColors.isDarkMode;
    
    // Status colors and icons
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'accepted':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'shortlisted':
        statusColor = AppColors.info;
        statusIcon = Icons.star_rounded;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'pending':
      default:
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted 
            ? (isDark ? const Color(0xFF2A1E05) : const Color(0xFFFFFDF5))
            : (isDark ? const Color(0xFF0F0F11) : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isHighlighted 
              ? AppColors.warning 
              : (isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB)),
          width: isHighlighted ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted 
                ? AppColors.warning.withValues(alpha: 0.12)
                : (isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.02)),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Brand Avatar, Name, Category and Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (brand != null) ...[
                    AppAvatar(
                      url: brand['avatar_url'],
                      fallbackText: brand['display_name'] ?? 'B',
                      size: 32,
                      onTap: () {
                        final bId = brand['id'];
                        if (bId != null) {
                          context.push('/influencer/brands/$bId');
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  final bId = brand['id'];
                                  if (bId != null) {
                                    context.push('/influencer/brands/$bId');
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        brand['display_name'] ?? 'Brand',
                                        style: AppTextStyles.labelSm.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (brand['is_verified'] == true) ...[
                                      const SizedBox(width: 3),
                                      const VerificationBadge(size: 11),
                                    ],
                                  ],
                                ),
                              ),
                              if (category.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: categoryColor.withValues(alpha: 0.15),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    category.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w900,
                                      color: categoryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            brand['industry'] ?? 'Industry',
                            style: AppTextStyles.captionSm.copyWith(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (app['pitch_message'] != null && (app['pitch_message'] as String).isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: isDark ? const Color(0xFF0F0F11) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                                width: 1.2,
                              ),
                            ),
                            title: Row(
                              children: [
                                Icon(Iconsax.message_text5, color: AppColors.accent, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Your Pitch',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            content: SingleChildScrollView(
                              child: Text(
                                app['pitch_message'],
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Iconsax.message_text,
                          size: 14,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: GoogleFonts.inter(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              
              // Campaign section (horizontal layout with cover image and title)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: isValidImageUrl(card?['cover_image_url'])
                          ? CachedNetworkImage(
                              imageUrl: card?['cover_image_url'] ?? '',
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Icon(Iconsax.image, size: 20, color: AppColors.textMuted),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card?['title'] ?? 'Campaign',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (app['proposed_rate'] != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Iconsax.empty_wallet, size: 13, color: AppColors.warning),
                              const SizedBox(width: 4),
                              Text(
                                'Proposed Rate: ₹${app['proposed_rate']}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              

              
              // Brand note
              if (app['brand_note'] != null && (app['brand_note'] as String).isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16120E) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C1F0E) : const Color(0xFFFDE68A),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Iconsax.note_2, size: 12, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Text(
                            'BRAND NOTE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warning,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        app['brand_note'],
                        style: AppTextStyles.captionSm.copyWith(
                          fontSize: 11,
                          color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Milestone tracker
              if (milestoneTracker != null) ...[
                milestoneTracker!,
              ],
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 400),
          delay: Duration(milliseconds: 30 * animationDelayIndex),
        )
        .slideY(
          begin: 0.1,
          end: 0.0,
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 400),
          delay: Duration(milliseconds: 30 * animationDelayIndex),
        );
  }
}

// ---------- _ShimmerBentoApplicationCard ----------
class _ShimmerBentoApplicationCard extends StatelessWidget {
  const _ShimmerBentoApplicationCard();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final shimmerBg = isDark ? const Color(0xFF0F0F11) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB);

    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: shimmerBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderCol, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerBox(width: 32, height: 32, borderRadius: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(width: 80, height: 12),
                      const SizedBox(height: 4),
                      const ShimmerBox(width: 40, height: 10),
                    ],
                  ),
                ),
                const ShimmerBox(width: 60, height: 20, borderRadius: 10),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const ShimmerBox(width: 64, height: 64, borderRadius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(width: double.infinity, height: 14),
                      const SizedBox(height: 6),
                      const ShimmerBox(width: 120, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const ShimmerBox(width: double.infinity, height: 12),
            const SizedBox(height: 6),
            const ShimmerBox(width: 180, height: 12),
          ],
        ),
      ),
    );
  }
}