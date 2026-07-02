import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_refresh_indicator.dart';

class CreatorLeaderboardScreen extends ConsumerStatefulWidget {
  const CreatorLeaderboardScreen({super.key});

  @override
  ConsumerState<CreatorLeaderboardScreen> createState() => _CreatorLeaderboardScreenState();
}

class _CreatorLeaderboardScreenState extends ConsumerState<CreatorLeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // Spotlight Creator of the Month (Featured)
  Map<String, dynamic>? _spotlightCreator;

  // Leaderboard data per category
  final List<List<Map<String, dynamic>>> _leaderboardData = [[], [], [], []];

  final List<Map<String, dynamic>> _tabs = [
    {'title': 'Most Applied', 'icon': Iconsax.send_2},
    {'title': 'Highest Rated', 'icon': Iconsax.star},
    {'title': 'Fastest Growing', 'icon': Iconsax.trend_up},
    {'title': 'Most Collabs', 'icon': Iconsax.briefcase},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _activeTabIndex = _tabController.index;
      });
    });
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatFollowers(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = SupabaseService.client;

      // 1. Fetch all active influencers from Supabase
      final profilesRes = await client
          .from('profiles')
          .select()
          .eq('role', 'influencer')
          .eq('is_active', true);

      final List<Map<String, dynamic>> rawInfluencers = List<Map<String, dynamic>>.from(profilesRes);

      if (rawInfluencers.isEmpty) {
        // Fallback to beautiful mock data if database is fresh and completely empty
        _loadMockData();
        return;
      }

      // 2. Fetch applications, agreements, and reviews in parallel
      final results = await Future.wait([
        client.from('applications').select('influencer_id'),
        client.from('collaboration_agreements').select('influencer_id'),
        client.from('reviews').select('reviewed_id, rating'),
      ]);

      final List<Map<String, dynamic>> allApps = List<Map<String, dynamic>>.from(results[0] as List);
      final List<Map<String, dynamic>> allAgreements = List<Map<String, dynamic>>.from(results[1] as List);
      final List<Map<String, dynamic>> allReviews = List<Map<String, dynamic>>.from(results[2] as List);

      // 3. Aggregate applications count
      final Map<String, int> appCounts = {};
      for (var app in allApps) {
        final infId = app['influencer_id'] as String?;
        if (infId != null) {
          appCounts[infId] = (appCounts[infId] ?? 0) + 1;
        }
      }

      // 4. Aggregate collaborations count
      final Map<String, int> collabCounts = {};
      for (var collab in allAgreements) {
        final infId = collab['influencer_id'] as String?;
        if (infId != null) {
          collabCounts[infId] = (collabCounts[infId] ?? 0) + 1;
        }
      }

      // 5. Aggregate reviews and ratings
      final Map<String, List<double>> ratings = {};
      for (var rev in allReviews) {
        final infId = rev['reviewed_id'] as String?;
        final rating = (rev['rating'] as num?)?.toDouble();
        if (infId != null && rating != null) {
          ratings.putIfAbsent(infId, () => []).add(rating);
        }
      }

      // 6. Enrich each influencer profile with calculated stats
      final List<Map<String, dynamic>> enrichedList = [];
      for (var inf in rawInfluencers) {
        final infId = inf['id'] as String;
        final appCount = appCounts[infId] ?? 0;
        final collabCount = collabCounts[infId] ?? 0;
        final followersRaw = inf['follower_count'] as int? ?? 0;

        final reviewList = ratings[infId] ?? [];
        final reviewCount = reviewList.length;
        final avgRating = reviewCount > 0 
            ? (reviewList.fold(0.0, (a, b) => a + b) / reviewCount)
            : 0.0;

        enrichedList.add({
          'id': infId,
          'name': inf['display_name'] ?? inf['username'] ?? 'Creator',
          'username': inf['username'] ?? 'creator',
          'avatar_url': inf['avatar_url'],
          'niches': (inf['niche'] as List?)?.cast<String>() ?? ['Creator'],
          'followers_raw': followersRaw,
          'followers': _formatFollowers(followersRaw),
          'app_count': appCount,
          'collab_count': collabCount,
          'avg_rating': avgRating,
          'review_count': reviewCount,
          'bio': inf['bio'] ?? 'Digital creator on Promo',
        });
      }

      // 7. Populate Category 0: 🔥 Most Applied
      final mostApplied = List<Map<String, dynamic>>.from(enrichedList);
      mostApplied.sort((a, b) => (b['app_count'] as int).compareTo(a['app_count'] as int));
      for (var item in mostApplied) {
        item['stat'] = '${item['app_count']} applications';
      }

      // 8. Populate Category 1: ⭐ Highest Rated
      final highestRated = List<Map<String, dynamic>>.from(enrichedList);
      highestRated.sort((a, b) {
        final ratingCompare = (b['avg_rating'] as double).compareTo(a['avg_rating'] as double);
        if (ratingCompare != 0) return ratingCompare;
        return (b['review_count'] as int).compareTo(a['review_count'] as int);
      });
      for (var item in highestRated) {
        item['stat'] = item['review_count'] > 0 
            ? '${(item['avg_rating'] as double).toStringAsFixed(1)} ★ (${item['review_count']})'
            : '— (0 reviews)';
      }

      // 9. Populate Category 2: 📈 Fastest Growing
      final fastestGrowing = List<Map<String, dynamic>>.from(enrichedList);
      fastestGrowing.sort((a, b) => (b['followers_raw'] as int).compareTo(a['followers_raw'] as int));
      for (var item in fastestGrowing) {
        item['stat'] = '${item['followers']} followers';
      }

      // 10. Populate Category 3: 💼 Most Collaborations Completed
      final mostCollabs = List<Map<String, dynamic>>.from(enrichedList);
      mostCollabs.sort((a, b) => (b['collab_count'] as int).compareTo(a['collab_count'] as int));
      for (var item in mostCollabs) {
        item['stat'] = '${item['collab_count']} collabs';
      }

      // 11. Populate Spotlight Creator of the Month (highest rating or follower count)
      final spotlightSource = highestRated.firstWhere((e) => e['review_count'] > 0, orElse: () => fastestGrowing.first);
      
      setState(() {
        _leaderboardData[0] = mostApplied;
        _leaderboardData[1] = highestRated;
        _leaderboardData[2] = fastestGrowing;
        _leaderboardData[3] = mostCollabs;

        _spotlightCreator = {
          'name': spotlightSource['name'],
          'username': spotlightSource['username'],
          'avatar_url': spotlightSource['avatar_url'],
          'niche': spotlightSource['niches'],
          'followers': spotlightSource['followers'],
          'bio': spotlightSource['bio'],
          'achievement': 'Spotlight Creator: Verified with ${spotlightSource['followers']} followers and outstanding reputation.'
        };
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load leaderboard: $e';
        _isLoading = false;
      });
    }
  }

  void _loadMockData() {
    setState(() {
      _spotlightCreator = {
        'name': 'Aisha Sharma',
        'username': 'aishasharma',
        'avatar_url': null,
        'niche': ['Lifestyle', 'Fashion'],
        'followers': '145K',
        'bio': 'Creating aesthetic lifestyle content and helping brands tell authentic stories.',
        'achievement': 'Fastest growing creator in June with +45.2K followers and 12 completed campaigns.'
      };

      // 🔥 Most Applied This Week
      _leaderboardData[0] = [
        {'id': 'm1', 'name': 'Rohan Mehta', 'username': 'rohanmehta', 'niches': ['Tech', 'Gaming'], 'followers': '24.5K', 'stat': '28 applications', 'avatar_url': null},
        {'id': 'm2', 'name': 'Elena Rostova', 'username': 'elenarostova', 'niches': ['Travel', 'Fashion'], 'followers': '52.1K', 'stat': '25 applications', 'avatar_url': null},
        {'id': 'm3', 'name': 'Marcus Chen', 'username': 'marcuschen', 'niches': ['Food', 'Fitness'], 'followers': '88.3K', 'stat': '22 applications', 'avatar_url': null},
        {'id': 'm4', 'name': 'Priya Nair', 'username': 'priyanair', 'niches': ['Lifestyle', 'Beauty'], 'followers': '12.4K', 'stat': '19 applications', 'avatar_url': null},
        {'id': 'm5', 'name': 'Sarah Jenkins', 'username': 'sarahj', 'niches': ['Fitness', 'Tech'], 'followers': '35.8K', 'stat': '17 applications', 'avatar_url': null},
      ];

      // ⭐ Highest Rated Creators
      _leaderboardData[1] = [
        {'id': 'm2', 'name': 'Elena Rostova', 'username': 'elenarostova', 'niches': ['Travel', 'Fashion'], 'followers': '52.1K', 'stat': '5.0 ★ (24 reviews)', 'avatar_url': null},
        {'id': 'm3', 'name': 'Marcus Chen', 'username': 'marcuschen', 'niches': ['Food', 'Fitness'], 'followers': '88.3K', 'stat': '4.9 ★ (38 reviews)', 'avatar_url': null},
        {'id': 'm5', 'name': 'Sarah Jenkins', 'username': 'sarahj', 'niches': ['Fitness', 'Tech'], 'followers': '35.8K', 'stat': '4.8 ★ (22 reviews)', 'avatar_url': null},
        {'id': 'm4', 'name': 'Priya Nair', 'username': 'priyanair', 'niches': ['Lifestyle', 'Beauty'], 'followers': '12.4K', 'stat': '4.8 ★ (11 reviews)', 'avatar_url': null},
        {'id': 'm1', 'name': 'Rohan Mehta', 'username': 'rohanmehta', 'niches': ['Tech', 'Gaming'], 'followers': '24.5K', 'stat': '4.7 ★ (16 reviews)', 'avatar_url': null},
      ];

      // 📈 Fastest Growing
      _leaderboardData[2] = [
        {'id': 'm4', 'name': 'Priya Nair', 'username': 'priyanair', 'niches': ['Lifestyle', 'Beauty'], 'followers': '12.4K', 'stat': '12.4K followers', 'avatar_url': null},
        {'id': 'm1', 'name': 'Rohan Mehta', 'username': 'rohanmehta', 'niches': ['Tech', 'Gaming'], 'followers': '24.5K', 'stat': '24.5K followers', 'avatar_url': null},
        {'id': 'm2', 'name': 'Elena Rostova', 'username': 'elenarostova', 'niches': ['Travel', 'Fashion'], 'followers': '52.1K', 'stat': '52.1K followers', 'avatar_url': null},
        {'id': 'm5', 'name': 'Sarah Jenkins', 'username': 'sarahj', 'niches': ['Fitness', 'Tech'], 'followers': '35.8K', 'stat': '35.8K followers', 'avatar_url': null},
        {'id': 'm3', 'name': 'Marcus Chen', 'username': 'marcuschen', 'niches': ['Food', 'Fitness'], 'followers': '88.3K', 'stat': '88.3K followers', 'avatar_url': null},
      ];

      // 💼 Most Collaborations Completed
      _leaderboardData[3] = [
        {'id': 'm3', 'name': 'Marcus Chen', 'username': 'marcuschen', 'niches': ['Food', 'Fitness'], 'followers': '88.3K', 'stat': '54 collabs', 'avatar_url': null},
        {'id': 'm2', 'name': 'Elena Rostova', 'username': 'elenarostova', 'niches': ['Travel', 'Fashion'], 'followers': '52.1K', 'stat': '42 collabs', 'avatar_url': null},
        {'id': 'm5', 'name': 'Sarah Jenkins', 'username': 'sarahj', 'niches': ['Fitness', 'Tech'], 'followers': '35.8K', 'stat': '36 collabs', 'avatar_url': null},
        {'id': 'm1', 'name': 'Rohan Mehta', 'username': 'rohanmehta', 'niches': ['Tech', 'Gaming'], 'followers': '24.5K', 'stat': '25 collabs', 'avatar_url': null},
        {'id': 'm4', 'name': 'Priya Nair', 'username': 'priyanair', 'niches': ['Lifestyle', 'Beauty'], 'followers': '12.4K', 'stat': '14 collabs', 'avatar_url': null},
      ];

      _isLoading = false;
    });
  }

  Widget _buildMedal(int rank) {
    if (rank == 1) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFFF5C518),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text('1', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
      );
    } else if (rank == 2) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFFC0C0C0),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text('2', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
      );
    } else if (rank == 3) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFFCD7F32),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text('3', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
      );
    }
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      child: Text('$rank', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildCreatorCard(Map<String, dynamic> creator, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rank = index + 1;
    final displayName = creator['name'] as String;
    final username = creator['username'] as String;
    final niches = creator['niches'] as List<String>;
    final followers = creator['followers'] as String;
    final stat = creator['stat'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank <= 3
              ? (rank == 1
                  ? const Color(0xFFF5C518).withOpacity(0.5)
                  : rank == 2
                      ? const Color(0xFFC0C0C0).withOpacity(0.5)
                      : const Color(0xFFCD7F32).withOpacity(0.5))
              : (isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB)),
          width: rank <= 3 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.01),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMedal(rank),
            const SizedBox(width: 12),
            AppAvatar(
              url: creator['avatar_url'],
              fallbackText: displayName,
              size: 40,
            ),
          ],
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                displayName,
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            if (rank <= 3) ...[
              const Icon(Iconsax.flash5, color: Colors.orange, size: 14),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@$username · $followers followers',
              style: AppTextStyles.captionSm.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: niches.map((niche) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    niche,
                    style: TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            stat,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.purple,
            ),
          ),
        ),
        onTap: () {
          context.push('/@$username');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(authProvider).profile;
    final role = profile?['role'] ?? 'brand';
    final isInfluencer = role == 'influencer';
    final currentUserId = profile?['id'];

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFFAF9FB),
        appBar: AppBar(
          title: const Text('Promo Leaderboard'),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.purple),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFFAF9FB),
        appBar: AppBar(
          title: const Text('Promo Leaderboard'),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Iconsax.danger, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error Loading Leaderboard', style: AppTextStyles.h4),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: AppTextStyles.body, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadLeaderboard,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Dynamic creator rank calculation based on loaded data
    String userRankText = '#—';
    String userStatText = '0';
    if (isInfluencer && currentUserId != null) {
      final activeList = _leaderboardData[_activeTabIndex];
      final userIndex = activeList.indexWhere((e) => e['id'] == currentUserId);
      if (userIndex != -1) {
        userRankText = '#${userIndex + 1}';
        userStatText = activeList[userIndex]['stat'] ?? '';
      } else {
        if (_activeTabIndex == 0) {
          userStatText = '0 applications';
        } else if (_activeTabIndex == 1) {
          userStatText = '— (0 reviews)';
        } else if (_activeTabIndex == 2) {
          final followerCount = profile?['follower_count'] as int? ?? 0;
          userStatText = '${_formatFollowers(followerCount)} followers';
        } else {
          userStatText = '0 collabs';
        }
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFFAF9FB),
      appBar: AppBar(
        title: const Text('Promo Leaderboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: AppRefreshIndicator(
        onRefresh: _loadLeaderboard,
        child: Column(
          children: [
            // Spotlight Creator of the Month (Header)
            if (_spotlightCreator != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E1B4B), const Color(0xFF1E1E24)]
                          : [const Color(0xFFEEF2FF), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFF5C518).withOpacity(0.4),
                      width: 1.5,
                ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF5C518).withOpacity(0.06),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5C518).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: const Color(0xFFF5C518), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Iconsax.star5, color: Color(0xFFF5C518), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'SPOTLIGHT CREATOR OF THE MONTH',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFF5C518),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          AppAvatar(
                            url: _spotlightCreator!['avatar_url'],
                            fallbackText: _spotlightCreator!['name'],
                            size: 52,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _spotlightCreator!['name'] as String,
                                        style: AppTextStyles.label.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: Colors.blue, size: 16),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${_spotlightCreator!['username']} · ${_spotlightCreator!['followers']} followers',
                                  style: AppTextStyles.captionSm.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              context.push('/@${_spotlightCreator!['username']}');
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Iconsax.arrow_right_1, color: isDark ? Colors.white : Colors.black, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _spotlightCreator!['achievement'] as String,
                        style: AppTextStyles.captionSm.copyWith(
                          color: isDark ? Colors.yellow.shade100 : Colors.yellow.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Category tabs
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: isDark ? Colors.white : Colors.black,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.purple,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
              labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
              dividerColor: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
              tabs: _tabs.map((tab) {
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab['icon'] as IconData, size: 14),
                      const SizedBox(width: 6),
                      Text(tab['title'] as String),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // List body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(_leaderboardData.length, (tabIdx) {
                  final list = _leaderboardData[tabIdx];
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.user, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 16),
                            const Text(
                              'No creators found in this category.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: list.length,
                    itemBuilder: (context, idx) {
                      return _buildCreatorCard(list[idx], idx);
                    },
                  );
                }),
              ),
            ),
            // Personal rank bottom bar (only for influencers/creators)
            if (isInfluencer) ...[
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141416) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                        width: 1.2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Iconsax.award, color: AppColors.purple, size: 18),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Your Standing',
                                style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userStatText,
                                style: AppTextStyles.captionSm.copyWith(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.purple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Rank $userRankText',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
