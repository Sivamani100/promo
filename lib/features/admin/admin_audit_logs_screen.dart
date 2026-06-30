import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_card.dart';

class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String _selectedCategory = 'all';
  String _query = '';
  bool _ascending = false;
  int? _expandedLogIndex;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('audit_logs')
          .select()
          .order('created_at', ascending: _ascending);

      setState(() {
        _logs = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ADMIN AUDIT LOGS] Error loading logs: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredLogs = _logs.where((l) {
      final action = (l['action'] ?? '').toString().toLowerCase();
      final targetType = (l['target_type'] ?? '').toString().toLowerCase();
      final actorId = (l['actor_id'] ?? '').toString().toLowerCase();
      final targetId = (l['target_id'] ?? '').toString().toLowerCase();
      final category = (l['action_category'] ?? '').toString().toLowerCase();
      final meta = (l['metadata'] ?? '').toString().toLowerCase();

      final matchesQuery = action.contains(_query) || 
          targetType.contains(_query) || 
          actorId.contains(_query) || 
          targetId.contains(_query) || 
          meta.contains(_query);

      final matchesCategory = _selectedCategory == 'all' || category == _selectedCategory;

      return matchesQuery && matchesCategory;
    }).toList();

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
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_left),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'System Audit Logs',
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
                icon: Icon(_ascending ? Iconsax.sort : Iconsax.sort, size: 20),
                onPressed: () {
                  setState(() {
                    _ascending = !_ascending;
                  });
                  _loadLogs();
                },
              ),
              IconButton(
                icon: const Icon(Iconsax.refresh, size: 20),
                onPressed: _loadLogs,
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by action, UUID, metadata details...',
                      prefixIcon: const Icon(Iconsax.search_normal),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['all', 'auth', 'push', 'admin', 'moderation', 'data', 'payment', 'trust'].map((category) {
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(category.toUpperCase()),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() {
                                _selectedCategory = category;
                                _expandedLogIndex = null;
                              });
                            },
                            selectedColor: AppColors.accent.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.accent,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.accent : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Logs List
                  Expanded(
                    child: filteredLogs.isEmpty
                        ? const AppEmptyState(icon: Iconsax.document_filter, title: 'No matching audit logs found')
                        : ListView.builder(
                            itemCount: filteredLogs.length,
                            itemBuilder: (context, idx) {
                              final log = filteredLogs[idx];
                              final action = (log['action'] as String? ?? 'event').toUpperCase().replaceAll('_', ' ');
                              final targetType = (log['target_type'] as String? ?? 'system').toUpperCase();
                              final category = (log['action_category'] as String? ?? 'general').toUpperCase();
                              final actorRole = (log['actor_role'] as String? ?? 'system').toUpperCase();
                              final actorId = log['actor_id'];
                              final targetId = log['target_id'];
                              final beforeState = log['before_state'];
                              final afterState = log['after_state'];
                              final metadata = log['metadata'];

                              final createdAt = log['created_at'] != null 
                                  ? DateFormat('MMM d, yyyy h:mm:ss a').format(DateTime.parse(log['created_at'])) 
                                  : 'Unknown';

                              final isExpanded = _expandedLogIndex == idx;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  onTap: () {
                                    setState(() {
                                      _expandedLogIndex = isExpanded ? null : idx;
                                    });
                                  },
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              action,
                                              style: AppTextStyles.label.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.purple,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              category,
                                              style: AppTextStyles.overline.copyWith(
                                                color: AppColors.accent,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Actor: $actorRole',
                                            style: AppTextStyles.captionSm.copyWith(color: AppColors.textSecondary),
                                          ),
                                          Text(
                                            'Target: $targetType',
                                            style: AppTextStyles.captionSm.copyWith(color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            createdAt,
                                            style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted, fontSize: 10),
                                          ),
                                          Icon(
                                            isExpanded ? Iconsax.arrow_up_1 : Iconsax.arrow_down_2,
                                            size: 14,
                                            color: AppColors.textMuted,
                                          ),
                                        ],
                                      ),
                                      if (isExpanded) ...[
                                        const Divider(height: 20),
                                        _buildExpandedDetails('Actor UUID', actorId),
                                        _buildExpandedDetails('Target UUID', targetId),
                                        if (metadata != null)
                                          _buildJsonSection('Metadata Context', metadata),
                                        if (beforeState != null)
                                          _buildJsonSection('Before State', beforeState),
                                        if (afterState != null)
                                          _buildJsonSection('After State', afterState),
                                      ],
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn(delay: (idx * 30).ms).slideY(begin: 0.1, end: 0);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildExpandedDetails(String label, dynamic val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: SelectableText(
              val?.toString() ?? 'None',
              style: AppTextStyles.caption.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonSection(String title, dynamic jsonVal) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF16161A) 
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
            ),
            child: SelectableText(
              jsonVal.toString(),
              style: AppTextStyles.caption.copyWith(fontFamily: 'monospace', fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
