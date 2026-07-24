import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/data_services.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../core/services/onboarding_analytics_service.dart';

// ---------- Onboarding State Model ----------
class OnboardingState {
  final String displayName;
  final String companyName;
  final String bio;
  final String websiteUrl;
  final String? avatarUrl;
  final List<String> niches;
  final List<String> platforms;
  final int followerCount;
  final String location;
  final String targetBudgetRange;
  final String targetAudience;
  final Map<String, String> platformHandles;
  final Map<String, int> platformFollowers;
  final bool isSaving;
  final double? latitude;
  final double? longitude;

  OnboardingState({
    this.displayName = '',
    this.companyName = '',
    this.bio = '',
    this.websiteUrl = '',
    this.avatarUrl,
    this.niches = const [],
    this.platforms = const [],
    this.followerCount = 0,
    this.location = '',
    this.targetBudgetRange = '',
    this.targetAudience = '',
    this.platformHandles = const {},
    this.platformFollowers = const {},
    this.isSaving = false,
    this.latitude,
    this.longitude,
  });

  OnboardingState copyWith({
    String? displayName,
    String? companyName,
    String? bio,
    String? websiteUrl,
    String? avatarUrl,
    List<String>? niches,
    List<String>? platforms,
    int? followerCount,
    String? location,
    String? targetBudgetRange,
    String? targetAudience,
    Map<String, String>? platformHandles,
    Map<String, int>? platformFollowers,
    bool? isSaving,
    double? latitude,
    double? longitude,
  }) {
    return OnboardingState(
      displayName: displayName ?? this.displayName,
      companyName: companyName ?? this.companyName,
      bio: bio ?? this.bio,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      niches: niches ?? this.niches,
      platforms: platforms ?? this.platforms,
      followerCount: followerCount ?? this.followerCount,
      location: location ?? this.location,
      targetBudgetRange: targetBudgetRange ?? this.targetBudgetRange,
      targetAudience: targetAudience ?? this.targetAudience,
      platformHandles: platformHandles ?? this.platformHandles,
      platformFollowers: platformFollowers ?? this.platformFollowers,
      isSaving: isSaving ?? this.isSaving,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

// ---------- Onboarding Notifier ----------
class OnboardingStateNotifier extends StateNotifier<OnboardingState> {
  OnboardingStateNotifier(Map<String, dynamic>? profile) : super(OnboardingState()) {
    if (profile != null) {
      final prefs = profile['preferences'] as Map<String, dynamic>? ?? {};
      
      final rawFollowers = prefs['platform_followers'] as Map<String, dynamic>? ?? {};
      final followersMap = <String, int>{};
      rawFollowers.forEach((k, v) {
        followersMap[k] = (v is num) ? v.toInt() : (int.tryParse(v.toString()) ?? 0);
      });

      state = OnboardingState(
        displayName: profile['display_name'] ?? '',
        companyName: profile['company_name'] ?? '',
        bio: profile['bio'] ?? '',
        websiteUrl: profile['website_url'] ?? '',
        avatarUrl: profile['avatar_url'],
        niches: List<String>.from(profile['niche'] ?? []),
        platforms: List<String>.from(profile['platforms'] ?? []),
        followerCount: profile['follower_count'] ?? 0,
        location: profile['location'] ?? '',
        targetBudgetRange: (profile['preferences'] as Map<String, dynamic>?)?['target_budget_range'] ?? '',
        targetAudience: (profile['preferences'] as Map<String, dynamic>?)?['target_audience'] ?? '',
        platformHandles: Map<String, String>.from((profile['preferences'] as Map<String, dynamic>?)?['platform_handles'] ?? {}),
        platformFollowers: followersMap,
        latitude: (prefs['latitude'] as num?)?.toDouble(),
        longitude: (prefs['longitude'] as num?)?.toDouble(),
      );
    }
  }

  void updateField(String field, dynamic val) {
    switch (field) {
      case 'displayName': state = state.copyWith(displayName: val); break;
      case 'companyName': state = state.copyWith(companyName: val); break;
      case 'bio': state = state.copyWith(bio: val); break;
      case 'websiteUrl': state = state.copyWith(websiteUrl: val); break;
      case 'avatarUrl': state = state.copyWith(avatarUrl: val); break;
      case 'niches': state = state.copyWith(niches: val); break;
      case 'platforms': state = state.copyWith(platforms: val); break;
      case 'followerCount': state = state.copyWith(followerCount: val); break;
      case 'location': state = state.copyWith(location: val); break;
      case 'targetBudgetRange': state = state.copyWith(targetBudgetRange: val); break;
      case 'targetAudience': state = state.copyWith(targetAudience: val); break;
      case 'latitude': state = state.copyWith(latitude: val); break;
      case 'longitude': state = state.copyWith(longitude: val); break;
    }
  }

  void toggleNiche(String niche) {
    final list = List<String>.from(state.niches);
    if (list.contains(niche)) {
      list.remove(niche);
    } else {
      list.add(niche);
    }
    state = state.copyWith(niches: list);
  }

  void connectPlatform(String platform, String handle, int followers) {
    final map = Map<String, String>.from(state.platformHandles);
    map[platform] = handle;
    final followersMap = Map<String, int>.from(state.platformFollowers);
    followersMap[platform] = followers;
    final list = List<String>.from(state.platforms);
    if (!list.contains(platform)) {
      list.add(platform);
    }
    final totalFollowers = followersMap.values.fold(0, (sum, val) => sum + val);
    state = state.copyWith(
      platformHandles: map,
      platformFollowers: followersMap,
      platforms: list,
      followerCount: totalFollowers,
    );
  }

  void disconnectPlatform(String platform) {
    final map = Map<String, String>.from(state.platformHandles);
    map.remove(platform);
    final followersMap = Map<String, int>.from(state.platformFollowers);
    followersMap.remove(platform);
    final list = List<String>.from(state.platforms);
    list.remove(platform);
    final totalFollowers = followersMap.values.fold(0, (sum, val) => sum + val);
    state = state.copyWith(
      platformHandles: map,
      platformFollowers: followersMap,
      platforms: list,
      followerCount: totalFollowers,
    );
  }

  Future<void> saveProfile(String userId, WidgetRef ref) async {
    state = state.copyWith(isSaving: true);
    try {
      final role = ref.read(authProvider).role;
      final updateData = <String, dynamic>{
        'bio': state.bio.trim(),
        'website_url': state.websiteUrl.trim(),
        'avatar_url': state.avatarUrl,
        'onboarding_complete': true,
        'onboarding_step': 5,
      };

      double? lat = state.latitude;
      double? lng = state.longitude;

      if (role == 'brand') {
        updateData['display_name'] = state.companyName.trim().isNotEmpty ? state.companyName.trim() : state.displayName.trim();
        updateData['company_name'] = state.companyName.trim();
        updateData['preferences'] = {
          'target_budget_range': state.targetBudgetRange,
          'target_audience': state.targetAudience,
        };
      } else {
        if (state.location.trim().isNotEmpty && (lat == null || lng == null || lat == 0.0 || lng == 0.0)) {
          try {
            final url = Uri.parse(
              'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(state.location.trim())}&format=json&limit=1',
            );
            final response = await http.get(url, headers: {
              'User-Agent': 'BrandMobileApp/1.0',
            }).timeout(const Duration(seconds: 5));
            if (response.statusCode == 200) {
              final results = json.decode(response.body) as List<dynamic>;
              if (results.isNotEmpty) {
                final first = results[0];
                lat = double.tryParse(first['lat']?.toString() ?? '');
                lng = double.tryParse(first['lon']?.toString() ?? '');
              }
            }
          } catch (e) {
            print('[ONBOARDING] Geocoding fallback failed: $e');
          }
        }

        updateData['display_name'] = state.displayName.trim();
        updateData['niche'] = state.niches;
        updateData['platforms'] = state.platforms;
        updateData['location'] = state.location.trim();
        
        updateData['follower_count'] = state.followerCount;
        updateData['preferences'] = {
          'platform_handles': state.platformHandles,
          'platform_followers': state.platformFollowers,
          'latitude': lat,
          'longitude': lng,
        };
      }

      await ProfileService().updateProfile(userId, updateData);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_complete_$userId', true);
      } catch (e) {
        print('Error saving local onboarding flag: $e');
      }
      await ref.read(authProvider.notifier).refreshProfile();
    } catch (e) {
      print('[ONBOARDING] Error saving onboarding: $e');
      rethrow;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final onboardingStateProvider = StateNotifierProvider<OnboardingStateNotifier, OnboardingState>((ref) {
  final profile = ref.watch(authProvider).profile;
  return OnboardingStateNotifier(profile);
});

final onboardingSelectedRoleProvider = StateProvider<String>((ref) {
  final role = ref.read(authProvider).role;
  return role ?? 'influencer';
});

// ---------- Onboarding Shell Widget ----------
class OnboardingShell extends ConsumerStatefulWidget {
  final int currentStep;
  const OnboardingShell({super.key, required this.currentStep});

  @override
  ConsumerState<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends ConsumerState<OnboardingShell> with WidgetsBindingObserver {
  DateTime _stepStartTime = DateTime.now();
  late int _trackedStep;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trackedStep = widget.currentStep;
    _logStepStart(_trackedStep);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _logStepAbandonment(_trackedStep);
    super.dispose();
  }

  @override
  void didUpdateWidget(OnboardingShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep) {
      final elapsed = DateTime.now().difference(_stepStartTime).inSeconds;
      _logStepComplete(oldWidget.currentStep, elapsed);
      _trackedStep = widget.currentStep;
      _stepStartTime = DateTime.now();
      _logStepStart(_trackedStep);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final elapsed = DateTime.now().difference(_stepStartTime).inSeconds;
      _logEvent(_trackedStep, 'abandoned', timeSpent: elapsed);
    } else if (state == AppLifecycleState.resumed) {
      _stepStartTime = DateTime.now();
      _logEvent(_trackedStep, 'started');
    }
  }

  String _getStepName(int step) {
    switch (step) {
      case 1: return 'Welcome / Role Selection';
      case 2: return 'Identity Form';
      case 3: return 'Visual / Niches';
      case 4: return 'Connect Platforms / Location';
      case 5: return 'Launch Launchpad';
      default: return 'Step $step';
    }
  }

  void _logStepStart(int step) {
    final user = ref.read(authProvider).user;
    if (user != null) {
      OnboardingAnalyticsService.logEvent(
        userId: user.id,
        stepNumber: step,
        stepName: _getStepName(step),
        eventType: 'started',
      );
    }
  }

  void _logStepComplete(int step, int elapsed) {
    final user = ref.read(authProvider).user;
    if (user != null) {
      OnboardingAnalyticsService.logEvent(
        userId: user.id,
        stepNumber: step,
        stepName: _getStepName(step),
        eventType: 'completed',
        timeSpentSeconds: elapsed,
      );
    }
  }

  void _logStepAbandonment(int step) {
    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    final isOnboardingComplete = profile?['onboarding_complete'] == true;
    if (user != null && !isOnboardingComplete) {
      final elapsed = DateTime.now().difference(_stepStartTime).inSeconds;
      OnboardingAnalyticsService.logEvent(
        userId: user.id,
        stepNumber: step,
        stepName: _getStepName(step),
        eventType: 'abandoned',
        timeSpentSeconds: elapsed,
      );
    }
  }

  void _logEvent(int step, String type, {int? timeSpent}) {
    final user = ref.read(authProvider).user;
    if (user != null) {
      OnboardingAnalyticsService.logEvent(
        userId: user.id,
        stepNumber: step,
        stepName: _getStepName(step),
        eventType: type,
        timeSpentSeconds: timeSpent,
      );
    }
  }

  Future<void> _handleStepContinue(BuildContext context, WidgetRef ref, String role) async {
    final step = widget.currentStep;
    final state = ref.read(onboardingStateProvider);

    if (step == 1) {
      final selectedRole = ref.read(onboardingSelectedRoleProvider);
      final user = ref.read(authProvider).user;
      if (user != null) {
        await ProfileService().updateProfile(user.id, {'role': selectedRole});
        await ref.read(authProvider.notifier).refreshProfile();
      }
      if (mounted) context.go('/onboarding/2');
    } else if (step == 2) {
      final name = role == 'brand' ? state.companyName : state.displayName;
      if (name.trim().isEmpty) {
        AppSnackbar.show(context, 'Please enter your ${role == 'brand' ? 'Company Name' : 'Display Name'}.');
        return;
      }
      context.go('/onboarding/3');
    } else if (step == 3) {
      if (role == 'influencer' && state.niches.isEmpty) {
        AppSnackbar.show(context, 'Please select at least one content niche.');
        return;
      }
      context.go('/onboarding/4');
    } else if (step == 4) {
      if (role == 'influencer') {
        if (state.location.trim().isEmpty) {
          AppSnackbar.show(context, 'Please enter your location.');
          return;
        }
        if (state.platforms.isEmpty) {
          AppSnackbar.show(context, 'Please connect at least one platform.');
          return;
        }
      } else {
        if (state.targetBudgetRange.trim().isEmpty) {
          AppSnackbar.show(context, 'Please enter target budget range.');
          return;
        }
      }
      context.go('/onboarding/5');
    } else if (step == 5) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        try {
          await ref.read(onboardingStateProvider.notifier).saveProfile(user.id, ref);
          if (mounted) {
            _showCelebrationOverlay(context, role);
          }
        } catch (e) {
          if (mounted) {
            AppSnackbar.show(context, 'Failed to save profile: $e');
          }
        }
      } else {
        context.go('/login');
      }
    }
  }

  void _showCelebrationOverlay(BuildContext context, String role) {
    HapticFeedback.vibrate();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Timer(const Duration(milliseconds: 2200), () {
          Navigator.of(dialogContext).pop();
          context.go(role == 'brand' ? '/brand/home' : '/influencer/home');
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 180,
                      width: 180,
                      child: Lottie.network(
                        'https://lottie.host/db6cf0a2-f3e4-4414-b6a1-cb9e4726e632/H3gVv8Z0Tz.json',
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Iconsax.flash, size: 80, color: AppColors.success);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ready to Grow!',
                      style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Redirecting to your dashboard...',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String stepTitle;
    switch (widget.currentStep) {
      case 1: stepTitle = 'Account Type'; break;
      case 2: stepTitle = 'Identity Details'; break;
      case 3: stepTitle = 'Niches & Visuals'; break;
      case 4: stepTitle = 'Platforms & Location'; break;
      case 5: stepTitle = 'Launch Dashboard'; break;
      default: stepTitle = 'Onboarding';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left circular back button
          GestureDetector(
            onTap: () {
              if (widget.currentStep > 1) {
                HapticFeedback.mediumImpact();
                context.go('/onboarding/${widget.currentStep - 1}');
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.surface : const Color(0xFFF9FAFB),
                border: Border.all(color: isDark ? AppColors.border : const Color(0xFFE5E7EB), width: 1.5),
              ),
              child: Icon(
                Iconsax.arrow_left_2,
                size: 18,
                color: widget.currentStep > 1
                    ? (isDark ? Colors.white : const Color(0xFF111827))
                    : (isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
              ),
            ),
          ),
          // Title
          Text(
            stepTitle,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          // Right circular help button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('Need Help?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  content: Text(
                    'Onboarding configures your workspace and account role. You can update or reset this anytime from Settings.',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Got it'),
                    )
                  ],
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.surface : const Color(0xFFF9FAFB),
                border: Border.all(color: isDark ? AppColors.border : const Color(0xFFE5E7EB), width: 1.5),
              ),
              child: Icon(
                Iconsax.info_circle,
                size: 18,
                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryBlue = Color(0xFF0066FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(5, (index) {
          final step = index + 1;
          final isCompleted = step < widget.currentStep;
          final isCurrent = step == widget.currentStep;
          final isLast = step == 5;

          return Expanded(
            flex: isLast ? 0 : 1,
            child: Row(
              children: [
                // Node
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: isCurrent ? 32 : 28,
                  height: isCurrent ? 32 : 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isCompleted || isCurrent) ? primaryBlue : (isDark ? AppColors.surface : const Color(0xFFF3F4F6)),
                    border: isCurrent
                        ? Border.all(color: primaryBlue.withOpacity(0.3), width: 4)
                        : (isCompleted ? null : Border.all(color: isDark ? AppColors.border : const Color(0xFFE5E7EB))),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: primaryBlue.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '$step',
                            style: GoogleFonts.inter(
                              fontSize: isCurrent ? 13 : 12,
                              fontWeight: FontWeight.bold,
                              color: (isCompleted || isCurrent) ? Colors.white : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                            ),
                          ),
                  ),
                ),
                // Connecting line
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2.5,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isCompleted ? primaryBlue : (isDark ? AppColors.border : const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final role = auth.role ?? 'influencer';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(context),
            _buildStepperBar(context),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                child: _buildStep(context, ref, role),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.border : const Color(0xFFF3F4F6),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (widget.currentStep > 1) ...[
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.go('/onboarding/${widget.currentStep - 1}');
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: isDark ? AppColors.surface2 : const Color(0xFFF3F4F6),
                      border: Border.all(
                        color: isDark ? AppColors.border : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Back',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => _handleStepContinue(context, ref, role),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: const Color(0xFF0066FF),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0066FF).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.currentStep == 5 ? 'Complete Setup' : 'Continue',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, WidgetRef ref, String role) {
    switch (widget.currentStep) {
      case 1: return _Step1Welcome(role: role);
      case 2: return _Step2Identity(role: role);
      case 3: return _Step3Visual(role: role);
      case 4: return _Step4Details(role: role);
      case 5: return _Step5Launch(role: role);
      default: return _Step1Welcome(role: role);
    }
  }
}

class _Step1Welcome extends ConsumerWidget {
  final String role;
  const _Step1Welcome({required this.role});

  Widget _roleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryBlue = Color(0xFF0066FF);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F6FF))
              : (isDark ? AppColors.surface : const Color(0xFFF9FAFB)),
          border: Border.all(
            color: selected ? primaryBlue : (isDark ? AppColors.border : const Color(0xFFE5E7EB)),
            width: selected ? 2.0 : 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon Illustration Tile
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: selected
                        ? primaryBlue.withOpacity(0.12)
                        : (isDark ? AppColors.surface2 : const Color(0xFFEEF2FF)),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: selected ? primaryBlue : (isDark ? Colors.white70 : const Color(0xFF4F46E5)),
                  ),
                ),
                // Radio Checkmark Badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? primaryBlue : Colors.transparent,
                    border: Border.all(
                      color: selected ? primaryBlue : (isDark ? Colors.white38 : const Color(0xFFD1D5DB)),
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedRole = ref.watch(onboardingSelectedRoleProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'What type of account would you like?',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your role to get started with tailored tools and recommendations.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 24),
        _roleCard(
          context,
          title: 'Creator / Influencer',
          subtitle: 'Pitch campaign briefs, collaborate with top brands, and monetize your audience.',
          icon: Iconsax.crown,
          selected: selectedRole == 'influencer',
          onTap: () => ref.read(onboardingSelectedRoleProvider.notifier).state = 'influencer',
        ),
        _roleCard(
          context,
          title: 'Brand / Business',
          subtitle: 'Create campaign cards, hire top creators, track ROI, and scale your brand.',
          icon: Iconsax.briefcase,
          selected: selectedRole == 'brand',
          onTap: () => ref.read(onboardingSelectedRoleProvider.notifier).state = 'brand',
        ),
      ],
    );
  }
}

class _Step2Identity extends ConsumerStatefulWidget {
  final String role;
  const _Step2Identity({required this.role});

  @override
  ConsumerState<_Step2Identity> createState() => _Step2IdentityState();
}

class _Step2IdentityState extends ConsumerState<_Step2Identity> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _websiteCtrl;

  final _nameFocusNode = FocusNode();
  final _bioFocusNode = FocusNode();
  final _websiteFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingStateProvider);
    _nameCtrl = TextEditingController(text: widget.role == 'brand' ? state.companyName : state.displayName);
    _bioCtrl = TextEditingController(text: state.bio);
    _websiteCtrl = TextEditingController(text: state.websiteUrl);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _websiteCtrl.dispose();
    _nameFocusNode.dispose();
    _bioFocusNode.dispose();
    _websiteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(onboardingStateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.role == 'brand' ? 'Establish Your Identity' : 'Your Creator Profile', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text(widget.role == 'brand' ? 'Tell us about your brand.' : 'Tell us about yourself.', style: AppTextStyles.caption),
        const SizedBox(height: 24),
        AppTextField(
          label: widget.role == 'brand' ? 'Company Name *' : 'Display Name *',
          hint: widget.role == 'brand' ? 'Acme Corp' : 'Your name',
          controller: _nameCtrl,
          focusNode: _nameFocusNode,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).requestFocus(_bioFocusNode),
          onChanged: (val) => notifier.updateField(widget.role == 'brand' ? 'companyName' : 'displayName', val),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Bio (Optional - add later)',
          hint: 'Describe yourself or company in a few sentences...',
          maxLines: 4,
          controller: _bioCtrl,
          focusNode: _bioFocusNode,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          onChanged: (val) => notifier.updateField('bio', val),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Website (Optional - add later)',
          hint: 'https://...',
          keyboardType: TextInputType.url,
          controller: _websiteCtrl,
          focusNode: _websiteFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          onChanged: (val) => notifier.updateField('websiteUrl', val),
        ),
      ],
    );
  }
}

class _Step3Visual extends ConsumerWidget {
  final String role;
  const _Step3Visual({required this.role});

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      if (!context.mounted) return;
      AppSnackbar.info(context, 'Uploading photo...');

      final bytes = await image.readAsBytes();
      final user = ref.read(authProvider).user;
      if (user == null) return;

      final path = 'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String url;
      try {
        url = await StorageService().uploadFile('message-attachments', path, bytes, 'image/jpeg');
      } catch (e) {
        try {
          url = await StorageService().uploadFile('avatars', path, bytes, 'image/jpeg');
        } catch (_) {
          url = 'https://api.dicebear.com/7.x/bottts/svg?seed=${user.id}';
        }
      }

      ref.read(onboardingStateProvider.notifier).updateField('avatarUrl', url);
      if (!context.mounted) return;
      AppSnackbar.show(context, 'Photo uploaded successfully!');
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(context, 'Upload failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(role == 'brand' ? 'Visual Representation' : 'Categorize Your Content', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text(
          role == 'brand'
              ? 'Upload your brand logo or mascot.'
              : 'Add your profile picture and pick your creator niches.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: () => _pickAvatar(context, ref),
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface2,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: state.avatarUrl != null
                      ? Image.network(state.avatarUrl!, fit: BoxFit.cover)
                      : Icon(Iconsax.camera, size: 32, color: AppColors.textMuted),
                ),
                if (state.avatarUrl != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      child: Icon(Icons.edit, size: 12, color: AppColors.accentOnDark),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text(state.avatarUrl != null ? 'Change Photo' : 'Tap to upload photo', style: AppTextStyles.captionSm)),
        
        if (role == 'influencer') ...[
          const SizedBox(height: 32),
          Text('Select Your Niches'.toUpperCase(), style: AppTextStyles.overline),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Fashion', 'Tech', 'Food', 'Fitness', 'Beauty', 'Travel', 'Gaming', 'Lifestyle'].map((n) {
              final selected = state.niches.contains(n);
              return AppChip(
                label: n,
                selected: selected,
                color: AppColors.getCategoryColor(n),
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.toggleNiche(n);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _Step4Details extends ConsumerStatefulWidget {
  final String role;
  const _Step4Details({required this.role});

  @override
  ConsumerState<_Step4Details> createState() => _Step4DetailsState();
}

class _Step4DetailsState extends ConsumerState<_Step4Details> {
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _audienceCtrl;
  late final TextEditingController _locationCtrl;
  bool _isLoadingLocation = false;

  final _budgetFocusNode = FocusNode();
  final _audienceFocusNode = FocusNode();
  final _locationFocusNode = FocusNode();

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AppSnackbar.warning(context, 'Location services are disabled. Please enable them.');
        }
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          final proceed = await showPremiumConfirmDialog(
            context: context,
            title: 'Location Permission',
            message: 'Promo uses your location to show nearby brands and creators on the map. Only your city is shown publicly — never your exact coordinates.',
            confirmLabel: 'Allow',
            cancelLabel: 'Not Now',
            icon: Iconsax.location,
          );
          if (proceed == true) {
            permission = await Geolocator.requestPermission();
          }
        }
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          AppSnackbar.warning(context, 'Location permissions are denied.');
        }
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppSnackbar.warning(context, 'Location permissions are permanently denied.');
        }
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'BrandMobileApp/1.0',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>? ?? {};
        
        final village = address['suburb'] ?? address['village'] ?? address['neighbourhood'] ?? address['road'] ?? '';
        final city = address['city'] ?? address['town'] ?? address['district'] ?? address['county'] ?? '';
        final stateName = address['state'] ?? '';

        final locStr = [village, city, stateName].where((s) => s.toString().trim().isNotEmpty).join(', ');

        if (mounted) {
          _locationCtrl.text = locStr;
          
          final notifier = ref.read(onboardingStateProvider.notifier);
          notifier.updateField('location', locStr);
          notifier.updateField('latitude', position.latitude);
          notifier.updateField('longitude', position.longitude);

          AppSnackbar.show(context, 'Location updated successfully!');
        }
      } else {
        throw 'Failed to reverse geocode location';
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Error getting location: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingStateProvider);
    _budgetCtrl = TextEditingController(text: state.targetBudgetRange);
    _audienceCtrl = TextEditingController(text: state.targetAudience);
    _locationCtrl = TextEditingController(text: state.location);
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _audienceCtrl.dispose();
    _locationCtrl.dispose();
    _budgetFocusNode.dispose();
    _audienceFocusNode.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _showConnectDialog(String platform) async {
    final handleCtrl = TextEditingController(text: ref.read(onboardingStateProvider).platformHandles[platform]);
    final followersCtrl = TextEditingController(
      text: (ref.read(onboardingStateProvider).platformFollowers[platform] ?? '').toString(),
    );

    final handleFocus = FocusNode();
    final followersFocus = FocusNode();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.link, color: AppColors.accent, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Connect $platform',
                      style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: handleCtrl,
                  focusNode: handleFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(sheetCtx).requestFocus(followersFocus),
                  decoration: const InputDecoration(
                    labelText: 'Username / Handle',
                    hintText: 'e.g. @username',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: followersCtrl,
                  focusNode: followersFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    final h = handleCtrl.text.trim();
                    final f = int.tryParse(followersCtrl.text.trim()) ?? 0;
                    Navigator.pop(sheetCtx, {'handle': h, 'followers': f});
                  },
                  decoration: const InputDecoration(
                    labelText: 'Followers Count',
                    hintText: 'e.g. 5000',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final h = handleCtrl.text.trim();
                          final f = int.tryParse(followersCtrl.text.trim()) ?? 0;
                          Navigator.pop(sheetCtx, {'handle': h, 'followers': f});
                        },
                        child: const Text('Connect'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );

    handleCtrl.dispose();
    followersCtrl.dispose();
    handleFocus.dispose();
    followersFocus.dispose();

    if (result == null) return;
    final handle = result['handle'] as String;
    final followers = result['followers'] as int;

    if (handle.isEmpty) {
      ref.read(onboardingStateProvider.notifier).disconnectPlatform(platform);
      return;
    }

    ref.read(onboardingStateProvider.notifier).connectPlatform(platform, handle, followers);
    if (mounted) {
      AppSnackbar.show(context, 'Linked $platform account! Followers count set to: $followers');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.role == 'brand' ? 'Campaign Targets & Budget' : 'Connect Your Platforms', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text(
          widget.role == 'brand' 
              ? 'Set your campaign preferences.' 
              : 'Link your social media accounts and input your location.', 
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 24),
        if (widget.role == 'brand') ...[
          AppTextField(
            label: 'Target Budget Range',
            hint: 'e.g. ₹10,000 - ₹50,000',
            controller: _budgetCtrl,
            focusNode: _budgetFocusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_audienceFocusNode),
            onChanged: (val) => notifier.updateField('targetBudgetRange', val),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Target Audience',
            hint: 'e.g. 18-35 year olds in India',
            controller: _audienceCtrl,
            focusNode: _audienceFocusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_locationFocusNode),
            onChanged: (val) => notifier.updateField('targetAudience', val),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Location',
            hint: 'e.g. Rajahmundry, Andhra Pradesh',
            controller: _locationCtrl,
            focusNode: _locationFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            onChanged: (val) => notifier.updateField('location', val.trim()),
          ),
          const SizedBox(height: 16),
          _isLoadingLocation
              ? const Center(child: CircularProgressIndicator())
              : AppButton(
                  label: 'Use Current Location',
                  icon: Iconsax.location,
                  isPrimary: false,
                  onTap: _getCurrentLocation,
                ),
        ] else ...[
          _buildPlatformRow('Instagram', Iconsax.instagram, const Color(0xFFE1306C), state.platformHandles['Instagram']),
          const SizedBox(height: 12),
          _buildPlatformRow('YouTube', Iconsax.video_play, const Color(0xFFFF0000), state.platformHandles['YouTube']),
          const SizedBox(height: 12),
          _buildPlatformRow('TikTok', Iconsax.music, AppColors.textPrimary, state.platformHandles['TikTok']),
          const SizedBox(height: 12),
          _buildPlatformRow('Twitter', Iconsax.global, const Color(0xFF1DA1F2), state.platformHandles['Twitter']),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Location *',
            hint: 'e.g. Rajahmundry, Andhra Pradesh',
            controller: _locationCtrl,
            focusNode: _locationFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            onChanged: (val) => notifier.updateField('location', val.trim()),
          ),
          const SizedBox(height: 16),
          _isLoadingLocation
              ? const Center(child: CircularProgressIndicator())
              : AppButton(
                  label: 'Use Current Location',
                  icon: Iconsax.location,
                  isPrimary: false,
                  onTap: _getCurrentLocation,
                ),
        ],
      ],
    );
  }

  Widget _buildPlatformRow(String name, IconData icon, Color color, String? handle) {
    final isConnected = handle != null && handle.isNotEmpty;
    final state = ref.watch(onboardingStateProvider);
    final followers = state.platformFollowers[name] ?? 0;

    String? assetPath;
    final lowerName = name.toLowerCase();
    if (lowerName.contains('instagram')) {
      assetPath = 'assets/Social media icons/Instagram logo.png';
    } else if (lowerName.contains('youtube')) {
      assetPath = 'assets/Social media icons/youtube logo.png';
    } else if (lowerName.contains('tiktok')) {
      assetPath = 'assets/Social media icons/Tiktok logo.png';
    } else if (lowerName.contains('twitter') || lowerName.contains('x')) {
      assetPath = 'assets/Social media icons/x logo.png';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: isConnected ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: Row(
        children: [
          assetPath != null
              ? Image.asset(assetPath, width: 28, height: 28)
              : Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.label),
                if (isConnected) ...[
                  const SizedBox(height: 2),
                  Text('$handle ($followers Followers)', style: AppTextStyles.captionSm.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
                ]
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _showConnectDialog(name),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isConnected ? AppColors.error : AppColors.border),
            ),
            child: Text(
              isConnected ? 'Disconnect' : 'Connect',
              style: TextStyle(fontSize: 12, color: isConnected ? AppColors.error : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step5Launch extends ConsumerWidget {
  final String role;
  const _Step5Launch({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.flash, size: 72, color: AppColors.success),
            const SizedBox(height: 28),
            Text('You\'re All Set!', style: AppTextStyles.h1, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                role == 'brand'
                    ? 'Your brand profile is ready. Start posting campaign cards and finding influencers!'
                    : 'Your creator profile is live. Start discovering and applying to campaigns!',
                style: AppTextStyles.caption.copyWith(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}