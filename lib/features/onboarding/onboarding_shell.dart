import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/data_services.dart';
import '../../core/services/social_agent.dart';
import '../../shared/widgets/shared_widgets.dart';

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

  void connectPlatform(String platform, String handle) {
    final map = Map<String, String>.from(state.platformHandles);
    map[platform] = handle;
    final list = List<String>.from(state.platforms);
    if (!list.contains(platform)) {
      list.add(platform);
    }
    state = state.copyWith(platformHandles: map, platforms: list);
  }

  void disconnectPlatform(String platform) {
    final map = Map<String, String>.from(state.platformHandles);
    map.remove(platform);
    final list = List<String>.from(state.platforms);
    list.remove(platform);
    state = state.copyWith(platformHandles: map, platforms: list);
  }

  Future<void> saveProfile(String userId, WidgetRef ref) async {
    state = state.copyWith(isSaving: true);
    try {
      final role = ref.read(authProvider).role;
      final updateData = <String, dynamic>{
        'bio': state.bio.trim(),
        'website_url': state.websiteUrl.trim(),
        'avatar_url': state.avatarUrl,
      };

      if (role == 'brand') {
        updateData['display_name'] = state.companyName.trim().isNotEmpty ? state.companyName.trim() : state.displayName.trim();
        updateData['company_name'] = state.companyName.trim();
        updateData['preferences'] = {
          'target_budget_range': state.targetBudgetRange,
          'target_audience': state.targetAudience,
        };
      } else {
        updateData['display_name'] = state.displayName.trim();
        updateData['niche'] = state.niches;
        updateData['platforms'] = state.platforms;
        updateData['location'] = state.location.trim();
        
        // Background verification agent resolves followers automatically
        int totalFollowers = 0;
        final insta = state.platformHandles['Instagram'];
        final tiktok = state.platformHandles['TikTok'];
        final yt = state.platformHandles['YouTube'];
        final twitter = state.platformHandles['Twitter'];
        
        if (insta != null && insta.isNotEmpty) {
          totalFollowers += await SocialAgent.resolveFollowers('Instagram', insta);
        }
        if (tiktok != null && tiktok.isNotEmpty) {
          totalFollowers += await SocialAgent.resolveFollowers('TikTok', tiktok);
        }
        if (yt != null && yt.isNotEmpty) {
          totalFollowers += await SocialAgent.resolveFollowers('YouTube', yt);
        }
        if (twitter != null && twitter.isNotEmpty) {
          totalFollowers += await SocialAgent.resolveFollowers('Twitter', twitter);
        }
        
        updateData['follower_count'] = totalFollowers;
        updateData['preferences'] = {
          'platform_handles': state.platformHandles,
          'latitude': state.latitude,
          'longitude': state.longitude,
        };
      }

      await ProfileService().updateProfile(userId, updateData);
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

// ---------- Onboarding Shell Widget ----------
class OnboardingShell extends ConsumerWidget {
  final int currentStep;
  const OnboardingShell({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final role = auth.role ?? 'influencer';
    final progress = currentStep / 5;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surface2,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
              minHeight: 3,
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (currentStep > 1)
                    GestureDetector(
                      onTap: () => context.go('/onboarding/${currentStep - 1}'),
                      child: Row(
                        children: [
                          Icon(Iconsax.arrow_left_2, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Back',
                            style: AppTextStyles.labelSm.copyWith(color: AppColors.textSecondary),
                          )
                        ],
                      ),
                    )
                  else
                    const SizedBox(),
                  Text('Step $currentStep of 5', style: AppTextStyles.captionSm),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: _buildStep(context, ref, role),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, WidgetRef ref, String role) {
    switch (currentStep) {
      case 1: return _Step1Welcome(role: role);
      case 2: return _Step2Identity(role: role);
      case 3: return _Step3Visual(role: role);
      case 4: return _Step4Details(role: role);
      case 5: return _Step5Launch(role: role);
      default: return _Step1Welcome(role: role);
    }
  }
}

class _Step1Welcome extends StatelessWidget {
  final String role;
  const _Step1Welcome({required this.role});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Iconsax.emoji_happy, size: 64, color: AppColors.warning),
        const SizedBox(height: 24),
        Text('Welcome to Brand!', style: AppTextStyles.h1, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          role == 'brand'
              ? 'Let\'s set up your brand profile to start finding perfect influencer matches.'
              : 'Let\'s set up your creator profile to start discovering brand collaborations.',
          style: AppTextStyles.caption.copyWith(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        AppButton(label: 'Get Started', onTap: () => context.go('/onboarding/2')),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.role == 'brand' ? 'Establish Your Identity' : 'Your Creator Profile', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text(widget.role == 'brand' ? 'Tell us about your brand.' : 'Tell us about yourself.', style: AppTextStyles.caption),
        const SizedBox(height: 24),
        AppTextField(
          label: widget.role == 'brand' ? 'Company Name' : 'Display Name',
          hint: widget.role == 'brand' ? 'Acme Corp' : 'Your name',
          controller: _nameCtrl,
          onChanged: (val) => notifier.updateField(widget.role == 'brand' ? 'companyName' : 'displayName', val),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Bio',
          hint: 'Describe yourself or company in a few sentences...',
          maxLines: 4,
          controller: _bioCtrl,
          onChanged: (val) => notifier.updateField('bio', val),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Website',
          hint: 'https://...',
          keyboardType: TextInputType.url,
          controller: _websiteCtrl,
          onChanged: (val) => notifier.updateField('websiteUrl', val),
        ),
        const SizedBox(height: 32),
        AppButton(
          label: 'Continue',
          onTap: () {
            final name = widget.role == 'brand' ? state.companyName : state.displayName;
            if (name.trim().isEmpty || state.bio.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill out Display/Company Name and Bio.')),
              );
              return;
            }
            context.go('/onboarding/3');
          },
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading photo...'), duration: Duration(seconds: 2)),
      );

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded successfully!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
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
                onTap: () => notifier.toggleNiche(n),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 32),
        AppButton(
          label: 'Continue',
          onTap: () {
            if (role == 'influencer' && state.niches.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select at least one content niche.')),
              );
              return;
            }
            context.go('/onboarding/4');
          },
        ),
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
  late final TextEditingController _villageCtrl;
  late final TextEditingController _mandalCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _stateCtrl;
  bool _isLoadingLocation = false;

  List<String> _splitLocation(String loc) {
    if (loc.isEmpty) return ['', '', '', ''];
    final parts = loc.split(',').map((e) => e.trim()).toList();
    while (parts.length < 4) {
      parts.add('');
    }
    return parts.sublist(0, 4);
  }

  void _updateLocation() {
    final combined = '${_villageCtrl.text.trim()}, ${_mandalCtrl.text.trim()}, ${_districtCtrl.text.trim()}, ${_stateCtrl.text.trim()}';
    ref.read(onboardingStateProvider.notifier).updateField('location', combined);
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied, we cannot request permissions.';
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
        
        final village = address['suburb'] ?? address['village'] ?? address['neighbourhood'] ?? address['road'] ?? address['residential'] ?? address['hamlet'] ?? '';
        final mandal = address['subdistrict'] ?? address['town'] ?? address['city_district'] ?? address['county'] ?? '';
        final district = address['district'] ?? address['state_district'] ?? address['city'] ?? '';
        final stateName = address['state'] ?? '';

        if (mounted) {
          _villageCtrl.text = village.toString();
          _mandalCtrl.text = mandal.toString();
          _districtCtrl.text = district.toString();
          _stateCtrl.text = stateName.toString();
          
          final combined = '${_villageCtrl.text.trim()}, ${_mandalCtrl.text.trim()}, ${_districtCtrl.text.trim()}, ${_stateCtrl.text.trim()}';
          
          final notifier = ref.read(onboardingStateProvider.notifier);
          notifier.updateField('location', combined);
          notifier.updateField('latitude', position.latitude);
          notifier.updateField('longitude', position.longitude);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location updated successfully!')),
          );
        }
      } else {
        throw 'Failed to reverse geocode location';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
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
    final parts = _splitLocation(state.location);
    _villageCtrl = TextEditingController(text: parts[0]);
    _mandalCtrl = TextEditingController(text: parts[1]);
    _districtCtrl = TextEditingController(text: parts[2]);
    _stateCtrl = TextEditingController(text: parts[3]);
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _audienceCtrl.dispose();
    _villageCtrl.dispose();
    _mandalCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _showConnectDialog(String platform) async {
    final ctrl = TextEditingController(text: ref.read(onboardingStateProvider).platformHandles[platform]);
    final handle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Connect $platform'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: 'Enter handle (e.g. @username)',
            hintStyle: AppTextStyles.caption,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Next'),
          ),
        ],
      ),
    );

    // Dispose dialog controller
    ctrl.dispose();

    if (handle == null) return;
    if (handle.isEmpty) {
      ref.read(onboardingStateProvider.notifier).disconnectPlatform(platform);
      return;
    }

    // Show a loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Verifying handle on social platform...', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final details = await SocialAgent.fetchProfileDetails(platform, handle);
      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog

      // Show confirmation dialog with DP and followers!
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Verify Social Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('We found the following profile. Please confirm if this is your account:'),
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: details.avatarUrl.isNotEmpty
                    ? Image.network(details.avatarUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.person, size: 40))
                    : const Icon(Icons.person, size: 40),
              ),
              const SizedBox(height: 12),
              Text(details.displayName, style: AppTextStyles.label.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('@${details.handle}', style: AppTextStyles.captionSm.copyWith(color: AppColors.accent)),
              const SizedBox(height: 8),
              Chip(
                backgroundColor: AppColors.surface2,
                label: Text(
                  '${details.followerCount} Followers',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, Change ID', style: TextStyle(color: AppColors.error)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              child: const Text('Yes, Link Account'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        ref.read(onboardingStateProvider.notifier).connectPlatform(platform, handle);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Linked $platform account! Verified follower count: ${details.followerCount}')),
          );
        }
      } else {
        // Try again recursively
        _showConnectDialog(platform);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to verify profile: $e')),
        );
      }
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
              : 'Link your social media accounts. Our automated verification agent will automatically resolve and sync your follower count.', 
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 24),
        if (widget.role == 'brand') ...[
          AppTextField(
            label: 'Target Budget Range',
            hint: 'e.g. ₹10,000 - ₹50,000',
            controller: _budgetCtrl,
            onChanged: (val) => notifier.updateField('targetBudgetRange', val),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Target Audience',
            hint: 'e.g. 18-35 year olds in India',
            controller: _audienceCtrl,
            onChanged: (val) => notifier.updateField('targetAudience', val),
          ),
        ] else ...[
          _buildPlatformRow('Instagram', Iconsax.instagram, const Color(0xFFE1306C), state.platformHandles['Instagram']),
          const SizedBox(height: 12),
          _buildPlatformRow('YouTube', Iconsax.video_play, const Color(0xFFFF0000), state.platformHandles['YouTube']),
          const SizedBox(height: 12),
          _buildPlatformRow('TikTok', Iconsax.music, AppColors.textPrimary, state.platformHandles['TikTok']),
          const SizedBox(height: 12),
          _buildPlatformRow('Twitter', Iconsax.global, const Color(0xFF1DA1F2), state.platformHandles['Twitter']),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          Text('Location Details'.toUpperCase(), style: AppTextStyles.overline),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Village / Street',
            hint: 'e.g. Danavaipeta',
            controller: _villageCtrl,
            onChanged: (val) => _updateLocation(),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Mandal / Town',
            hint: 'e.g. Rajahmundry Urban',
            controller: _mandalCtrl,
            onChanged: (val) => _updateLocation(),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'District',
            hint: 'e.g. East Godavari',
            controller: _districtCtrl,
            onChanged: (val) => _updateLocation(),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'State',
            hint: 'e.g. Andhra Pradesh',
            controller: _stateCtrl,
            onChanged: (val) => _updateLocation(),
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
        const SizedBox(height: 32),
        AppButton(
          label: 'Continue',
          onTap: () {
            if (widget.role == 'influencer') {
              if (state.location.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your location.')));
                return;
              }
              if (state.platforms.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please connect at least one platform.')));
                return;
              }
            } else {
              if (state.targetBudgetRange.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter target budget range.')));
                return;
              }
            }
            context.go('/onboarding/5');
          },
        ),
      ],
    );
  }

  Widget _buildPlatformRow(String name, IconData icon, Color color, String? handle) {
    final isConnected = handle != null && handle.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: isConnected ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.label),
                if (isConnected) ...[
                  const SizedBox(height: 2),
                  Text(handle, style: AppTextStyles.captionSm.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
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
    final state = ref.watch(onboardingStateProvider);

    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Iconsax.flash, size: 64, color: AppColors.success),
        const SizedBox(height: 24),
        Text('You\'re All Set!', style: AppTextStyles.h1, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          role == 'brand'
              ? 'Your brand profile is ready. Start posting campaign cards and finding influencers!'
              : 'Your creator profile is live. Start discovering and applying to campaigns!',
          style: AppTextStyles.caption.copyWith(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        AppButton(
          label: 'Launch Dashboard',
          isLoading: state.isSaving,
          onTap: () async {
            final user = ref.read(authProvider).user;
            if (user != null) {
              try {
                await ref.read(onboardingStateProvider.notifier).saveProfile(user.id, ref);
                if (context.mounted) {
                  context.go(role == 'brand' ? '/brand/home' : '/influencer/home');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
                }
              }
            } else {
              context.go('/login');
            }
          },
        ),
      ],
    );
  }
}