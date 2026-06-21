import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  Widget _statusBadge(String status) {
    final color = status == 'accepted' ? AppColors.success : status == 'shortlisted' ? AppColors.info : status == 'rejected' ? AppColors.error : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(100)),
      child: Text(status, style: AppTextStyles.captionSm.copyWith(color: color, fontWeight: FontWeight.w700)),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(c['title'] ?? 'Card'),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMarginHorizontal,
          AppSpacing.pageMarginVertical,
          AppSpacing.pageMarginHorizontal,
          AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
        ),
        children: [
          if (c['cover_image_url'] != null)
            ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 16 / 9, child: Image.network(c['cover_image_url'], fit: BoxFit.cover))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppColors.getCategoryColor(c['category'] ?? ''), borderRadius: BorderRadius.circular(100)),
              child: Text(c['category'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: c['status'] == 'active' ? AppColors.success.withOpacity(0.2) : AppColors.surface2, borderRadius: BorderRadius.circular(100)),
              child: Text(c['status'] ?? '', style: AppTextStyles.captionSm.copyWith(color: c['status'] == 'active' ? AppColors.success : AppColors.textMuted)),
            ),
          ]),
          const SizedBox(height: 16),
          Text(c['title'] ?? '', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          Text(c['description'] ?? '', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: 20),
          _infoRow('Budget', c['budget_range'] ?? 'Not set'),
          _infoRow('Timeline', c['timeline'] ?? 'Not set'),
          if (deliverables.isNotEmpty) _infoRow('Deliverables', deliverables.join(', ')),
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(color: AppColors.border),
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
                    Text(
                      app['pitch_message'] ?? '',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (app['proposed_rate'] != null) ...[
                      const SizedBox(height: 8),
                      Text('Rate: ${app['proposed_rate']}', style: AppTextStyles.labelSm.copyWith(color: AppColors.warning)),
                    ],
                    if (app['status'] == 'pending') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: AppButton(label: 'Accept', onTap: () => _updateStatus(app['id'], 'accepted'))),
                          const SizedBox(width: 8),
                          Expanded(child: AppButton(label: 'Shortlist', isPrimary: false, onTap: () => _updateStatus(app['id'], 'shortlisted'))),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Iconsax.close_circle, color: AppColors.error),
                            onPressed: () => _updateStatus(app['id'], 'rejected'),
                          ),
                        ],
                      ),
                    ],
                    if (app['status'] == 'accepted') ...[
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

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: AppTextStyles.caption),
      Text(value, style: AppTextStyles.label),
    ]),
  );
}