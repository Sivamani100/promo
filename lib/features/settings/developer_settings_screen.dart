import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/shared_widgets.dart';

class DeveloperSettingsScreen extends ConsumerWidget {
  const DeveloperSettingsScreen({super.key});

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(context, 'Failed to open link: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerHeight = 160.0 + MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image & Overlay avatar stack
          SizedBox(
            height: bannerHeight,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                // Premium pastel gradient banner matching the screenshot
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF1E1430),
                              const Color(0xFF2A281E),
                            ]
                          : [
                              const Color(0xFFF1EAFA),
                              const Color(0xFFFFFCEA),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Center text logo "Promo" matching the screenshot
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top / 2),
                    child: Text(
                      'Promo',
                      style: GoogleFonts.inter(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFFECEFF1) : const Color(0xFF0F0F11),
                        letterSpacing: -3.5,
                      ),
                    ),
                  ),
                ),
                // Back button round overlay matching the screenshot
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Iconsax.arrow_left_2,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                // Overlapping Avatar and Name details matching the screenshot
                Positioned(
                  bottom: -38, // half overlap
                  left: AppSpacing.pageMarginHorizontal,
                  right: AppSpacing.pageMarginHorizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Avatar container with white border
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F6),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/siva.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.black,
                                alignment: Alignment.center,
                                child: Text(
                                  'S',
                                  style: GoogleFonts.inter(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Sivamanikanta Mallipurapu',
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const VerificationBadge(size: 17),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Founder & Lead Creator',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 38), // spacing for avatar bottom

          // Rest of developer details scroll area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageMarginHorizontal,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Badges / Roles Grid
                  AutoScrollingRolesList(
                    children: [
                      _buildRoleChip('CEO', isDark),
                      _buildRoleChip('CTO', isDark),
                      _buildRoleChip('Lead Developer', isDark),
                      _buildRoleChip('Product Architect', isDark),
                      _buildRoleChip('UI/UX Designer', isDark),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Bio / Description Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Iconsax.profile_2user, size: 18, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text(
                              'About Me',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'I am the founder, designer, and developer behind Promo. Serving simultaneously as the CEO, CTO, and Lead Creator, I envisioned, styled, and architected this entire platform from the ground up. Driven by a passion for clean visual aesthetics and seamless user experiences, I built Promo to bridge the communication gap between brands and digital influencers, creating a premium space where partnerships are formed and ideas are turned into realities.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Developer Connections / Social handles
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F0F11) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Iconsax.link, size: 18, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text(
                              'Connect',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildConnectionRow(
                          context: context,
                          icon: Iconsax.link,
                          title: 'LinkedIn',
                          subtitle: 'linkedin.com/in/sivamanikanta-mallipurapu',
                          url: 'https://linkedin.com/in/sivamanikanta-mallipurapu',
                          brandColor: const Color(0xFF0A66C2),
                        ),
                        _buildThinDivider(isDark),
                        _buildConnectionRow(
                          context: context,
                          icon: Iconsax.bezier,
                          title: 'Behance',
                          subtitle: 'behance.net/mallipurapu',
                          url: 'https://www.behance.net/mallipurapu',
                          brandColor: const Color(0xFF0057FF),
                        ),
                        _buildThinDivider(isDark),
                        _buildConnectionRow(
                          context: context,
                          icon: Iconsax.global,
                          title: 'GitHub',
                          subtitle: 'github.com/Sivamani100',
                          url: 'https://github.com/Sivamani100',
                          brandColor: isDark ? Colors.white : Colors.black,
                        ),
                        _buildThinDivider(isDark),
                        _buildConnectionRow(
                          context: context,
                          icon: Iconsax.instagram,
                          title: 'Instagram',
                          subtitle: '@the_only_one_siva',
                          url: 'https://instagram.com/the_only_one_siva',
                          brandColor: const Color(0xFFE1306C),
                        ),
                        _buildThinDivider(isDark),
                        _buildConnectionRow(
                          context: context,
                          icon: Iconsax.sms,
                          title: 'Email',
                          subtitle: 'mallipurapusiva@gmail.com',
                          url: 'mailto:mallipurapusiva@gmail.com',
                          brandColor: const Color(0xFFEA4335),
                        ),
                        _buildThinDivider(isDark),
                        _buildConnectionRow(
                          context: context,
                          icon: Iconsax.call,
                          title: 'Phone',
                          subtitle: '+91 9849497911',
                          url: 'tel:+919849497911',
                          brandColor: const Color(0xFF34A853),
                        ),
                        _buildThinDivider(isDark),
                        _buildConnectionRow(
                          context: context,
                          icon: Iconsax.message,
                          title: 'WhatsApp',
                          subtitle: '+91 9849497911',
                          url: 'https://wa.me/919849497911',
                          brandColor: const Color(0xFF25D366),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Footer App version
                  Center(
                    child: Text(
                      'Promo · Built with Love',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

   Widget _buildRoleChip(String role, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Text(
        role,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildConnectionRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
    required Color brandColor,
  }) {
    return InkWell(
      onTap: () => _launchUrl(context, url),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: brandColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Divider(
        height: 1,
        color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
        indent: 48,
      ),
    );
  }
}

class AutoScrollingRolesList extends StatefulWidget {
  final List<Widget> children;
  final double spacing;

  const AutoScrollingRolesList({
    super.key,
    required this.children,
    this.spacing = 8.0,
  });

  @override
  State<AutoScrollingRolesList> createState() => _AutoScrollingRolesListState();
}

class _AutoScrollingRolesListState extends State<AutoScrollingRolesList> {
  late final ScrollController _scrollController;
  bool _scrollingToEnd = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        _startAutoScrollLoop();
      }
    });
  }

  void _startAutoScrollLoop() async {
    while (!_disposed) {
      await Future.delayed(const Duration(seconds: 2));
      if (_disposed || !_scrollController.hasClients) break;

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) continue;

      // If user is currently dragging or scrolling, skip this tick
      if (_scrollController.position.isScrollingNotifier.value) {
        continue;
      }

      if (_scrollingToEnd) {
        final durationMs = (maxScroll * 35).toInt().clamp(1500, 8000);
        if (_disposed || !_scrollController.hasClients) break;
        await _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeInOut,
        ).then((_) {}, onError: (_) {});
        _scrollingToEnd = false;
      } else {
        final durationMs = (maxScroll * 35).toInt().clamp(1500, 8000);
        if (_disposed || !_scrollController.hasClients) break;
        await _scrollController.animateTo(
          0,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeInOut,
        ).then((_) {}, onError: (_) {});
        _scrollingToEnd = true;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (int i = 0; i < widget.children.length; i++) ...[
            widget.children[i],
            if (i < widget.children.length - 1) SizedBox(width: widget.spacing),
          ],
        ],
      ),
    );
  }
}
