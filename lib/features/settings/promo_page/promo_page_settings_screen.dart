import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/data_services.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../promo_page/promo_page_service.dart';
import '../../promo_page/promo_public_page_screen.dart';
import '../../promo_page/promo_analytics_screen.dart';

class PromoPageSettingsScreen extends ConsumerStatefulWidget {
  const PromoPageSettingsScreen({super.key});

  @override
  ConsumerState<PromoPageSettingsScreen> createState() => _PromoPageSettingsScreenState();
}

class _PromoPageSettingsScreenState extends ConsumerState<PromoPageSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // State variables
  bool _loading = true;
  PromoPage? _promoPage;
  List<PromoPageLink> _links = [];
  bool _showPreview = false;

  // Floating bottom nav items
  final List<_SubNavItem> _subNavItems = const [
    _SubNavItem(icon: Iconsax.user, label: 'Profile'),
    _SubNavItem(icon: Iconsax.link_1, label: 'Links'),
    _SubNavItem(icon: Iconsax.colorfilter, label: 'Theme'),
    _SubNavItem(icon: Iconsax.chart_2, label: 'Analytics'),
    _SubNavItem(icon: Iconsax.setting, label: 'Settings'),
  ];

  // Claim Username controllers
  final _usernameCtrl = TextEditingController();
  Timer? _debounceTimer;
  bool _usernameValid = false;
  bool _checkingUsername = false;
  String? _usernameError;
  bool _usernameAvailable = false;

  // Edit Controllers
  final _displayNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _twitterCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  bool _showSocials = true;
  bool _showBadge = true;
  String _selectedTheme = 'dark';
  String? _accentColorHex;
  bool _uploadingAvatar = false;
  bool _savingProfile = false;

  String _selectedButtonColor = 'black';
  String _selectedButtonShape = 'normal_rounded';
  String _selectedButtonTextColor = 'white';
  String _selectedSocialIconColor = 'white';
  String? _customBgPhotoUrl;
  bool _uploadingBackground = false;

  Map<String, String> _parseAccentField(String? value) {
    if (value == null || value.isEmpty) {
      return {
        'hex': 'A855F7',
        'buttonColor': 'black',
        'buttonShape': 'normal_rounded',
        'buttonTextColor': 'white',
        'socialIconColor': 'white',
      };
    }
    final parts = value.split('|');
    final hex = parts[0];
    final buttonColor = parts.length > 1 ? parts[1] : 'black';
    final buttonShape = parts.length > 2 ? parts[2] : 'normal_rounded';
    final buttonTextColor = parts.length > 3 ? parts[3] : (buttonColor == 'white' ? 'black' : 'white');
    final socialIconColor = parts.length > 4 ? parts[4] : 'white';
    return {
      'hex': hex,
      'buttonColor': buttonColor,
      'buttonShape': buttonShape,
      'buttonTextColor': buttonTextColor,
      'socialIconColor': socialIconColor,
    };
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _loadPromoData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _youtubeCtrl.dispose();
    _twitterCtrl.dispose();
    _linkedinCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPromoData() async {
    setState(() => _loading = true);
    try {
      final page = await PromoPageService.getMyPage();
      if (page != null) {
        final linksList = await PromoPageService.getLinks(page.id);
        
        final profile = ref.read(authProvider).profile;
        final prefs = profile?['preferences'] as Map<String, dynamic>? ?? {};
        final handles = prefs['platform_handles'] as Map<String, dynamic>? ?? {};

        setState(() {
          _promoPage = page;
          _links = linksList;
          
          // prefill edit fields
          _displayNameCtrl.text = page.displayName ?? '';
          _bioCtrl.text = page.bio ?? '';
          _showSocials = page.showSocialPlatforms;
          _showBadge = page.showPromoBadge;
          _selectedTheme = page.theme;
          _accentColorHex = page.accentColor;
          _customBgPhotoUrl = page.backgroundColor;

           final parsedAccent = _parseAccentField(page.accentColor);
          _selectedButtonColor = parsedAccent['buttonColor'] ?? 'black';
          _selectedButtonShape = parsedAccent['buttonShape'] ?? 'normal_rounded';
          _selectedButtonTextColor = parsedAccent['buttonTextColor'] ?? (_selectedButtonColor == 'white' ? 'black' : 'white');
          _selectedSocialIconColor = parsedAccent['socialIconColor'] ?? 'white';

          _instagramCtrl.text = handles['Instagram'] ?? handles['instagram'] ?? '';
          _tiktokCtrl.text = handles['TikTok'] ?? handles['tiktok'] ?? '';
          _youtubeCtrl.text = handles['YouTube'] ?? handles['youtube'] ?? '';
          _twitterCtrl.text = handles['Twitter'] ?? handles['twitter'] ?? '';
          _linkedinCtrl.text = handles['LinkedIn'] ?? handles['linkedin'] ?? '';
        });
      }
    } catch (e) {
      AppSnackbar.show(context, 'Failed to load Promo Page: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onUsernameChanged(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    final cleaned = val.trim().toLowerCase();

    if (cleaned.isEmpty) {
      setState(() {
        _usernameValid = false;
        _usernameError = null;
        _checkingUsername = false;
        _usernameAvailable = false;
      });
      return;
    }

    // Regexp check
    final regExp = RegExp(r'^[a-z0-9_]{3,30}$');
    if (!regExp.hasMatch(cleaned)) {
      setState(() {
        _usernameValid = false;
        _usernameError = 'Use 3-30 lowercase letters, numbers, or underscores';
        _checkingUsername = false;
        _usernameAvailable = false;
      });
      return;
    }

    // Reserved check
    if (PromoPageService.reservedUsernames.contains(cleaned)) {
      setState(() {
        _usernameValid = false;
        _usernameError = 'This handle is reserved';
        _checkingUsername = false;
        _usernameAvailable = false;
      });
      return;
    }

    setState(() {
      _usernameValid = true;
      _usernameError = null;
      _checkingUsername = true;
      _usernameAvailable = false;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      final available = await PromoPageService.checkUsernameAvailability(cleaned);
      if (mounted) {
        setState(() {
          _checkingUsername = false;
          _usernameAvailable = available;
          if (!available) {
            _usernameError = 'This username is already taken';
          }
        });
      }
    });
  }

  Future<void> _claimUsername() async {
    final username = _usernameCtrl.text.trim();
    if (!_usernameValid || !_usernameAvailable || username.isEmpty) return;

    setState(() => _loading = true);
    try {
      await PromoPageService.claimUsername(username);
      AppSnackbar.show(context, 'Promo page claimed! Now customize it.');
      await _loadPromoData();
    } catch (e) {
      AppSnackbar.show(context, 'Failed to claim username: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image == null) return;

      setState(() => _uploadingAvatar = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last.toLowerCase();
      final cleanExt = ['jpg', 'jpeg', 'png', 'webp'].contains(fileExt) ? fileExt : 'jpg';
      final publicUrl = await StorageService().uploadFile(
        'avatars',
        'avatar_${DateTime.now().microsecondsSinceEpoch}.$cleanExt',
        bytes,
        'image/$cleanExt',
      );

      // Update page state with new avatar
      final updated = await PromoPageService.updatePage({'avatar_url': publicUrl});
      setState(() {
        _promoPage = updated;
        _uploadingAvatar = false;
      });

      if (mounted) {
        AppSnackbar.show(context, 'Avatar updated successfully!');
      }
    } catch (e) {
      setState(() => _uploadingAvatar = false);
      AppSnackbar.show(context, 'Error uploading avatar: $e');
    }
  }

  Future<void> _pickAndUploadBackground() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image == null) return;

      setState(() => _uploadingBackground = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last.toLowerCase();
      final cleanExt = ['jpg', 'jpeg', 'png', 'webp'].contains(fileExt) ? fileExt : 'jpg';
      final publicUrl = await StorageService().uploadFile(
        'avatars',
        'background_${DateTime.now().microsecondsSinceEpoch}.$cleanExt',
        bytes,
        'image/$cleanExt',
      );

      setState(() {
        _customBgPhotoUrl = publicUrl;
        _uploadingBackground = false;
      });

      if (mounted) {
        AppSnackbar.show(context, 'Background photo uploaded successfully! Save to apply changes.');
      }
    } catch (e) {
      setState(() => _uploadingBackground = false);
      AppSnackbar.show(context, 'Error uploading background image: $e');
    }
  }

  void _removeBackground() {
    setState(() {
      _customBgPhotoUrl = null;
    });
    AppSnackbar.show(context, 'Background photo removed! Save to apply changes.');
  }

  Future<void> _saveProfile() async {
    if (_promoPage == null) return;
    setState(() => _savingProfile = true);

    try {
      final updated = await PromoPageService.updatePage({
        'display_name': _displayNameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'show_social_platforms': _showSocials,
        'show_promo_badge': _showBadge,
        'theme': _selectedTheme,
        'accent_color': '${_accentColorHex != null ? _parseAccentField(_accentColorHex)['hex'] : 'A855F7'}|$_selectedButtonColor|$_selectedButtonShape|$_selectedButtonTextColor|$_selectedSocialIconColor',
        'background_color': _customBgPhotoUrl,
      });

      final user = ref.read(authProvider).user;
      final profile = ref.read(authProvider).profile;
      if (user != null && profile != null) {
        final currentPrefs = Map<String, dynamic>.from(profile['preferences'] ?? {});
        final handles = {
          'Instagram': _instagramCtrl.text.trim(),
          'TikTok': _tiktokCtrl.text.trim(),
          'YouTube': _youtubeCtrl.text.trim(),
          'Twitter': _twitterCtrl.text.trim(),
          'LinkedIn': _linkedinCtrl.text.trim(),
        };
        currentPrefs['platform_handles'] = handles;
        
        await ref.read(authProvider.notifier).updatePreferences(currentPrefs);

        final List<String> activePlatforms = [];
        handles.forEach((key, val) {
          if (val.isNotEmpty) {
            activePlatforms.add(key);
          }
        });

        await SupabaseService.client.from('profiles').update({
          'platforms': activePlatforms,
        }).eq('id', user.id);

        await ref.read(authProvider.notifier).refreshProfile();
      }

      setState(() {
        _promoPage = updated;
      });

      if (mounted) {
        AppSnackbar.show(context, 'Promo profile saved!');
      }
    } catch (e) {
      AppSnackbar.show(context, 'Error saving profile: $e');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _publishPage() async {
    if (_promoPage == null) return;
    try {
      final updated = await PromoPageService.updatePage({'is_published': true});
      setState(() {
        _promoPage = updated;
      });
      if (mounted) {
        AppSnackbar.show(context, 'Your Promo Page is now Live!');
      }
    } catch (e) {
      AppSnackbar.show(context, 'Error publishing page: $e');
    }
  }

  Future<void> _unpublishPage() async {
    if (_promoPage == null) return;
    try {
      final updated = await PromoPageService.updatePage({'is_published': false});
      setState(() {
        _promoPage = updated;
      });
      if (mounted) {
        AppSnackbar.show(context, 'Your Promo Page is unpublished.');
      }
    } catch (e) {
      AppSnackbar.show(context, 'Error unpublishing page: $e');
    }
  }

  void _openAddLinkBottomSheet({PromoPageLink? existingLink}) {
    final titleCtrl = TextEditingController(text: existingLink?.title ?? '');
    final urlCtrl = TextEditingController(text: existingLink?.url ?? 'https://');
    final iconCtrl = TextEditingController(text: existingLink?.icon ?? '🔗');
    bool savingLink = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
                top: AppSpacing.xl,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existingLink == null ? 'Add Link' : 'Edit Link',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: titleCtrl,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. My YouTube Channel',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'URL (must start with https://)',
                      hintText: 'https://youtube.com/...',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: iconCtrl,
                          maxLength: 2,
                          decoration: const InputDecoration(
                            labelText: 'Emoji Icon',
                            hintText: '🔗',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Preset emojis
                      Wrap(
                        spacing: 8,
                        children: ['🔗', '🎥', '📸', '🎵', '💼', '🛍️'].map((emoji) {
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                iconCtrl.text = emoji;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(emoji, style: const TextStyle(fontSize: 18)),
                            ),
                          );
                        }).toList(),
                      )
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: savingLink
                        ? null
                        : () async {
                            final title = titleCtrl.text.trim();
                            final url = urlCtrl.text.trim();
                            final icon = iconCtrl.text.trim();

                            if (title.isEmpty || url.isEmpty) {
                              AppSnackbar.show(ctx, 'Title and URL cannot be empty');
                              return;
                            }
                            if (!url.startsWith('https://')) {
                              AppSnackbar.show(ctx, 'URL must start with https://');
                              return;
                            }

                            setModalState(() => savingLink = true);

                            try {
                              if (existingLink == null) {
                                // Add link
                                if (_links.length >= 20) {
                                  throw Exception('Maximum limit of 20 links reached.');
                                }
                                final newLink = await PromoPageService.addLink(
                                  _promoPage!.id,
                                  title,
                                  url,
                                  icon.isNotEmpty ? icon : null,
                                );
                                setState(() {
                                  _links.add(newLink);
                                });
                              } else {
                                // Update link
                                await PromoPageService.updateLink(existingLink.id, {
                                  'title': title,
                                  'url': url,
                                  'icon': icon.isNotEmpty ? icon : null,
                                });
                                // Refresh link list
                                final updatedLinks = await PromoPageService.getLinks(_promoPage!.id);
                                setState(() {
                                  _links = updatedLinks;
                                });
                              }
                              Navigator.pop(ctx);
                              AppSnackbar.show(context, 'Link saved!');
                            } catch (e) {
                              AppSnackbar.show(ctx, 'Error saving link: $e');
                            } finally {
                              setModalState(() => savingLink = false);
                            }
                          },
                    child: savingLink
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Link'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleLinkEnabled(PromoPageLink link, bool enabled) async {
    try {
      await PromoPageService.updateLink(link.id, {'is_enabled': enabled});
      final updatedLinks = await PromoPageService.getLinks(_promoPage!.id);
      setState(() {
        _links = updatedLinks;
      });
    } catch (e) {
      AppSnackbar.show(context, 'Error updating link: $e');
    }
  }

  Future<void> _deleteLink(PromoPageLink link) async {
    try {
      await PromoPageService.deleteLink(link.id);
      setState(() {
        _links.removeWhere((l) => l.id == link.id);
      });
      AppSnackbar.show(context, 'Link deleted');
    } catch (e) {
      AppSnackbar.show(context, 'Error deleting link: $e');
    }
  }

  Future<void> _reorderLinks(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _links.removeAt(oldIndex);
    _links.insert(newIndex, item);
    setState(() {});

    try {
      final orderedIds = _links.map((l) => l.id).toList();
      await PromoPageService.reorderLinks(_promoPage!.id, orderedIds);
    } catch (e) {
      AppSnackbar.show(context, 'Failed to update link order: $e');
    }
  }

  void _sharePage() {
    if (_promoPage == null) return;
    final url = 'https://promo.arkio.in/@${_promoPage!.username}';
    Share.share('Check out my Promo Page! Connect, Create and Collaborate: $url');
  }

  void _copyPageUrl() {
    if (_promoPage == null) return;
    final url = 'https://promo.arkio.in/@${_promoPage!.username}';
    Clipboard.setData(ClipboardData(text: url));
    AppSnackbar.show(context, 'Page URL copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Promo Page')),
        body: Center(child: CircularProgressIndicator(color: AppColors.purple)),
      );
    }

    if (_promoPage == null) {
      // STATE A: Claim Username screen
      return Scaffold(
        appBar: AppBar(title: const Text('My Promo Page')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Iconsax.link, size: 72, color: AppColors.purple),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Create Your Promo Page',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Build a beautiful, public link-in-bio page to share all your platforms & campaigns in one single link.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _usernameCtrl,
                onChanged: _onUsernameChanged,
                decoration: InputDecoration(
                  prefixText: 'promo.arkio.in/@',
                  prefixStyle: TextStyle(
                    color: AppColors.purple,
                    fontWeight: FontWeight.bold,
                  ),
                  labelText: 'Username',
                  hintText: 'your_handle',
                  suffixIcon: _checkingUsername
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : (_usernameCtrl.text.isEmpty
                          ? null
                          : (_usernameValid && _usernameAvailable
                              ? const Icon(Icons.check_circle, color: AppColors.success)
                              : const Icon(Icons.cancel, color: AppColors.error))),
                  errorText: _usernameError,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: (_usernameValid && _usernameAvailable && !_checkingUsername)
                    ? _claimUsername
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Claim Username'),
              ),
            ],
          ),
        ),
      );
    }

    // STATE B: Main Editor screen
    final isPagePublished = _promoPage!.isPublished;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor = isDark ? const Color(0xFF1E1E22) : Colors.black;
    final shadowColor = isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.35);
    final activePillColor = Colors.white;
    final activeTextColor = Colors.black;
    final inactiveIconColor = isDark ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.6);

    final mainContent = Scaffold(
      appBar: AppBar(
        title: const Text('My Promo Page'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.eye),
            onPressed: () => setState(() => _showPreview = true),
          ),
          IconButton(
            icon: const Icon(Iconsax.share),
            onPressed: _sharePage,
          ),
          const SizedBox(width: 12),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: navBgColor,
                  borderRadius: BorderRadius.circular(100),
                  border: isDark
                      ? Border.all(color: Colors.white.withOpacity(0.08), width: 1)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_subNavItems.length, (i) {
                    final item = _subNavItems[i];
                    final isActive = _tabController.index == i;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _tabController.animateTo(i);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          padding: isActive
                              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 9)
                              : const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: isActive ? activePillColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 20,
                                color: isActive ? activeTextColor : inactiveIconColor,
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 8),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: activeTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Banner for live status
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPagePublished ? AppColors.success.withOpacity(0.12) : AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isPagePublished ? AppColors.success : AppColors.warning).withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPagePublished ? Icons.check_circle : Icons.warning_rounded,
                  color: isPagePublished ? AppColors.success : AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPagePublished ? 'Your Promo Page is public and live!' : 'Page is draft and unpublished.',
                    style: TextStyle(
                      color: isPagePublished ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isPagePublished ? _unpublishPage : _publishPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPagePublished 
                        ? AppColors.error.withOpacity(0.15) 
                        : AppColors.success.withOpacity(0.15),
                    foregroundColor: isPagePublished ? AppColors.error : AppColors.success,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isPagePublished ? AppColors.error : AppColors.success,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    isPagePublished ? 'Unpublish' : 'Publish',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Profile customization
                _buildProfileTab(),

                // TAB 2: Links builder
                _buildLinksTab(),

                // TAB 3: Theme picking
                _buildThemeTab(),

                // TAB 4: Analytics Dashboard
                PromoAnalyticsDashboard(
                  pageId: _promoPage!.id,
                  username: _promoPage!.username,
                ),

                // TAB 5: General Settings
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );

    if (_showPreview) {
      return Stack(
        children: [
          mainContent,
          Positioned.fill(
            child: _FullScreenPreview(
              username: _promoPage!.username,
              onBack: () => setState(() => _showPreview = false),
            ),
          ),
        ],
      );
    }

    return mainContent;
  }

  Widget _buildProfileTab() {
    final avatar = _promoPage!.avatarUrl ?? ref.read(authProvider).profile?['avatar_url'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.surface3,
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? const Icon(Iconsax.user, size: 36, color: Colors.grey)
                      : null,
                ),
                if (_uploadingAvatar)
                  const Positioned.fill(
                    child: CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: CircularProgressIndicator(),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.purple,
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _displayNameCtrl,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              hintText: 'e.g. S Siva Mani',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _bioCtrl,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bio / Tagline',
              hintText: 'Tell the world about yourself...',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Iconsax.global, size: 20, color: AppColors.purple),
              const SizedBox(width: 8),
              const Text(
                'Social Media Handles',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Add your handles so visitors can find you on other platforms',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _instagramCtrl,
            decoration: InputDecoration(
              labelText: 'Instagram',
              hintText: 'e.g. username',
              prefixText: '@ ',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/Social media icons/Instagram logo.png',
                  width: 20,
                  height: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _tiktokCtrl,
            decoration: InputDecoration(
              labelText: 'TikTok',
              hintText: 'e.g. username',
              prefixText: '@ ',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/Social media icons/Tiktok logo.png',
                  width: 20,
                  height: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _youtubeCtrl,
            decoration: InputDecoration(
              labelText: 'YouTube',
              hintText: 'e.g. channelname',
              prefixText: '@ ',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/Social media icons/youtube logo.png',
                  width: 20,
                  height: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _twitterCtrl,
            decoration: InputDecoration(
              labelText: 'X / Twitter',
              hintText: 'e.g. username',
              prefixText: '@ ',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/Social media icons/x logo.png',
                  width: 20,
                  height: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _linkedinCtrl,
            decoration: InputDecoration(
              labelText: 'LinkedIn',
              hintText: 'e.g. username',
              prefixText: '@ ',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/Social media icons/LinkedIn.png',
                  width: 20,
                  height: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            title: const Text('Show Social Icons'),
            subtitle: const Text('Links to your verified platform profiles (Instagram, YouTube etc)'),
            value: _showSocials,
            onChanged: (val) => setState(() => _showSocials = val),
            activeColor: AppColors.purple,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _savingProfile ? null : _saveProfile,
            child: _savingProfile
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save Profile Details'),
          ),
        ],
      ),
    );
  }

  Widget _buildLinksTab() {
    return Column(
      children: [
        // Helper text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Custom Links (${_links.length}/20)',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Drag handles to reorder',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: _links.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.link, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('No links added yet', style: AppTextStyles.body),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _openAddLinkBottomSheet(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Link'),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: _links.length,
                  onReorder: _reorderLinks,
                  itemBuilder: (ctx, idx) {
                    final link = _links[idx];
                    return Container(
                      key: ValueKey(link.id),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surface3, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // 1. Drag handle on left
                          ReorderableDragStartListener(
                            index: idx,
                            child: const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.drag_indicator, color: Colors.grey, size: 22),
                            ),
                          ),
                          
                          // 2. Icon box
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(link.icon ?? '🔗', style: const TextStyle(fontSize: 20)),
                          ),
                          const SizedBox(width: 12),
                          
                          // 3. Title & URL
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  link.title,
                                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  link.url,
                                  style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 8),
                          
                          // 4. Switch + Edit + Delete
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.scale(
                                scale: 0.8,
                                child: Switch(
                                  value: link.isEnabled,
                                  onChanged: (val) => _toggleLinkEnabled(link, val),
                                  activeColor: AppColors.purple,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Iconsax.edit, size: 18),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                                onPressed: () => _openAddLinkBottomSheet(existingLink: link),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Iconsax.trash, size: 18, color: AppColors.error),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                                onPressed: () => _deleteLink(link),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (_links.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ElevatedButton.icon(
              onPressed: _links.length >= 20 ? null : () => _openAddLinkBottomSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add Link'),
            ),
          ),
      ],
    );
  }

  Widget _buildThemeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choose Theme', style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(
            'Pick a style for your public promo page',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),

          // Uniform 2-column grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: [
              // 1. Dark Slate
              _buildThemeCard(
                id: 'dark',
                name: 'Dark Slate',
                preview: Container(
                  color: const Color(0xFF0F0F12),
                  child: _miniMockup(
                    avatarColor: Colors.white24,
                    lineColor: Colors.white12,
                    btnColor: Colors.white10,
                  ),
                ),
              ),
              // 2. Light Clean
              _buildThemeCard(
                id: 'light',
                name: 'Light Clean',
                preview: Container(
                  color: const Color(0xFFF3F4F6),
                  child: _miniMockup(
                    avatarColor: Colors.black12,
                    lineColor: Colors.black26,
                    btnColor: const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              // 3. Brand Purple
              _buildThemeCard(
                id: 'purple',
                name: 'Brand Purple',
                preview: Container(
                  color: const Color(0xFFA855F7),
                  child: _miniMockup(
                    avatarColor: Colors.white30,
                    lineColor: Colors.white60,
                    btnColor: Colors.white24,
                  ),
                ),
              ),
              // 4. Gradient Glam
              _buildThemeCard(
                id: 'gradient',
                name: 'Gradient Glam',
                preview: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: _miniMockup(
                    avatarColor: Colors.white30,
                    lineColor: Colors.white60,
                    btnColor: Colors.white24,
                  ),
                ),
              ),
              // 5. Glass Frosted
              _buildThemeCard(
                id: 'glass',
                name: 'Glass Frosted',
                preview: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF475569)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Container(
                          width: 35,
                          height: 35,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF472B6).withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 50,
                        right: 15,
                        child: Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                            child: Container(
                              width: 90,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircleAvatar(radius: 10, backgroundColor: Colors.white24),
                                  const SizedBox(height: 6),
                                  Container(width: 50, height: 3, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
                                  const SizedBox(height: 4),
                                  Container(width: 40, height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 6. Creator Vibes (image-based)
              _buildThemeCard(
                id: 'creator',
                name: 'Creator Vibes',
                preview: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/creator_theme_bg.png',
                      fit: BoxFit.cover,
                    ),
                    // Semi-transparent overlay for readability of mockup
                    Container(
                      color: Colors.black.withValues(alpha: 0.15),
                    ),
                    _miniMockup(
                      avatarColor: Colors.white38,
                      lineColor: Colors.white60,
                      btnColor: Colors.white30,
                    ),
                  ],
                ),
              ),
              // 7. Yaar Promo 1
              _buildThemeCard(
                id: 'yaar',
                name: 'Yaar Promo 1',
                preview: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/Profile_BG/1.png',
                      fit: BoxFit.cover,
                    ),
                    _miniMockup(
                      avatarColor: Colors.white70,
                      lineColor: Colors.white54,
                      btnColor: Colors.white,
                    ),
                  ],
                ),
              ),
              // 8. Yaar Promo 2
              _buildThemeCard(
                id: 'yaar_2',
                name: 'Yaar Promo 2',
                preview: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/Profile_BG/2.png',
                      fit: BoxFit.cover,
                    ),
                    _miniMockup(
                      avatarColor: Colors.white70,
                      lineColor: Colors.white54,
                      btnColor: Colors.white,
                    ),
                  ],
                ),
              ),
              // 9. Yaar Promo 3
              _buildThemeCard(
                id: 'yaar_3',
                name: 'Yaar Promo 3',
                preview: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/Profile_BG/3.png',
                      fit: BoxFit.cover,
                    ),
                    _miniMockup(
                      avatarColor: Colors.white70,
                      lineColor: Colors.white54,
                      btnColor: Colors.white,
                    ),
                  ],
                ),
              ),
              // 10. Yaar Promo 4
              _buildThemeCard(
                id: 'yaar_4',
                name: 'Yaar Promo 4',
                preview: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/Profile_BG/4.png',
                      fit: BoxFit.cover,
                    ),
                    _miniMockup(
                      avatarColor: Colors.white70,
                      lineColor: Colors.white54,
                      btnColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Section 1: Button Customization
          Text('Button Customization', style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(
            'Customize how link cards look on your page',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          
          Card(
            color: AppColors.surface3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Button Card Color', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildChoiceButton(
                          label: 'Black Card',
                          selected: _selectedButtonColor == 'black',
                          onTap: () => setState(() => _selectedButtonColor = 'black'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildChoiceButton(
                          label: 'White Card',
                          selected: _selectedButtonColor == 'white',
                          onTap: () => setState(() => _selectedButtonColor = 'white'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Card(
            color: AppColors.surface3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Button Corner Shape', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildChoiceButton(
                          label: 'Normal Rounded',
                          selected: _selectedButtonShape == 'normal_rounded',
                          onTap: () => setState(() => _selectedButtonShape = 'normal_rounded'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildChoiceButton(
                          label: 'Fully Rounded',
                          selected: _selectedButtonShape == 'fully_rounded',
                          onTap: () => setState(() => _selectedButtonShape = 'fully_rounded'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Card(
            color: AppColors.surface3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Page Text Color (Title, Handle, Bio)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildChoiceButton(
                          label: 'White Text',
                          selected: _selectedButtonTextColor == 'white',
                          onTap: () => setState(() => _selectedButtonTextColor = 'white'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChoiceButton(
                          label: 'Black Text',
                          selected: _selectedButtonTextColor == 'black',
                          onTap: () => setState(() => _selectedButtonTextColor = 'black'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChoiceButton(
                          label: 'Accent Color',
                          selected: _selectedButtonTextColor == 'accent',
                          onTap: () => setState(() => _selectedButtonTextColor = 'accent'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Card(
            color: AppColors.surface3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Social Icons Style', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildChoiceButton(
                          label: 'White Icons',
                          selected: _selectedSocialIconColor == 'white',
                          onTap: () => setState(() => _selectedSocialIconColor = 'white'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildChoiceButton(
                          label: 'Black Icons',
                          selected: _selectedSocialIconColor == 'black',
                          onTap: () => setState(() => _selectedSocialIconColor = 'black'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),

          // Section 2: Custom Background Photo
          Text('Custom Background Photo', style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(
            'Upload a photo to use as your page background instead of theme presets',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          
          Card(
            color: AppColors.surface3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_uploadingBackground) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(color: AppColors.purple),
                      ),
                    ),
                  ] else if (_customBgPhotoUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(_customBgPhotoUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Iconsax.edit, size: 16),
                            label: const Text('Change Background'),
                            onPressed: _pickAndUploadBackground,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Iconsax.trash, color: Colors.redAccent),
                          onPressed: _removeBackground,
                          tooltip: 'Remove Custom Background',
                        ),
                      ],
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      icon: const Icon(Iconsax.image, size: 18),
                      label: const Text('Upload Background Image'),
                      onPressed: _pickAndUploadBackground,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppColors.purple.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: _savingProfile ? null : _saveProfile,
            child: _savingProfile
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save Theme settings'),
          ),
        ],
      ),
    );
  }

  /// Miniature mockup widget showing avatar + lines + button skeleton
  Widget _miniMockup({
    required Color avatarColor,
    required Color lineColor,
    required Color btnColor,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(radius: 14, backgroundColor: avatarColor),
          const SizedBox(height: 8),
          Container(width: 55, height: 4, decoration: BoxDecoration(color: lineColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 5),
          Container(width: 40, height: 3, decoration: BoxDecoration(color: lineColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          Container(width: 60, height: 14, decoration: BoxDecoration(color: btnColor, borderRadius: BorderRadius.circular(7))),
          const SizedBox(height: 5),
          Container(width: 60, height: 14, decoration: BoxDecoration(color: btnColor, borderRadius: BorderRadius.circular(7))),
        ],
      ),
    );
  }

  /// Builds a single theme card for the grid
  Widget _buildThemeCard({
    required String id,
    required String name,
    required Widget preview,
  }) {
    final isSelected = _selectedTheme == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedTheme = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.purple : Colors.grey.withValues(alpha: 0.15),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              Positioned.fill(child: preview),

              // Bottom label bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check, size: 11, color: AppColors.purple),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.purple : Colors.grey.shade700,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade300,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }


  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('General Page Settings', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Promo Handle', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    '@${_promoPage!.username}',
                    style: AppTextStyles.h3.copyWith(color: AppColors.purple),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Handle changes are limited to once per 30 days.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            title: const Text('Show Powered by Promo Badge'),
            subtitle: const Text('Add a small badge at the bottom of your profile page'),
            value: _showBadge,
            onChanged: (val) => setState(() => _showBadge = val),
            activeColor: AppColors.purple,
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: _savingProfile ? null : _saveProfile,
            child: const Text('Save Settings'),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Text('Danger Zone', style: AppTextStyles.h3.copyWith(color: AppColors.error)),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _promoPage!.isPublished
                ? () async {
                    await _unpublishPage();
                  }
                : null,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              foregroundColor: AppColors.error,
            ),
            child: const Text('Unpublish My Promo Page'),
          ),
        ],
      ),
    );
  }
}

class _SubNavItem {
  final IconData icon;
  final String label;

  const _SubNavItem({
    required this.icon,
    required this.label,
  });
}

class _FullScreenPreview extends StatelessWidget {
  final String username;
  final VoidCallback onBack;

  const _FullScreenPreview({required this.username, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PromoPublicPageScreen(username: username, embedded: true),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
