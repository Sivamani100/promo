import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_card.dart';

class AdminCampaignsScreen extends StatefulWidget {
  const AdminCampaignsScreen({super.key});

  @override
  State<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends State<AdminCampaignsScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _campaigns = [];
  bool _loading = true;
  String _selectedStatus = 'all';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
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

  Future<void> _loadCampaigns() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('cards')
          .select('*, brand:profiles!cards_brand_id_fkey(*)')
          .order('created_at', ascending: false);

      setState(() {
        _campaigns = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ADMIN CAMPAIGNS] Error loading cards: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _updateCampaignField(String cardId, Map<String, dynamic> updates, String actionType) async {
    try {
      final sb = SupabaseService.client;
      await sb.from('cards').update(updates).eq('id', cardId);

      // Log moderation action to audit_logs
      final currentUser = sb.auth.currentUser;
      if (currentUser != null) {
        await sb.from('audit_logs').insert({
          'actor_id': currentUser.id,
          'actor_role': 'admin',
          'action': 'campaign.$actionType',
          'target_type': 'campaign',
          'target_id': cardId,
          'metadata': {
            'updates': updates,
            'campaign_id': cardId,
          },
        });
      }

      _loadCampaigns();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign successfully moderated: ${actionType.toUpperCase()}')),
        );
      }
    } catch (e) {
      debugPrint('[ADMIN CAMPAIGNS] Error updating card: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update campaign: $e')),
        );
      }
    }
  }

  void _showModerationOptions(Map<String, dynamic> campaign) {
    final cardId = campaign['id'] as String;
    final title = campaign['title'] ?? 'No Title';
    final currentStatus = campaign['status'] as String? ?? 'active';
    final deletedAt = campaign['deleted_at'];
    final isDeleted = deletedAt != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
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
                'Campaign Moderation',
                style: AppTextStyles.overline,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              // Campaign Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).brightness == Brightness.dark 
                      ? const Color(0xFF16161A) 
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    _buildModalInfoRow('Budget', campaign['budget_range'] ?? 'Open Budget'),
                    _buildModalInfoRow('Category', campaign['category'] ?? 'General'),
                    _buildModalInfoRow('Location', campaign['preferred_location'] ?? 'Worldwide'),
                    _buildModalInfoRow('Status', currentStatus.toUpperCase()),
                    _buildModalInfoRow('Visibility', isDeleted ? 'SOFT DELETED' : 'VISIBLE'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('MODERATOR ACTIONS', style: AppTextStyles.overline),
              const SizedBox(height: 12),

              // Suspend/Reactivate Action
              ListTile(
                leading: Icon(
                  currentStatus == 'suspended' ? Iconsax.tick_circle : Iconsax.forbidden,
                  color: currentStatus == 'suspended' ? Colors.green : Colors.orange,
                ),
                title: Text(currentStatus == 'suspended' ? 'Reactivate Campaign' : 'Suspend Campaign'),
                subtitle: Text(
                  currentStatus == 'suspended' 
                      ? 'Mark campaign as active and visible in searches' 
                      : 'Remove campaign from search feeds and place under review',
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  final nextStatus = currentStatus == 'suspended' ? 'active' : 'suspended';
                  _updateCampaignField(cardId, {'status': nextStatus}, nextStatus == 'active' ? 'reactivate' : 'suspend');
                },
              ),
              const Divider(),

              // Soft Delete Action
              ListTile(
                leading: Icon(
                  isDeleted ? Iconsax.eye : Iconsax.trash,
                  color: isDeleted ? Colors.blue : Colors.red,
                ),
                title: Text(isDeleted ? 'Restore Campaign' : 'Soft Delete Campaign'),
                subtitle: Text(
                  isDeleted 
                      ? 'Make campaign visible on platform listings' 
                      : 'Flag campaign as deleted (hides it immediately)',
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _updateCampaignField(
                    cardId, 
                    {'deleted_at': isDeleted ? null : DateTime.now().toIso8601String()}, 
                    isDeleted ? 'restore' : 'delete',
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalInfoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          Text(val, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredCampaigns = _campaigns.where((c) {
      final title = (c['title'] ?? '').toString().toLowerCase();
      final desc = (c['description'] ?? '').toString().toLowerCase();
      final cat = (c['category'] ?? '').toString().toLowerCase();
      final brandName = (c['brand']?['display_name'] ?? '').toString().toLowerCase();
      final status = (c['status'] ?? 'active').toString().toLowerCase();
      final isDeleted = c['deleted_at'] != null;

      final matchesQuery = title.contains(_query) || desc.contains(_query) || cat.contains(_query) || brandName.contains(_query);
      
      bool matchesStatus = true;
      if (_selectedStatus == 'active') {
        matchesStatus = status == 'active' && !isDeleted;
      } else if (_selectedStatus == 'suspended') {
        matchesStatus = status == 'suspended';
      } else if (_selectedStatus == 'deleted') {
        matchesStatus = isDeleted;
      }

      return matchesQuery && matchesStatus;
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
              'Campaign Moderation',
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
                icon: const Icon(Iconsax.refresh, size: 20),
                onPressed: _loadCampaigns,
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
                  // Search Bar
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by title, category, brand name...',
                      prefixIcon: const Icon(Iconsax.search_normal),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['all', 'active', 'suspended', 'deleted'].map((status) {
                        final isSelected = _selectedStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(status.toUpperCase()),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() => _selectedStatus = status);
                            },
                            selectedColor: AppColors.purple.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.purple,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.purple : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gigs list
                  Expanded(
                    child: filteredCampaigns.isEmpty
                        ? const AppEmptyState(icon: Iconsax.note_2, title: 'No campaigns found')
                        : ListView.builder(
                            itemCount: filteredCampaigns.length,
                            itemBuilder: (context, idx) {
                              final campaign = filteredCampaigns[idx];
                              final title = campaign['title'] ?? 'No Title';
                              final category = campaign['category'] ?? 'General';
                              final budget = campaign['budget_range'] ?? 'Open Budget';
                              final brand = campaign['brand'];
                              final brandName = brand?['display_name'] ?? 'Unknown Brand';
                              final status = campaign['status'] as String? ?? 'active';
                              final isDeleted = campaign['deleted_at'] != null;

                              Color statusColor = Colors.green;
                              if (isDeleted) {
                                statusColor = Colors.red;
                              } else if (status == 'suspended') {
                                statusColor = Colors.orange;
                              }

                              String dispStatus = status.toUpperCase();
                              if (isDeleted) {
                                dispStatus = 'DELETED';
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  onTap: () => _showModerationOptions(campaign),
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.purple.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(Iconsax.note_2, color: AppColors.purple, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(brandName, style: AppTextStyles.captionSm.copyWith(color: AppColors.textSecondary)),
                                                const SizedBox(width: 8),
                                                Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey)),
                                                const SizedBox(width: 8),
                                                Text(category, style: AppTextStyles.captionSm.copyWith(color: AppColors.purple)),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Text(budget, style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted)),
                                                const SizedBox(width: 10),
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(dispStatus, style: AppTextStyles.captionSm.copyWith(color: statusColor, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Iconsax.setting_3, color: AppColors.textMuted, size: 20),
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn(delay: (idx * 50).ms).slideY(begin: 0.1, end: 0);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
