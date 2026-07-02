import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../shared/widgets/social_button.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'promo_page_service.dart';

class PromoPublicPageScreen extends ConsumerStatefulWidget {
  final String username;
  final bool embedded;
  const PromoPublicPageScreen({super.key, required this.username, this.embedded = false});

  @override
  ConsumerState<PromoPublicPageScreen> createState() => _PromoPublicPageScreenState();
}

class _PromoPublicPageScreenState extends ConsumerState<PromoPublicPageScreen> with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  PromoPage? _page;
  List<PromoPageLink> _links = [];
  Map<String, dynamic>? _socials;
  bool _isDisposed = false;
  
  // Staggered list animations controllers
  List<AnimationController> _staggerControllers = [];
  List<Animation<double>> _fadeAnimations = [];
  List<Animation<Offset>> _slideAnimations = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        _fetchPublicPage();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (var controller in _staggerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchPublicPage() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      var page = await PromoPageService.getPublicPage(widget.username);
      if (!mounted || _isDisposed) return;
      
      
      // Override/Mock default live page for sivamanikanta if not present
      if (page == null && widget.username.toLowerCase() == 'sivamanikanta') {
        page = PromoPage(
          id: 'sivamanikanta-page-id',
          userId: 'sivamanikanta-user-id',
          username: 'sivamanikanta',
          displayName: 'Siva Manikanta',
          bio: 'Founder of Arkio · Innovating digital print solutions',
          theme: 'yaar',
          showSocialPlatforms: true,
          showPromoBadge: true,
          isPublished: true,
          viewCount: 1024,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      if (page == null) {
        if (mounted) {
          setState(() {
            _error = '404';
            _loading = false;
          });
        }
        return;
      }

      // Fetch links and socials (unauthenticated)
      List<PromoPageLink> linksList = [];
      Map<String, dynamic>? socialsMap;

      if (page.id == 'sivamanikanta-page-id') {
        linksList = [
          PromoPageLink(
            id: 'link-csa',
            pageId: page.id,
            userId: page.userId,
            title: 'Join our local CSA',
            url: 'https://promo.arkio.in',
            displayOrder: 0,
            isEnabled: true,
            clickCount: 42,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          PromoPageLink(
            id: 'link-cleanup',
            pageId: page.id,
            userId: page.userId,
            title: 'Neighbourhood clean up',
            url: 'https://promo.arkio.in',
            displayOrder: 1,
            isEnabled: true,
            clickCount: 19,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          PromoPageLink(
            id: 'link-council',
            pageId: page.id,
            userId: page.userId,
            title: 'Local Council group',
            url: 'https://promo.arkio.in',
            displayOrder: 2,
            isEnabled: true,
            clickCount: 88,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];
        socialsMap = {
          'avatar_url': 'assets/siva.png',
          'display_name': 'Siva Manikanta',
          'bio': 'Founder of Arkio · Innovating digital print solutions',
          'preferences': {
            'platform_handles': {
              'tiktok': 'sivamanikanta',
              'youtube': 'sivamanikanta',
              'twitter': 'sivamanikanta',
              'instagram': 'sivamanikanta',
            }
          }
        };
      } else {
        linksList = await PromoPageService.getLinks(page.id, enabledOnly: true);
        if (!mounted || _isDisposed) return;
        socialsMap = await PromoPageService.getPublicSocials(page.userId);
        if (!mounted || _isDisposed) return;
      }

      if (mounted) {
        setState(() {
          _page = page;
          _links = linksList;
          _socials = socialsMap;
          _loading = false;
        });
      }

      // Track view count safely (if not mock page)
      if (page.id != 'sivamanikanta-page-id') {
        PromoPageService.recordPageView(page.id, Uri.base.toString());
      }

      // Setup staggered animations for links after frame is built
      // to avoid mutating render objects during layout phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          _setupAnimations();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'network';
          _loading = false;
        });
      }
    }
  }

  void _setupAnimations() {
    if (_isDisposed) return;
    
    // Clear old controllers
    for (var controller in _staggerControllers) {
      try {
        controller.dispose();
      } catch (_) {}
    }

    final newControllers = <AnimationController>[];
    final newFadeAnimations = <Animation<double>>[];
    final newSlideAnimations = <Animation<Offset>>[];

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

      newControllers.add(controller);
      newFadeAnimations.add(fade);
      newSlideAnimations.add(slide);

      // Stagger each animation with a minimum 16ms delay to stay off the layout phase
      Future.delayed(Duration(milliseconds: 16 + i * 80), () {
        if (!_isDisposed && mounted) {
          try {
            if (controller.status == AnimationStatus.dismissed) {
              controller.forward();
            }
          } catch (_) {
            // Safety fallback if controller got disposed
          }
        }
      });
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _staggerControllers = newControllers;
        _fadeAnimations = newFadeAnimations;
        _slideAnimations = newSlideAnimations;
      });
    }
  }

  Color _getThemeTextColor(String theme) {
    if (theme == 'light' || theme == 'yaar_2' || theme == 'yaar_3') return const Color(0xFF111111);
    return Colors.white;
  }

  Color _getThemeMutedTextColor(String theme) {
    if (theme == 'light' || theme == 'yaar_2' || theme == 'yaar_3') return const Color(0xFF555555);
    return Colors.white70;
  }

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

  Widget _buildSocialIcon(String platform, String? url) {
    if (url == null || url.trim().isEmpty) return const SizedBox.shrink();

    FaIconData? iconData;
    if (platform == 'instagram') iconData = FontAwesomeIcons.instagram;
    else if (platform == 'tiktok') iconData = FontAwesomeIcons.tiktok;
    else if (platform == 'youtube') iconData = FontAwesomeIcons.youtube;
    else if (platform == 'twitter') iconData = FontAwesomeIcons.x;
    else if (platform == 'linkedin') iconData = FontAwesomeIcons.linkedin;

    if (iconData == null) return const SizedBox.shrink();

    // Parse button card background color setting
    final accentField = _parseAccentField(_page?.accentColor);
    final btnColorStr = accentField['buttonColor'] ?? 'black';

    // If button card is white, render white social icon, else render black/dark social icon
    final Color iconColor = btnColorStr == 'white' ? Colors.white : const Color(0xFF141414);

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: FaIcon(
          iconData,
          color: iconColor,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildLinkCard(PromoPageLink link, int idx) {
    final theme = _page?.theme ?? 'dark';
    final isYaar = theme.startsWith('yaar');
    
    // Parse custom button styling from accentColor
    final accentField = _parseAccentField(_page?.accentColor);
    final accentHex = accentField['hex'];
    final btnColorStr = accentField['buttonColor'] ?? 'black';
    final btnShapeStr = accentField['buttonShape'] ?? 'normal_rounded';
    
    Color accentColor = AppColors.purple;
    if (accentHex != null && accentHex.length == 8) {
      final intVal = int.tryParse(accentHex, radix: 16);
      if (intVal != null) accentColor = Color(intVal);
    }

    // Glassmorphism styling if theme is 'glass'
    final isGlass = theme == 'glass';
    final isDark = theme == 'dark';
    final isLight = theme == 'light';

    // Determine custom button properties
    Color cardBgColor;
    BorderRadius cardBorderRadius = btnShapeStr == 'fully_rounded' 
        ? BorderRadius.circular(30) 
        : BorderRadius.circular(12);

    if (btnColorStr == 'white') {
      cardBgColor = Colors.white;
    } else {
      cardBgColor = const Color(0xFF141414);
    }

    final Color textColor = btnColorStr == 'white' ? const Color(0xFF111111) : Colors.white;

    BoxDecoration decoration;
    if (isYaar) {
      decoration = BoxDecoration(
        color: cardBgColor,
        borderRadius: cardBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      );
    } else if (isGlass) {
      decoration = BoxDecoration(
        color: btnColorStr == 'white' ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.08),
        borderRadius: cardBorderRadius,
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
        color: cardBgColor,
        borderRadius: cardBorderRadius,
        border: Border.all(color: btnColorStr == 'white' ? Colors.grey.shade300 : Colors.grey.shade800, width: 1),
      );
    } else if (theme == 'creator') {
      decoration = BoxDecoration(
        color: btnColorStr == 'white' ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.25),
        borderRadius: cardBorderRadius,
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      );
    } else {
      decoration = BoxDecoration(
        color: cardBgColor,
        borderRadius: cardBorderRadius,
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
      );
    }

    final animeIdx = idx + 3; // skip header indexes
    Widget cardChild = Container(
      decoration: decoration,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: cardBorderRadius,
        onTap: () async {
          // Increment click count with referrer tracking
          if (_page?.id != 'sivamanikanta-page-id') {
            PromoPageService.incrementLinkClick(link.id, referrer: Uri.base.toString());
          }
          final uri = Uri.parse(link.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            mainAxisAlignment: isYaar ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (!isYaar) ...[
                Text(
                  link.icon ?? '🔗',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  link.title,
                  textAlign: isYaar ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (!isYaar)
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

  Widget _buildCertBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.4), width: 0.8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.flash5, color: Colors.orange, size: 11),
          SizedBox(width: 4),
          Text(
            'Trending',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: Colors.orange,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmbedded = widget.embedded;

    if (_loading) {
      final loadingBody = Center(
        child: CircularProgressIndicator(color: AppColors.purple),
      );
      if (isEmbedded) return loadingBody;
      return Scaffold(body: loadingBody);
    }

    if (_error == '404') {
      final errorBody = Center(
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
      );
      if (isEmbedded) return errorBody;
      return Scaffold(body: errorBody);
    }

    if (_error == 'network') {
      final networkBody = Center(
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
      );
      if (isEmbedded) return networkBody;
      return Scaffold(body: networkBody);
    }

    final page = _page!;
    final theme = page.theme;
    final isYaar = theme.startsWith('yaar');
    final isLight = theme == 'light' || theme == 'yaar_2' || theme == 'yaar_3';

    // Parse custom text color selection
    final accentField = _parseAccentField(page.accentColor);
    final btnTextColorStr = accentField['buttonTextColor'] ?? (accentField['buttonColor'] == 'white' ? 'black' : 'white');

    Color textColor;
    if (btnTextColorStr == 'white') {
      textColor = Colors.white;
    } else if (btnTextColorStr == 'black') {
      textColor = const Color(0xFF111111);
    } else {
      // 'accent'
      Color accentColor = AppColors.purple;
      final accentHex = accentField['hex'];
      if (accentHex != null && accentHex.length == 8) {
        final intVal = int.tryParse(accentHex, radix: 16);
        if (intVal != null) accentColor = Color(intVal);
      }
      textColor = accentColor;
    }

    final mutedTextColor = textColor.withOpacity(0.7);

    // Decorate Background based on theme choice
    BoxDecoration bgDecoration;
    if (page.backgroundColor != null && page.backgroundColor!.startsWith('http')) {
      bgDecoration = BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(page.backgroundColor!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.3),
            BlendMode.darken,
          ),
        ),
      );
    } else if (theme == 'light') {
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
    } else if (theme == 'creator') {
      bgDecoration = const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/creator_theme_bg.png'),
          fit: BoxFit.cover,
        ),
      );
    } else if (theme == 'yaar' || theme == 'yaar_1') {
      bgDecoration = const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/Profile_BG/1.png'),
          fit: BoxFit.cover,
        ),
      );
    } else if (theme == 'yaar_2') {
      bgDecoration = const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/Profile_BG/2.png'),
          fit: BoxFit.cover,
        ),
      );
    } else if (theme == 'yaar_3') {
      bgDecoration = const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/Profile_BG/3.png'),
          fit: BoxFit.cover,
        ),
      );
    } else if (theme == 'yaar_4') {
      bgDecoration = const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/Profile_BG/4.png'),
          fit: BoxFit.cover,
        ),
      );
    } else {
      bgDecoration = const BoxDecoration(color: Color(0xFF0D0D0D));
    }

    final avatar = page.avatarUrl ?? _socials?['avatar_url'] as String?;
    final displayName = page.displayName ?? _socials?['display_name'] as String? ?? widget.username;
    final bio = page.bio ?? _socials?['bio'] as String?;

    // Extract Certifications & Trending state
    final Map<String, dynamic> certs = {};
    bool isTrending = false;
    if (_socials != null && _socials!['preferences'] != null) {
      final prefs = Map<String, dynamic>.from(_socials!['preferences'] as Map);
      if (prefs['certifications'] is Map) {
        certs.addAll(Map<String, dynamic>.from(prefs['certifications'] as Map));
      }
      isTrending = prefs['trending'] == true;
    }

    // Social accounts links
    final Map<String, dynamic> platforms = {};
    if (_socials != null && _socials!['preferences'] != null) {
      final prefs = Map<String, dynamic>.from(_socials!['preferences'] as Map);
      final handles = prefs['platform_handles'] != null 
          ? Map<String, dynamic>.from(prefs['platform_handles'] as Map) 
          : {};
          
      handles.forEach((key, val) {
        if (val != null && val.toString().trim().isNotEmpty) {
          final handle = val.toString().trim().replaceAll('@', '');
          final lowerKey = key.toString().toLowerCase();
          
          if (lowerKey == 'instagram') {
            platforms['instagram'] = 'https://instagram.com/$handle';
          } else if (lowerKey == 'tiktok') {
            platforms['tiktok'] = 'https://tiktok.com/@$handle';
          } else if (lowerKey == 'youtube') {
            platforms['youtube'] = 'https://youtube.com/$handle';
          } else if (lowerKey == 'twitter' || lowerKey == 'x') {
            platforms['twitter'] = 'https://x.com/$handle';
          } else if (lowerKey == 'linkedin') {
            platforms['linkedin'] = 'https://linkedin.com/in/$handle';
          }
        }
      });
    }
    final hasSocials = page.showSocialPlatforms && platforms.isNotEmpty;

    Widget contentWidget = Container(
      decoration: bgDecoration,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              const SizedBox(height: 48),

                // 1. AVATAR & NAMES ROW ANIMATION (Avatar centered on 'yaar', row on others)
                _fadeAnimations.isNotEmpty
                    ? FadeTransition(
                        opacity: _fadeAnimations[0],
                        child: SlideTransition(
                          position: _slideAnimations[0],
                          child: isYaar
                              ? Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 48,
                                      backgroundColor: isLight ? Colors.black12 : Colors.white24,
                                      backgroundImage: avatar != null 
                                          ? (avatar.startsWith('assets/') 
                                              ? AssetImage(avatar) as ImageProvider 
                                              : NetworkImage(avatar))
                                          : null,
                                      child: avatar == null
                                          ? Icon(Iconsax.user, size: 36, color: isLight ? const Color(0xFF111111) : Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      displayName,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '@${widget.username}',
                                      style: TextStyle(
                                        color: mutedTextColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (isTrending || certs.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          if (isTrending) _buildTrendingBadge(),
                                          if (certs['professional_collaborator'] != null)
                                            _buildCertBadge('Promo Certified — Professional Collaborator ✓', Colors.purple),
                                          if (certs['content_brief_master'] != null)
                                            _buildCertBadge('Promo Certified — Content Brief Master ✓', Colors.blue),
                                          if (certs['rate_negotiation_pro'] != null)
                                            _buildCertBadge('Promo Certified — Rate Negotiation Pro ✓', Colors.green),
                                        ],
                                      ),
                                    ],
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 38,
                                      backgroundColor: Colors.grey.shade800,
                                      backgroundImage: avatar != null 
                                          ? (avatar.startsWith('assets/') 
                                              ? AssetImage(avatar) as ImageProvider 
                                              : NetworkImage(avatar))
                                          : null,
                                      child: avatar == null
                                          ? const Icon(Iconsax.user, size: 28, color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            displayName,
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                           Text(
                                            '@${widget.username}',
                                            style: TextStyle(
                                              color: mutedTextColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (isTrending || certs.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                if (isTrending) _buildTrendingBadge(),
                                                if (certs['professional_collaborator'] != null)
                                                  _buildCertBadge('Promo Certified — Professional Collaborator ✓', Colors.purple),
                                                if (certs['content_brief_master'] != null)
                                                  _buildCertBadge('Promo Certified — Content Brief Master ✓', Colors.blue),
                                                if (certs['rate_negotiation_pro'] != null)
                                                  _buildCertBadge('Promo Certified — Rate Negotiation Pro ✓', Colors.green),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      )
                    : const SizedBox.shrink(),

                const SizedBox(height: 16),

                // 2. BIO ANIMATION
                bio != null && bio.isNotEmpty
                    ? (_fadeAnimations.length > 1
                        ? FadeTransition(
                            opacity: _fadeAnimations[1],
                            child: SlideTransition(
                              position: _slideAnimations[1],
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                                child: Text(
                                  bio,
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.85),
                                    fontSize: 15,
                                  ),
                                  textAlign: isYaar ? TextAlign.center : TextAlign.start,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink())
                    : const SizedBox.shrink(),

                // 4. LINKS LIST
                ...List.generate(_links.length, (index) {
                  return _buildLinkCard(_links[index], index);
                }),

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
                                _buildSocialIcon('tiktok', platforms['tiktok']),
                                _buildSocialIcon('youtube', platforms['youtube']),
                                _buildSocialIcon('twitter', platforms['twitter']),
                                _buildSocialIcon('instagram', platforms['instagram']),
                                _buildSocialIcon('linkedin', platforms['linkedin']),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),

                const SizedBox(height: 24),

                const SizedBox(height: 48),

                // 4.5. SIGNUP CTA FOR VISITORS
                if (!ref.watch(authProvider).isAuthenticated) ...[
                  Center(
                    child: ElevatedButton(
                      onPressed: () => context.go('/signup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                        foregroundColor: isLight ? Colors.white : const Color(0xFF1A1A1A),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.user_add, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Create Your Promo Page',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // 5. PROMO BADGE
                if (page.showPromoBadge)
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: mutedTextColor.withOpacity(0.8),
                          fontSize: 13,
                        ),
                        children: [
                          const TextSpan(text: 'Designed by '),
                          TextSpan(
                            text: 'Promo',
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                final uri = Uri.parse('https://promo.arkio.in');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
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
      );

    if (widget.embedded) {
      return contentWidget;
    }

    return Scaffold(
      body: contentWidget,
    );
  }
}
