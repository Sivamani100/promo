import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'promo_page_service.dart';

class PromoPublicPageScreen extends StatefulWidget {
  final String username;
  const PromoPublicPageScreen({super.key, required this.username});

  @override
  State<PromoPublicPageScreen> createState() => _PromoPublicPageScreenState();
}

class _PromoPublicPageScreenState extends State<PromoPublicPageScreen> with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  PromoPage? _page;
  List<PromoPageLink> _links = [];
  Map<String, dynamic>? _socials;
  
  // Staggered list animations controllers
  List<AnimationController> _staggerControllers = [];
  List<Animation<double>> _fadeAnimations = [];
  List<Animation<Offset>> _slideAnimations = [];

  @override
  void initState() {
    super.initState();
    _fetchPublicPage();
  }

  @override
  void dispose() {
    for (var controller in _staggerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchPublicPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await PromoPageService.getPublicPage(widget.username);
      if (page == null) {
        setState(() {
          _error = '404';
          _loading = false;
        });
        return;
      }

      // Fetch links and socials (unauthenticated)
      final linksList = await PromoPageService.getLinks(page.id, enabledOnly: true);
      final socialsMap = await PromoPageService.getPublicSocials(page.userId);

      setState(() {
        _page = page;
        _links = linksList;
        _socials = socialsMap;
        _loading = false;
      });

      // Track view count safely
      PromoPageService.recordPageView(page.id, Uri.base.toString());

      // Setup staggered animations for links
      _setupAnimations();
    } catch (e) {
      setState(() {
        _error = 'network';
        _loading = false;
      });
    }
  }

  void _setupAnimations() {
    // Clear old controllers
    for (var controller in _staggerControllers) {
      controller.dispose();
    }
    _staggerControllers.clear();
    _fadeAnimations.clear();
    _slideAnimations.clear();

    final count = _links.length + 3; // Avatar, name/bio, socials, then links
    for (int i = 0; i < count; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );

      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );

      final slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
      );

      _staggerControllers.add(controller);
      _fadeAnimations.add(fade);
      _slideAnimations.add(slide);

      // Delay execution sequentially
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (mounted && controller.status == AnimationStatus.dismissed) {
          controller.forward();
        }
      });
    }
  }

  Color _getThemeTextColor(String theme) {
    if (theme == 'light') return const Color(0xFF1A1A1A);
    return Colors.white;
  }

  Color _getThemeMutedTextColor(String theme) {
    if (theme == 'light') return const Color(0xFF626262);
    return Colors.white70;
  }

  Widget _buildSocialIcon(IconData icon, String? url) {
    if (url == null || url.trim().isEmpty) return const SizedBox.shrink();
    final theme = _page?.theme ?? 'dark';
    final textColor = _getThemeTextColor(theme);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: IconButton(
        icon: Icon(icon, size: 24, color: textColor),
        onPressed: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
      ),
    );
  }

  Widget _buildLinkCard(PromoPageLink link, int idx) {
    final theme = _page?.theme ?? 'dark';
    final textColor = _getThemeTextColor(theme);
    final accentHex = _page?.accentColor;
    
    Color accentColor = AppColors.purple;
    if (accentHex != null && accentHex.length == 8) {
      final intVal = int.tryParse(accentHex, radix: 16);
      if (intVal != null) accentColor = Color(intVal);
    }

    // Glassmorphism styling if theme is 'glass'
    final isGlass = theme == 'glass';
    final isDark = theme == 'dark';
    final isLight = theme == 'light';

    BoxDecoration decoration;
    if (isGlass) {
      decoration = BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      );
    } else if (isLight) {
      decoration = BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      );
    } else {
      decoration = BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
      );
    }

    final animeIdx = idx + 3; // skip header indexes
    Widget cardChild = Container(
      decoration: decoration,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          // Increment click count asynchronously
          PromoPageService.incrementLinkClick(link.id);
          final uri = Uri.parse(link.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Text(
                link.icon ?? '🔗',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  link.title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(Iconsax.arrow_right_1, color: textColor.withOpacity(0.6), size: 18),
            ],
          ),
        ),
      ),
    );

    // Apply staggered animation if initialized
    if (animeIdx < _fadeAnimations.length) {
      return FadeTransition(
        opacity: _fadeAnimations[animeIdx],
        child: SlideTransition(
          position: _slideAnimations[animeIdx],
          child: cardChild,
        ),
      );
    }
    return cardChild;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.purple),
        ),
      );
    }

    if (_error == '404') {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.danger, size: 72, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Page Not Found', style: AppTextStyles.h2),
                const SizedBox(height: 8),
                Text(
                  'The user @${widget.username} does not exist or has not created a Promo Page yet.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => launchUrl(Uri.parse('https://promo.arkio.in')),
                  child: const Text('Visit Promo App'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error == 'network') {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.wifi, size: 72, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Network Error', style: AppTextStyles.h2),
                const SizedBox(height: 8),
                const Text('Please check your internet connection and try again.'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _fetchPublicPage,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final page = _page!;
    final theme = page.theme;
    final textColor = _getThemeTextColor(theme);
    final mutedTextColor = _getThemeMutedTextColor(theme);

    // Decorate Background based on theme choice
    BoxDecoration bgDecoration;
    if (theme == 'light') {
      bgDecoration = const BoxDecoration(color: Colors.white);
    } else if (theme == 'purple') {
      bgDecoration = const BoxDecoration(color: Color(0xFFA855F7));
    } else if (theme == 'gradient') {
      bgDecoration = const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFA855F7), Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    } else if (theme == 'glass') {
      bgDecoration = const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    } else {
      bgDecoration = const BoxDecoration(color: Color(0xFF0D0D0D));
    }

    final avatar = page.avatarUrl ?? _socials?['avatar_url'] as String?;
    final displayName = page.displayName ?? _socials?['display_name'] as String? ?? widget.username;
    final bio = page.bio ?? _socials?['bio'] as String?;

    // Social accounts links
    final Map<String, dynamic> platforms = _socials?['platforms'] as Map<String, dynamic>? ?? {};
    final hasSocials = page.showSocialPlatforms && platforms.isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: bgDecoration,
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 48),

                  // 1. AVATAR ANIMATION
                  _fadeAnimations.isNotEmpty
                      ? FadeTransition(
                          opacity: _fadeAnimations[0],
                          child: SlideTransition(
                            position: _slideAnimations[0],
                            child: Center(
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.grey.shade800,
                                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                                child: avatar == null
                                    ? const Icon(Iconsax.user, size: 36, color: Colors.white)
                                    : null,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),

                  const SizedBox(height: 16),

                  // 2. NAME & USERNAME ANIMATION
                  _fadeAnimations.length > 1
                      ? FadeTransition(
                          opacity: _fadeAnimations[1],
                          child: SlideTransition(
                            position: _slideAnimations[1],
                            child: Column(
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@${widget.username}',
                                  style: TextStyle(
                                    color: mutedTextColor,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (bio != null && bio.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    bio,
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.85),
                                      fontSize: 15,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),

                  const SizedBox(height: 24),

                  // 3. SOCIAL PLATFORMS ROW ANIMATION
                  if (hasSocials)
                    _fadeAnimations.length > 2
                        ? FadeTransition(
                            opacity: _fadeAnimations[2],
                            child: SlideTransition(
                              position: _slideAnimations[2],
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildSocialIcon(Icons.camera_alt_outlined, platforms['instagram']),
                                  _buildSocialIcon(Icons.video_library_outlined, platforms['youtube']),
                                  _buildSocialIcon(Icons.tiktok, platforms['tiktok']),
                                  _buildSocialIcon(Icons.link, platforms['twitter']),
                                  _buildSocialIcon(Icons.work_outline, platforms['linkedin']),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),

                  const SizedBox(height: 24),

                  // 4. LINKS LIST
                  ...List.generate(_links.length, (index) {
                    return _buildLinkCard(_links[index], index);
                  }),

                  const SizedBox(height: 48),

                  // 5. PROMO BADGE
                  if (page.showPromoBadge)
                    Center(
                      child: InkWell(
                        onTap: () => launchUrl(Uri.parse('https://promo.arkio.in')),
                        child: Column(
                          children: [
                            Text(
                              'Promo.',
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Connect · Create · Collaborate',
                              style: TextStyle(
                                color: mutedTextColor.withOpacity(0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
