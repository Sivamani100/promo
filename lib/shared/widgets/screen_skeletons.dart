import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_skeleton.dart';
// ─────────────────────────────────────────────────────────────────────────────
// SCREEN-SPECIFIC SKELETON WIDGETS
// Handcrafted skeletons mapping to actual layout structures.
// ─────────────────────────────────────────────────────────────────────────────

/// Home Screen Skeleton for Influencers
/// Home Screen Body Skeleton for Influencers
class InfluencerHomeBodySkeleton extends StatelessWidget {
  const InfluencerHomeBodySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical,
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
      ),
      children: [
        // Welcome Bento Box Card
        const InfluencerWelcomeCardSkeleton(),
        const SizedBox(height: 20),
        // Analytics Grid (Matches, ER, Views, Milestones)
        Row(
          children: [
            Expanded(child: const InfluencerStatCardSkeleton(title: 'Total Matches')),
            const SizedBox(width: 12),
            Expanded(child: const InfluencerStatCardSkeleton(title: 'Engagement Rate')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: const InfluencerStatCardSkeleton(title: 'Profile Views')),
            const SizedBox(width: 12),
            Expanded(child: const InfluencerStatCardSkeleton(title: 'Completed Milestones')),
          ],
        ),
        const SizedBox(height: 20),
        // Upcoming deliverables
        const InfluencerDeliverablesSkeleton(),
        const SizedBox(height: 16),
        // Featured Partners
        const InfluencerFeaturedPartnersSkeleton(),
        const SizedBox(height: 16),
        // Campaign Matches
        const InfluencerCampaignMatchesSkeleton(),
        
        // Footer text
        const SizedBox(height: 56),
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'With love,',
                style: GoogleFonts.inter(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'from Promo.',
                style: GoogleFonts.inter(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Discover Page Skeleton for Influencers
class InfluencerDiscoverSkeleton extends StatelessWidget {
  const InfluencerDiscoverSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Column(
      children: [
        // Sort & count row
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.pageMarginHorizontal, 10, AppSpacing.pageMarginHorizontal, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonShimmer(
                child: Container(
                  width: 70,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.sort,
                      size: 14,
                      color: (isDark ? AppColors.textSecondary : const Color(0xFF6E6E73)).withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 6),
                    SkeletonShimmer(
                      child: Container(
                        width: 45,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: (isDark ? AppColors.textSecondary : const Color(0xFF6E6E73)).withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Campaign list skeleton
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMarginHorizontal,
              AppSpacing.pageMarginVertical,
              AppSpacing.pageMarginHorizontal,
              AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
            ),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => const BentoListCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

/// Bento-Style Creator Welcome Card Skeleton
class InfluencerWelcomeCardSkeleton extends StatelessWidget {
  const InfluencerWelcomeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SkeletonShimmer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 90,
                        height: 11,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 150,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 110,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SkeletonShimmer(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: isDark ? const Color(0xFF1C1C21) : const Color(0xFFF1F1F5),
          ),
          const SizedBox(height: 16),
          // Completeness meter skeleton
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonShimmer(
                    child: Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  SkeletonShimmer(
                    child: Container(
                      width: 30,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Linear progress indicator skeleton
              SkeletonShimmer(
                child: Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonShimmer(
                    child: Container(
                      width: 200,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SkeletonShimmer(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bento-Style Creator Stat Card Skeleton
class InfluencerStatCardSkeleton extends StatelessWidget {
  final String title;
  const InfluencerStatCardSkeleton({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    Color bgColor;
    if (title == 'Total Matches') {
      bgColor = isDark ? const Color(0xFF0C243C) : const Color(0xFFD0ECFC);
    } else if (title == 'Engagement Rate') {
      bgColor = isDark ? const Color(0xFF0D3E26) : const Color(0xFFC1F0D5);
    } else if (title == 'Profile Views') {
      bgColor = isDark ? const Color(0xFF481030) : const Color(0xFFFCD3E6);
    } else { // Completed Milestones
      bgColor = isDark ? const Color(0xFF482B08) : const Color(0xFFFDE2B5);
    }

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28.0),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: SkeletonShimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: 50,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 90,
                height: 11,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bento-Style Upcoming Deliverables Skeleton
class InfluencerDeliverablesSkeleton extends StatelessWidget {
  const InfluencerDeliverablesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141417) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Iconsax.calendar_15,
                      color: (isDark ? AppColors.textSecondary : const Color(0xFF6E6E73)).withValues(alpha: 0.4),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SkeletonShimmer(
                    child: Container(
                      width: 130,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C21) : const Color(0xFFF1F1F5),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: SkeletonShimmer(
                  child: Container(
                    width: 60,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Deliverables List Items (3 items)
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                height: 1,
                color: isDark ? const Color(0xFF1F1F24) : const Color(0xFFF1F1F5),
              ),
            ),
            itemBuilder: (context, idx) {
              return Row(
                children: [
                  SkeletonShimmer(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SkeletonShimmer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 110,
                            height: 11,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 80,
                            height: 9,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SkeletonShimmer(
                    child: Container(
                      width: 55,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Bento-Style Featured Partners Skeleton
class InfluencerFeaturedPartnersSkeleton extends StatelessWidget {
  const InfluencerFeaturedPartnersSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.only(top: 18, bottom: 18, left: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141417) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Iconsax.star5,
                        color: (isDark ? AppColors.textSecondary : const Color(0xFF6E6E73)).withValues(alpha: 0.4),
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SkeletonShimmer(
                      child: Container(
                        width: 110,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C21) : const Color(0xFFF1F1F5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: SkeletonShimmer(
                    child: Container(
                      width: 40,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 125,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (context, i) {
                return Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      SkeletonShimmer(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SkeletonShimmer(
                        child: Container(
                          width: 60,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SkeletonShimmer(
                        child: Container(
                          width: 50,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bento-Style Campaign Matches Skeleton
class InfluencerCampaignMatchesSkeleton extends StatelessWidget {
  const InfluencerCampaignMatchesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141417) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: (isDark ? AppColors.textSecondary : const Color(0xFF6E6E73)).withValues(alpha: 0.4),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SkeletonShimmer(
                    child: Container(
                      width: 130,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C21) : const Color(0xFFF1F1F5),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: SkeletonShimmer(
                  child: Container(
                    width: 45,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Campaign Matches Rows (3 items)
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                height: 1,
                color: isDark ? const Color(0xFF1F1F24) : const Color(0xFFF1F1F5),
              ),
            ),
            itemBuilder: (context, index) {
              return Row(
                children: [
                  SkeletonShimmer(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SkeletonShimmer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 140,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 90,
                            height: 9,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                width: 50,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class BrandHomeBodySkeleton extends StatelessWidget {
  const BrandHomeBodySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical,
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
      ),
      children: [
        // Welcome Bento Box Card
        const BrandWelcomeCardSkeleton(),
        const SizedBox(height: 12),
        // Stats Grid
        Row(
          children: [
            Expanded(child: const BrandStatCardSkeleton(title: 'Active Cards')),
            const SizedBox(width: 12),
            Expanded(child: const BrandStatCardSkeleton(title: 'Applications')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: const BrandStatCardSkeleton(title: 'Active Chats')),
            const SizedBox(width: 12),
            Expanded(child: const BrandStatCardSkeleton(title: 'Accepted Deals')),
          ],
        ),
        const SizedBox(height: 16),
        // Quick Actions Card
        const BrandQuickActionsSkeleton(),
        const SizedBox(height: 16),
        // Featured Creators Card
        const BrandFeaturedCreatorsSkeleton(),
        const SizedBox(height: 16),
        // Tip of the Day Card
        const BrandTipCardSkeleton(),
        const SizedBox(height: 16),
        // Recent Activity Card
        const BrandRecentActivitySkeleton(),
        
        // Footer text
        const SizedBox(height: 56),
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'With love,',
                style: GoogleFonts.inter(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'from Promo.',
                style: GoogleFonts.inter(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bento-Style Welcome Card Skeleton
class BrandWelcomeCardSkeleton extends StatelessWidget {
  const BrandWelcomeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SkeletonShimmer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 90,
                        height: 11,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 150,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 110,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SkeletonShimmer(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Verified banner skeleton (standard grey/white container)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141417) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                SkeletonShimmer(
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SkeletonShimmer(
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bento-Style Stat Card Skeleton
class BrandStatCardSkeleton extends StatelessWidget {
  final String title;
  const BrandStatCardSkeleton({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    Color bgColor;
    if (title == 'Active Cards') {
      bgColor = isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF);
    } else if (title == 'Applications') {
      bgColor = isDark ? const Color(0xFF4C0519) : const Color(0xFFFFE4E6);
    } else if (title == 'Active Chats') {
      bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
    } else { // Accepted Deals
      bgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
    }

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28.0),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: SkeletonShimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: 50,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 90,
                height: 11,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bento-Style Quick Actions Card Skeleton
class BrandQuickActionsSkeleton extends StatelessWidget {
  const BrandQuickActionsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141417) : const Color(0xFFF9FAFB),
                  shape: BoxShape.circle,
                ),
                child: Icon(Iconsax.flash, size: 16, color: (isDark ? AppColors.textSecondary : const Color(0xFF6E6E73)).withValues(alpha: 0.4)),
              ),
              const SizedBox(width: 10),
              SkeletonShimmer(
                child: Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // First button skeleton
          SkeletonShimmer(
            child: Container(
              height: 48,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Second button skeleton
          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.receive_square, size: 18, color: (isDark ? AppColors.textSecondary : const Color(0xFF6E6E73)).withValues(alpha: 0.4)),
                const SizedBox(width: 8),
                SkeletonShimmer(
                  child: Container(
                    width: 120,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bento-Style Featured Creators Card Skeleton
class BrandFeaturedCreatorsSkeleton extends StatelessWidget {
  const BrandFeaturedCreatorsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.only(top: 18, bottom: 18, left: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141417) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Iconsax.star5,
                        color: (isDark ? AppColors.textSecondary : const Color(0xFF6E6E73)).withValues(alpha: 0.4),
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SkeletonShimmer(
                      child: Container(
                        width: 120,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C21) : const Color(0xFFF1F1F5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: SkeletonShimmer(
                    child: Container(
                      width: 40,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 135,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (context, i) {
                return Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      SkeletonShimmer(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SkeletonShimmer(
                        child: Container(
                          width: 65,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SkeletonShimmer(
                        child: Container(
                          width: 50,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bento-Style Tip Card Skeleton
class BrandTipCardSkeleton extends StatelessWidget {
  const BrandTipCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B).withValues(alpha: 0.95), const Color(0xFF0F0F17).withValues(alpha: 0.95)]
              : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark 
              ? const Color(0xFF3B0764).withValues(alpha: 0.2) 
              : const Color(0xFFC084FC).withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFA855F7).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFA855F7).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(
              Iconsax.lamp_on,
              color: const Color(0xFFA855F7).withValues(alpha: 0.5),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonShimmer(
                  child: Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SkeletonShimmer(
                  child: Container(
                    width: double.infinity,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SkeletonShimmer(
                  child: Container(
                    width: 160,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bento-Style Recent Activity Card Skeleton
class BrandRecentActivitySkeleton extends StatelessWidget {
  const BrandRecentActivitySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Iconsax.notification,
                  color: AppColors.accent.withValues(alpha: 0.4),
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              SkeletonShimmer(
                child: Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(2, (i) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent.withValues(alpha: 0.1),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.25), width: 2),
                            ),
                          ),
                          if (i < 1)
                            Expanded(
                              child: Container(
                                width: 1.5,
                                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonShimmer(
                              child: Container(
                                width: 140,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SkeletonShimmer(
                              child: Container(
                                width: double.infinity,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SkeletonShimmer(
                              child: Container(
                                width: 80,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Bento-Style Discover Card Skeleton
class BentoListCardSkeleton extends StatelessWidget {
  const BentoListCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
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
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: SkeletonShimmer(
        child: Row(
          children: [
            // Cover image skeleton
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 14),
            // Details skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand & category row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 60,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 45,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Title text line
                  Container(
                    width: double.infinity,
                    height: 13,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Bottom row (Location on left, platforms/budget on right)
                  Row(
                    children: [
                      // Location indicator icon mock
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 50,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Spacer(),
                      // Platform icon mock
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 60,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
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
    );
  }
}

/// Bento-Style Application Card Skeleton
class BentoApplicationCardSkeleton extends StatelessWidget {
  const BentoApplicationCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      padding: EdgeInsets.all(16),
      child: SkeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonCircle(size: 32),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonText(width: 80, height: 12),
                      SizedBox(height: 4),
                      SkeletonText(width: 40, height: 10),
                    ],
                  ),
                ),
                SkeletonBox(width: 60, height: 20, borderRadius: 10),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                SkeletonBox(width: 64, height: 64, borderRadius: 14),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonText(width: double.infinity, height: 14),
                      SizedBox(height: 6),
                      SkeletonText(width: 120, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            SkeletonText(width: double.infinity, height: 12),
            SizedBox(height: 6),
            SkeletonText(width: 180, height: 12),
          ],
        ),
      ),
    );
  }
}

/// Campaign Card Skeleton
class CampaignCardSkeleton extends StatelessWidget {
  const CampaignCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonImage(aspectRatio: 16 / 9, borderRadius: 0),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      SkeletonCircle(size: 24),
                      SizedBox(width: 8),
                      SkeletonText(width: 80, height: 12),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const SkeletonText(width: 180, height: 18),
                  const SizedBox(height: 8),
                  const SkeletonText(width: double.infinity, height: 12),
                  const SizedBox(height: 4),
                  const SkeletonText(width: 240, height: 12),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonText(width: 40, height: 8),
                      SizedBox(height: 4),
                      SkeletonText(width: 80, height: 14),
                    ],
                  ),
                  SkeletonBox(width: 70, height: 32, borderRadius: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bento Brand Card Skeleton
class BentoBrandCardSkeleton extends StatelessWidget {
  const BentoBrandCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SkeletonShimmer(
          child: Stack(
            children: [
              Row(
                children: [
                  // Cover image placeholder on left: 68x68, rounded corners 16
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Details on right
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category tag placeholder
                        Container(
                          width: 50,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        // Title placeholder (double lines to match loaded height)
                        const SizedBox(height: 8),
                        const SkeletonText(width: 180, height: 14),
                        const SizedBox(height: 6),
                        const SkeletonText(width: 110, height: 14),
                        const SizedBox(height: 12),
                        // Bottom metadata row placeholder
                        Row(
                          children: [
                            // Wallet icon placeholder
                            Container(
                              width: 13,
                              height: 13,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const SkeletonText(width: 35, height: 10),
                            const Spacer(),
                            // User icon placeholder
                            Container(
                              width: 13,
                              height: 13,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const SkeletonText(width: 60, height: 10),
                            const SizedBox(width: 8),
                            // Platform requirements placeholder
                            Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Status pill placeholder at top right
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 50,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brand Tile Skeleton
class BrandTileSkeleton extends StatelessWidget {
  const BrandTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Row(
        children: [
          SkeletonCircle(size: 48),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 120, height: 14),
                SizedBox(height: 4),
                SkeletonText(width: 70, height: 10),
                SizedBox(height: 4),
                SkeletonText(width: 90, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Notification Tile Skeleton
class NotificationTileSkeleton extends StatelessWidget {
  const NotificationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: SkeletonShimmer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonCircle(size: 40),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(width: 140, height: 13),
                  SizedBox(height: 6),
                  SkeletonText(width: 180, height: 10),
                  SizedBox(height: 6),
                  SkeletonText(width: 80, height: 9),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Unread dot placeholder
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Application Card Skeleton
class ApplicationCardSkeleton extends StatelessWidget {
  final bool isPending;
  const ApplicationCardSkeleton({super.key, this.isPending = true});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: SkeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Details + Status Pill
            Row(
              children: [
                const SkeletonCircle(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonText(width: 110, height: 14),
                      const SizedBox(height: 4),
                      const SkeletonText(width: 70, height: 10),
                    ],
                  ),
                ),
                // Status Pill placeholder
                Container(
                  width: 64,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Bio/Message Text
            const SkeletonText(width: double.infinity, height: 11),
            const SizedBox(height: 8),
            // Proposed Rate Text
            const SkeletonText(width: 150, height: 11),
            const SizedBox(height: 16),
            if (isPending) ...[
              // Action Buttons for Pending application
              Row(
                children: [
                  // Accept capsule button
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Reject circle button
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Portfolio Attachments Header
              const SkeletonText(width: 120, height: 10),
              const SizedBox(height: 8),
              // Attachment link chip
              Container(
                width: 140,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              // Deliverables & Progress Bento Box
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141417) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SkeletonText(width: 120, height: 10),
                        SkeletonText(width: 60, height: 10),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SkeletonText(width: 100, height: 11),
                              const SizedBox(height: 4),
                              const SkeletonText(width: 80, height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: SkeletonText(width: 90, height: 10),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chat Tile Skeleton
class ChatTileSkeleton extends StatelessWidget {
  const ChatTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: SkeletonShimmer(
        child: Row(
          children: [
            // Avatar Stack with online dot placeholder
            Stack(
              children: [
                SkeletonCircle(size: 50),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: SkeletonCircle(size: 12),
                ),
              ],
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonText(width: 120, height: 14),
                      SkeletonText(width: 40, height: 10),
                    ],
                  ),
                  SizedBox(height: 6),
                  SkeletonText(width: 180, height: 11),
                ],
              ),
            ),
            SizedBox(width: 8),
            // Right-side chevron or unread badge placeholder
            SkeletonCircle(size: 16),
          ],
        ),
      ),
    );
  }
}

/// Stats Grid Skeleton
class StatGridSkeleton extends StatelessWidget {
  final int count;
  const StatGridSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: List.generate(
        count,
        (_) => const SkeletonCard(padding: EdgeInsets.zero),
      ),
    );
  }
}

/// Profile Detail Skeleton
class ProfileDetailSkeleton extends StatelessWidget {
  const ProfileDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMarginHorizontal,
        8.0,
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
      ),
      children: [
        // Main Profile Info Bento Card
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0F11) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: SkeletonShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Stack with online dot placeholder: size 72
                    Stack(
                      children: [
                        const SkeletonCircle(size: 72),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Name and details
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SkeletonText(width: 100, height: 16),
                              SizedBox(width: 4),
                              SkeletonCircle(size: 13),
                            ],
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              SkeletonCircle(size: 12),
                              SizedBox(width: 4),
                              SkeletonText(width: 80, height: 10),
                            ],
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              SkeletonCircle(size: 12),
                              SizedBox(width: 4),
                              SkeletonText(width: 130, height: 10),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Edit button placeholder
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Bio text
                const SkeletonText(width: double.infinity, height: 11),
                const SizedBox(height: 6),
                const SkeletonText(width: 240, height: 11),
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  color: Colors.white24,
                ),
                const SizedBox(height: 16),
                // Stats Row (4 stats)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(4, (index) {
                    return const Column(
                      children: [
                        SkeletonText(width: 30, height: 16),
                        SizedBox(height: 6),
                        SkeletonText(width: 50, height: 10),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Row of 3 action buttons: Campaigns, Chats, Settings
        SkeletonShimmer(
          child: Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 6,
                    right: index == 2 ? 0 : 6,
                  ),
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 24),
        // My Cards Header
        SkeletonShimmer(
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonText(width: 80, height: 16),
              SkeletonText(width: 40, height: 12),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Grid of 2 cover cards
        Row(
          children: [
            Expanded(child: const BentoGridCardSkeleton()),
            const SizedBox(width: 12),
            Expanded(child: const BentoGridCardSkeleton()),
          ],
        ),
      ],
    );
  }
}

// Helper Widget: BentoGridCardSkeleton
class BentoGridCardSkeleton extends StatelessWidget {
  const BentoGridCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image placeholder
            const AspectRatio(
              aspectRatio: 1,
              child: SkeletonShimmer(
                child: ColoredBox(color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SkeletonShimmer(
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(width: 110, height: 13),
                    SizedBox(height: 6),
                    SkeletonText(width: 80, height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search Results Skeleton
class SearchResultsSkeleton extends StatelessWidget {
  const SearchResultsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageMarginHorizontal,
        vertical: AppSpacing.pageMarginVertical,
      ),
      children: [
        // Brands Section Header
        const SkeletonShimmer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonText(width: 70, height: 16),
              SkeletonText(width: 20, height: 12),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Brands list (3 items)
        ...List.generate(3, (i) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _SearchBrandTileSkeleton(),
          );
        }),
        const SizedBox(height: 16),
        // Influencers Section Header
        const SkeletonShimmer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonText(width: 100, height: 16),
              SkeletonText(width: 20, height: 12),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Influencers list (2 items)
        ...List.generate(2, (i) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _SearchInfluencerTileSkeleton(),
          );
        }),
      ],
    );
  }
}

class _SearchBrandTileSkeleton extends StatelessWidget {
  const _SearchBrandTileSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: const SkeletonShimmer(
        child: Row(
          children: [
            SkeletonCircle(size: 50),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonText(width: 80, height: 13),
                      SizedBox(width: 6),
                      SkeletonBox(width: 40, height: 14, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 6),
                  SkeletonText(width: 140, height: 10),
                ],
              ),
            ),
            SizedBox(width: 8),
            SkeletonCircle(size: 16),
          ],
        ),
      ),
    );
  }
}

class _SearchInfluencerTileSkeleton extends StatelessWidget {
  const _SearchInfluencerTileSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: const SkeletonShimmer(
        child: Row(
          children: [
            SkeletonCircle(size: 50),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonText(width: 100, height: 13),
                      SizedBox(width: 6),
                      SkeletonBox(width: 48, height: 14, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      SkeletonBox(width: 35, height: 12, borderRadius: 4),
                      SizedBox(width: 4),
                      SkeletonBox(width: 42, height: 12, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 6),
                  SkeletonText(width: 180, height: 10),
                ],
              ),
            ),
            SizedBox(width: 8),
            SkeletonCircle(size: 16),
          ],
        ),
      ),
    );
  }
}

/// Settings List Skeleton
class SettingsListSkeleton extends StatelessWidget {
  final int count;
  const SettingsListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: List.generate(
        count,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SkeletonBox(width: 36, height: 36, borderRadius: 10),
                SizedBox(width: 12),
                Expanded(child: SkeletonText(width: 120, height: 14)),
                SkeletonBox(width: 16, height: 16, borderRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bento Influencer Card Skeleton
class BentoInfluencerCardSkeleton extends StatelessWidget {
  const BentoInfluencerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SkeletonShimmer(
          child: Row(
            children: [
              // Avatar circle placeholder on left: size 54
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              // Details column on right
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name placeholder
                    const SkeletonText(width: 140, height: 14),
                    const SizedBox(height: 8),
                    // Niches capsules placeholder
                    Row(
                      children: [
                        Container(
                          width: 45,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 40,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Metrics row placeholder
                    Row(
                      children: [
                        // People icon placeholder
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const SkeletonText(width: 70, height: 10),
                        const SizedBox(width: 12),
                        // Location icon placeholder
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const SkeletonText(width: 60, height: 10),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic List Tile Skeleton
class GenericListTileSkeleton extends StatelessWidget {
  const GenericListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Row(
        children: [
          SkeletonCircle(size: 40),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 140, height: 14),
                SizedBox(height: 6),
                SkeletonText(width: 90, height: 10),
              ],
            ),
          ),
          SkeletonCircle(size: 18),
        ],
      ),
    );
  }
}

/// Card Detail Screen Skeleton
class CardDetailSkeleton extends StatelessWidget {
  const CardDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final borderColor = isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB);
    final surfaceColor = isDark ? const Color(0xFF0F0F11) : Colors.white;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical,
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
      ),
      children: [
        // ── 1. Cover Image (16:9) ──
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: SkeletonShimmer(
              child: Container(
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── 2. Brand Owner Card ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              SkeletonShimmer(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonShimmer(
                      child: Container(
                        width: 120,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SkeletonShimmer(
                      child: Container(
                        width: 60,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Iconsax.arrow_right_3, color: AppColors.textMuted.withValues(alpha: 0.4), size: 18),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 3. Category pill ──
        Row(
          children: [
            SkeletonShimmer(
              child: Container(
                width: 60,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── 4. Title ──
        SkeletonShimmer(
          child: Container(
            width: 220,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── 5. Description ──
        SkeletonShimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 260,
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Divider(color: borderColor, thickness: 1.2),
        const SizedBox(height: 24),

        // ── 6. Follower requirement banner ──
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: const Color(0xFF10B981).withValues(alpha: 0.4), size: 20),
              const SizedBox(width: 12),
              SkeletonShimmer(
                child: Container(
                  width: 200,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── 7. CAMPAIGN METRICS Header ──
        SkeletonShimmer(
          child: Container(
            width: 100,
            height: 9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── 8. Metrics Grid (2x2) ──
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          padding: EdgeInsets.zero,
          children: [
            _buildBentoTileSkeleton(surfaceColor, borderColor, const Color(0xFF6366F1)),
            _buildBentoTileSkeleton(surfaceColor, borderColor, const Color(0xFF10B981)),
            _buildBentoTileSkeleton(surfaceColor, borderColor, const Color(0xFFF59E0B)),
            _buildBentoTileSkeleton(surfaceColor, borderColor, const Color(0xFFF43F5E)),
          ],
        ),
        const SizedBox(height: 12),

        // ── 9. Positions alert container ──
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Iconsax.profile_2user, color: AppColors.accent.withValues(alpha: 0.4), size: 20),
              const SizedBox(width: 12),
              SkeletonShimmer(
                child: Container(
                  width: 180,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── 10. Required Deliverables ──
        SkeletonShimmer(
          child: Container(
            width: 140,
            height: 9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: List.generate(2, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: AppColors.accent.withValues(alpha: 0.4), size: 18),
                    const SizedBox(width: 10),
                    SkeletonShimmer(
                      child: Container(
                        width: index == 0 ? 150 : 120,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildBentoTileSkeleton(Color surfaceColor, Color borderColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: SkeletonShimmer(
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonShimmer(
                  child: Container(
                    width: 50,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SkeletonShimmer(
                  child: Container(
                    width: 70,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Influencer Grid Card Skeleton
class InfluencerGridSkeleton extends StatelessWidget {
  const InfluencerGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Column(
        children: [
          SkeletonCircle(size: 56),
          SizedBox(height: 8),
          SkeletonText(width: 80, height: 12),
          SizedBox(height: 4),
          SkeletonText(width: 60, height: 10),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkeletonBox(width: 30, height: 16, borderRadius: 4),
              SizedBox(width: 12),
              SkeletonBox(width: 30, height: 16, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Analytics Screen Skeleton
class AnalyticsScreenSkeleton extends StatelessWidget {
  const AnalyticsScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical,
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
      ),
      children: [
        const StatGridSkeleton(count: 4),
        const SizedBox(height: 24),
        const SkeletonCard(height: 200, padding: EdgeInsets.zero),
        const SizedBox(height: 24),
        const SkeletonCard(height: 180, padding: EdgeInsets.zero),
      ],
    );
  }
}

/// Chat Room Skeleton
class ChatRoomSkeleton extends StatelessWidget {
  const ChatRoomSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;

    return Column(
      children: [
        // ── 1. Contract prompt banner ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            border: Border(
              bottom: BorderSide(color: AppColors.accent.withValues(alpha: 0.15), width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(Iconsax.document_text, size: 16, color: AppColors.accent.withValues(alpha: 0.5)),
              const SizedBox(width: 10),
              Expanded(
                child: SkeletonShimmer(
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SkeletonShimmer(
                  child: Container(
                    width: 95,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 2. Message list area ──
        Expanded(
          child: ListView(
            reverse: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // --- Latest sent text bubble (bottom) ---
              _buildSentBubble(
                isDark: isDark,
                contentWidth: 80,
                contentHeight: 14,
              ),
              const SizedBox(height: 10),

              // --- Sent image bubble ---
              _buildSentImageBubble(isDark: isDark),
              const SizedBox(height: 10),

              // --- Sent text bubble ---
              _buildSentBubble(
                isDark: isDark,
                contentWidth: 120,
                contentHeight: 14,
              ),
              const SizedBox(height: 10),

              // --- Date separator "TODAY" ---
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: SkeletonShimmer(
                    child: Container(
                      width: 42,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),

              // --- Received image bubble ---
              _buildReceivedImageBubble(isDark: isDark),
              const SizedBox(height: 10),

              // --- Received text bubble ---
              _buildReceivedBubble(
                isDark: isDark,
                contentWidth: 160,
                contentHeight: 14,
              ),
              const SizedBox(height: 10),

              // --- Sent text bubble ---
              _buildSentBubble(
                isDark: isDark,
                contentWidth: 140,
                contentHeight: 14,
              ),
            ],
          ),
        ),

        // ── 3. Bottom input bar ──
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFF0F0F0),
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            8, 8, 8,
            MediaQuery.of(context).padding.bottom + 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Plus icon
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(bottom: 2),
                alignment: Alignment.center,
                child: Icon(
                  Iconsax.add,
                  color: (isDark ? AppColors.textSecondary : const Color(0xFF6E6E73)).withValues(alpha: 0.4),
                  size: 24,
                ),
              ),
              const SizedBox(width: 4),
              // Input field
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8E8ED),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Type a message...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send button
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Iconsax.send_1, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Sent message bubble (right-aligned, accent-colored)
  Widget _buildSentBubble({required bool isDark, required double contentWidth, required double contentHeight}) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Text content
              SkeletonShimmer(
                child: Container(
                  width: contentWidth,
                  height: contentHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Timestamp + read receipts row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  Container(
                    width: 45,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Double tick (read receipt)
                  Icon(Iconsax.tick_circle, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sent image bubble (right-aligned, accent-colored)
  Widget _buildSentImageBubble({required bool isDark}) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SkeletonShimmer(
                  child: Container(
                    width: 220,
                    height: 140,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // "Shared a photo" caption
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 90,
                  height: 11,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Timestamp + read receipts
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  Container(
                    width: 45,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Iconsax.tick_circle, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Received message bubble (left-aligned, surface2-colored)
  Widget _buildReceivedBubble({required bool isDark, required double contentWidth, required double contentHeight}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sender name
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: SkeletonShimmer(
                  child: Container(
                    width: 80,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              // Text content
              SkeletonShimmer(
                child: Container(
                  width: contentWidth,
                  height: contentHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Timestamp row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  SkeletonShimmer(
                    child: Container(
                      width: 45,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Received image bubble (left-aligned)
  Widget _buildReceivedImageBubble({required bool isDark}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sender name
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: SkeletonShimmer(
                  child: Container(
                    width: 90,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              // Image placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SkeletonShimmer(
                  child: Container(
                    width: 220,
                    height: 130,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // "Shared a photo" caption
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SkeletonShimmer(
                  child: Container(
                    width: 90,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Timestamp row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  SkeletonShimmer(
                    child: Container(
                      width: 45,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AcceptedDealCardSkeleton extends StatelessWidget {
  const AcceptedDealCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SkeletonShimmer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image square with overlay badge placeholder
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Positioned(
                  bottom: -6,
                  right: -6,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Right Side Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status + Date Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Status pill
                      Container(
                        width: 90,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      // Date text
                      const SkeletonText(width: 70, height: 10),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Deal Title
                  const SkeletonText(width: 150, height: 14),
                  const SizedBox(height: 6),
                  // Partner text
                  const SkeletonText(width: 180, height: 10),
                  const SizedBox(height: 6),
                  // Budget range (with icon space simulated)
                  const Row(
                    children: [
                      SkeletonCircle(size: 12),
                      SizedBox(width: 4),
                      SkeletonText(width: 90, height: 10),
                    ],
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

class CreatorBrandDetailSkeleton extends StatelessWidget {
  const CreatorBrandDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Banner Image & Overlay avatar stack (Matches the loaded cover overlap layout)
        SizedBox(
          height: 160.0 + statusBarHeight,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              // Cover Image loaded instantly from local assets
              Image.asset(
                'assets/Logo.png',
                fit: BoxFit.cover,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            AppColors.accent.withValues(alpha: 0.25),
                            AppColors.purple.withValues(alpha: 0.15),
                            Colors.transparent,
                          ]
                        : [
                            AppColors.accent.withValues(alpha: 0.2),
                            AppColors.purple.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Back Button placeholder
              Positioned(
                top: statusBarHeight + 8,
                left: 12,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Bookmark Button placeholder
              Positioned(
                top: statusBarHeight + 8,
                right: 56,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // More Button placeholder
              Positioned(
                top: statusBarHeight + 8,
                right: 12,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Overlapping Avatar and details
              Positioned(
                bottom: -36, // Overlap cover by 36 (half of 72 avatar size)
                left: AppSpacing.pageMarginHorizontal,
                right: AppSpacing.pageMarginHorizontal,
                child: SkeletonShimmer(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Avatar circle with border placeholder
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
                            width: 4,
                          ),
                        ),
                        child: const SkeletonCircle(size: 72),
                      ),
                      const SizedBox(width: 14),
                      // Details columns
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SkeletonText(width: 160, height: 16),
                              SizedBox(height: 6),
                              SkeletonText(width: 220, height: 10),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36), // spacing to clear the overlapping avatar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Stats bar (3 columns)
              Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        left: index == 0 ? 0 : 5,
                        right: index == 2 ? 0 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const SkeletonShimmer(
                        child: Column(
                          children: [
                            SkeletonCircle(size: 16),
                            SizedBox(height: 6),
                            SkeletonText(width: 20, height: 14),
                            SizedBox(height: 4),
                            SkeletonText(width: 50, height: 9),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              // Action Buttons: Message capsule + bookmark circle
              SkeletonShimmer(
                child: Row(
                  children: [
                    // Message capsule
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Bookmark circle
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Custom Tab Bar: About, Portfolio, Reviews
              SkeletonShimmer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Container(
                      width: 60,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 70,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 16),
              // Tab Content: About Info Cards
              // Card 1: TRUST & VERIFICATION
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: SkeletonShimmer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          SkeletonCircle(size: 14),
                          SizedBox(width: 8),
                          SkeletonText(width: 150, height: 12),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(3, (index) {
                          return Container(
                            width: 130.0 + (index * 10),
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Card 2: Bio
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: const SkeletonShimmer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkeletonCircle(size: 14),
                          SizedBox(width: 8),
                          SkeletonText(width: 40, height: 12),
                        ],
                      ),
                      SizedBox(height: 16),
                      SkeletonText(width: double.infinity, height: 11),
                      SizedBox(height: 6),
                      SkeletonText(width: 240, height: 11),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Card 3: Niches
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: const SkeletonShimmer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkeletonCircle(size: 14),
                          SizedBox(width: 8),
                          SkeletonText(width: 60, height: 12),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          SkeletonBox(width: 70, height: 26, borderRadius: 100),
                          SizedBox(width: 8),
                          SkeletonBox(width: 60, height: 26, borderRadius: 100),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding),
            ],
          ),
        ),
      ],
    );
  }
}

class CreateCampaignSkeleton extends StatelessWidget {
  const CreateCampaignSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final borderColor = isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB);
    final fieldColor = isDark ? const Color(0xFF0F0F11) : const Color(0xFFF3F3F5);

    return Column(
      children: [
        // 1. Stepper indicator (static / non-shimmering outer circles)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0F11) : Colors.white,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(7, (idx) {
              if (idx.isOdd) {
                return Container(
                  width: 50,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                );
              } else {
                final stepIndex = idx ~/ 2;
                final isActive = stepIndex == 0;
                return Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? AppColors.accent
                        : (isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? Colors.white
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                );
              }
            }),
          ),
        ),
        // 2. Body Fields area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Basic Campaign Details" heading
                SkeletonShimmer(
                  child: Container(
                    width: 180,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // CAMPAIGN TITLE label
                SkeletonShimmer(
                  child: Container(
                    width: 100,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Title Field Outline Box
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: fieldColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: SkeletonShimmer(
                    child: Container(
                      width: 160,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // DESCRIPTION label
                SkeletonShimmer(
                  child: Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Description Field Outline Box
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: fieldColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SkeletonShimmer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 240,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // CAMPAIGN TYPE label
                SkeletonShimmer(
                  child: Container(
                    width: 90,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Campaign Type Selector Box
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: fieldColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonShimmer(
                        child: Container(
                          width: 100,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down_rounded, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // PRIMARY CATEGORY label
                SkeletonShimmer(
                  child: Container(
                    width: 110,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ChoiceChips Flow List
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: List.generate(8, (index) {
                    final isSelected = index == 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? AppColors.accent.withValues(alpha: 0.3) : AppColors.accent.withValues(alpha: 0.15))
                            : fieldColor,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : borderColor,
                          width: 1.2,
                        ),
                      ),
                      child: SkeletonShimmer(
                        child: Container(
                          width: 45.0 + (index % 3) * 8,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accent : Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // CAMPAIGN COVER IMAGE label
                SkeletonShimmer(
                  child: Container(
                    width: 130,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Horizontal list of preset/upload images
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Upload Cover Card
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: fieldColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.image, size: 24, color: isDark ? Colors.grey[700] : Colors.grey[400]),
                            const SizedBox(height: 6),
                            SkeletonShimmer(
                              child: Container(
                                width: 50,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Preset image 1 (with tick overlay simulated)
                      Container(
                        width: 120,
                        height: 90,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141416) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Preset image 2
                      Container(
                        width: 120,
                        height: 90,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141416) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // 3. Bottom Continue Button Capsule
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0F11) : Colors.white,
            border: Border(top: BorderSide(color: borderColor, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.black,
                borderRadius: BorderRadius.circular(100),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
