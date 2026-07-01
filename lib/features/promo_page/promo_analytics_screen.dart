import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import 'promo_page_service.dart';

/// Embeddable analytics dashboard widget for the Promo Page.
/// Used both inside the settings tab and as a standalone screen.
class PromoAnalyticsDashboard extends StatefulWidget {
  final String pageId;
  final String username;

  const PromoAnalyticsDashboard({
    super.key,
    required this.pageId,
    required this.username,
  });

  @override
  State<PromoAnalyticsDashboard> createState() => _PromoAnalyticsDashboardState();
}

class _PromoAnalyticsDashboardState extends State<PromoAnalyticsDashboard> {
  bool _loading = true;
  PromoAnalyticsSummary? _summary;
  List<PromoLinkAnalytics> _linkStats = [];
  List<PromoPageView> _recentViews = [];
  String _chartRange = '30'; // '7' or '30'

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        PromoPageService.getAnalyticsSummary(widget.pageId),
        PromoPageService.getLinkAnalytics(widget.pageId),
        PromoPageService.getRecentViews(widget.pageId, limit: 25),
      ]);

      setState(() {
        _summary = results[0] as PromoAnalyticsSummary?;
        _linkStats = results[1] as List<PromoLinkAnalytics>;
        _recentViews = results[2] as List<PromoPageView>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: CircularProgressIndicator(color: AppColors.purple),
        ),
      );
    }

    if (_summary == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No analytics data yet', style: AppTextStyles.body),
            const SizedBox(height: 8),
            Text(
              'Share your promo page to start tracking views and clicks.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    final summary = _summary!;

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: AppColors.purple,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. Sleek URL Overview Banner
          _buildPageUrlBanner(),
          const SizedBox(height: 14),

          // 2. Summary stats cards
          _buildSummaryCards(summary),
          const SizedBox(height: 14),

          // 3. Bento Card: Views Over Time Chart
          _buildViewsChart(summary),
          const SizedBox(height: 14),

          // 4. Bento Card: Link Performance
          _buildLinkPerformance(summary),
          const SizedBox(height: 14),

          // 5. Bento Card: Traffic Sources
          _buildTopReferrers(summary),
          const SizedBox(height: 14),

          // 6. Bento Card: Recent Activity
          _buildRecentActivity(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Page URL Banner
  // ═══════════════════════════════════════════════════════════

  Widget _buildPageUrlBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surface3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.purple, AppColors.purple.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: const Icon(Iconsax.chart_success, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics Overview',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'promo.arkio.in/@${widget.username}',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.purple,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _loadAnalytics,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.surface3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.refresh, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Summary Cards
  // ═══════════════════════════════════════════════════════════

  Widget _buildSummaryCards(PromoAnalyticsSummary summary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine colors based on isDark (matching InfluencerHomeScreen exactly)
    final Color skyBg = isDark ? const Color(0xFF0C243C) : const Color(0xFFD0ECFC);
    final Color greenBg = isDark ? const Color(0xFF0D3E26) : const Color(0xFFC1F0D5);
    final Color pinkBg = isDark ? const Color(0xFF481030) : const Color(0xFFFCD3E6);
    final Color yellowBg = isDark ? const Color(0xFF482B08) : const Color(0xFFFDE2B5);

    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0, // Perfect square aspect ratio
      children: [
        _buildStatCard(
          label: 'Total Views',
          value: _formatNumber(summary.totalViews),
          subValue: '+${summary.viewsToday} today',
          icon: Iconsax.eye,
          bgColor: skyBg,
          textColor: textColor,
          subTextColor: subTextColor,
          iconColor: iconColor,
        ),
        _buildStatCard(
          label: 'Unique Visitors',
          value: _formatNumber(summary.uniqueViews),
          subValue: '${summary.viewsThisWeek} this week',
          icon: Iconsax.people,
          bgColor: greenBg,
          textColor: textColor,
          subTextColor: subTextColor,
          iconColor: iconColor,
        ),
        _buildStatCard(
          label: 'Total Clicks',
          value: _formatNumber(summary.totalClicks),
          subValue: '+${summary.clicksToday} today',
          icon: Iconsax.mouse_circle,
          bgColor: pinkBg,
          textColor: textColor,
          subTextColor: subTextColor,
          iconColor: iconColor,
        ),
        _buildStatCard(
          label: 'Click Rate',
          value: '${summary.ctr.toStringAsFixed(1)}%',
          subValue: 'CTR (clicks/views)',
          icon: Iconsax.percentage_circle,
          bgColor: yellowBg,
          textColor: textColor,
          subTextColor: subTextColor,
          iconColor: iconColor,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String subValue,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required Color subTextColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(28.0), // Rounded squarish bento styling
      ),
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
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
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
                color: iconColor,
                size: 20,
              ),
            ],
          ),
          const Spacer(),
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
            subValue,
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
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Views Chart
  // ═══════════════════════════════════════════════════════════

  Widget _buildChartRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surface3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRangeChip('7', 'Last 7 Days'),
          _buildRangeChip('30', 'Last 30 Days'),
        ],
      ),
    );
  }

  Widget _buildRangeChip(String range, String label) {
    final isSelected = _chartRange == range;
    return GestureDetector(
      onTap: () => setState(() => _chartRange = range),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildViewsChart(PromoAnalyticsSummary summary) {
    final daysCount = int.parse(_chartRange);
    final allDays = summary.viewsByDay;

    // Get the last N days
    final days = allDays.length > daysCount
        ? allDays.sublist(allDays.length - daysCount)
        : allDays;

    if (days.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No view data yet', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final maxY = days.map((d) => d.views).reduce(max).toDouble();
    final adjustedMaxY = maxY <= 0 ? 5.0 : (maxY * 1.3);

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surface3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (days.length - 1).toDouble(),
          minY: 0,
          maxY: adjustedMaxY,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.purple.withValues(alpha: 0.9),
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final day = days[spot.x.toInt()];
                  final dateParsed = DateTime.tryParse(day.date);
                  final dateLabel = dateParsed != null
                      ? DateFormat('MMM d').format(dateParsed)
                      : day.date;
                  return LineTooltipItem(
                    '$dateLabel\n${spot.y.toInt()} views',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: max(1.0, adjustedMaxY / 4),
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.surface3,
              strokeWidth: 0.8,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: max(1.0, adjustedMaxY / 4),
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= days.length) return const SizedBox.shrink();

                  final interval = daysCount <= 7 ? 1 : 5;
                  if (idx % interval != 0 && idx != days.length - 1) {
                    return const SizedBox.shrink();
                  }

                  final dateParsed = DateTime.tryParse(days[idx].date);
                  final label = dateParsed != null
                      ? DateFormat('d/M').format(dateParsed)
                      : '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: days.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value.views.toDouble());
              }).toList(),
              isCurved: true,
              color: AppColors.purple,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.purple,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
                checkToShowDot: (spot, barData) {
                  return spot.x == days.length - 1;
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.purple.withValues(alpha: 0.25),
                    AppColors.purple.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Link Performance
  // ═══════════════════════════════════════════════════════════

  Widget _buildLinkPerformance(PromoAnalyticsSummary summary) {
    if (_linkStats.isEmpty) {
      return _buildEmptySection('No link data yet. Add links to your Promo Page to start tracking clicks.');
    }

    final totalClicks = _linkStats.fold(0, (sum, l) => sum + l.totalClicks);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surface3),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Link', style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  )),
                ),
                Expanded(
                  child: Text('Clicks', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  )),
                ),
                SizedBox(width: 100, child: Text('Share', textAlign: TextAlign.center, style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ))),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(_linkStats.length, (idx) {
            final link = _linkStats[idx];
            final percentage = totalClicks > 0 ? (link.totalClicks / totalClicks) : 0.0;

            // Color gradient based on rank
            final colors = [
              const Color(0xFFA855F7), // purple
              const Color(0xFF6366F1), // indigo
              const Color(0xFF38BDF8), // blue
              const Color(0xFF4ADE80), // green
              const Color(0xFFFBBF24), // amber
            ];
            final barColor = colors[idx % colors.length];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Icon + Title
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Text(link.icon ?? '🔗', style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    link.title,
                                    style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '+${link.clicksToday} today',
                                    style: TextStyle(
                                      color: link.clicksToday > 0 ? AppColors.success : AppColors.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Click count
                      Expanded(
                        child: Text(
                          _formatNumber(link.totalClicks),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Percentage bar
                      SizedBox(
                        width: 100,
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage,
                                  backgroundColor: AppColors.surface3,
                                  valueColor: AlwaysStoppedAnimation(barColor),
                                  minHeight: 8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(percentage * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (idx < _linkStats.length - 1)
                  Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.surface3),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Top Referrers
  // ═══════════════════════════════════════════════════════════

  Widget _buildTopReferrers(PromoAnalyticsSummary summary) {
    final referrers = summary.topReferrers;
    if (referrers.isEmpty) {
      return _buildEmptySection('No referrer data yet. Traffic source tracking will show where your visitors come from.');
    }

    final totalRefs = referrers.fold(0, (sum, r) => sum + r.count);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surface3),
      ),
      child: Column(
        children: List.generate(referrers.length, (idx) {
          final ref = referrers[idx];
          final pct = totalRefs > 0 ? (ref.count / totalRefs) : 0.0;

          IconData sourceIcon;
          Color sourceColor;
          if (ref.source.toLowerCase() == 'direct') {
            sourceIcon = Iconsax.direct;
            sourceColor = const Color(0xFF4ADE80);
          } else if (ref.source.contains('instagram')) {
            sourceIcon = Icons.camera_alt_outlined;
            sourceColor = const Color(0xFFF472B6);
          } else if (ref.source.contains('twitter') || ref.source.contains('x.com')) {
            sourceIcon = Icons.alternate_email;
            sourceColor = const Color(0xFF38BDF8);
          } else if (ref.source.contains('youtube')) {
            sourceIcon = Icons.play_circle_outline;
            sourceColor = const Color(0xFFF87171);
          } else if (ref.source.contains('linkedin')) {
            sourceIcon = Icons.work_outline;
            sourceColor = const Color(0xFF38BDF8);
          } else if (ref.source.contains('tiktok')) {
            sourceIcon = Icons.music_note;
            sourceColor = Colors.white;
          } else {
            sourceIcon = Iconsax.global;
            sourceColor = const Color(0xFFFBBF24);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: sourceColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(sourceIcon, size: 16, color: sourceColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ref.source,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${ref.count} visits',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sourceColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: sourceColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (idx < referrers.length - 1)
                Divider(height: 1, indent: 52, endIndent: 16, color: AppColors.surface3),
            ],
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Recent Activity
  // ═══════════════════════════════════════════════════════════

  Widget _buildRecentActivity() {
    if (_recentViews.isEmpty) {
      return _buildEmptySection('No recent activity. Views will appear here as people visit your page.');
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surface3),
      ),
      child: Column(
        children: List.generate(
          _recentViews.length > 15 ? 15 : _recentViews.length,
          (idx) {
            final view = _recentViews[idx];
            final timeAgo = _getTimeAgo(view.viewedAt);
            final referrer = view.referrer?.isNotEmpty == true
                ? _extractDomain(view.referrer!)
                : 'Direct';

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Iconsax.eye, size: 14, color: AppColors.purple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Page view',
                              style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'From: $referrer',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (idx < _recentViews.length - 1 && idx < 14)
                  Divider(height: 1, indent: 44, endIndent: 16, color: AppColors.surface3),
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.purple),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.h3.copyWith(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildEmptySection(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surface3),
      ),
      child: Center(
        child: Text(
          message,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _formatNumber(int num) {
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M';
    }
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toString();
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
  }

  String _extractDomain(String url) {
    try {
      if (url.isEmpty) return 'Direct';
      final uri = Uri.tryParse(url);
      if (uri != null && uri.host.isNotEmpty) return uri.host;
      // Try splitting as a plain domain
      final parts = url.split('://');
      if (parts.length > 1) return parts[1].split('/').first;
      return url.split('/').first;
    } catch (_) {
      return url;
    }
  }
}

/// Standalone full-screen analytics page
class PromoAnalyticsScreen extends StatelessWidget {
  final String pageId;
  final String username;

  const PromoAnalyticsScreen({
    super.key,
    required this.pageId,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promo Analytics'),
      ),
      body: PromoAnalyticsDashboard(
        pageId: pageId,
        username: username,
      ),
    );
  }
}
