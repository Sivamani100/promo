import 'dart:async';
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
import '../../../shared/widgets/shared_widgets.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../promo_page/promo_page_service.dart';

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
  bool _showSocials = true;
  bool _showBadge = true;
  String _selectedTheme = 'dark';
  String? _accentColorHex;
  bool _uploadingAvatar = false;
  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPromoData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPromoData() async {
    setState(() => _loading = true);
    try {
      final page = await PromoPageService.getMyPage();
      if (page != null) {
        final linksList = await PromoPageService.getLinks(page.id);
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
      final page = await PromoPageService.claimUsername(username);
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
        'accent_color': _accentColorHex,
      });

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
        body: Center(child: const LoadingIndicator()),
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
    final pageUrl = 'https://promo.arkio.in/@${_promoPage!.username}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Promo Page'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.share),
            onPressed: _sharePage,
          ),
          IconButton(
            icon: const Icon(Iconsax.copy),
            onPressed: _copyPageUrl,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.purple,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.purple,
          tabs: const [
            Tab(icon: Icon(Iconsax.user), text: 'Profile'),
            Tab(icon: Icon(Iconsax.link_1), text: 'Links'),
            Tab(icon: Icon(Iconsax.colorfilter), text: 'Theme'),
            Tab(icon: Icon(Iconsax.setting), text: 'Settings'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner for live status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isPagePublished ? AppColors.success.withOpacity(0.15) : AppColors.warning.withOpacity(0.15),
            child: Row(
              children: [
                Icon(
                  isPagePublished ? Icons.check_circle : Icons.warning_rounded,
                  color: isPagePublished ? AppColors.success : AppColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
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
                TextButton(
                  onPressed: isPagePublished ? _unpublishPage : _publishPage,
                  child: Text(isPagePublished ? 'Unpublish' : 'Publish'),
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

                // TAB 4: General Settings
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
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
          const SizedBox(height: AppSpacing.md),
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
                  itemCount: _links.length,
                  onReorder: _reorderLinks,
                  itemBuilder: (ctx, idx) {
                    final link = _links[idx];
                    return Card(
                      key: ValueKey(link.id),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surface3,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(link.icon ?? '🔗', style: const TextStyle(fontSize: 20)),
                        ),
                        title: Text(link.title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          link.url,
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: link.isEnabled,
                              onChanged: (val) => _toggleLinkEnabled(link, val),
                              activeColor: AppColors.purple,
                            ),
                            IconButton(
                              icon: const Icon(Iconsax.edit, size: 18),
                              onPressed: () => _openAddLinkBottomSheet(existingLink: link),
                            ),
                            IconButton(
                              icon: const Icon(Iconsax.trash, size: 18, color: AppColors.error),
                              onPressed: () => _deleteLink(link),
                            ),
                            const Icon(Icons.drag_handle, color: Colors.grey),
                          ],
                        ),
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
    final themes = [
      {'id': 'dark', 'name': 'Dark Slate', 'bg': Colors.black, 'fg': Colors.white},
      {'id': 'light', 'name': 'Light Clean', 'bg': Colors.white, 'fg': Colors.black},
      {'id': 'purple', 'name': 'Brand Purple', 'bg': const Color(0xFFA855F7), 'fg': Colors.white},
      {'id': 'gradient', 'name': 'Gradient Glam', 'bg': Colors.indigo, 'fg': Colors.white},
      {'id': 'glass', 'name': 'Glass Frosted', 'bg': Colors.blueGrey, 'fg': Colors.white},
    ];

    final colorAccents = [
      {'id': 'FBA855F7', 'name': 'Purple', 'color': const Color(0xFFA855F7)},
      {'id': 'FB6366F1', 'name': 'Indigo', 'color': const Color(0xFF6366F1)},
      {'id': 'FBFBBF24', 'name': 'Amber', 'color': const Color(0xFFFBBF24)},
      {'id': 'FBF87171', 'name': 'Red', 'color': const Color(0xFFF87171)},
      {'id': 'FB4ADE80', 'name': 'Green', 'color': const Color(0xFF4ADE80)},
      {'id': 'FB38BDF8', 'name': 'Blue', 'color': const Color(0xFF38BDF8)},
      {'id': 'FFFFFFFF', 'name': 'White', 'color': Colors.white},
      {'id': 'FF000000', 'name': 'Black', 'color': Colors.black},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choose Theme', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: themes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemBuilder: (ctx, idx) {
              final th = themes[idx];
              final isSelected = _selectedTheme == th['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTheme = th['id'] as String;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: th['bg'] as Color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.purple : Colors.grey.withOpacity(0.3),
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    th['name'] as String,
                    style: TextStyle(
                      color: th['fg'] as Color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Custom Accent Color', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: colorAccents.length,
              itemBuilder: (ctx, idx) {
                final ac = colorAccents[idx];
                final hex = ac['id'] as String;
                final isSelected = _accentColorHex == hex;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _accentColorHex = hex;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 40,
                    decoration: BoxDecoration(
                      color: ac['color'] as Color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.purple : Colors.grey.withOpacity(0.5),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: _savingProfile ? null : _saveProfile,
            child: const Text('Save Theme settings'),
          ),
        ],
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
