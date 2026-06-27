import 'dart:convert';
import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/data_services.dart';
import '../../core/services/application_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_skeleton.dart';
import '../../shared/widgets/screen_skeletons.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/widgets/premium_image_cropper.dart';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

// ========== Influencer Brands Screen ==========
class InfluencerBrandsScreen extends ConsumerStatefulWidget {
  final String? initialTab;
  const InfluencerBrandsScreen({super.key, this.initialTab});
  @override
  ConsumerState<InfluencerBrandsScreen> createState() => _InfluencerBrandsScreenState();
}

class _InfluencerBrandsScreenState extends ConsumerState<InfluencerBrandsScreen> {
  List<Map<String, dynamic>> _brands = [];
  Set<String> _followingIds = {};
  bool _loading = true;
  final _followService = FollowService();
  String _selectedTab = 'browse';

  @override
  void initState() {
    super.initState();
    if (widget.initialTab == 'following') {
      _selectedTab = 'following';
    }
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    final data = await ProfileService().getBrands(limit: 50);
    Set<String> followIds = {};
    if (user != null) {
      try { followIds = await _followService.getFollowingIds(user.id); } catch (_) {}
    }
    if (mounted) setState(() { _brands = data; _followingIds = followIds; _loading = false; });
  }

  Future<void> _toggleFollow(String brandId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final wasFollowing = _followingIds.contains(brandId);
    setState(() { wasFollowing ? _followingIds.remove(brandId) : _followingIds.add(brandId); });
    try {
      wasFollowing ? await _followService.unfollow(user.id, brandId) : await _followService.follow(user.id, brandId);
    } catch (e) {
      setState(() { wasFollowing ? _followingIds.add(brandId) : _followingIds.remove(brandId); });
      if (mounted) AppSnackbar.show(context, 'Failed to update follow status');
    }
  }

  Widget _buildTabChip(String label, String value, int count) {
    final isSelected = _selectedTab == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppColors.accent;
    final activeTextColor = AppColors.accentOnDark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? activeColor 
              : (isDark ? const Color(0xFF0F0F11) : Colors.white),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected 
                ? activeColor 
                : (isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB)),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? activeColor.withValues(alpha: 0.2) 
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected 
                    ? activeTextColor 
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? activeTextColor.withValues(alpha: 0.15) 
                    : (isDark ? const Color(0xFF1F1F24) : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? activeTextColor : AppColors.textMuted,
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
    final filteredBrands = _selectedTab == 'following'
        ? _brands.where((b) => _followingIds.contains(b['id'] as String? ?? '')).toList()
        : _brands;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/influencer/home'),
        ),
        title: const Text('Browse Brands'),
      ),
      body: _loading
          ? SkeletonShimmer(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: AppSpacing.pageMarginVertical),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, __) => const BrandTileSkeleton(),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 12),
                    child: Row(
                      children: [
                        _buildTabChip('Browse All', 'browse', _brands.length),
                        const SizedBox(width: 8),
                        _buildTabChip('Following', 'following', _followingIds.length),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filteredBrands.isEmpty
                        ? AppEmptyState(
                            icon: _selectedTab == 'following' ? Iconsax.people : Iconsax.briefcase,
                            title: _selectedTab == 'following' ? 'No followed brands' : 'No brands found',
                            subtitle: _selectedTab == 'following'
                                ? 'Brands you follow will appear here. Switch to Browse to find brands.'
                                : 'We couldn\'t find any brands at the moment.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.pageMarginHorizontal,
                              0,
                              AppSpacing.pageMarginHorizontal,
                              AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                            ),
                            itemCount: filteredBrands.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final b = filteredBrands[i];
                              final brandId = b['id'] as String? ?? '';
                              final isFollowing = _followingIds.contains(brandId);
                              return Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.01),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => context.push('/influencer/brands/$brandId'),
                                      child: AppAvatar(url: b['avatar_url'], fallbackText: b['display_name'] ?? 'B', size: 48),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => context.push('/influencer/brands/$brandId'),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Flexible(child: Text(b['display_name'] ?? '', style: AppTextStyles.label, overflow: TextOverflow.ellipsis)),
                                              if (b['is_verified'] == true) ...[const SizedBox(width: 4), const VerificationBadge(size: 14)],
                                            ]),
                                            if (b['company_name'] != null) Text(b['company_name'], style: AppTextStyles.captionSm),
                                            const SizedBox(height: 4),
                                            Text(b['industry'] ?? '', style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    isFollowing
                                        ? OutlinedButton(
                                            onPressed: () => _toggleFollow(brandId),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              side: BorderSide(color: AppColors.accent),
                                              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                                            ),
                                            child: Text('Following', style: TextStyle(fontSize: 12, color: AppColors.accent)),
                                          )
                                        : ElevatedButton(
                                            onPressed: () => _toggleFollow(brandId),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              backgroundColor: AppColors.accent,
                                              elevation: 0,
                                            ),
                                            child: Text('Follow', style: TextStyle(fontSize: 12, color: AppColors.accentOnDark)),
                                          ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ========== Influencer Saved Screen ==========
class InfluencerSavedScreen extends ConsumerStatefulWidget {
  const InfluencerSavedScreen({super.key});
  @override
  ConsumerState<InfluencerSavedScreen> createState() => _InfluencerSavedScreenState();
}

class _InfluencerSavedScreenState extends ConsumerState<InfluencerSavedScreen> {
  List<Map<String, dynamic>> _saved = [];
  Set<String> _appliedCardIds = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final data = await SavedService().getSavedCards(user.id);
    final appliedIds = await ApplicationService().getAppliedCardIds(user.id);
    if (mounted) {
      setState(() {
        _saved = data;
        _appliedCardIds = appliedIds.toSet();
        _loading = false;
      });
    }
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
          onPressed: () => context.go('/influencer/home'),
        ),
        title: const Text('Saved Cards'),
      ),
      body: _loading
          ? SkeletonShimmer(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, __) => const CampaignCardSkeleton(),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _saved.isEmpty
                  ? const AppEmptyState(icon: Iconsax.archive_1, title: 'No saved campaigns', subtitle: 'Bookmark campaigns to view them later')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical,
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                      ),
                      itemCount: _saved.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (_, i) {
                        final card = _saved[i]['card'] as Map<String, dynamic>?;
                        if (card == null) return const SizedBox.shrink();
                        return Dismissible(
                          key: Key(_saved[i]['id'].toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.2), borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
                            child: Icon(Iconsax.trash, color: AppColors.error),
                          ),
                          onDismissed: (_) async {
                            final user = ref.read(authProvider).user!;
                            await SavedService().unsaveCard(user.id, card['id']);
                            _load();
                          },
                          child: CampaignCardWidget(
                            card: card,
                            isApplied: _appliedCardIds.contains(card['id']),
                            onTap: () => context.push('/influencer/discover/${card['id']}'),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ========== Influencer Portfolio Screen ==========
class InfluencerPortfolioScreen extends ConsumerStatefulWidget {
  const InfluencerPortfolioScreen({super.key});
  @override
  ConsumerState<InfluencerPortfolioScreen> createState() => _InfluencerPortfolioScreenState();
}

class _InfluencerPortfolioScreenState extends ConsumerState<InfluencerPortfolioScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final data = await PortfolioService().getPortfolioItems(user.id);
    if (mounted) setState(() { _items = data; _loading = false; });
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
          onPressed: () => context.go('/influencer/home'),
        ),
        title: const Text('My Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_circle),
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: _loading
          ? SkeletonShimmer(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.75,
                ),
                itemCount: 8,
                itemBuilder: (_, __) => const SkeletonBox(
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? AppEmptyState(
                      icon: Iconsax.gallery,
                      title: 'No portfolio items',
                      subtitle: 'Add your best work to showcase to brands',
                      actionLabel: 'Add Item',
                      onAction: () => _showAddDialog(),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical,
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        final postUrl = item['post_url'] as String?;
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () => _showEditDialog(item),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                  border: Border.all(color: AppColors.border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        color: AppColors.surface2,
                                        width: double.infinity,
                                        child: AppImage(
                                          url: item['media_url'],
                                          fit: BoxFit.cover,
                                          fallback: Icon(Iconsax.image, size: 40, color: AppColors.textMuted),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(AppSpacing.md),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['title'] ?? 'Untitled', style: AppTextStyles.labelSm, maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(item['platform'] ?? '', style: AppTextStyles.captionSm),
                                              if (postUrl != null && postUrl.trim().isNotEmpty)
                                                Icon(Iconsax.link, size: 12, color: AppColors.accent),
                                            ],
                                          ),
                                          if (item['engagement_rate'] != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Iconsax.trend_up, size: 12, color: AppColors.success),
                                                const SizedBox(width: 4),
                                                Text('${item['engagement_rate']}% ER', style: AppTextStyles.captionSm.copyWith(color: AppColors.success)),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () async {
                                  final confirmed = await showPremiumConfirmDialog(
                                    context: context,
                                    title: 'Delete Portfolio Item',
                                    message: 'Are you sure you want to delete "${item['title'] ?? 'Untitled'}" from your portfolio?',
                                    confirmLabel: 'Delete',
                                    isDestructive: true,
                                    icon: Iconsax.trash,
                                  );
                                  if (confirmed == true) {
                                    setState(() => _loading = true);
                                    try {
                                      await PortfolioService().deletePortfolioItem(item['id'] as String);
                                      _load();
                                    } catch (e) {
                                      setState(() => _loading = false);
                                      if (mounted) {
                                        AppSnackbar.show(context, 'Failed to delete item: $e');
                                      }
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Iconsax.trash,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
    );
  }

  Future<void> _showAddDialog() async {
    final titleCtrl = TextEditingController();
    final platformCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final postUrlCtrl = TextEditingController();

    // Extract unique existing photos from current portfolio items
    final existingPhotos = _items
        .map((e) => e['media_url'] as String?)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();

    String? selectedMediaUrl;
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add Portfolio Item', style: AppTextStyles.h3, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  AppTextField(label: 'Title', hint: 'My Instagram Reel', controller: titleCtrl),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Platform', hint: 'Instagram', controller: platformCtrl),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Reel / Post URL', hint: 'https://instagram.com/p/...', controller: postUrlCtrl),
                  const SizedBox(height: 16),
                  
                  // Cover Photo Section
                  Text('COVER PHOTO', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  
                  // Selected Cover Preview
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: selectedMediaUrl != null && selectedMediaUrl!.isNotEmpty
                        ? AppImage(
                            url: selectedMediaUrl!,
                            fit: BoxFit.cover,
                            fallback: Center(child: Icon(Iconsax.gallery, size: 40, color: AppColors.textMuted)),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Iconsax.image, size: 36, color: AppColors.textMuted),
                                const SizedBox(height: 8),
                                Text('No cover photo selected', style: AppTextStyles.captionSm),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Horizontal Photo Selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Upload Button
                        GestureDetector(
                          onTap: uploading
                              ? null
                              : () async {
                                  final ImageSource? source = await showModalBottomSheet<ImageSource>(
                                    context: context,
                                    backgroundColor: AppColors.surface,
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                    builder: (ctx2) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(Iconsax.camera),
                                            title: const Text('Take Photo'),
                                            onTap: () => Navigator.pop(ctx2, ImageSource.camera),
                                          ),
                                          ListTile(
                                            leading: const Icon(Iconsax.image),
                                            title: const Text('Choose from Gallery'),
                                            onTap: () => Navigator.pop(ctx2, ImageSource.gallery),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (source == null) return;
                                  setDialogState(() => uploading = true);
                                  try {
                                    final user = ref.read(authProvider).user!;
                                    final picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
                                    if (image != null) {
                                      final bytes = await image.readAsBytes();
                                      final fileExt = image.name.split('.').last.toLowerCase();
                                      final cleanExt = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(fileExt) ? fileExt : 'jpg';
                                      final fileName = 'portfolio_${DateTime.now().microsecondsSinceEpoch}.$cleanExt';
                                      final path = '${user.id}/$fileName';
                                      final publicUrl = await StorageService().uploadFile(
                                        'portfolio',
                                        path,
                                        bytes,
                                        'image/$cleanExt',
                                      );
                                      setDialogState(() {
                                        selectedMediaUrl = publicUrl;
                                        urlCtrl.text = publicUrl;
                                      });
                                    }
                                  } catch (e) {
                                    print('Error uploading photo: $e');
                                    if (context.mounted) {
                                      AppSnackbar.show(context, 'Failed to upload photo: $e');
                                    }
                                  } finally {
                                    setDialogState(() => uploading = false);
                                  }
                                },
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Center(
                              child: uploading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Iconsax.document_upload, size: 20, color: AppColors.accent),
                                        const SizedBox(height: 4),
                                        const Text('Upload', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        // Existing Photos
                        ...existingPhotos.map((photoUrl) {
                          final isSelected = selectedMediaUrl == photoUrl;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedMediaUrl = photoUrl;
                                urlCtrl.text = photoUrl;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 10),
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                border: Border.all(
                                  color: isSelected ? AppColors.accent : AppColors.border,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AppImage(
                                    url: photoUrl,
                                    fit: BoxFit.cover,
                                    fallback: Center(child: Icon(Iconsax.image, size: 20, color: AppColors.textMuted)),
                                  ),
                                  if (isSelected)
                                    Container(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      child: const Center(
                                        child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  AppTextField(
                    label: 'Or Custom Image URL',
                    hint: 'https://...',
                    controller: urlCtrl,
                    onChanged: (val) {
                      setDialogState(() {
                        selectedMediaUrl = val.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  AppButton(
                    label: 'Add Item',
                    onTap: () async {
                      if (titleCtrl.text.isNotEmpty) {
                        final user = ref.read(authProvider).user!;
                        await PortfolioService().addPortfolioItem({
                          'owner_id': user.id,
                          'title': titleCtrl.text.trim(),
                          'platform': platformCtrl.text.trim(),
                          'media_url': urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                          'post_url': postUrlCtrl.text.trim().isEmpty ? null : postUrlCtrl.text.trim(),
                          'sort_order': _items.length,
                        });
                        if (mounted) Navigator.pop(ctx);
                        _load();
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> item) async {
    final titleCtrl = TextEditingController(text: item['title'] ?? '');
    final platformCtrl = TextEditingController(text: item['platform'] ?? '');
    final urlCtrl = TextEditingController(text: item['media_url'] ?? '');
    final postUrlCtrl = TextEditingController(text: item['post_url'] ?? '');

    final existingPhotos = _items
        .map((e) => e['media_url'] as String?)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();

    String? selectedMediaUrl = item['media_url'];
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Edit Portfolio Item', style: AppTextStyles.h3, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  AppTextField(label: 'Title', hint: 'My Instagram Reel', controller: titleCtrl),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Platform', hint: 'Instagram', controller: platformCtrl),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Reel / Post URL', hint: 'https://instagram.com/p/...', controller: postUrlCtrl),
                  const SizedBox(height: 16),
                  
                  Text('COVER PHOTO', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: selectedMediaUrl != null && selectedMediaUrl!.isNotEmpty
                        ? AppImage(
                            url: selectedMediaUrl!,
                            fit: BoxFit.cover,
                            fallback: Center(child: Icon(Iconsax.gallery, size: 40, color: AppColors.textMuted)),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Iconsax.image, size: 36, color: AppColors.textMuted),
                                const SizedBox(height: 8),
                                Text('No cover photo selected', style: AppTextStyles.captionSm),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: uploading
                              ? null
                              : () async {
                                  final ImageSource? source = await showModalBottomSheet<ImageSource>(
                                    context: context,
                                    backgroundColor: AppColors.surface,
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                    builder: (ctx2) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(Iconsax.camera),
                                            title: const Text('Take Photo'),
                                            onTap: () => Navigator.pop(ctx2, ImageSource.camera),
                                          ),
                                          ListTile(
                                            leading: const Icon(Iconsax.image),
                                            title: const Text('Choose from Gallery'),
                                            onTap: () => Navigator.pop(ctx2, ImageSource.gallery),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (source == null) return;
                                  setDialogState(() => uploading = true);
                                  try {
                                    final user = ref.read(authProvider).user!;
                                    final picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
                                    if (image != null) {
                                      final bytes = await image.readAsBytes();
                                      final fileExt = image.name.split('.').last.toLowerCase();
                                      final cleanExt = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(fileExt) ? fileExt : 'jpg';
                                      final fileName = 'portfolio_${DateTime.now().microsecondsSinceEpoch}.$cleanExt';
                                      final path = '${user.id}/$fileName';
                                      final publicUrl = await StorageService().uploadFile(
                                        'portfolio',
                                        path,
                                        bytes,
                                        'image/$cleanExt',
                                      );
                                      setDialogState(() {
                                        selectedMediaUrl = publicUrl;
                                        urlCtrl.text = publicUrl;
                                      });
                                    }
                                  } catch (e) {
                                    print('Error uploading photo: $e');
                                    if (context.mounted) {
                                      AppSnackbar.show(context, 'Failed to upload photo: $e');
                                    }
                                  } finally {
                                    setDialogState(() => uploading = false);
                                  }
                                },
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Center(
                              child: uploading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Iconsax.document_upload, size: 20, color: AppColors.accent),
                                        const SizedBox(height: 4),
                                        const Text('Upload', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        ...existingPhotos.map((photoUrl) {
                          final isSelected = selectedMediaUrl == photoUrl;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedMediaUrl = photoUrl;
                                urlCtrl.text = photoUrl;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 10),
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                border: Border.all(
                                  color: isSelected ? AppColors.accent : AppColors.border,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AppImage(
                                    url: photoUrl,
                                    fit: BoxFit.cover,
                                    fallback: Center(child: Icon(Iconsax.image, size: 20, color: AppColors.textMuted)),
                                  ),
                                  if (isSelected)
                                    Container(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      child: const Center(
                                        child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  AppTextField(
                    label: 'Or Custom Image URL',
                    hint: 'https://...',
                    controller: urlCtrl,
                    onChanged: (val) {
                      setDialogState(() {
                        selectedMediaUrl = val.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Delete',
                          isPrimary: false,
                          onTap: () async {
                            final confirmed = await showPremiumConfirmDialog(
                              context: context,
                              title: 'Delete Portfolio Item',
                              message: 'Are you sure you want to delete "${item['title'] ?? 'Untitled'}"?',
                              confirmLabel: 'Delete',
                              isDestructive: true,
                              icon: Iconsax.trash,
                            );
                            if (confirmed == true) {
                              try {
                                await PortfolioService().deletePortfolioItem(item['id'] as String);
                                if (mounted) Navigator.pop(ctx);
                                _load();
                              } catch (e) {
                                if (context.mounted) {
                                  AppSnackbar.show(context, 'Failed to delete: $e');
                                }
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'Save',
                          onTap: () async {
                            if (titleCtrl.text.isNotEmpty) {
                              try {
                                await PortfolioService().updatePortfolioItem(item['id'] as String, {
                                  'title': titleCtrl.text.trim(),
                                  'platform': platformCtrl.text.trim(),
                                  'media_url': urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                                  'post_url': postUrlCtrl.text.trim().isEmpty ? null : postUrlCtrl.text.trim(),
                                });
                                if (mounted) Navigator.pop(ctx);
                                _load();
                              } catch (e) {
                                if (context.mounted) {
                                  AppSnackbar.show(context, 'Failed to save: $e');
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ],
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

// ========== Influencer Analytics Screen ==========
class InfluencerAnalyticsScreen extends ConsumerStatefulWidget {
  const InfluencerAnalyticsScreen({super.key});
  @override
  ConsumerState<InfluencerAnalyticsScreen> createState() => _InfluencerAnalyticsScreenState();
}

class _InfluencerAnalyticsScreenState extends ConsumerState<InfluencerAnalyticsScreen> {
  int _profileViews = 0;
  int _totalApps = 0;
  int _acceptedApps = 0;
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  
  // Rate Estimator variables
  double _calculatorFollowers = 15000;
  double _calculatorER = 3.5;
  String _calculatorContentType = 'Reel';
  bool _calculatorInitialized = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null) return;
    
    if (profile != null && !_calculatorInitialized) {
      _calculatorFollowers = (profile['follower_count'] ?? 15000).toDouble();
      _calculatorInitialized = true;
    }
    
    final views = await AnalyticsService().getProfileViewCount(user.id);
    final reviews = await AnalyticsService().getReviews(user.id);
    final apps = await ApplicationService().getApplicationsForInfluencer(user.id);
    if (mounted) {
      setState(() {
        _profileViews = views;
        _reviews = reviews;
        _totalApps = apps.length;
        _acceptedApps = apps.where((a) => a['status'] == 'accepted').length;
        _loading = false;
      });
    }
  }

  Map<String, double> _calculateEstimatedRate() {
    double minRatePerK;
    double maxRatePerK;
    
    switch (_calculatorContentType) {
      case 'Story':
        minRatePerK = 5.0;
        maxRatePerK = 15.0;
        break;
      case 'Post':
        minRatePerK = 10.0;
        maxRatePerK = 25.0;
        break;
      case 'Video':
        minRatePerK = 20.0;
        maxRatePerK = 50.0;
        break;
      case 'Reel':
      default:
        minRatePerK = 15.0;
        maxRatePerK = 35.0;
        break;
    }
    
    final erFactor = 0.8 + (_calculatorER / 3.0) * 0.2;
    
    double minEstimated = (_calculatorFollowers / 1000.0) * minRatePerK * erFactor;
    double maxEstimated = (_calculatorFollowers / 1000.0) * maxRatePerK * erFactor;
    
    if (minEstimated < 5) minEstimated = 5;
    if (maxEstimated < 10) maxEstimated = 10;
    
    return {
      'low': minEstimated,
      'high': maxEstimated,
    };
  }

  Widget _buildRateEstimatorCard() {
    final rates = _calculateEstimatedRate();
    final lowFormatted = rates['low']!.toStringAsFixed(0);
    final highFormatted = rates['high']!.toStringAsFixed(0);
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.calculator, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text('Collab Rate Estimator', style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Content Format', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _calculatorContentType,
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    style: AppTextStyles.labelSm.copyWith(color: AppColors.textPrimary),
                    dropdownColor: AppColors.surface,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _calculatorContentType = val;
                        });
                      }
                    },
                    items: ['Story', 'Post', 'Reel', 'Video'].map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Followers Count', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  Text(
                    _calculatorFollowers >= 1000000 
                        ? '${(_calculatorFollowers / 1000000).toStringAsFixed(1)}M'
                        : _calculatorFollowers >= 1000 
                            ? '${(_calculatorFollowers / 1000).toStringAsFixed(0)}K'
                            : '${_calculatorFollowers.toStringAsFixed(0)}',
                    style: AppTextStyles.label.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: AppColors.border,
                  thumbColor: AppColors.accent,
                  overlayColor: AppColors.accent.withOpacity(0.1),
                ),
                child: Slider(
                  value: _calculatorFollowers.clamp(1000.0, 500000.0),
                  min: 1000.0,
                  max: 500000.0,
                  divisions: 499,
                  onChanged: (val) {
                    setState(() {
                      _calculatorFollowers = val;
                    });
                  },
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Engagement Rate', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  Text('${_calculatorER.toStringAsFixed(1)}%', style: AppTextStyles.label.copyWith(color: AppColors.accent)),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: AppColors.border,
                  thumbColor: AppColors.accent,
                  overlayColor: AppColors.accent.withOpacity(0.1),
                ),
                child: Slider(
                  value: _calculatorER.clamp(0.5, 15.0),
                  min: 0.5,
                  max: 15.0,
                  divisions: 29,
                  onChanged: (val) {
                    setState(() {
                      _calculatorER = val;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.purple.withOpacity(0.12), AppColors.indigo.withOpacity(0.06)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.purple.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text(
                  'ESTIMATED VALUE RANGE',
                  style: AppTextStyles.overline.copyWith(color: AppColors.purple),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$$lowFormatted - \$$highFormatted',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Suggested pitch rate for a single ${_calculatorContentType.toLowerCase()}',
                  style: AppTextStyles.captionSm,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          onPressed: () => context.go('/influencer/home'),
        ),
        title: const Text('Analytics'),
      ),
      body: _loading
          ? const SkeletonShimmer(child: AnalyticsScreenSkeleton())
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
                      StatCard(label: 'Applications', value: '$_totalApps', icon: Iconsax.document_text, preset: StatCardPreset.purple),
                      StatCard(label: 'Accepted', value: '$_acceptedApps', icon: Iconsax.tick_circle, preset: StatCardPreset.emerald),
                      StatCard(label: 'Reviews', value: '${_reviews.length}', icon: Iconsax.star, preset: StatCardPreset.amber),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _buildRateEstimatorCard(),
                  const SizedBox(height: 24),

                  // Reviews section
                  SectionHeader(title: 'Reviews', icon: Iconsax.star),
                  if (_reviews.isEmpty)
                    const AppEmptyState(icon: Iconsax.star, title: 'No reviews yet')
                  else
                    ...List.generate(_reviews.length, (i) {
                      final r = _reviews[i];
                      final reviewer = r['reviewer'] as Map<String, dynamic>?;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      final rId = reviewer?['id'];
                                      if (rId != null) {
                                        context.push('/influencer/brands/$rId');
                                      }
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Row(
                                      children: [
                                        AppAvatar(
                                          url: reviewer?['avatar_url'],
                                          fallbackText: reviewer?['display_name'] ?? 'R',
                                          size: 32,
                                          onTap: () {
                                            final rId = reviewer?['id'];
                                            if (rId != null) {
                                              context.push('/influencer/brands/$rId');
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(reviewer?['display_name'] ?? 'Reviewer', style: AppTextStyles.labelSm)),
                                      ],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (j) => Icon(
                                    j < (r['rating'] ?? 0) ? Iconsax.star1 : Iconsax.star,
                                    size: 16,
                                    color: AppColors.warning,
                                  )),
                                ),
                              ],
                            ),
                            if (r['comment'] != null) ...[
                              const SizedBox(height: 8),
                              Text(r['comment'], style: AppTextStyles.caption.copyWith(height: 1.5)),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

// ========== Influencer Profile Screen ==========
class InfluencerProfileScreen extends ConsumerStatefulWidget {
  final bool startInEditMode;
  const InfluencerProfileScreen({super.key, this.startInEditMode = false});
  @override
  ConsumerState<InfluencerProfileScreen> createState() => _InfluencerProfileScreenState();
}

class _InfluencerProfileScreenState extends ConsumerState<InfluencerProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _mandalCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _twitterCtrl = TextEditingController();
  final _instagramFollowersCtrl = TextEditingController();
  final _tiktokFollowersCtrl = TextEditingController();
  final _youtubeFollowersCtrl = TextEditingController();
  final _twitterFollowersCtrl = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  bool _saving = false;
  bool _isEditing = false;
  String? _avatarUrl;
  bool _uploadingAvatar = false;
  List<Map<String, dynamic>> _portfolio = [];
  int _appsCount = 0;
  List<Map<String, dynamic>> _followingBrands = [];
  bool _loadingData = true;

  List<String> _splitLocation(String loc) {
    if (loc.isEmpty) return ['', '', '', ''];
    final parts = loc.split(',').map((e) => e.trim()).toList();
    while (parts.length < 4) {
      parts.add('');
    }
    return parts.sublist(0, 4);
  }

  void _updateLocationString() {
    _locationCtrl.text = '${_villageCtrl.text.trim()}, ${_mandalCtrl.text.trim()}, ${_districtCtrl.text.trim()}, ${_stateCtrl.text.trim()}';
  }

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
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AppSnackbar.warning(context, 'Location permissions denied. Enter location manually below.');
          }
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppSnackbar.warning(context, 'Location permissions permanently denied. Enable in settings.');
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
        
        final village = address['suburb'] ?? address['village'] ?? address['neighbourhood'] ?? address['road'] ?? address['residential'] ?? address['hamlet'] ?? '';
        final mandal = address['subdistrict'] ?? address['town'] ?? address['city_district'] ?? address['county'] ?? '';
        final district = address['district'] ?? address['state_district'] ?? address['city'] ?? '';
        final stateName = address['state'] ?? '';

        if (mounted) {
          setState(() {
            _villageCtrl.text = village.toString();
            _mandalCtrl.text = mandal.toString();
            _districtCtrl.text = district.toString();
            _stateCtrl.text = stateName.toString();
            _latitude = position.latitude;
            _longitude = position.longitude;
            _updateLocationString();
          });

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

  Future<void> _pickProfileAvatar() async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      if (!mounted) return;
      final croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => PremiumImageCropper(imageFile: image),
        ),
      );
      if (croppedBytes == null) return;

      if (!mounted) return;
      setState(() {
        _uploadingAvatar = true;
      });
      AppSnackbar.info(context, 'Uploading photo...');

      final bytes = croppedBytes;
      final user = ref.read(authProvider).user;
      if (user == null) return;

      final path = 'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String url;
      try {
        url = await StorageService().uploadFile('avatars', path, bytes, 'image/jpeg');
      } catch (e) {
        try {
          url = await StorageService().uploadFile('message-attachments', path, bytes, 'image/jpeg');
        } catch (_) {
          rethrow;
        }
      }

      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _uploadingAvatar = false;
        });
        AppSnackbar.show(context, 'Photo uploaded successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
        });
        AppSnackbar.show(context, 'Upload failed: $e');
      }
    }
  }

  void _setEditing(bool editing) {
    setState(() {
      _isEditing = editing;
    });
    ref.read(hideBottomNavProvider.notifier).state = editing;
  }

  @override
  void initState() {
    super.initState();
    _isEditing = widget.startInEditMode;
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(hideBottomNavProvider.notifier).state = true;
        }
      });
    }
    final p = ref.read(authProvider).profile;
    if (p != null) {
      _nameCtrl.text = p['display_name'] ?? '';
      _bioCtrl.text = p['bio'] ?? '';
      _locationCtrl.text = p['location'] ?? '';
      _avatarUrl = p['avatar_url'];
      
      final parts = _splitLocation(_locationCtrl.text);
      _villageCtrl.text = parts[0];
      _mandalCtrl.text = parts[1];
      _districtCtrl.text = parts[2];
      _stateCtrl.text = parts[3];

      final prefs = p['preferences'] as Map<String, dynamic>? ?? {};
      _latitude = (prefs['latitude'] as num?)?.toDouble();
      _longitude = (prefs['longitude'] as num?)?.toDouble();

      _loadSocialHandles(p);
    }
    _loadDashboardData();
  }

  void _loadSocialHandles(Map<String, dynamic>? profile) {
    if (profile == null) return;
    final prefs = profile['preferences'] as Map<String, dynamic>? ?? {};
    final handles = prefs['platform_handles'] as Map<String, dynamic>? ?? {};
    _instagramCtrl.text = handles['Instagram'] ?? handles['instagram'] ?? '';
    _tiktokCtrl.text = handles['TikTok'] ?? handles['tiktok'] ?? '';
    _youtubeCtrl.text = handles['YouTube'] ?? handles['youtube'] ?? '';
    _twitterCtrl.text = handles['Twitter'] ?? handles['twitter'] ?? '';

    final followers = prefs['platform_followers'] as Map<String, dynamic>? ?? {};
    _instagramFollowersCtrl.text = (followers['Instagram'] ?? followers['instagram'] ?? '').toString();
    _tiktokFollowersCtrl.text = (followers['TikTok'] ?? followers['tiktok'] ?? '').toString();
    _youtubeFollowersCtrl.text = (followers['YouTube'] ?? followers['youtube'] ?? '').toString();
    _twitterFollowersCtrl.text = (followers['Twitter'] ?? followers['twitter'] ?? '').toString();
  }


  Future<void> _loadDashboardData() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final items = await PortfolioService().getPortfolioItems(user.id);
      final apps = await ApplicationService().getApplicationsForInfluencer(user.id);
      final followingIds = await FollowService().getFollowingIds(user.id);
      List<Map<String, dynamic>> followedBrands = [];
      if (followingIds.isNotEmpty) {
        final brandsData = await SupabaseService.client
            .from('profiles')
            .select()
            .inFilter('id', followingIds.toList());
        followedBrands = List<Map<String, dynamic>>.from(brandsData);
      }
      if (mounted) {
        setState(() {
          _portfolio = items;
          _appsCount = apps.length;
          _followingBrands = followedBrands;
          _loadingData = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _loadingData = false;
        });
      }
    }
  }

  Future<void> _unfollowBrand(String brandId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final brandIndex = _followingBrands.indexWhere((b) => b['id'] == brandId);
    if (brandIndex == -1) return;
    final removedBrand = _followingBrands[brandIndex];
    setState(() {
      _followingBrands.removeAt(brandIndex);
    });
    try {
      await FollowService().unfollow(user.id, brandId);
    } catch (e) {
      setState(() {
        _followingBrands.insert(brandIndex, removedBrand);
      });
      if (mounted) {
        AppSnackbar.show(context, 'Failed to unfollow brand');
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = ref.read(authProvider).user!;
      final profile = ref.read(authProvider).profile;

      final loc = _locationCtrl.text.trim();
      if (loc.isNotEmpty && (_latitude == null || _longitude == null || _latitude == 0.0 || _longitude == 0.0)) {
        try {
          final url = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(loc)}&format=json&limit=1',
          );
          final response = await http.get(url, headers: {
            'User-Agent': 'BrandMobileApp/1.0',
          }).timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            final results = json.decode(response.body) as List<dynamic>;
            if (results.isNotEmpty) {
              final first = results[0];
              _latitude = double.tryParse(first['lat']?.toString() ?? '');
              _longitude = double.tryParse(first['lon']?.toString() ?? '');
            }
          }
        } catch (e) {
          print('[PROFILE] Geocoding fallback failed: $e');
        }
      }

      final currentPrefs = Map<String, dynamic>.from(profile?['preferences'] ?? {});
      final instagramHandle = _instagramCtrl.text.trim();
      final tiktokHandle = _tiktokCtrl.text.trim();
      final youtubeHandle = _youtubeCtrl.text.trim();
      final twitterHandle = _twitterCtrl.text.trim();

      final handles = {
        'Instagram': instagramHandle,
        'TikTok': tiktokHandle,
        'YouTube': youtubeHandle,
        'Twitter': twitterHandle,
      };

      final int instagramFollowers = int.tryParse(_instagramFollowersCtrl.text.trim()) ?? 0;
      final int tiktokFollowers = int.tryParse(_tiktokFollowersCtrl.text.trim()) ?? 0;
      final int youtubeFollowers = int.tryParse(_youtubeFollowersCtrl.text.trim()) ?? 0;
      final int twitterFollowers = int.tryParse(_twitterFollowersCtrl.text.trim()) ?? 0;

      final followers = {
        'Instagram': instagramFollowers,
        'TikTok': tiktokFollowers,
        'YouTube': youtubeFollowers,
        'Twitter': twitterFollowers,
      };

      currentPrefs['platform_handles'] = handles;
      currentPrefs['platform_followers'] = followers;
      currentPrefs['latitude'] = _latitude;
      currentPrefs['longitude'] = _longitude;

      int totalFollowers = instagramFollowers + tiktokFollowers + youtubeFollowers + twitterFollowers;

      await ref.read(authProvider.notifier).updatePreferences(currentPrefs);
      await ProfileService().updateProfile(user.id, {
        'display_name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'avatar_url': _avatarUrl,
        'follower_count': totalFollowers,
        'platforms': handles.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toList(),
      });
      await ref.read(authProvider.notifier).refreshProfile();
      if (mounted) {
        AppSnackbar.show(context, 'Profile and platforms updated! Total followers: $totalFollowers');
        _setEditing(false);
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _villageCtrl.dispose();
    _mandalCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _youtubeCtrl.dispose();
    _twitterCtrl.dispose();
    _instagramFollowersCtrl.dispose();
    _tiktokFollowersCtrl.dispose();
    _youtubeFollowersCtrl.dispose();
    _twitterFollowersCtrl.dispose();
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
        _bioCtrl.text = next.profile!['bio'] ?? '';
        _locationCtrl.text = next.profile!['location'] ?? '';
        _avatarUrl = next.profile!['avatar_url'];
        
        final parts = _splitLocation(_locationCtrl.text);
        _villageCtrl.text = parts[0];
        _mandalCtrl.text = parts[1];
        _districtCtrl.text = parts[2];
        _stateCtrl.text = parts[3];

        final prefs = next.profile!['preferences'] as Map<String, dynamic>? ?? {};
        _latitude = (prefs['latitude'] as num?)?.toDouble();
        _longitude = (prefs['longitude'] as num?)?.toDouble();

        _loadSocialHandles(next.profile);
      }
    });


    final profile = ref.watch(authProvider).profile;
    final niches = (profile?['niche'] as List?)?.cast<String>() ?? [];
    final platforms = (profile?['platforms'] as List?)?.cast<String>() ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    final followersCount = profile?['follower_count'] ?? 0;
    String followersText = '${followersCount}';
    if (followersCount >= 1000) {
      followersText = '${(followersCount / 1000).toStringAsFixed(1)}K';
    }

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
                  onTap: () => context.push('/influencer/notifications'),
                ),
                const SizedBox(width: 8),
                _buildAppBarIcon(
                  icon: Iconsax.setting_2,
                  onTap: () => context.push('/influencer/settings'),
                ),
              ],
            ],
          ),
        ),
      ),
      body: _loadingData
          ? const SkeletonShimmer(child: ProfileDetailSkeleton())
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
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _uploadingAvatar
                                  ? Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.surface2,
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : AppAvatar(
                                      url: _avatarUrl,
                                      fallbackText: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'I',
                                      size: 100,
                                    ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickProfileAvatar,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6), width: 2),
                                    ),
                                    child: const Icon(
                                      Iconsax.camera,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppTextField(label: 'Display Name', controller: _nameCtrl),
                        const SizedBox(height: 16),
                        AppTextField(label: 'Bio', controller: _bioCtrl, maxLines: 4),
                        const SizedBox(height: 16),
                        AppTextField(label: 'Village / Street', controller: _villageCtrl, onChanged: (_) => _updateLocationString()),
                        const SizedBox(height: 16),
                        AppTextField(label: 'Mandal / Town', controller: _mandalCtrl, onChanged: (_) => _updateLocationString()),
                        const SizedBox(height: 16),
                        AppTextField(label: 'District', controller: _districtCtrl, onChanged: (_) => _updateLocationString()),
                        const SizedBox(height: 16),
                        AppTextField(label: 'State', controller: _stateCtrl, onChanged: (_) => _updateLocationString()),
                        const SizedBox(height: 16),
                        _isLoadingLocation
                            ? const Center(child: CircularProgressIndicator())
                            : AppButton(
                                label: 'Use Current Location',
                                icon: Iconsax.location,
                                isPrimary: false,
                                onTap: _getCurrentLocation,
                              ),
                        const SizedBox(height: 24),
                        Text('Connected Platforms', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Enter your social media handles and follower counts manually.',
                          style: AppTextStyles.captionSm.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Instagram Handle',
                          controller: _instagramCtrl,
                          hint: 'username or profile URL',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset('assets/Social media icons/Instagram logo.png', width: 20, height: 20),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          label: 'Instagram Followers',
                          controller: _instagramFollowersCtrl,
                          hint: 'e.g. 5000',
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Iconsax.people, color: Color(0xFFE1306C), size: 20),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'TikTok Handle',
                          controller: _tiktokCtrl,
                          hint: 'username or profile URL',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset('assets/Social media icons/Tiktok logo.png', width: 20, height: 20),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          label: 'TikTok Followers',
                          controller: _tiktokFollowersCtrl,
                          hint: 'e.g. 5000',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icon(Iconsax.people, color: AppColors.textPrimary, size: 20),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'YouTube Channel / Handle',
                          controller: _youtubeCtrl,
                          hint: 'channel URL or handle',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset('assets/Social media icons/youtube logo.png', width: 20, height: 20),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          label: 'YouTube Followers',
                          controller: _youtubeFollowersCtrl,
                          hint: 'e.g. 5000',
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Iconsax.people, color: Color(0xFFFF0000), size: 20),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Twitter / X Handle',
                          controller: _twitterCtrl,
                          hint: 'username or profile URL',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset('assets/Social media icons/x logo.png', width: 20, height: 20),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          label: 'Twitter / X Followers',
                          controller: _twitterFollowersCtrl,
                          hint: 'e.g. 5000',
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Iconsax.people, color: Color(0xFF1DA1F2), size: 20),
                        ),
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
                                      AppAvatar(url: profile?['avatar_url'], fallbackText: profile?['display_name'] ?? 'I', size: 60),
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
                                                profile?['display_name'] ?? 'Creator',
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
                                              Icon(Iconsax.star5, color: Colors.orange, size: 14),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              profile?['is_verified'] == true ? 'Verified Creator' : 'Essential',
                                              style: AppTextStyles.captionSm.copyWith(
                                                color: Colors.orange,
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
                              Divider(
                                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                                height: 1,
                              ),
                              const SizedBox(height: 16),
                              // Stats (divided by vertical lines)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _profileStatItem('Followers', followersText),
                                  Container(
                                    width: 1,
                                    height: 28,
                                    color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                                  ),
                                  _profileStatItem(
                                    'Niches',
                                    '${niches.length}',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => InfluencerNichesScreen(niches: niches),
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    width: 1,
                                    height: 28,
                                    color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                                  ),
                                  _profileStatItem(
                                    'Platforms',
                                    '${platforms.length}',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => InfluencerPlatformsScreen(
                                            platforms: platforms,
                                            followersCount: followersCount,
                                            displayName: profile?['display_name'] ?? 'Creator',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    width: 1,
                                    height: 28,
                                    color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                                  ),
                                  _profileStatItem('Applied', '$_appsCount'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _showMediaKit(context, profile, niches, platforms, followersText),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.01),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.purple.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Iconsax.cards, color: AppColors.purple, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'My Digital Card',
                                        style: AppTextStyles.label.copyWith(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Showcase your stats and portfolio to brands',
                                        style: AppTextStyles.captionSm.copyWith(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 16),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        // Action buttons row (right screen style)
                        Row(
                          children: [
                            _capsuleButton(
                              'Portfolio',
                              Iconsax.gallery,
                              isDark ? const Color(0xFFF5C518) : const Color(0xFFDDA600),
                              () => context.push('/influencer/portfolio'),
                            ),
                            const SizedBox(width: 12),
                            _capsuleButton(
                              'Chats',
                              Iconsax.message,
                              isDark ? const Color(0xFF2ECC71) : const Color(0xFF1E8449),
                              () => context.go('/influencer/chats'),
                            ),
                            const SizedBox(width: 12),
                            _capsuleButton(
                              'Settings',
                              Iconsax.setting_2,
                              isDark ? const Color(0xFF3498DB) : const Color(0xFF21618C),
                              () => context.push('/influencer/settings'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Portfolio Section (grid style from left screen)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('My Portfolio', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: () => context.push('/influencer/portfolio'),
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
                        if (_portfolio.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Iconsax.gallery, color: AppColors.textMuted, size: 36),
                                const SizedBox(height: 12),
                                Text('No portfolio items yet', style: AppTextStyles.label),
                                const SizedBox(height: 4),
                                Text('Add images of your previous works to show brands.', style: AppTextStyles.captionSm, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(Iconsax.add, size: 16),
                                  label: const Text('Add Item'),
                                  onPressed: () => context.push('/influencer/portfolio'),
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
                              final displayItems = _portfolio.take(4).toList();
                              return Column(
                                children: [
                                  for (int i = 0; i < displayItems.length; i += 2) ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _buildPortfolioCard(context, displayItems[i])),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: i + 1 < displayItems.length
                                              ? _buildPortfolioCard(context, displayItems[i + 1])
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                    if (i + 2 < displayItems.length) const SizedBox(height: 16),
                                  ],
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: 24),
                        // Options menu list (right screen style)
                        Text('Menu', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Material(
                          color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              children: [
                                _menuTile('Discover Brands', Iconsax.briefcase, () => context.go('/influencer/brands')),
                                _menuDivider(),
                                _menuTile(
                                  'Following',
                                  Iconsax.people,
                                  () => context.push('/influencer/brands?tab=following'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${_followingBrands.length} ${_followingBrands.length == 1 ? 'brand' : 'brands'}',
                                        style: AppTextStyles.captionSm.copyWith(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
                                    ],
                                  ),
                                ),
                                _menuDivider(),
                                _menuTile('Help Center', Iconsax.info_circle, () => context.push('/influencer/support')),
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
                        // Footer (Jio Style)
                        const SizedBox(height: 56),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 40),
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
                                'your influence.',
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
                        ),
                      ],
              ),
            ),
    );
  }

  Widget _profileStatItem(String label, String value, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(value, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: AppTextStyles.captionSm.copyWith(
                    color: onTap != null ? AppColors.accent : AppColors.textMuted,
                    fontWeight: onTap != null ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down_rounded, size: 12, color: AppColors.accent),
                ],
              ],
            ),
          ],
        ),
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

  Widget _menuTile(String title, IconData icon, VoidCallback onTap, {bool isDestructive = false, Widget? trailing}) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: isDestructive ? AppColors.error : AppColors.accent, size: 20),
      title: Text(title, style: AppTextStyles.label.copyWith(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
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

  Widget _buildPortfolioCard(BuildContext context, Map<String, dynamic> item) {
    final mediaUrl = item['media_url'] as String?;
    final postUrl = item['post_url'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 0.85,
      child: GestureDetector(
        onTap: () => _showEditDialog(item),
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
                  url: mediaUrl,
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
                      child: Icon(Iconsax.gallery, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['title'] ?? 'Portfolio Item',
                            style: AppTextStyles.label.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (postUrl != null && postUrl.trim().isNotEmpty)
                          Icon(Iconsax.link, size: 12, color: AppColors.accent),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['platform'] ?? item['description'] ?? '',
                      style: AppTextStyles.captionSm.copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Future<void> _showEditDialog(Map<String, dynamic> item) async {
    final titleCtrl = TextEditingController(text: item['title'] ?? '');
    final platformCtrl = TextEditingController(text: item['platform'] ?? '');
    final urlCtrl = TextEditingController(text: item['media_url'] ?? '');
    final postUrlCtrl = TextEditingController(text: item['post_url'] ?? '');

    final existingPhotos = _portfolio
        .map((e) => e['media_url'] as String?)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();

    String? selectedMediaUrl = item['media_url'];
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Edit Portfolio Item', style: AppTextStyles.h3, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  AppTextField(label: 'Title', hint: 'My Instagram Reel', controller: titleCtrl),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Platform', hint: 'Instagram', controller: platformCtrl),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Reel / Post URL', hint: 'https://instagram.com/p/...', controller: postUrlCtrl),
                  const SizedBox(height: 16),
                  
                  Text('COVER PHOTO', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: selectedMediaUrl != null && selectedMediaUrl!.isNotEmpty
                        ? AppImage(
                            url: selectedMediaUrl!,
                            fit: BoxFit.cover,
                            fallback: Center(child: Icon(Iconsax.gallery, size: 40, color: AppColors.textMuted)),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Iconsax.image, size: 36, color: AppColors.textMuted),
                                const SizedBox(height: 8),
                                Text('No cover photo selected', style: AppTextStyles.captionSm),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: uploading
                              ? null
                              : () async {
                                  final ImageSource? source = await showModalBottomSheet<ImageSource>(
                                    context: context,
                                    backgroundColor: AppColors.surface,
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                    builder: (ctx2) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(Iconsax.camera),
                                            title: const Text('Take Photo'),
                                            onTap: () => Navigator.pop(ctx2, ImageSource.camera),
                                          ),
                                          ListTile(
                                            leading: const Icon(Iconsax.image),
                                            title: const Text('Choose from Gallery'),
                                            onTap: () => Navigator.pop(ctx2, ImageSource.gallery),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (source == null) return;
                                  setDialogState(() => uploading = true);
                                  try {
                                    final user = ref.read(authProvider).user!;
                                    final picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
                                    if (image != null) {
                                      final bytes = await image.readAsBytes();
                                      final fileExt = image.name.split('.').last.toLowerCase();
                                      final cleanExt = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(fileExt) ? fileExt : 'jpg';
                                      final fileName = 'portfolio_${DateTime.now().microsecondsSinceEpoch}.$cleanExt';
                                      final path = '${user.id}/$fileName';
                                      final publicUrl = await StorageService().uploadFile(
                                        'portfolio',
                                        path,
                                        bytes,
                                        'image/$cleanExt',
                                      );
                                      setDialogState(() {
                                        selectedMediaUrl = publicUrl;
                                        urlCtrl.text = publicUrl;
                                      });
                                    }
                                  } catch (e) {
                                    print('Error uploading photo: $e');
                                    if (context.mounted) {
                                      AppSnackbar.show(context, 'Failed to upload photo: $e');
                                    }
                                  } finally {
                                    setDialogState(() => uploading = false);
                                  }
                                },
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Center(
                              child: uploading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Iconsax.document_upload, size: 20, color: AppColors.accent),
                                        const SizedBox(height: 4),
                                        const Text('Upload', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        ...existingPhotos.map((photoUrl) {
                          final isSelected = selectedMediaUrl == photoUrl;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedMediaUrl = photoUrl;
                                urlCtrl.text = photoUrl;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 10),
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                border: Border.all(
                                  color: isSelected ? AppColors.accent : AppColors.border,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AppImage(
                                    url: photoUrl,
                                    fit: BoxFit.cover,
                                    fallback: Center(child: Icon(Iconsax.image, size: 20, color: AppColors.textMuted)),
                                  ),
                                  if (isSelected)
                                    Container(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      child: const Center(
                                        child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  AppTextField(
                    label: 'Or Custom Image URL',
                    hint: 'https://...',
                    controller: urlCtrl,
                    onChanged: (val) {
                      setDialogState(() {
                        selectedMediaUrl = val.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Delete',
                          isPrimary: false,
                          onTap: () async {
                            final confirmed = await showPremiumConfirmDialog(
                              context: context,
                              title: 'Delete Portfolio Item',
                              message: 'Are you sure you want to delete "${item['title'] ?? 'Untitled'}"?',
                              confirmLabel: 'Delete',
                              isDestructive: true,
                              icon: Iconsax.trash,
                            );
                            if (confirmed == true) {
                              try {
                                await PortfolioService().deletePortfolioItem(item['id'] as String);
                                if (mounted) Navigator.pop(ctx);
                                _loadDashboardData();
                              } catch (e) {
                                if (context.mounted) {
                                  AppSnackbar.show(context, 'Failed to delete: $e');
                                }
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'Save',
                          onTap: () async {
                            if (titleCtrl.text.isNotEmpty) {
                              try {
                                await PortfolioService().updatePortfolioItem(item['id'] as String, {
                                  'title': titleCtrl.text.trim(),
                                  'platform': platformCtrl.text.trim(),
                                  'media_url': urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                                  'post_url': postUrlCtrl.text.trim().isEmpty ? null : postUrlCtrl.text.trim(),
                                });
                                if (mounted) Navigator.pop(ctx);
                                _loadDashboardData();
                              } catch (e) {
                                if (context.mounted) {
                                  AppSnackbar.show(context, 'Failed to save: $e');
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMediaKit(
    BuildContext context,
    Map<String, dynamic>? profile,
    List<String> niches,
    List<String> platforms,
    String followersText,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0F11) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Media Kit Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16161A) : const Color(0xFFF9F9FB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF26262B) : const Color(0xFFE5E7EB),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    AppAvatar(
                      url: profile?['avatar_url'],
                      fallbackText: profile?['display_name'] ?? 'I',
                      size: 72,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          profile?['display_name'] ?? 'Creator',
                          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (profile?['is_verified'] == true) ...[
                          const SizedBox(width: 4),
                          const VerificationBadge(size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile?['location'] ?? 'Global Partner',
                      style: AppTextStyles.captionSm,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _mediaKitStatItem('FOLLOWERS', followersText),
                        Container(
                          width: 1,
                          height: 24,
                          color: isDark ? const Color(0xFF26262B) : const Color(0xFFE5E7EB),
                        ),
                        _mediaKitStatItem('ENGAGEMENT', '4.8%'),
                        Container(
                          width: 1,
                          height: 24,
                          color: isDark ? const Color(0xFF26262B) : const Color(0xFFE5E7EB),
                        ),
                        _mediaKitStatItem('CHANNELS', '${platforms.length}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Bio Section
              if (profile?['bio'] != null && (profile!['bio'] as String).isNotEmpty) ...[
                Text('CREATOR BIO', style: AppTextStyles.overline.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Text(
                  profile['bio'],
                  style: AppTextStyles.bodySm.copyWith(height: 1.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
              ],
 
              // Niches Section
              if (niches.isNotEmpty) ...[
                Text('NICHES & INDUSTRIES', style: AppTextStyles.overline.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: niches.map((n) => AppChip(label: n, selected: true, color: AppColors.getCategoryColor(n))).toList(),
                ),
                const SizedBox(height: 20),
              ],
 
              // Portfolio Highlights Section
              Text('PORTFOLIO HIGHLIGHTS', style: AppTextStyles.overline.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 8),
              if (_portfolio.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  child: Text('No portfolio items added yet.', style: AppTextStyles.caption),
                )
              else
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _portfolio.length,
                    itemBuilder: (context, idx) {
                      final item = _portfolio[idx];
                      return GestureDetector(
                        onTap: () => PortfolioItemDetailSheet.show(context, item),
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF16161A) : const Color(0xFFF9F9FB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF26262B) : const Color(0xFFE5E7EB),
                              width: 1.2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AppImage(
                            url: item['media_url'],
                            fit: BoxFit.cover,
                            fallback: Icon(Iconsax.image, color: AppColors.textMuted),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Share Digital Card',
                      icon: Iconsax.export_1,
                      onTap: () async {
                        final profileId = profile?['id'] ?? '';
                        final displayName = profile?['display_name'] ?? 'Creator';
                        final followers = followersText;
                        final nichesStr = niches.join(', ');
                        final shareUrl = 'https://lokoxgwymvvnxhmavuyv.supabase.co/storage/v1/object/public/cards/index.html?profileId=$profileId';
                        
                        final shareText = 'Check out my Digital Card / Media Kit on Promo!\n'
                            'Name: $displayName\n'
                            'Followers: $followers\n'
                            'Niches: $nichesStr\n\n'
                            'View my full profile here: $shareUrl';
                            
                        await Clipboard.setData(ClipboardData(text: shareText));
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          AppSnackbar.success(context, 'Digital card profile details copied to clipboard!');
                          await Share.share(shareText, subject: '$displayName\'s Digital Card');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Close',
                      isPrimary: false,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
 
  Widget _mediaKitStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.overline.copyWith(fontSize: 8),
        ),
      ],
    );
  }
}

// ========== Influencer Niches Detail Screen ==========
class InfluencerNichesScreen extends StatelessWidget {
  final List<String> niches;

  const InfluencerNichesScreen({super.key, required this.niches});

  static final Map<String, String> _nicheImages = {
    'tech': 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=500&auto=format&fit=crop',
    'food': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=500&auto=format&fit=crop',
    'fashion': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=500&auto=format&fit=crop',
    'travel': 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=500&auto=format&fit=crop',
    'gaming': 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=500&auto=format&fit=crop',
    'fitness': 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=500&auto=format&fit=crop',
    'beauty': 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=500&auto=format&fit=crop',
    'lifestyle': 'https://images.unsplash.com/photo-1511556532299-8f662fc26c06?w=500&auto=format&fit=crop',
  };

  static final Map<String, String> _nicheDescriptions = {
    'tech': 'Gadgets, reviews, software, and future tech trends.',
    'food': 'Gourmet cooking, restaurant reviews, and recipes.',
    'fashion': 'Style trends, outfit inspiration, and brand collabs.',
    'travel': 'Destination guides, travel hacks, and photography.',
    'gaming': 'Let\'s plays, streams, game news, and reviews.',
    'fitness': 'Workouts, nutrition guides, and wellness tips.',
    'beauty': 'Skincare routines, makeup tutorials, and reviews.',
    'lifestyle': 'Daily vlogs, organization, and personal growth.',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F16) : const Color(0xFFFAFAFC),
      appBar: AppBar(
        title: const Text('My Niches'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: niches.isEmpty
          ? const AppEmptyState(
              icon: Iconsax.category,
              title: 'No Niches Added',
              subtitle: 'Edit your profile to add content niches.',
            )
          : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: niches.length,
              itemBuilder: (context, index) {
                final nicheKey = niches[index].toLowerCase().trim();
                final imageUrl = _nicheImages[nicheKey] ??
                    'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=500&auto=format&fit=crop';
                final description = _nicheDescriptions[nicheKey] ?? 'Content creation and audience engagement in ${niches[index]}.';

                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14141E) : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // Image Background
                      Positioned.fill(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.surface2,
                            child: Icon(Iconsax.gallery, color: AppColors.textMuted),
                          ),
                        ),
                      ),
                      // Dark Overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.1),
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Content
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2ECC71),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    niches[index],
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              description,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10,
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ========== Influencer Platforms Detail Screen ==========
class InfluencerPlatformsScreen extends StatelessWidget {
  final List<String> platforms;
  final int followersCount;
  final String displayName;

  const InfluencerPlatformsScreen({
    super.key,
    required this.platforms,
    required this.followersCount,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasInstagram = platforms.isEmpty || platforms.any((p) => p.toLowerCase().contains('instagram')); // Default to Instagram link if empty for demo

    String followersText = '${followersCount}';
    if (followersCount >= 1000) {
      followersText = '${(followersCount / 1000).toStringAsFixed(1)}K';
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F16) : const Color(0xFFFAFAFC),
      appBar: AppBar(
        title: const Text('Connected Platforms'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            'Active Connections',
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (hasInstagram) ...[
            _instagramCard(context, isDark, followersText),
            const SizedBox(height: 20),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  'No platforms linked yet.',
                  style: AppTextStyles.caption,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'Available to Link',
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _inactivePlatformCard('YouTube', 'assets/Social media icons/youtube logo.png'),
          const SizedBox(height: 12),
          _inactivePlatformCard('TikTok', 'assets/Social media icons/Tiktok logo.png'),
          const SizedBox(height: 12),
          _inactivePlatformCard('Twitter / X', 'assets/Social media icons/x logo.png'),
        ],
      ),
    );
  }

  Widget _instagramCard(BuildContext context, bool isDark, String followersText) {
    final handle = '@${displayName.toLowerCase().replaceAll(' ', '_')}';
    final username = handle.replaceAll('@', '').trim();
    final url = Uri.parse('https://www.instagram.com/$username/');

    return GestureDetector(
      onTap: () async {
        try {
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            AppSnackbar.show(context, 'Could not launch Instagram: $handle');
          }
        } catch (e) {
          AppSnackbar.show(context, 'Error launching Instagram: $e');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2E1A2B), const Color(0xFF161424)]
                : [const Color(0xFFFDF0F6), const Color(0xFFF3EFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/Social media icons/Instagram logo.png',
                  width: 48,
                  height: 48,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instagram',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        handle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Color(0xFF2ECC71), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Active',
                        style: TextStyle(color: Color(0xFF2ECC71), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricCol('Followers', followersText),
                _metricCol('Niche', 'Tech / Food'),
                _metricCol('Engagement', '4.2%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCol(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _inactivePlatformCard(String name, String assetPath) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(assetPath, width: 24, height: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reach wider brand partnerships.',
                  style: AppTextStyles.captionSm,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: Text(
              'Link',
              style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileViewsScreen extends ConsumerStatefulWidget {
  const ProfileViewsScreen({super.key});

  @override
  ConsumerState<ProfileViewsScreen> createState() => _ProfileViewsScreenState();
}

class _ProfileViewsScreenState extends ConsumerState<ProfileViewsScreen> {
  List<Map<String, dynamic>> _views = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadViews();
  }

  Future<void> _loadViews() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final data = await AnalyticsService().getProfileViews(user.id);
      if (mounted) {
        setState(() {
          _views = data;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading profile views screen: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Views'),
      ),
      body: _loading
          ? SkeletonShimmer(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, __) => const GenericListTileSkeleton(),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadViews,
              color: AppColors.accent,
              child: _views.isEmpty
                  ? const AppEmptyState(
                      icon: Iconsax.eye,
                      title: 'No views yet',
                      subtitle: 'Share your profile to brands to get more views!',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical,
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                      ),
                      itemCount: _views.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final view = _views[i];
                        final viewer = view['viewer'] as Map<String, dynamic>? ?? {};
                        final displayName = viewer['display_name'] ?? 'Anonymous Brand';
                        final isBrand = viewer['role'] == 'brand';
                        final isVerified = viewer['is_verified'] == true;
                        final company = viewer['company_name'] ?? viewer['industry'] ?? 'Brand Partner';
                        final timestamp = view['viewed_at'] as String?;

                        String timeString = 'Recent';
                        if (timestamp != null) {
                          try {
                            final dt = DateTime.parse(timestamp);
                            timeString = '${dt.day}/${dt.month}/${dt.year}';
                          } catch (_) {}
                        }

                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    final id = viewer['id'];
                                    if (id == null) return;
                                    if (isBrand) {
                                      context.push('/influencer/brands/$id');
                                    } else {
                                      context.push('/search');
                                    }
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Row(
                                    children: [
                                      AppAvatar(
                                        url: viewer['avatar_url'],
                                        fallbackText: displayName,
                                        size: 44,
                                        onTap: () {
                                          final id = viewer['id'];
                                          if (id == null) return;
                                          if (isBrand) {
                                            context.push('/influencer/brands/$id');
                                          } else {
                                            context.push('/search');
                                          }
                                        },
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
                                                    displayName,
                                                    style: AppTextStyles.label,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isVerified) ...[
                                                  const SizedBox(width: 4),
                                                  const VerificationBadge(size: 14),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isBrand ? company : 'Content Creator',
                                              style: AppTextStyles.captionSm,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    timeString,
                                    style: AppTextStyles.captionSm.copyWith(fontSize: 10),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () {
                                      final id = viewer['id'];
                                      if (id == null) return;
                                      if (isBrand) {
                                        context.push('/influencer/brands/$id');
                                      } else {
                                        context.push('/search');
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'View Profile',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ========== Influencer Engagement Insights Screen ==========
class EngagementRateScreen extends ConsumerWidget {
  const EngagementRateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final followerCount = profile?['follower_count'] as int? ?? 0;
    final erValue = followerCount > 5000 ? "5.4%" : "4.8%";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Engagement Insights'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMarginHorizontal,
          16,
          AppSpacing.pageMarginHorizontal,
          AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
        ),
        children: [
          // 1. Current Engagement Score Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFDCFCE7).withValues(alpha: 0.8),
                  const Color(0xFFBBF7D0).withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Iconsax.activity,
                  color: Color(0xFF15803D),
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your Engagement Rate',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  erValue,
                  style: GoogleFonts.inter(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF166534),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'High Engagement Tier',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. What is Engagement Rate?
          Text(
            'What is Engagement Rate?',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Engagement Rate (ER) is a key performance indicator that measures the level of active interaction (likes, comments, shares, saves) that your content gets relative to your total followers.',
                  style: AppTextStyles.caption.copyWith(height: 1.5, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  'Why brands care:',
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Brands prefer a creator with 10k followers and 5% ER over one with 100k followers and 0.5% ER. High ER proves that your audience is real, active, and highly receptive to your recommendations.',
                  style: AppTextStyles.caption.copyWith(height: 1.5, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. How it is calculated?
          Text(
            'How is it calculated?',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We aggregate interactions across all connected profiles and divide them by your total follower base:',
                  style: AppTextStyles.caption.copyWith(height: 1.5, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Likes + Comments + Shares',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          height: 1.5,
                          color: AppColors.border,
                          width: 180,
                        ),
                      ),
                      Text(
                        'Total Followers',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '× 100',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Benchmark Tiers
          Text(
            'Industry Benchmarks',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildTierRow('Below 1%', 'Low', Colors.red),
                const Divider(height: 20),
                _buildTierRow('1% – 3%', 'Average', Colors.orange),
                const Divider(height: 20),
                _buildTierRow('3% – 6%', 'High (Great!)', Colors.green),
                const Divider(height: 20),
                _buildTierRow('Above 6%', 'Exceptional', AppColors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierRow(String range, String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          range,
          style: GoogleFonts.firaCode(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ========== Influencer Milestones Hub Screen ==========
class InfluencerMilestonesScreen extends ConsumerStatefulWidget {
  const InfluencerMilestonesScreen({super.key});

  @override
  ConsumerState<InfluencerMilestonesScreen> createState() => _InfluencerMilestonesScreenState();
}

class _InfluencerMilestonesScreenState extends ConsumerState<InfluencerMilestonesScreen> {
  List<Map<String, dynamic>> _collaborations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final apps = await ApplicationService().getApplicationsForInfluencer(user.id);
      final acceptedApps = apps.where((a) => a['status'] == 'accepted').toList();

      List<Map<String, dynamic>> collaborations = [];
      for (final app in acceptedApps) {
        final card = app['card'] as Map<String, dynamic>? ?? {};
        final brand = card['brand'] as Map<String, dynamic>? ?? {};
        final cardId = card['id'];
        final brandId = brand['id'];
        if (cardId == null || brandId == null) continue;

        final room = await ChatService().getOrCreate1to1Room(
          brandId: brandId,
          influencerId: user.id,
          cardId: cardId,
        );
        final milestones = await ChatService().getMilestones(room['id']);
        collaborations.add({
          'application': app,
          'card': card,
          'brand': brand,
          'room_id': room['id'],
          'milestones': milestones,
        });
      }

      if (mounted) {
        setState(() {
          _collaborations = collaborations;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading milestones hub: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'No deadline set';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _toggleMilestone(Map<String, dynamic> m) async {
    final done = m['status'] == 'completed';
    final newStatus = done ? 'pending' : 'completed';

    setState(() {
      m['status'] = newStatus;
    });

    try {
      await ChatService().updateMilestoneStatus(m['id'] as String, newStatus);
    } catch (e) {
      setState(() {
        m['status'] = done ? 'completed' : 'pending';
      });
      if (mounted) {
        AppSnackbar.show(context, 'Failed to update milestone status');
      }
    }
  }

  Future<void> _requestExtension(Map<String, dynamic> m) async {
    DateTime? selectedDate;
    final reasonCtrl = TextEditingController();

    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Request Extension',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Propose a new due date and provide a brief explanation to the brand.',
                    style: AppTextStyles.captionSm,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'NEW PROPOSED DATE',
                    style: AppTextStyles.overline,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 3)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setModalState(() {
                          selectedDate = date;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate == null
                                ? 'Select new date...'
                                : DateFormat('MMMM d, yyyy').format(selectedDate!),
                            style: AppTextStyles.body.copyWith(
                              color: selectedDate == null ? AppColors.textMuted : AppColors.textPrimary,
                            ),
                          ),
                          Icon(Iconsax.calendar_1, color: AppColors.accent, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'REASON FOR EXTENSION',
                    style: AppTextStyles.overline,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'e.g. Awaiting product delivery, editing delays...',
                      hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surface2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        borderSide: BorderSide(color: AppColors.accent, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Cancel',
                          isPrimary: false,
                          onTap: () => Navigator.pop(context, false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'Submit Request',
                          onTap: () {
                            if (selectedDate == null) {
                              AppSnackbar.show(ctx, 'Please select a new proposed date');
                              return;
                            }
                            if (reasonCtrl.text.trim().isEmpty) {
                              AppSnackbar.show(ctx, 'Please specify a reason');
                              return;
                            }
                            Navigator.pop(context, true);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (success == true && selectedDate != null) {
      final ext = MilestoneExtension(
        newDueDate: selectedDate!,
        status: 'pending',
        reason: reasonCtrl.text.trim(),
      );
      final displayTitle = MilestoneHelper.getDisplayTitle(m['title']);
      final newRawTitle = MilestoneHelper.buildRawTitle(displayTitle, ext);

      final oldTitle = m['title'];
      setState(() {
        m['title'] = newRawTitle;
      });

      try {
        await ChatService().updateMilestoneTitle(m['id'] as String, newRawTitle);
        if (mounted) {
          AppSnackbar.show(context, 'Extension requested successfully!');
        }
      } catch (e) {
        setState(() {
          m['title'] = oldTitle;
        });
        if (mounted) {
          AppSnackbar.show(context, 'Failed to submit extension request: $e');
        }
      }
    }
    reasonCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              onPressed: () => context.go('/influencer/home'),
            ),
            leadingWidth: 30,
            titleSpacing: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Milestones',
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
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: _loading
          ? SkeletonShimmer(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, __) => const ApplicationCardSkeleton(),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.accent,
              child: _collaborations.isEmpty
                  ? const AppEmptyState(
                      icon: Iconsax.crown,
                      title: 'No active collaborations',
                      subtitle: 'Milestones will appear here once campaign requests are accepted!',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical,
                        AppSpacing.pageMarginHorizontal,
                        AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
                      ),
                      itemCount: _collaborations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final col = _collaborations[i];
                        final card = col['card'] as Map<String, dynamic>? ?? {};
                        final brand = col['brand'] as Map<String, dynamic>? ?? {};
                        final milestones = col['milestones'] as List<dynamic>? ?? [];

                        final completedCount = milestones.where((m) => m['status'] == 'completed').length;
                        final totalCount = milestones.length;
                        final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

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
                              // Brand + Campaign details header
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        final bId = brand['id'];
                                        if (bId != null) {
                                          context.push('/influencer/brands/$bId');
                                        }
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: Row(
                                        children: [
                                          AppAvatar(
                                            url: brand['avatar_url'],
                                            fallbackText: brand['display_name'] ?? 'B',
                                            size: 40,
                                            onTap: () {
                                              final bId = brand['id'];
                                              if (bId != null) {
                                                context.push('/influencer/brands/$bId');
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  brand['display_name'] ?? 'Brand',
                                                  style: AppTextStyles.label.copyWith(fontSize: 13, color: AppColors.textMuted),
                                                ),
                                                Text(
                                                  card['title'] ?? 'Campaign Name',
                                                  style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (card['budget'] != null)
                                    Text(
                                      card['budget_range'] ?? '\$${card['budget']}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Symmetrical Progress indicator
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Milestone Progress',
                                    style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    '$completedCount / $totalCount Completed',
                                    style: AppTextStyles.captionSm.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: AppColors.surface2,
                                  valueColor: AlwaysStoppedAnimation(AppColors.accent),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // List of milestones
                              if (milestones.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    'No milestones defined for this contract.',
                                    style: AppTextStyles.captionSm.copyWith(fontStyle: FontStyle.italic),
                                  ),
                                )
                              else
                                ...milestones.map((m) {
                                  final isCompleted = m['status'] == 'completed';
                                  final rawTitle = m['title'] as String? ?? '';
                                  final displayTitle = MilestoneHelper.getDisplayTitle(rawTitle);
                                  final ext = MilestoneHelper.getExtension(rawTitle);

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () => _toggleMilestone(m),
                                              child: Icon(
                                                isCompleted
                                                    ? Icons.check_box_rounded
                                                    : Icons.check_box_outline_blank_rounded,
                                                size: 22,
                                                color: isCompleted ? AppColors.success : AppColors.textMuted,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    displayTitle,
                                                    style: AppTextStyles.body.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                      color: isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Icon(Iconsax.calendar, size: 12, color: AppColors.textMuted),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Due: ${_formatDate(m['due_date'])}',
                                                        style: AppTextStyles.captionSm.copyWith(fontSize: 11),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (!isCompleted && ext == null)
                                              OutlinedButton.icon(
                                                onPressed: () => _requestExtension(m),
                                                icon: Icon(Iconsax.clock, size: 12, color: AppColors.textSecondary),
                                                label: Text(
                                                  'Extend',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  minimumSize: const Size(60, 24),
                                                  side: BorderSide(color: AppColors.border),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(100),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (ext != null) ...[
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 32.0),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: ext.status == 'pending'
                                                    ? AppColors.warning.withValues(alpha: 0.1)
                                                    : ext.status == 'approved'
                                                        ? AppColors.success.withValues(alpha: 0.1)
                                                        : AppColors.error.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                                border: Border.all(
                                                  color: ext.status == 'pending'
                                                      ? AppColors.warning.withValues(alpha: 0.2)
                                                      : ext.status == 'approved'
                                                          ? AppColors.success.withValues(alpha: 0.2)
                                                          : AppColors.error.withValues(alpha: 0.2),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        ext.status == 'pending'
                                                            ? Iconsax.info_circle
                                                            : ext.status == 'approved'
                                                                ? Icons.check_circle_rounded
                                                                : Icons.cancel_rounded,
                                                        size: 13,
                                                        color: ext.status == 'pending'
                                                            ? AppColors.warning
                                                            : ext.status == 'approved'
                                                                ? AppColors.success
                                                                : AppColors.error,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        ext.status == 'pending'
                                                            ? 'Extension Requested'
                                                            : ext.status == 'approved'
                                                                ? 'Extension Approved'
                                                                : 'Extension Rejected',
                                                        style: AppTextStyles.labelSm.copyWith(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: ext.status == 'pending'
                                                              ? AppColors.warning
                                                              : ext.status == 'approved'
                                                                  ? AppColors.success
                                                                  : AppColors.error,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Proposed Date: ${DateFormat('MMMM d, yyyy').format(ext.newDueDate)}',
                                                    style: AppTextStyles.captionSm.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Reason: "${ext.reason}"',
                                                    style: AppTextStyles.captionSm.copyWith(fontSize: 10, fontStyle: FontStyle.italic),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}