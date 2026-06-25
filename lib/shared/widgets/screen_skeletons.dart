import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_skeleton.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN-SPECIFIC SKELETON WIDGETS
// Handcrafted skeletons mapping to actual layout structures.
// ─────────────────────────────────────────────────────────────────────────────

/// Home Screen Skeleton for Influencers
class InfluencerHomeSkeleton extends StatelessWidget {
  const InfluencerHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
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
            titleSpacing: 0,
            title: const SkeletonShimmer(
              child: SkeletonText(width: 100, height: 24),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: SkeletonShimmer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMarginHorizontal,
            AppSpacing.pageMarginVertical,
            AppSpacing.pageMarginHorizontal,
            AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
          ),
          children: [
            // Welcome & Profile Card
            const SkeletonCard(height: 160),
            const SizedBox(height: 16),
            // Analytics Grid
            Row(
              children: [
                Expanded(child: const SkeletonCard(height: 135)),
                const SizedBox(width: 12),
                Expanded(child: const SkeletonCard(height: 135)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: const SkeletonCard(height: 135)),
                const SizedBox(width: 12),
                Expanded(child: const SkeletonCard(height: 135)),
              ],
            ),
            const SizedBox(height: 16),
            // Deliverables Card
            const SkeletonCard(height: 120),
            const SizedBox(height: 16),
            // Featured Partners Card
            const SkeletonCard(height: 190),
          ],
        ),
      ),
    );
  }
}

/// Home Screen Skeleton for Brands
class BrandHomeSkeleton extends StatelessWidget {
  const BrandHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
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
            titleSpacing: 0,
            title: const SkeletonShimmer(
              child: SkeletonText(width: 100, height: 24),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: SkeletonShimmer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMarginHorizontal,
            AppSpacing.pageMarginVertical,
            AppSpacing.pageMarginHorizontal,
            AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
          ),
          children: [
            // Welcome Bento Box Card
            const SkeletonCard(height: 160),
            const SizedBox(height: 16),
            // Stats Grid
            Row(
              children: [
                Expanded(child: const SkeletonCard(height: 100)),
                const SizedBox(width: 12),
                Expanded(child: const SkeletonCard(height: 100)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: const SkeletonCard(height: 100)),
                const SizedBox(width: 12),
                Expanded(child: const SkeletonCard(height: 100)),
              ],
            ),
            const SizedBox(height: 16),
            // Quick Actions Card
            const SkeletonCard(height: 150),
            const SizedBox(height: 16),
            // Featured Creators Card
            const SkeletonCard(height: 190),
          ],
        ),
      ),
    );
  }
}

/// Bento-Style Discover Card Skeleton
class BentoListCardSkeleton extends StatelessWidget {
  const BentoListCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          SkeletonBox(width: 88, height: 88, borderRadius: 16),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SkeletonCircle(size: 18),
                        SizedBox(width: 6),
                        SkeletonText(width: 50, height: 10),
                      ],
                    ),
                    SkeletonBox(width: 45, height: 16, borderRadius: 6),
                  ],
                ),
                SizedBox(height: 8),
                SkeletonText(width: double.infinity, height: 14),
                SizedBox(height: 4),
                SkeletonText(width: 100, height: 14),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonText(width: 60, height: 10),
                    SkeletonText(width: 50, height: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonCircle(size: 36),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 160, height: 13),
                SizedBox(height: 6),
                SkeletonText(width: double.infinity, height: 10),
                SizedBox(height: 4),
                SkeletonText(width: 60, height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Application Card Skeleton
class ApplicationCardSkeleton extends StatelessWidget {
  const ApplicationCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonCircle(size: 40),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(width: 100, height: 14),
                    SizedBox(height: 4),
                    SkeletonText(width: 70, height: 10),
                  ],
                ),
              ),
              SkeletonBox(width: 60, height: 22, borderRadius: 100),
            ],
          ),
          SizedBox(height: 12),
          SkeletonText(width: double.infinity, height: 12),
          SizedBox(height: 4),
          SkeletonText(width: 200, height: 12),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SkeletonBox(width: double.infinity, height: 36, borderRadius: 100)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(width: double.infinity, height: 36, borderRadius: 100)),
            ],
          ),
        ],
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
      child: Row(
        children: [
          SkeletonCircle(size: 50),
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
        ],
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical,
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
      ),
      children: [
        const Center(
          child: Column(
            children: [
              SkeletonCircle(size: 80),
              SizedBox(height: 12),
              SkeletonText(width: 140, height: 18),
              SizedBox(height: 6),
              SkeletonText(width: 100, height: 12),
              SizedBox(height: 8),
              SkeletonText(width: 200, height: 12),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            3,
            (_) => const Column(
              children: [
                SkeletonText(width: 40, height: 20),
                SizedBox(height: 4),
                SkeletonText(width: 60, height: 10),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SkeletonButton(height: 44),
        const SizedBox(height: 24),
        const SkeletonText(width: 80, height: 14),
        const SizedBox(height: 8),
        const SkeletonBox(width: double.infinity, height: 60, borderRadius: 12),
        const SizedBox(height: 24),
        const SkeletonText(width: 80, height: 14),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            5,
            (i) => SkeletonBox(width: 60.0 + (i * 10), height: 28, borderRadius: 100),
          ),
        ),
      ],
    );
  }
}

/// Search Results Skeleton
class SearchResultsSkeleton extends StatelessWidget {
  const SearchResultsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SkeletonText(width: 100, height: 14),
        const SizedBox(height: 12),
        const CampaignCardSkeleton(),
        const SizedBox(height: 20),
        const SkeletonText(width: 80, height: 14),
        const SizedBox(height: 12),
        ...List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: ProfileTileSkeleton(),
          ),
        ),
      ],
    );
  }
}

/// Private Profile Tile Skeleton for Search
class ProfileTileSkeleton extends StatelessWidget {
  const ProfileTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          SkeletonCircle(size: 40),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 100, height: 13),
                SizedBox(height: 4),
                SkeletonText(width: 70, height: 10),
              ],
            ),
          ),
        ],
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

/// Generic List Tile Skeleton
class GenericListTileSkeleton extends StatelessWidget {
  const GenericListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Row(
        children: [
          SkeletonBox(width: 32, height: 32, borderRadius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 140, height: 14),
                SizedBox(height: 4),
                SkeletonText(width: 90, height: 10),
              ],
            ),
          ),
          SkeletonBox(width: 18, height: 18, borderRadius: 100),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical,
        AppSpacing.pageMarginHorizontal,
        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
      ),
      children: [
        const SkeletonImage(aspectRatio: 16 / 9, borderRadius: AppSpacing.radiusXl),
        const SizedBox(height: 20),
        const SkeletonText(width: 200, height: 22),
        const SizedBox(height: 8),
        const SkeletonText(width: 120, height: 12),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(child: SkeletonButton(height: 40)),
            SizedBox(width: 12),
            Expanded(child: SkeletonButton(height: 40)),
          ],
        ),
        const SizedBox(height: 24),
        const SkeletonText(width: 80, height: 14),
        const SizedBox(height: 8),
        const SkeletonText(width: double.infinity, height: 14),
        const SizedBox(height: 4),
        const SkeletonText(width: double.infinity, height: 14),
        const SizedBox(height: 4),
        const SkeletonText(width: 220, height: 14),
        const SizedBox(height: 24),
        const SkeletonText(width: 80, height: 14),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            4,
            (i) => SkeletonBox(width: 70.0 + (i * 12), height: 28, borderRadius: 100),
          ),
        ),
      ],
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
    return ListView(
      reverse: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: List.generate(6, (i) {
        final isMe = i % 3 == 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                const SkeletonCircle(size: 28),
                const SizedBox(width: 8),
              ],
              SkeletonBox(
                width: isMe ? 180 : 200,
                height: 44 + (i % 2) * 16.0,
                borderRadius: 16,
              ),
            ],
          ),
        );
      }),
    );
  }
}
