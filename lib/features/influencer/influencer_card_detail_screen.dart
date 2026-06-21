import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/card_service.dart';
import '../../core/services/application_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class InfluencerCardDetailScreen extends ConsumerStatefulWidget {
  final String cardId;
  const InfluencerCardDetailScreen({super.key, required this.cardId});
  @override
  ConsumerState<InfluencerCardDetailScreen> createState() => _InfluencerCardDetailScreenState();
}

class _InfluencerCardDetailScreenState extends ConsumerState<InfluencerCardDetailScreen> {
  Map<String, dynamic>? _card;
  Map<String, dynamic>? _application;
  bool _loading = true;
  bool _applied = false;
  bool _applying = false;

  // Controllers
  final _pitchCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  
  // Portfolio links state
  final List<TextEditingController> _portfolioCtrls = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pitchCtrl.dispose();
    _rateCtrl.dispose();
    for (final ctrl in _portfolioCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final data = await CardService().getCardById(widget.cardId);
    final user = ref.read(authProvider).user;
    if (user != null) {
      final appData = await ApplicationService().getApplicationForCardAndInfluencer(widget.cardId, user.id);
      _application = appData;
      _applied = appData != null;
    }
    if (mounted) setState(() { _card = data; _loading = false; });
  }

  void _addPortfolioLinkField() {
    if (_portfolioCtrls.length < 3) {
      setState(() {
        _portfolioCtrls.add(TextEditingController());
      });
    }
  }

  void _removePortfolioLinkField(int index) {
    setState(() {
      _portfolioCtrls[index].dispose();
      _portfolioCtrls.removeAt(index);
    });
  }

  Future<void> _apply() async {
    if (_pitchCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a pitch message.')));
      return;
    }
    setState(() => _applying = true);
    try {
      final user = ref.read(authProvider).user!;
      
      // Gather active portfolio links
      final portfolioLinks = _portfolioCtrls
          .map((ctrl) => ctrl.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final appData = {
        'card_id': widget.cardId,
        'influencer_id': user.id,
        'pitch_message': _pitchCtrl.text.trim(),
        'proposed_rate': _rateCtrl.text.trim().isEmpty ? null : _rateCtrl.text.trim(),
        'portfolio_links': portfolioLinks.isEmpty ? null : portfolioLinks,
        'status': 'pending',
      };

      if (_application != null) {
        await ApplicationService().updateApplication(_application!['id'], appData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application updated successfully!')));
        }
      } else {
        await ApplicationService().createApplication(appData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted successfully!')));
        }
      }
      
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(title: const Text('Campaign Details')), body: const ShimmerCardDetail());
    if (_card == null) return Scaffold(appBar: AppBar(title: const Text('Campaign Details')), body: const AppEmptyState(icon: Icons.error_rounded, title: 'Campaign not found'));

    final c = _card!;
    final brand = c['brand'] as Map<String, dynamic>?;
    
    final category = c['category'] ?? 'Fashion';
    final nicheTags = (c['niche_tags'] as List?)?.cast<String>() ?? [];
    final platformReqs = (c['platform_requirements'] as List?)?.cast<String>() ?? [];
    final deliverables = (c['deliverables'] as List?)?.cast<String>() ?? [];
    
    // Qualification check
    final profile = ref.watch(authProvider).profile;
    final userFollowers = profile?['follower_count'] as int? ?? 0;
    final minReqFollowers = c['min_followers'] as int? ?? 0;
    final qualifies = userFollowers >= minReqFollowers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaign Details'),
        actions: [
          if (_applied) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) {
                if (val == 'edit') {
                  _showApplyBottomSheetForm();
                } else if (val == 'info') {
                  _showApplicationInfoDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Iconsax.info_circle, size: 18),
                      SizedBox(width: 8),
                      Text('View My Pitch'),
                    ],
                  ),
                ),
                if (_application?['status'] == 'pending')
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Iconsax.edit_2, size: 18),
                        SizedBox(width: 8),
                        Text('Edit My Pitch'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Cover Image
                if (c['cover_image_url'] != null && (c['cover_image_url'] as String).isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
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
                ],

                // Brand Card Header
                if (brand != null) ...[
                  GestureDetector(
                    onTap: () {
                      if (brand['id'] != null) {
                        context.push('/influencer/brands/${brand['id']}');
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(
                            url: brand['avatar_url'],
                            fallbackText: brand['display_name'] ?? 'B',
                            size: 44,
                            onTap: () {
                              if (brand['id'] != null) {
                                context.push('/influencer/brands/${brand['id']}');
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        brand['display_name'] ?? 'Brand Owner',
                                        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (brand['is_verified'] == true) ...[
                                      const SizedBox(width: 4),
                                      const VerificationBadge(size: 14),
                                    ]
                                  ],
                                ),
                                Text(brand['industry'] ?? 'Industry', style: AppTextStyles.captionSm),
                              ],
                            ),
                          ),
                          Icon(Iconsax.arrow_right_3, color: AppColors.textMuted, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.getCategoryColor(category),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(c['title'] ?? 'Untitled Campaign', style: AppTextStyles.h2),
                const SizedBox(height: 12),
                Text(
                  c['description'] ?? 'No description provided.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.6),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // Follower match status banner
                _buildFollowerMatchBanner(qualifies, minReqFollowers, userFollowers),
                const SizedBox(height: 24),

                Text('CAMPAIGN METRICS', style: AppTextStyles.overline),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  padding: EdgeInsets.zero,
                  children: [
                    _buildMetricGridCard(Iconsax.wallet_3, 'Compensation', c['budget_range'] ?? 'Open'),
                    _buildMetricGridCard(Iconsax.clock, 'Timeline', c['timeline'] ?? 'Flexible'),
                    _buildMetricGridCard(Iconsax.user_tick, 'Follower Target', minReqFollowers > 0 ? '${NumberFormat.compact().format(minReqFollowers)}+' : 'Any tier'),
                    _buildMetricGridCard(Iconsax.location, 'Preferred Location', c['preferred_location'] ?? 'Anywhere'),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withOpacity(0.08),
                        AppColors.accent.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.profile_2user, color: AppColors.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${c['openings'] ?? 1} positions available for this collaboration',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (c['application_deadline'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Iconsax.calendar_1, size: 16, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text(
                          'Application Deadline',
                          style: AppTextStyles.captionSm.copyWith(color: AppColors.error, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('MMMM dd, yyyy').format(DateTime.parse(c['application_deadline'])),
                          style: AppTextStyles.label.copyWith(color: AppColors.error, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                if (deliverables.isNotEmpty) ...[
                  Text('REQUIRED DELIVERABLES', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: deliverables.map((deliv) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: AppColors.accent, size: 18),
                              const SizedBox(width: 10),
                              Text(deliv, style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (platformReqs.isNotEmpty) ...[
                  Text('PLATFORMS REQUIRED', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: platformReqs.map((plat) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            plat.toLowerCase().contains('instagram')
                                ? Iconsax.instagram
                                : plat.toLowerCase().contains('youtube')
                                    ? Iconsax.video_play
                                    : Iconsax.global,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(plat, style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                if (nicheTags.isNotEmpty) ...[
                  Text('TAGS & NICHES', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: nicheTags.map((tag) => AppChip(label: '#$tag')).toList(),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
          _buildApplySection(),
        ],
      ),
    );
  }

  Widget _buildFollowerMatchBanner(bool qualifies, int minReq, int userFollowers) {
    if (minReq == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Open to all tiers! No minimum follower requirement.',
                style: AppTextStyles.captionSm.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final format = NumberFormat.compact();
    final reqLabel = format.format(minReq);
    final userLabel = format.format(userFollowers);

    if (qualifies) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You qualify! You have $userLabel followers ($reqLabel required).',
                style: AppTextStyles.captionSm.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Followers mismatch: Requires $reqLabel followers (you have $userLabel). You can still pitch, but priority is given to matching creators.',
                style: AppTextStyles.captionSm.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.bodySm.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricGridCard(IconData icon, String title, String value) {
    final isDark = AppColors.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: AppTextStyles.overline.copyWith(
                    fontSize: 8,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.bold,
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

  Widget _buildApplySection() {
    if (_applied) {
      final status = _application?['status'] ?? 'pending';

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: status == 'accepted' 
                ? AppColors.success.withOpacity(0.08) 
                : status == 'rejected'
                    ? AppColors.error.withOpacity(0.08)
                    : AppColors.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: status == 'accepted' 
                  ? AppColors.success.withOpacity(0.2) 
                  : status == 'rejected'
                      ? AppColors.error.withOpacity(0.2)
                      : AppColors.success.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                status == 'accepted' 
                    ? Icons.check_circle_rounded 
                    : status == 'rejected'
                        ? Icons.cancel_rounded
                        : Icons.check_circle_rounded, 
                color: status == 'accepted' 
                    ? AppColors.success 
                    : status == 'rejected'
                        ? AppColors.error
                        : AppColors.success,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status == 'accepted' 
                      ? 'Your application has been accepted!'
                      : status == 'rejected'
                          ? 'Your application was not selected.'
                          : 'You have applied to this campaign! (Status: ${status.toUpperCase()})',
                  style: AppTextStyles.label.copyWith(
                    color: status == 'accepted' 
                        ? AppColors.success 
                        : status == 'rejected'
                            ? AppColors.error
                            : AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: AppButton(
        label: 'Apply to Campaign',
        icon: Iconsax.send_2,
        onTap: _showApplyBottomSheetForm,
      ),
    );
  }

  void _showApplicationInfoDialog() {
    if (_application == null) return;
    
    final pitch = _application!['pitch_message'] ?? 'No pitch message.';
    final rate = _application!['proposed_rate'] ?? 'Not specified';
    final links = (_application!['portfolio_links'] as List?)?.cast<String>() ?? [];
    final status = _application!['status'] ?? 'pending';

    showPremiumDialog(
      context: context,
      title: 'My Application Details',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATUS', style: AppTextStyles.overline),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'accepted' 
                  ? AppColors.success.withOpacity(0.1) 
                  : status == 'rejected' 
                      ? AppColors.error.withOpacity(0.1) 
                      : AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: status == 'accepted' 
                    ? AppColors.success 
                    : status == 'rejected' 
                        ? AppColors.error 
                        : AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('PITCH MESSAGE', style: AppTextStyles.overline),
          const SizedBox(height: 6),
          Text(
            pitch,
            style: AppTextStyles.body.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          Text('PROPOSED RATE', style: AppTextStyles.overline),
          const SizedBox(height: 6),
          Text(
            rate,
            style: AppTextStyles.label,
          ),
          if (links.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('ATTACHED PORTFOLIO LINKS', style: AppTextStyles.overline),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: links.map((link) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  link,
                  style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.w600),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _showApplyBottomSheetForm() {
    if (_application != null) {
      _pitchCtrl.text = _application!['pitch_message'] ?? '';
      _rateCtrl.text = _application!['proposed_rate'] ?? '';
      
      // Clean up old controllers first
      for (final ctrl in _portfolioCtrls) {
        ctrl.dispose();
      }
      _portfolioCtrls.clear();
      
      final portfolioLinks = _application!['portfolio_links'] as List<dynamic>?;
      if (portfolioLinks != null) {
        for (final link in portfolioLinks) {
          _portfolioCtrls.add(TextEditingController(text: link.toString()));
        }
      }
    } else {
      _pitchCtrl.clear();
      _rateCtrl.clear();
      for (final ctrl in _portfolioCtrls) {
        ctrl.dispose();
      }
      _portfolioCtrls.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Container(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.of(dialogCtx).viewInsets.bottom),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.borderSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_application != null ? 'Edit Collaboration Pitch' : 'Submit Collaboration Pitch', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  AppTextField(
                    label: 'Pitch Message',
                    hint: 'Explain why you are a perfect fit for this collaboration opportunity...',
                    controller: _pitchCtrl,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  
                  AppTextField(
                    label: 'Proposed Rate (Optional)',
                    hint: 'e.g. ₹25,000',
                    controller: _rateCtrl,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('PORTFOLIO LINKS', style: AppTextStyles.overline),
                      if (_portfolioCtrls.length < 3)
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              _addPortfolioLinkField();
                            });
                          },
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Add Link', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  if (_portfolioCtrls.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No portfolio links attached. (Optional, max 3)',
                        style: AppTextStyles.captionSm.copyWith(fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _portfolioCtrls.length,
                      itemBuilder: (context, idx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _portfolioCtrls[idx],
                                  decoration: InputDecoration(
                                    hintText: 'e.g. instagram.com/reel/xyz',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  style: AppTextStyles.bodySm,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline_rounded, color: AppColors.error),
                                onPressed: () {
                                  setDialogState(() {
                                    _removePortfolioLinkField(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  
                  const SizedBox(height: 24),
                  
                  AppButton(
                    label: _application != null ? 'Update Pitch' : 'Submit Pitch',
                    isLoading: _applying,
                    onTap: () async {
                      Navigator.pop(dialogCtx);
                      await _apply();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}