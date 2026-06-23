import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/card_service.dart';
import '../../core/services/application_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'brand_applications_screen.dart';

class BrandCardDetailScreen extends StatefulWidget {
  final String cardId;
  const BrandCardDetailScreen({super.key, required this.cardId});
  @override
  State<BrandCardDetailScreen> createState() => _BrandCardDetailScreenState();
}

class _BrandCardDetailScreenState extends State<BrandCardDetailScreen> {
  Map<String, dynamic>? _card;
  List<Map<String, dynamic>> _apps = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _navigateToGroupChat() async {
    final brandId = SupabaseService.client.auth.currentUser?.id;
    if (brandId == null) return;

    setState(() => _loading = true);
    try {
      // 1. Get or create the group room
      final room = await ChatService().createGroupRoom(brandId, widget.cardId);
      final roomId = room['id'] as String;

      // 2. Fetch existing group members to avoid duplicate invites
      final existingMembers = await ChatService().getGroupMembers(roomId);
      final existingUserIds = existingMembers.map((m) => m['user_id'] as String).toSet();

      // 3. Invite all applicants who are not already invited/joined
      final inviteUserIds = _apps
          .map((app) => (app['influencer'] as Map<String, dynamic>?)?['id'] as String?)
          .where((id) => id != null && !existingUserIds.contains(id))
          .cast<String>()
          .toList();

      for (final uid in inviteUserIds) {
        try {
          await ChatService().inviteUserToGroup(roomId, uid);
        } catch (e) {
          print('Error inviting $uid: $e');
        }
      }

      if (mounted) {
        // 4. Navigate to the chat room
        context.push('/brand/chats/$roomId');
      }
    } catch (e) {
      print('Error creating group chat for card: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open or create group chat')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _load() async {
    final data = await CardService().getCardById(widget.cardId);
    final appsData = await ApplicationService().getApplicationsForCard(widget.cardId);
    if (mounted) {
      setState(() {
        _card = data;
        _apps = appsData;
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    await ApplicationService().updateApplicationStatus(id, status);
    _load();
  }

  Future<void> _handleAccept(Map<String, dynamic> app) async {
    final c = _card;
    if (c == null) return;
    final totalOpenings = c['openings'] ?? 1;
    final acceptedCount = _apps.where((a) => a['status'] == 'accepted').length;

    if (acceptedCount >= totalOpenings) {
      final confirmed = await showPremiumConfirmDialog(
        context: context,
        title: 'Openings Limit Reached',
        message: 'All $totalOpenings openings have been filled. Would you like to increase the openings limit to ${totalOpenings + 1} and accept this applicant?',
        confirmLabel: 'Increase & Accept',
        cancelLabel: 'Cancel',
      );
      if (confirmed == true) {
        try {
          setState(() => _loading = true);
          await CardService().updateCard(widget.cardId, {'openings': totalOpenings + 1});
          await ApplicationService().updateApplicationStatus(app['id'], 'accepted');
          await _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Openings increased and application accepted successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update: $e')),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _loading = false);
          }
        }
      }
    } else {
      final confirmed = await showPremiumConfirmDialog(
        context: context,
        title: 'Accept Application',
        message: 'Are you sure you want to accept this application? This will create a milestone agreement.',
        confirmLabel: 'Accept',
      );
      if (confirmed == true) {
        await _updateStatus(app['id'], 'accepted');
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> app) async {
    final confirmed = await showPremiumConfirmDialog(
      context: context,
      title: 'Reject Application',
      message: 'Are you sure you want to reject this application? This action cannot be undone.',
      confirmLabel: 'Reject',
      isDestructive: true,
    );
    if (confirmed == true) {
      await _updateStatus(app['id'], 'rejected');
    }
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'accepted':
        color = const Color(0xFF10B981);
        break;
      case 'shortlisted':
        color = const Color(0xFF3B82F6);
        break;
      case 'rejected':
        color = const Color(0xFFEF4444);
        break;
      default:
        color = const Color(0xFFF59E0B); // pending
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(), body: const ShimmerCardDetail());
    if (_card == null) return Scaffold(appBar: AppBar(), body: const AppEmptyState(icon: Iconsax.info_circle, title: 'Card not found'));

    final c = _card!;
    final nicheTags = (c['niche_tags'] as List<dynamic>?)?.cast<String>() ?? [];
    final platforms = (c['platform_requirements'] as List<dynamic>?)?.cast<String>() ?? [];
    final deliverables = (c['deliverables'] as List<dynamic>?)?.cast<String>() ?? [];
    final isDark = AppColors.isDarkMode;

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
                Flexible(
                  child: Text(
                    c['title'] ?? 'Card Detail',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            actions: [
              TextButton.icon(
                onPressed: _navigateToGroupChat,
                icon: const Icon(Iconsax.message, size: 18),
                label: const Text('Group', style: TextStyle(fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    final result = await context.push('/brand/cards/new', extra: _card);
                    if (result == true) {
                      _load();
                    }
                  } else if (value == 'delete') {
                    final confirmed = await showPremiumConfirmDialog(
                      context: context,
                      title: 'Delete Campaign Card',
                      message: 'Are you sure you want to delete this campaign card? This action cannot be undone.',
                      confirmLabel: 'Delete',
                      isDestructive: true,
                      icon: Iconsax.trash,
                    );
                    if (confirmed == true && mounted) {
                      try {
                        await CardService().deleteCard(widget.cardId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Card deleted successfully')),
                          );
                          context.pop();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to delete card: $e')),
                          );
                        }
                      }
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMarginHorizontal,
          AppSpacing.pageMarginVertical,
          AppSpacing.pageMarginHorizontal,
          AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
        ),
        children: [
          if (c['cover_image_url'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: AppImage(
                  url: c['cover_image_url'],
                  fit: BoxFit.cover,
                  fallback: Container(
                    color: AppColors.surface2,
                    child: Center(
                      child: Icon(Iconsax.image, size: 48, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.getCategoryColor(c['category'] ?? '').withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.getCategoryColor(c['category'] ?? '').withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Text(
                (c['category'] ?? '').toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.getCategoryColor(c['category'] ?? ''),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (c['status'] == 'active' ? AppColors.success : AppColors.textMuted).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (c['status'] == 'active' ? AppColors.success : AppColors.textMuted).withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Text(
                (c['status'] ?? '').toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: c['status'] == 'active' ? AppColors.success : AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text(c['title'] ?? '', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          Text(c['description'] ?? '', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.6)),
          
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _buildBentoInfoTile(
                icon: Iconsax.wallet_3,
                label: 'Budget',
                value: c['budget_range'] ?? 'Open Budget',
                color: const Color(0xFF6366F1),
              ),
              _buildBentoInfoTile(
                icon: Iconsax.calendar,
                label: 'Timeline',
                value: c['timeline'] ?? 'Flexible',
                color: const Color(0xFF10B981),
              ),
              _buildBentoInfoTile(
                icon: Iconsax.profile_2user,
                label: 'Openings',
                value: '${_apps.where((a) => a['status'] == 'accepted').length} / ${c['openings'] ?? 1} filled',
                color: const Color(0xFFF59E0B),
              ),
              _buildBentoInfoTile(
                icon: Iconsax.global,
                label: 'Location',
                value: c['preferred_location'] ?? 'Anywhere',
                color: const Color(0xFFF43F5E),
              ),
            ],
          ),

          if (deliverables.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('DELIVERABLES', style: AppTextStyles.overline),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: deliverables.map((d) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.06),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.document_text, size: 12, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text(
                        d,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          if (nicheTags.isNotEmpty) ...[
            Text('NICHE TAGS', style: AppTextStyles.overline),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: nicheTags.map((t) => AppChip(label: '#$t')).toList()),
            const SizedBox(height: 16),
          ],
          if (platforms.isNotEmpty) ...[
            Text('PLATFORMS', style: AppTextStyles.overline),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: platforms.map((p) => AppChip(label: p)).toList()),
          ],
          
          const Divider(height: 40),
          Text('Applicants (${_apps.length})', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_apps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AppEmptyState(
                icon: Iconsax.receive_square,
                title: 'No applications yet',
                subtitle: 'Influencers will appear here once they apply to this card.',
              ),
            )
          else
            ..._apps.map((app) {
              final inf = app['influencer'] as Map<String, dynamic>?;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.02),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        app['pitch_message'] ?? 'No pitch message provided.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                          fontSize: 13,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (app['proposed_rate'] != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Iconsax.wallet_3, size: 14, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Text(
                            'Proposed Rate: ${app['proposed_rate']}',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (app['status'] == 'pending' || app['status'] == 'shortlisted') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Accept',
                              onTap: () => _handleAccept(app),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Iconsax.close_circle, color: AppColors.error),
                            onPressed: () => _handleReject(app),
                          ),
                        ],
                      ),
                    ],
                    if (app['status'] == 'accepted') ...[
                      const SizedBox(height: 12),
                      BrandMilestoneTrackerWidget(
                        influencerId: inf?['id'] ?? '',
                        cardId: app['card_id'] ?? '',
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildBentoInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = AppColors.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}