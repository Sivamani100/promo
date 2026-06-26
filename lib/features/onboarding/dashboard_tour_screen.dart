import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';

class TourStep {
  final String title;
  final String description;
  final IconData icon;
  final Widget previewWidget;

  TourStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.previewWidget,
  });
}

class DashboardTourScreen extends ConsumerStatefulWidget {
  const DashboardTourScreen({super.key});

  @override
  ConsumerState<DashboardTourScreen> createState() => _DashboardTourScreenState();
}

class _DashboardTourScreenState extends ConsumerState<DashboardTourScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isTransitioning = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeTour(String role, String userId) async {
    if (_isTransitioning) return;
    setState(() => _isTransitioning = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final tourKey = 'first_time_tour_shown_$userId';
      await prefs.setBool(tourKey, true);
      
      if (mounted) {
        context.go(role == 'brand' ? '/brand/home' : '/influencer/home');
      }
    } catch (e) {
      debugPrint('[TOUR] Error saving tour status: $e');
      if (mounted) {
        context.go(role == 'brand' ? '/brand/home' : '/influencer/home');
      }
    }
  }

  void _nextPage(int totalSteps, String role, String userId) {
    if (_currentIndex < totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeTour(role, userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = authState.role ?? 'influencer';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final steps = role == 'brand' ? _buildBrandSteps(isDark) : _buildInfluencerSteps(isDark);
    final currentStep = steps[_currentIndex];
    final isLast = _currentIndex == steps.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          // Background Premium Gradient
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF13072E),
                        const Color(0xFF070014),
                        const Color(0xFF000000),
                      ]
                    : [
                        const Color(0xFFF3E8FF),
                        const Color(0xFFF9FAFB),
                        const Color(0xFFFFFFFF),
                      ],
              ),
            ),
          ),

          // Safe Area Content
          SafeArea(
            child: Column(
              children: [
                // Top Progress indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      Row(
                        children: [
                          Text(
                            'Promo',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.purple,
                            ),
                          ),
                        ],
                      ),
                      // Page text indicator
                      Text(
                        '${_currentIndex + 1} of ${steps.length}',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Slider Area
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: steps.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 1. Premium Preview Mockup representation
                            Expanded(
                              flex: 5,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 24, top: 12),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0E0E13) : Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.08),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.4)
                                          : Colors.purple.withValues(alpha: 0.06),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    // Subtle accent gradient inside mockup
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: RadialGradient(
                                            center: Alignment.center,
                                            radius: 1.2,
                                            colors: isDark
                                                ? [
                                                    AppColors.purple.withValues(alpha: 0.05),
                                                    Colors.transparent,
                                                  ]
                                                : [
                                                    AppColors.purple.withValues(alpha: 0.03),
                                                    Colors.transparent,
                                                  ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // The actual mockup
                                    Center(child: step.previewWidget),
                                  ],
                                ),
                              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutBack),
                            ),

                            // 2. Icon + Title + Description Section
                            Expanded(
                              flex: 4,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  // Rounded Icon
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.purple.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      step.icon,
                                      color: AppColors.purple,
                                      size: 28,
                                    ),
                                  ).animate(key: ValueKey('icon_$_currentIndex')).scale(delay: 100.ms, duration: 300.ms, curve: Curves.elasticOut),
                                  const SizedBox(height: 16),

                                  // Title
                                  Text(
                                    step.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ).animate(key: ValueKey('title_$_currentIndex')).fadeIn(delay: 150.ms, duration: 350.ms).slideY(begin: 0.2, end: 0),
                                  const SizedBox(height: 10),

                                  // Description
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      step.description,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textSecondary,
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ).animate(key: ValueKey('desc_$_currentIndex')).fadeIn(delay: 250.ms, duration: 350.ms),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Action Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skip Button
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: isLast ? 0.0 : 1.0,
                        child: IgnorePointer(
                          ignoring: isLast,
                          child: TextButton(
                            onPressed: () => _completeTour(role, user.id),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: Text(
                              'Skip',
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Progress Indicators (Dots)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          steps.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: index == _currentIndex ? 22 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: index == _currentIndex
                                  ? AppColors.purple
                                  : (isDark ? Colors.white24 : Colors.black12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),

                      // Next / Finished Button
                      ElevatedButton(
                        onPressed: () => _nextPage(steps.length, role, user.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: Text(
                          isLast ? 'Get Started' : 'Next',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Influencer steps Mockups ───────────────────────────────────────────────
  List<TourStep> _buildInfluencerSteps(bool isDark) {
    return [
      TourStep(
        title: 'Welcome to your Dashboard',
        description: 'This is your main launchpad to track matches, view analytics, and access support.',
        icon: Iconsax.home_1,
        previewWidget: _buildMockDashboardPreview(isDark),
      ),
      TourStep(
        title: 'Track Key Metrics',
        description: 'Monitor your total matches, estimated engagement rate, weekly profile views, and milestone completions.',
        icon: Iconsax.activity,
        previewWidget: _buildMockMetricsPreview(isDark),
      ),
      TourStep(
        title: 'Check Deliverables',
        description: 'Keep tabs on your active agreements, due deliverables, and pending tasks in real-time.',
        icon: Iconsax.flag,
        previewWidget: _buildMockDeliverablesPreview(isDark),
      ),
      TourStep(
        title: 'Discover Partnerships',
        description: 'Tap discover or settings to search for campaign cards and connect with premium brands.',
        icon: Iconsax.discover,
        previewWidget: _buildMockCampaignsPreview(isDark),
      ),
      TourStep(
        title: 'Get Instant Help',
        description: 'Encountered an issue? Open settings and tap Help Center to check FAQs or create a support ticket.',
        icon: Iconsax.message_question,
        previewWidget: _buildMockSupportPreview(isDark),
      ),
    ];
  }

  // ── Brand steps Mockups ────────────────────────────────────────────────────
  List<TourStep> _buildBrandSteps(bool isDark) {
    return [
      TourStep(
        title: 'Welcome to Promo',
        description: 'Manage your active campaigns, incoming creator applications, and active chats here.',
        icon: Iconsax.home_1,
        previewWidget: _buildMockDashboardPreview(isDark),
      ),
      TourStep(
        title: 'Dashboard Analytics',
        description: 'See at a glance how many active campaign cards you have, total applications received, and signed deals.',
        icon: Iconsax.activity,
        previewWidget: _buildMockMetricsPreview(isDark, isBrand: true),
      ),
      TourStep(
        title: 'Find Top Creators',
        description: 'Browse our curated list of best creators or use search to filter influencers by location, niches, and follower counts.',
        icon: Iconsax.user_search,
        previewWidget: _buildMockCreatorsPreview(isDark),
      ),
      TourStep(
        title: 'Collaboration Center',
        description: 'Create and manage contracts, agreements, payments, and resolve disputes smoothly.',
        icon: Iconsax.document_text_1,
        previewWidget: _buildMockDeliverablesPreview(isDark, isBrand: true),
      ),
      TourStep(
        title: 'Brand Support',
        description: 'Access our FAQs or file a priority support ticket at any time from the settings menu.',
        icon: Iconsax.message_question,
        previewWidget: _buildMockSupportPreview(isDark),
      ),
    ];
  }

  // ── Mock UIs for Preview ───────────────────────────────────────────────────
  
  Widget _buildMockDashboardPreview(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.purple.withValues(alpha: 0.2),
                child: Icon(Iconsax.user, color: AppColors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 80, height: 10, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(5))),
                  const SizedBox(height: 6),
                  Container(width: 140, height: 14, decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141419) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile Status', style: AppTextStyles.label.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    Text('Verified Partner', style: AppTextStyles.h4.copyWith(color: AppColors.purple, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Text('100% Done', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockMetricsPreview(bool isDark, {bool isBrand = false}) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('41', isBrand ? 'Applications' : 'Total Matches', Iconsax.hierarchy, isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(isBrand ? '8' : '4.8%', isBrand ? 'Active Campaigns' : 'Engagement Rate', Iconsax.activity, isDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('2.4k', isBrand ? 'Impressions' : 'Profile Views', Iconsax.eye, isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard('12', isBrand ? 'Signed Deals' : 'Milestones Done', Iconsax.award, isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String val, String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141419) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.purple, size: 20),
          const SizedBox(height: 12),
          Text(val, style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildMockDeliverablesPreview(bool isDark, {bool isBrand = false}) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pending Actions', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Container(width: 45, height: 16, decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4))),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionItem('IG Video Post', 'Due in 2 days', isBrand ? 'Review Draft' : 'Submit Draft', Colors.orange, isDark),
          const SizedBox(height: 8),
          _buildActionItem('Brand Guidelines', 'Signed agreement', 'View Contract', Colors.blue, isDark),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, String subtitle, String btnText, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141419) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(btnText, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMockCampaignsPreview(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141419) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 85,
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(Iconsax.image, color: AppColors.purple.withValues(alpha: 0.4), size: 32),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('TECH & DEV', style: TextStyle(color: Colors.blue, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
                Text('\$500 - \$1.5k', style: AppTextStyles.label.copyWith(color: AppColors.purple, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Smart Gadgets Launch Campaign', style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 32,
              decoration: BoxDecoration(color: AppColors.purple, borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('Apply Now', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockCreatorsPreview(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141419) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.purple.withValues(alpha: 0.15),
                  child: const Text('AJ', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aria Jenkins', style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Text('Beauty & Fashion • 120k Followers', style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const Icon(Iconsax.verify, color: Colors.blue, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMockStat('4.9%', 'Eng. Rate'),
                  _buildMockStat('NY, USA', 'Location'),
                  _buildMockStat('15', 'Deals Done'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockStat(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 8)),
      ],
    );
  }

  Widget _buildMockSupportPreview(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Iconsax.message_question, color: AppColors.purple, size: 24),
              const SizedBox(width: 8),
              Text('Help & Support', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          _buildFaqItem('How do payments work?', isDark),
          const SizedBox(height: 8),
          _buildFaqItem('What is the dispute process?', isDark),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.purple.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.edit, color: AppColors.purple, size: 16),
                const SizedBox(width: 8),
                Text('Create Support Ticket', style: AppTextStyles.label.copyWith(color: AppColors.purple, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141419) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text, style: AppTextStyles.bodySm.copyWith(color: AppColors.textPrimary)),
          const Icon(Icons.keyboard_arrow_right, size: 16),
        ],
      ),
    );
  }
}
