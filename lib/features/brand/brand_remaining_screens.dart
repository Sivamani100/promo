import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/card_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/data_services.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/application_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'package:fl_chart/fl_chart.dart';

// Brand Saved Lists
class BrandSavedListsScreen extends ConsumerStatefulWidget {
  const BrandSavedListsScreen({super.key});
  @override
  ConsumerState<BrandSavedListsScreen> createState() => _BrandSavedListsScreenState();
}

class _BrandSavedListsScreenState extends ConsumerState<BrandSavedListsScreen> {
  List<Map<String, dynamic>> _lists = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final data = await SavedService().getSavedLists(user.id);
    if (mounted) setState(() { _lists = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && _loading) {
        _load();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/brand/home'),
        ),
        title: const Text('Saved Lists'),
        actions: [
          IconButton(icon: const Icon(Iconsax.add), onPressed: () async {
          final name = await _showCreateDialog();
          if (name != null && name.isNotEmpty) {
            await SavedService().createList(ref.read(authProvider).user!.id, name);
            _load();
          }
        }),
      ]),
      body: _loading
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const ShimmerGenericListTile(),
            )
          : _lists.isEmpty
              ? const AppEmptyState(icon: Iconsax.archive_1, title: 'No saved lists', subtitle: 'Create a list to organize influencers')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageMarginHorizontal,
                    AppSpacing.pageMarginVertical,
                    AppSpacing.pageMarginHorizontal,
                    AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                  ),
                  itemCount: _lists.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final list = _lists[i];
                    final items = (list['items'] as List?) ?? [];
                    return GestureDetector(
                      onTap: () async {
                        await context.push('/brand/saved-lists/${list['id']}', extra: {'name': list['name']});
                        _load();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusXl), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          Icon(Iconsax.folder, color: AppColors.textMuted, size: 32),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(list['name'] ?? 'List', style: AppTextStyles.label),
                            Text('${items.length} influencers', style: AppTextStyles.captionSm),
                          ])),
                          Icon(Iconsax.arrow_right_3, color: AppColors.textMuted),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }

  Future<String?> _showCreateDialog() async {
    final ctrl = TextEditingController();
    return showPremiumDialog<String>(
      context: context,
      title: 'New List',
      icon: Iconsax.folder_add,
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: 'List name',
          hintStyle: AppTextStyles.caption,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
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
                  final text = ctrl.text.trim();
                  if (text.isNotEmpty) Navigator.pop(context, text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentOnDark,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  elevation: 0,
                ),
                child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Brand Campaigns
class BrandCampaignsScreen extends ConsumerStatefulWidget {
  const BrandCampaignsScreen({super.key});
  @override
  ConsumerState<BrandCampaignsScreen> createState() => _BrandCampaignsScreenState();
}

class _BrandCampaignsScreenState extends ConsumerState<BrandCampaignsScreen> {
  List<Map<String, dynamic>> _applications = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final data = await ApplicationService().getApplicationsForBrand(user.id);
      final acceptedData = data.where((app) => app['status'] == 'accepted').toList();
      if (mounted) {
        setState(() {
          _applications = acceptedData;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading accepted deals: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && _loading) {
        _load();
      }
    });

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
              onPressed: () => context.go('/brand/home'),
            ),
            leadingWidth: 30,
            centerTitle: false,
            titleSpacing: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Accepted Deals',
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
          ),
        ),
      ),
      body: _loading
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const ShimmerApplicationCard(),
            )
          : _applications.isEmpty
              ? const AppEmptyState(
                  icon: Iconsax.tick_circle,
                  title: 'No accepted deals yet',
                  subtitle: 'When you accept an influencer\'s application, it will appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageMarginHorizontal,
                    AppSpacing.pageMarginVertical,
                    AppSpacing.pageMarginHorizontal,
                    AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                  ),
                  itemCount: _applications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final app = _applications[i];
                    final card = app['card'] as Map<String, dynamic>?;
                    final influencer = app['influencer'] as Map<String, dynamic>?;

                    String formattedDate = '';
                    try {
                      final dateStr = app['updated_at'] ?? app['created_at'];
                      if (dateStr != null) {
                        final parsed = DateTime.parse(dateStr);
                        formattedDate = DateFormat('MMM dd, yyyy').format(parsed);
                      }
                    } catch (_) {}

                    return Container(
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (card != null && card['id'] != null) {
                                context.push('/brand/cards/${card['id']}');
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Visual Stack (Campaign cover + Influencer avatar overlay)
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          width: 68,
                                          height: 68,
                                          color: AppColors.surface2,
                                          child: AppImage(
                                            url: card?['cover_image_url'],
                                            fit: BoxFit.cover,
                                            fallback: Icon(Iconsax.image, color: AppColors.textMuted),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: -6,
                                        bottom: -6,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
                                              width: 2.0,
                                            ),
                                          ),
                                          child: AppAvatar(
                                            url: influencer?['avatar_url'],
                                            fallbackText: influencer?['display_name'] ?? 'I',
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 18),
                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Accepted Status Tag and Date row
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                'DEAL ACCEPTED',
                                                style: GoogleFonts.inter(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF10B981),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                            if (formattedDate.isNotEmpty)
                                              Text(
                                                formattedDate,
                                                style: AppTextStyles.captionSm.copyWith(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        // Card Title
                                        Text(
                                          card?['title'] ?? 'Campaign Card',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                            height: 1.25,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        // Creator / Partner Name
                                        Text(
                                          'Partner: ${influencer?['display_name'] ?? 'Creator'}',
                                          style: AppTextStyles.captionSm.copyWith(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        // Budget
                                        Row(
                                          children: [
                                            Icon(
                                              Iconsax.wallet_3,
                                              size: 14,
                                              color: AppColors.textMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              card?['budget_range'] != null
                                                  ? (card!['budget_range'].toString().startsWith('₹')
                                                      ? card['budget_range']
                                                      : '₹${card['budget_range']}')
                                                  : 'Open Budget',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// Brand Analytics
class BrandAnalyticsScreen extends ConsumerStatefulWidget {
  const BrandAnalyticsScreen({super.key});
  @override
  ConsumerState<BrandAnalyticsScreen> createState() => _BrandAnalyticsScreenState();
}

class _BrandAnalyticsScreenState extends ConsumerState<BrandAnalyticsScreen> {
  int _profileViews = 0;
  int _totalApps = 0;
  int _acceptedApps = 0;
  int _pendingApps = 0;
  int _rejectedApps = 0;
  int _totalCards = 0;
  int _activeCards = 0;
  int _totalCampaigns = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final results = await Future.wait([
        AnalyticsService().getProfileViewCount(user.id),
        ApplicationService().getApplicationsForBrand(user.id),
        CardService().getBrandCards(user.id),
        CampaignService().getCampaigns(user.id),
      ]);
      final views = results[0] as int;
      final apps = results[1] as List<Map<String, dynamic>>;
      final cards = results[2] as List<Map<String, dynamic>>;
      final campaigns = results[3] as List<Map<String, dynamic>>;
      if (mounted) setState(() {
        _profileViews = views;
        _totalApps = apps.length;
        _acceptedApps = apps.where((a) => a['status'] == 'accepted').length;
        _pendingApps = apps.where((a) => a['status'] == 'pending').length;
        _rejectedApps = apps.where((a) => a['status'] == 'rejected').length;
        _totalCards = cards.length;
        _activeCards = cards.where((c) => c['status'] == 'active').length;
        _totalCampaigns = campaigns.length;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && _loading) _load();
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/brand/home'),
        ),
        title: const Text('Analytics'),
      ),
      body: _loading
          ? const ShimmerAnalyticsScreen()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageMarginHorizontal,
                  AppSpacing.pageMarginVertical,
                  AppSpacing.pageMarginHorizontal,
                  AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                ),
                children: [
                  // Stat cards row
                  GridView.count(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      StatCard(label: 'Profile Views', value: '$_profileViews', icon: Iconsax.eye, preset: StatCardPreset.cyan),
                      StatCard(label: 'Applications', value: '$_totalApps', icon: Iconsax.document_text, preset: StatCardPreset.rose),
                      StatCard(label: 'Active Cards', value: '$_activeCards', icon: Iconsax.cards, preset: StatCardPreset.indigo),
                      StatCard(label: 'Campaigns', value: '$_totalCampaigns', icon: Iconsax.flag, preset: StatCardPreset.amber),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Application Conversion Donut Chart
                  _buildChartCard(
                    title: 'Application Status',
                    icon: Iconsax.chart_1,
                    isDark: isDark,
                    height: 200,
                    child: _totalApps == 0
                        ? Center(child: Text('No applications yet', style: AppTextStyles.captionSm))
                        : Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 32,
                                    sections: [
                                      PieChartSectionData(
                                        color: AppColors.success,
                                        value: _acceptedApps.toDouble(),
                                        title: '$_acceptedApps',
                                        titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        radius: 40,
                                      ),
                                      PieChartSectionData(
                                        color: AppColors.warning,
                                        value: _pendingApps.toDouble(),
                                        title: '$_pendingApps',
                                        titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        radius: 40,
                                      ),
                                      PieChartSectionData(
                                        color: AppColors.error,
                                        value: _rejectedApps.toDouble(),
                                        title: '$_rejectedApps',
                                        titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        radius: 40,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _legendDot('Accepted', AppColors.success, _acceptedApps),
                                    const SizedBox(height: 10),
                                    _legendDot('Pending', AppColors.warning, _pendingApps),
                                    const SizedBox(height: 10),
                                    _legendDot('Rejected', AppColors.error, _rejectedApps),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Performance Overview Bar Chart
                  _buildChartCard(
                    title: 'Performance Overview',
                    icon: Iconsax.chart_2,
                    isDark: isDark,
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: ([_totalCards, _totalApps, _acceptedApps, _totalCampaigns]
                                .reduce((a, b) => a > b ? a : b)
                                .toDouble()) * 1.3 + 1,
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                const labels = ['Cards', 'Apps', 'Accepted', 'Campaigns'];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    labels[value.toInt()],
                                    style: AppTextStyles.captionSm.copyWith(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          _barGroup(0, _totalCards.toDouble(), AppColors.info),
                          _barGroup(1, _totalApps.toDouble(), AppColors.purple),
                          _barGroup(2, _acceptedApps.toDouble(), AppColors.success),
                          _barGroup(3, _totalCampaigns.toDouble(), AppColors.warning),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Conversion rate summary
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Conversion Rate', style: AppTextStyles.label),
                              const SizedBox(height: 4),
                              Text('Applications → Accepted', style: AppTextStyles.captionSm),
                            ],
                          ),
                        ),
                        Text(
                          _totalApps > 0
                              ? '${((_acceptedApps / _totalApps) * 100).toStringAsFixed(1)}%'
                              : '0%',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildChartCard({required String title, required IconData icon, required bool isDark, required double height, required Widget child}) {
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
          Row(children: [
            Icon(icon, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.label),
          ]),
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color, int count) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label ($count)',
            style: AppTextStyles.captionSm,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  BarChartGroupData _barGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }
}

// Brand Profile
class BrandProfileScreen extends ConsumerStatefulWidget {
  const BrandProfileScreen({super.key});
  @override
  ConsumerState<BrandProfileScreen> createState() => _BrandProfileScreenState();
}

class _BrandProfileScreenState extends ConsumerState<BrandProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  bool _saving = false;
  bool _isEditing = false;
  List<Map<String, dynamic>> _cards = [];
  int _campaignsCount = 0;
  int _applicantsCount = 0;
  int _roomsCount = 0;
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    final p = ref.read(authProvider).profile;
    if (p != null) {
      _nameCtrl.text = p['display_name'] ?? '';
      _companyCtrl.text = p['company_name'] ?? '';
      _bioCtrl.text = p['bio'] ?? '';
      _websiteCtrl.text = p['website_url'] ?? '';
    }
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final sb = SupabaseService.client;
    try {
      final futures = await Future.wait<dynamic>([
        CardService().getBrandCards(user.id),
        CampaignService().getCampaigns(user.id),
        sb.from('applications').select('*, cards!inner(*)').eq('cards.brand_id', user.id).count(CountOption.exact).timeout(const Duration(seconds: 15)),
        sb.from('rooms').select('id').eq('brand_id', user.id).count(CountOption.exact).timeout(const Duration(seconds: 15)),
      ]);
      if (mounted) {
        setState(() {
          _cards = futures[0] as List<Map<String, dynamic>>;
          _campaignsCount = (futures[1] as List).length;
          _applicantsCount = (futures[2] as PostgrestResponse).count;
          _roomsCount = (futures[3] as PostgrestResponse).count;
          _loadingData = false;
        });
      }
    } catch (e) {
      print('Error loading brand profile dashboard: $e');
      if (mounted) {
        setState(() {
          _loadingData = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = ref.read(authProvider).user!;
      await ProfileService().updateProfile(user.id, {
        'display_name': _nameCtrl.text.trim(),
        'company_name': _companyCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'website_url': _websiteCtrl.text.trim(),
      });
      ref.read(authProvider.notifier).refreshProfile();
      if (mounted) {
        AppSnackbar.show(context, 'Profile updated!');
        _setEditing(false);
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  void _setEditing(bool editing) {
    setState(() {
      _isEditing = editing;
    });
    ref.read(hideBottomNavProvider.notifier).state = editing;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _bioCtrl.dispose();
    _websiteCtrl.dispose();
    ref.read(hideBottomNavProvider.notifier).state = false;
    super.dispose();
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
                    minWidth: 7,
                    minHeight: 7,
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
      if (next.user != null && _loadingData) {
        _loadDashboardData();
      }
      if (next.profile != null && previous?.profile == null) {
        _nameCtrl.text = next.profile!['display_name'] ?? '';
        _companyCtrl.text = next.profile!['company_name'] ?? '';
        _bioCtrl.text = next.profile!['bio'] ?? '';
        _websiteCtrl.text = next.profile!['website_url'] ?? '';
      }
    });

    final profile = ref.watch(authProvider).profile;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

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
            automaticallyImplyLeading: false,
            leading: null,
            centerTitle: false,
            titleSpacing: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isEditing) ...[
                  GestureDetector(
                    onTap: () => _setEditing(false),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Icon(Iconsax.arrow_left_2, size: 22, color: AppColors.textPrimary),
                    ),
                  ),
                ],
                Text(
                  _isEditing ? 'Edit Profile' : 'Profile',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!_isEditing)
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
              if (_isEditing)
                GestureDetector(
                  onTap: () => _setEditing(false),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Transform.rotate(
                        angle: 0.785398, // 45 degrees in radians (pi / 4)
                        child: Icon(Iconsax.add, size: 24, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                )
              else ...[
                _buildAppBarIcon(
                  icon: Iconsax.notification,
                  badgeCount: unreadNotifications,
                  onTap: () => context.push('/brand/notifications'),
                ),
                const SizedBox(width: 8),
                _buildAppBarIcon(
                  icon: Iconsax.setting_2,
                  onTap: () => context.push('/brand/settings'),
                ),
              ],
            ],
          ),
        ),
      ),
      body: _loadingData
          ? const ShimmerProfileDetail()
          : RefreshIndicator(
              onRefresh: () async {
                ref.read(authProvider.notifier).refreshProfile();
                await _loadDashboardData();
              },
              color: AppColors.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageMarginHorizontal,
                  8.0,
                  AppSpacing.pageMarginHorizontal,
                  AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                ),
                children: _isEditing
                    ? [
                        AppTextField(label: 'Display Name', controller: _nameCtrl),
                        const SizedBox(height: 16),
                        AppTextField(label: 'Company Name', controller: _companyCtrl),
                        const SizedBox(height: 16),
                        AppTextField(label: 'Bio', controller: _bioCtrl, maxLines: 4),
                        const SizedBox(height: 16),
                        AppTextField(label: 'Website', controller: _websiteCtrl, keyboardType: TextInputType.url),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(label: 'Save Changes', onTap: _save, isLoading: _saving),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppButton(
                                label: 'Cancel',
                                isPrimary: false,
                                onTap: () async {
                                  final confirmed = await showPremiumConfirmDialog(
                                    context: context,
                                    title: 'Discard Changes',
                                    message: 'Are you sure you want to discard your profile edits?',
                                    confirmLabel: 'Discard',
                                    isDestructive: true,
                                  );
                                  if (confirmed == true && mounted) {
                                    _setEditing(false);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ]
                    : [
                        // Profile dark card (left screen style)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.02),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                           child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Stack(
                                    children: [
                                      AppAvatar(url: profile?['avatar_url'], fallbackText: profile?['display_name'] ?? 'B', size: 60),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2ECC71),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: isDark ? const Color(0xFF0F0F11) : Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                profile?['display_name'] ?? 'Brand',
                                                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (profile?['is_verified'] == true) ...[
                                              const SizedBox(width: 4),
                                              const VerificationBadge(size: 18),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (profile?['is_verified'] == true) ...[
                                              const VerificationBadge(size: 14),
                                              const SizedBox(width: 4),
                                            ] else ...[
                                              Icon(Iconsax.verify, color: AppColors.accent, size: 14),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              profile?['is_verified'] == true ? 'Verified Brand' : 'Essential Partner',
                                              style: AppTextStyles.captionSm.copyWith(
                                                color: AppColors.accent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _setEditing(true),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Iconsax.edit, size: 16, color: AppColors.accent),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (profile?['bio'] != null && (profile!['bio'] as String).isNotEmpty) ...[
                                  Text(
                                    profile['bio'],
                                    style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              Divider(color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB), height: 1),
                              const SizedBox(height: 16),
                              // Stats (divided by vertical lines)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _profileStatItem('Cards', '${_cards.length}'),
                                  Container(width: 1, height: 28, color: AppColors.border),
                                  _profileStatItem('Campaigns', '$_campaignsCount'),
                                  Container(width: 1, height: 28, color: AppColors.border),
                                  _profileStatItem('Applicants', '$_applicantsCount'),
                                  Container(width: 1, height: 28, color: AppColors.border),
                                  _profileStatItem('Chats', '$_roomsCount'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Action buttons row (right screen style)
                        Row(
                          children: [
                            _capsuleButton(
                              'Campaigns',
                              Iconsax.briefcase,
                              isDark ? const Color(0xFFF5C518) : const Color(0xFFDDA600),
                              () => context.go('/brand/campaigns'),
                            ),
                            const SizedBox(width: 12),
                            _capsuleButton(
                              'Chats',
                              Iconsax.message,
                              isDark ? const Color(0xFF2ECC71) : const Color(0xFF1E8449),
                              () => context.go('/brand/chats'),
                            ),
                            const SizedBox(width: 12),
                            _capsuleButton(
                              'Settings',
                              Iconsax.setting_2,
                              isDark ? const Color(0xFF3498DB) : const Color(0xFF21618C),
                              () => context.push('/brand/settings'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // My Cards section (grid style)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('My Cards', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: () => context.go('/brand/cards'),
                              child: Text(
                                'See All',
                                style: AppTextStyles.captionSm.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_cards.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                Icon(Iconsax.cards, color: AppColors.textMuted, size: 36),
                                const SizedBox(height: 12),
                                Text('No campaign cards yet', style: AppTextStyles.label),
                                const SizedBox(height: 4),
                                Text('Create campaign cards to start matching with creators.', style: AppTextStyles.captionSm, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(Iconsax.add, size: 16),
                                  label: const Text('Post Card'),
                                  onPressed: () => context.push('/brand/cards/new'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.accent,
                                    side: BorderSide(color: AppColors.accent),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Builder(
                            builder: (context) {
                              final displayCards = _cards.take(4).toList();
                              return Column(
                                children: [
                                  for (int i = 0; i < displayCards.length; i += 2) ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _buildBrandCard(context, displayCards[i])),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: i + 1 < displayCards.length
                                              ? _buildBrandCard(context, displayCards[i + 1])
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                    if (i + 2 < displayCards.length) const SizedBox(height: 16),
                                  ],
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: 24),
                        // Options menu list
                        Text('Menu', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                _menuTile('Discover Influencers', Iconsax.profile_2user, () => context.go('/brand/influencers')),
                                _menuDivider(),
                                _menuTile('Saved Lists', Iconsax.archive_1, () => context.go('/brand/saved-lists')),
                                _menuDivider(),
                                _menuTile('Help Center', Iconsax.info_circle, () => context.push('/brand/support')),
                                _menuDivider(),
                                _menuTile(
                                  'Sign Out',
                                  Iconsax.logout,
                                  () async {
                                    final confirm = await showPremiumConfirmDialog(
                                      context: context,
                                      title: 'Sign Out',
                                      message: 'Are you sure you want to sign out of your account?',
                                      confirmLabel: 'Sign Out',
                                      isDestructive: true,
                                      icon: Iconsax.logout,
                                    );
                                    if (confirm == true) {
                                      await ref.read(authProvider.notifier).signOut();
                                    }
                                  },
                                  isDestructive: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildFooter(),
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
            'Your story,',
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
            'your brand.',
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

  Widget _profileStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _capsuleButton(String label, IconData icon, Color accentColor, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0F11) : Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.01),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile(String title, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: isDestructive ? AppColors.error : AppColors.accent, size: 20),
      title: Text(title, style: AppTextStyles.label.copyWith(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _menuDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
      height: 1,
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildBrandCard(BuildContext context, Map<String, dynamic> card) {
    final coverUrl = card['cover_image_url'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F11) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.01),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppImage(
                url: coverUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                fallback: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.purple.withValues(alpha: 0.1),
                        AppColors.indigo.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(Iconsax.cards, color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card['title'] ?? 'Campaign Card',
                    style: AppTextStyles.label.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card['budget_range'] != null
                        ? (card['budget_range'].toString().startsWith('₹')
                            ? 'Budget: ${card['budget_range']}'
                            : 'Budget: ₹${card['budget_range']}')
                        : 'No budget set',
                    style: AppTextStyles.captionSm.copyWith(
                      fontSize: 10,
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandSavedListDetailScreen extends StatefulWidget {
  final String listId;
  final String name;
  const BrandSavedListDetailScreen({super.key, required this.listId, required this.name});
  @override
  State<BrandSavedListDetailScreen> createState() => _BrandSavedListDetailScreenState();
}

class _BrandSavedListDetailScreenState extends State<BrandSavedListDetailScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sb = SupabaseService.client;
      final data = await sb
          .from('influencer_list_items')
          .select('*, influencer:profiles!influencer_list_items_influencer_id_fkey(*)')
          .eq('list_id', widget.listId)
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading list items: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeItem(String influencerId) async {
    final confirmed = await showPremiumConfirmDialog(
      context: context,
      title: 'Remove Creator',
      message: 'Are you sure you want to remove this creator from the list?',
      confirmLabel: 'Remove',
      isDestructive: true,
      icon: Iconsax.trash,
    );
    if (confirmed == true) {
      setState(() => _loading = true);
      await SavedService().removeFromList(widget.listId, influencerId);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
      ),
      body: _loading
          ? ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const ShimmerGenericListTile(),
            )
          : _items.isEmpty
              ? const AppEmptyState(
                  icon: Iconsax.profile_2user,
                  title: 'List is empty',
                  subtitle: 'Add creators to this list from their profiles',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageMarginHorizontal,
                    AppSpacing.pageMarginVertical,
                    AppSpacing.pageMarginHorizontal,
                    AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                  ),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    final inf = item['influencer'] as Map<String, dynamic>?;
                    if (inf == null) return const SizedBox.shrink();
                    final niches = (inf['niche'] as List<dynamic>?)?.cast<String>() ?? [];

                    return GestureDetector(
                      onTap: () => context.push('/brand/influencers/${inf['id']}'),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            AppAvatar(
                              url: inf['avatar_url'],
                              fallbackText: inf['display_name'] ?? 'I',
                              size: 48,
                              onTap: () => context.push('/brand/influencers/${inf['id']}'),
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
                                          inf['display_name'] ?? '',
                                          style: AppTextStyles.label,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (inf['is_verified'] == true) ...[
                                        const SizedBox(width: 4),
                                        const VerificationBadge(size: 14),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(niches.take(2).join(' · '), style: AppTextStyles.captionSm),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${((inf['follower_count'] ?? 0) / 1000).toStringAsFixed(0)}K followers · ${inf['location'] ?? 'Global'}',
                                    style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Iconsax.trash, color: AppColors.error, size: 20),
                              onPressed: () => _removeItem(inf['id']),
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