import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/design_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/media/image_cache_config.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------- AppButton ----------
// Enhanced with pressed/loading/success/disabled states + haptic feedback.
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isSuccess;
  final bool isDisabled;
  final bool isPrimary;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.isSuccess = false,
    this.isDisabled = false,
    this.isPrimary = true,
    this.icon,
    this.width,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) {
    if (widget.isLoading || widget.isDisabled) return;
    setState(() => _scale = 0.96);
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.isLoading || widget.isDisabled) return;
    setState(() => _scale = 1.0);
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  void _handleTap() {
    if (widget.isLoading || widget.isDisabled || widget.onTap == null) return;
    HapticFeedback.lightImpact();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _scale,
        duration: DesignTokens.durationXS,
        curve: DesignTokens.curveDefault,
        child: AnimatedOpacity(
          opacity: widget.isDisabled ? 0.4 : 1.0,
          duration: DesignTokens.durationSM,
          child: SizedBox(
            width: widget.width ?? double.infinity,
            child: widget.isPrimary
                ? ElevatedButton(
                    onPressed: (widget.isLoading || widget.isDisabled) ? null : _handleTap,
                    child: _buildContent(),
                  )
                : OutlinedButton(
                    onPressed: (widget.isLoading || widget.isDisabled) ? null : _handleTap,
                    child: _buildContent(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return SizedBox(
        height: 20, width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: widget.isPrimary ? AppColors.accentOnDark : AppColors.accent),
      );
    }
    if (widget.isSuccess) {
      return Icon(Icons.check_rounded, color: widget.isPrimary ? AppColors.accentOnDark : AppColors.success, size: 22);
    }
    if (widget.icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(widget.icon, size: 20), const SizedBox(width: 8), Text(widget.label)],
      );
    }
    return Text(widget.label);
  }
}

// ---------- AppTextField ----------
// Enhanced with focusNode, textInputAction, autocorrect, prefixText for keyboard UX.
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? suffix;
  final Widget? prefixIcon;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final bool autocorrect;
  final bool enableSuggestions;
  final String? prefixText;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.onChanged,
    this.suffix,
    this.prefixIcon,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.prefixText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.overline),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLines: maxLines,
          minLines: minLines,
          validator: validator,
          onChanged: onChanged,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            prefixIcon: prefixIcon,
            prefixText: prefixText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              borderSide: BorderSide(color: AppColors.textPrimary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              borderSide: BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- AppAvatar ----------
class AppAvatar extends StatelessWidget {
  final String? url;
  final String? fallbackText;
  final double size;
  final VoidCallback? onTap;

  const AppAvatar({super.key, this.url, this.fallbackText, this.size = 40, this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface2,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: ClipOval(
        child: isValidImageUrl(url)
            ? CachedNetworkImage(
                cacheManager: AppCacheManager.instance,
                imageUrl: url!.trim(),
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: SizedBox(
                    width: size * 0.5,
                    height: size * 0.5,
                    child: const CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ),
                errorWidget: (_, _, _) => _fallback(),
                memCacheWidth: (size * 2).toInt(),
                memCacheHeight: (size * 2).toInt(),
              )
            : _fallback(),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatar,
      );
    }
    return avatar;
  }

  Widget _fallback() {
    final letter = (fallbackText ?? '?')[0].toUpperCase();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(letter, style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: AppColors.accentOnDark)),
    );
  }
}

// ---------- AppChip ----------
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;

  const AppChip({super.key, required this.label, this.selected = false, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? (color ?? AppColors.accent) : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: selected ? Colors.transparent : AppColors.borderSubtle),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: selected ? AppColors.accentOnDark : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

enum StatCardPreset {
  indigo,
  rose,
  emerald,
  amber,
  cyan,
  purple,
}

// ---------- StatCard ----------
class StatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final StatCardPreset? preset;
  final Color? backgroundColor;
  final List<Color>? gradientColors;
  final Color? borderColor;
  final Color? textColor;
  final Color? labelColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.preset,
    this.backgroundColor,
    this.gradientColors,
    this.borderColor,
    this.textColor,
    this.labelColor,
    this.iconColor,
    this.onTap,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _animCtrl;
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _animCtrl.reverse();
  }

  void _onTapUp(TapUpDetails _) {
    _animCtrl.forward();
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    _animCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    List<Color>? resolvedGradient;
    Color? resolvedBorder;
    Color? resolvedText;
    Color? resolvedLabel;
    Color? resolvedIcon;

    if (widget.preset != null) {
      switch (widget.preset!) {
        case StatCardPreset.indigo:
          resolvedGradient = isDark 
              ? [const Color(0xFF1E1B4B).withOpacity(0.85), const Color(0xFF312E81).withOpacity(0.85)] 
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)];
          resolvedBorder = isDark ? const Color(0xFF4338CA).withOpacity(0.6) : const Color(0xFFC7D2FE);
          resolvedText = isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5);
          resolvedLabel = resolvedText.withOpacity(0.85);
          resolvedIcon = resolvedText;
          break;
        case StatCardPreset.rose:
          resolvedGradient = isDark 
              ? [const Color(0xFF500730).withOpacity(0.85), const Color(0xFF700B48).withOpacity(0.85)] 
              : [const Color(0xFFFDF2F8), const Color(0xFFFCE7F3)];
          resolvedBorder = isDark ? const Color(0xFF9D174D).withOpacity(0.6) : const Color(0xFFFBCFE8);
          resolvedText = isDark ? const Color(0xFFFBCFE8) : const Color(0xFFDB2777);
          resolvedLabel = resolvedText.withOpacity(0.85);
          resolvedIcon = resolvedText;
          break;
        case StatCardPreset.emerald:
          resolvedGradient = isDark 
              ? [const Color(0xFF064E3B).withOpacity(0.85), const Color(0xFF065F46).withOpacity(0.85)] 
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)];
          resolvedBorder = isDark ? const Color(0xFF047857).withOpacity(0.6) : const Color(0xFFA7F3D0);
          resolvedText = isDark ? const Color(0xFFA7F3D0) : const Color(0xFF059669);
          resolvedLabel = resolvedText.withOpacity(0.85);
          resolvedIcon = resolvedText;
          break;
        case StatCardPreset.amber:
          resolvedGradient = isDark 
              ? [const Color(0xFF451A03).withOpacity(0.85), const Color(0xFF78350F).withOpacity(0.85)] 
              : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)];
          resolvedBorder = isDark ? const Color(0xFF92400E).withOpacity(0.6) : const Color(0xFFFFD8A8);
          resolvedText = isDark ? const Color(0xFFFFD8A8) : const Color(0xFFD97706);
          resolvedLabel = resolvedText.withOpacity(0.85);
          resolvedIcon = resolvedText;
          break;
        case StatCardPreset.cyan:
          resolvedGradient = isDark 
              ? [const Color(0xFF0C4A6E).withOpacity(0.85), const Color(0xFF075985).withOpacity(0.85)] 
              : [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)];
          resolvedBorder = isDark ? const Color(0xFF0369A1).withOpacity(0.6) : const Color(0xFFBAE6FD);
          resolvedText = isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0284C7);
          resolvedLabel = resolvedText.withOpacity(0.85);
          resolvedIcon = resolvedText;
          break;
        case StatCardPreset.purple:
          resolvedGradient = isDark 
              ? [const Color(0xFF3B0764).withOpacity(0.85), const Color(0xFF581C87).withOpacity(0.85)] 
              : [const Color(0xFFFAF5FF), const Color(0xFFF3E8FF)];
          resolvedBorder = isDark ? const Color(0xFF7E22CE).withOpacity(0.6) : const Color(0xFFE9D5FF);
          resolvedText = isDark ? const Color(0xFFE9D5FF) : const Color(0xFF9333EA);
          resolvedLabel = resolvedText.withOpacity(0.85);
          resolvedIcon = resolvedText;
          break;
      }
    }

    final bg = widget.backgroundColor ?? AppColors.surface;
    final grads = widget.gradientColors ?? resolvedGradient;
    final borderCol = widget.borderColor ?? resolvedBorder ?? AppColors.border;
    final valColor = widget.textColor ?? resolvedText ?? AppColors.textPrimary;
    final lblColor = widget.labelColor ?? resolvedLabel ?? AppColors.textSecondary;
    final icColor = widget.iconColor ?? resolvedIcon ?? AppColors.textMuted;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: grads == null ? bg : null,
            gradient: grads != null ? LinearGradient(
              colors: grads,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ) : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: borderCol, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      widget.label,
                      style: AppTextStyles.captionSm.copyWith(
                        color: lblColor,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(widget.icon, size: 16, color: icColor),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.value,
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: valColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- SectionHeader ----------
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: AppColors.warning), SizedBox(width: 8)],
              Text(title, style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!, style: AppTextStyles.labelSm.copyWith(color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}

// ---------- AppEmptyState ----------
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({super.key, required this.icon, required this.title, this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.label, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: AppTextStyles.caption, textAlign: TextAlign.center),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              AppButton(label: actionLabel!, onTap: onAction, width: 200),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- CampaignCardWidget ----------
class CampaignCardWidget extends StatelessWidget {
  final Map<String, dynamic> card;
  final VoidCallback? onTap;
  final int? matchScore;
  final bool isApplied;

  const CampaignCardWidget({
    super.key,
    required this.card,
    this.onTap,
    this.matchScore,
    this.isApplied = false,
  });

  static const _followerTiers = [
    {'label': 'Any tier', 'value': 0},
    {'label': '10k+ followers', 'value': 10000},
    {'label': '50k+ followers', 'value': 50000},
    {'label': '100k+ followers', 'value': 100000},
    {'label': '500k+ followers', 'value': 500000},
  ];

  @override
  Widget build(BuildContext context) {
    final brand = card['brand'] as Map<String, dynamic>?;
    final category = card['category'] as String? ?? '';
    final categoryColor = AppColors.getCategoryColor(category);
    final nicheTags = (card['niche_tags'] as List<dynamic>?)?.cast<String>() ?? [];
    
    // Extract campaign type from niche tags
    String campaignType = 'Sponsored Post';
    if (nicheTags.contains('Sponsored Post')) {
      campaignType = 'Sponsored Post';
    } else if (nicheTags.contains('Product Review')) {
      campaignType = 'Product Review';
    } else if (nicheTags.contains('Brand Ambassador')) {
      campaignType = 'Brand Ambassador';
    } else if (nicheTags.contains('Affiliate / Commission')) {
      campaignType = 'Affiliate / Commission';
    } else if (nicheTags.contains('Other')) {
      campaignType = 'Other';
    }

    final minFollowers = card['min_followers'] as int? ?? 0;
    final followersLabel = (() {
      final Map<String, Object>? tier = _followerTiers.cast<Map<String, Object>?>().firstWhere(
        (t) => t?['value'] == minFollowers,
        orElse: () => null,
      );
      if (tier != null) return tier['label'] as String;
      return '${NumberFormat.compact().format(minFollowers)}+ followers';
    })();

    final location = card['preferred_location'] as String? ?? 'Anywhere';
    final budget = card['budget_range'] as String? ?? 'Open';
    final timeline = card['timeline'] as String? ?? 'Flexible';

    final deliverables = (card['deliverables'] as List<dynamic>?)?.cast<String>() ?? [];

    DateTime? applicationDeadline;
    if (card['application_deadline'] != null) {
      applicationDeadline = DateTime.tryParse(card['application_deadline'].toString());
    }

    final isDark = AppColors.isDarkMode;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.03),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with linear gradient
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: AppColors.surface2,
                      child: card['cover_image_url'] != null && card['cover_image_url'].toString().isNotEmpty
                          ? CachedNetworkImage(
                              cacheManager: AppCacheManager.instance,
                              imageUrl: card['cover_image_url'],
                              fit: BoxFit.cover,
                              memCacheWidth: 800,
                              memCacheHeight: 450,
                              placeholder: (context, url) => const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Icon(Iconsax.image, size: 40, color: AppColors.borderSubtle),
                              ),
                            )
                          : Center(
                              child: Icon(Iconsax.image, size: 40, color: AppColors.borderSubtle),
                            ),
                    ),
                  ),
                  // Dark sheen gradient backdrop overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.35),
                            Colors.transparent,
                            Colors.black.withOpacity(0.55),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: categoryColor,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: categoryColor.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (matchScore != null && matchScore! > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'Match: +$matchScore',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                      ),
                      child: Text(
                        campaignType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (brand != null) ...[
                    GestureDetector(
                      onTap: () {
                        if (brand['id'] != null) {
                          context.push('/influencer/brands/${brand['id']}');
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          AppAvatar(
                            url: brand['avatar_url'],
                            fallbackText: brand['display_name'] ?? 'B',
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            brand['display_name'] ?? 'Brand',
                            style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    card['title'] ?? '',
                    style: AppTextStyles.h4.copyWith(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card['description'] ?? '',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary, height: 1.45),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Key Info Parameter Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          Iconsax.wallet_3,
                          'Budget',
                          budget,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDetailItem(
                          Iconsax.clock,
                          'Timeline',
                          timeline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          Iconsax.user_tick,
                          'Followers Target',
                          followersLabel,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDetailItem(
                          Iconsax.location,
                          'Preferred Location',
                          location,
                        ),
                      ),
                    ],
                  ),
                  if (deliverables.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('DELIVERABLES', style: AppTextStyles.overline),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: deliverables.map((str) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          str,
                          style: AppTextStyles.labelSm.copyWith(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      )).toList(),
                    ),
                  ],
                  if (applicationDeadline != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(Iconsax.calendar_1, size: 14, color: AppColors.error),
                        const SizedBox(width: 6),
                        Text(
                          'Applications close: ${DateFormat('MMMM dd, yyyy').format(applicationDeadline)}',
                          style: AppTextStyles.captionSm.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              alignment: Alignment.centerRight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isApplied
                      ? const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [AppColors.accent, AppColors.accent.withOpacity(0.85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: isApplied
                          ? const Color(0xFF059669).withOpacity(0.25)
                          : AppColors.accent.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isApplied) ...[
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      isApplied ? 'Applied' : 'View Campaign',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isApplied ? Colors.white : AppColors.accentOnDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String title, String value) {
    final isDark = AppColors.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: AppColors.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: AppTextStyles.overline.copyWith(
                    fontSize: 8,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- AppShimmer ----------
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1A1A24) : const Color(0xFFEBEBEB),
      highlightColor: isDark ? const Color(0xFF272736) : const Color(0xFFF5F5F5),
      child: child,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class ShimmerCampaignCard extends StatelessWidget {
  const ShimmerCampaignCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const ShimmerBox(width: 80, height: 12),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const ShimmerBox(width: 180, height: 18),
                  const SizedBox(height: 8),
                  const ShimmerBox(width: double.infinity, height: 12),
                  const SizedBox(height: 4),
                  const ShimmerBox(width: 240, height: 12),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 40, height: 8),
                      SizedBox(height: 4),
                      ShimmerBox(width: 80, height: 14),
                    ],
                  ),
                  const ShimmerBox(width: 70, height: 32, borderRadius: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerBrandTile extends StatelessWidget {
  const ShimmerBrandTile({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 120, height: 14),
                  SizedBox(height: 4),
                  ShimmerBox(width: 70, height: 10),
                  SizedBox(height: 4),
                  ShimmerBox(width: 90, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VerificationBadge extends StatelessWidget {
  final double size;
  const VerificationBadge({super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      isDark
          ? 'assets/verification badge white.png'
          : 'assets/Verification badge.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

// ---------- Skeleton Loading Widgets ----------

/// A skeleton for notification list items
class ShimmerNotificationTile extends StatelessWidget {
  const ShimmerNotificationTile({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 160, height: 13),
                  SizedBox(height: 6),
                  ShimmerBox(width: double.infinity, height: 10),
                  SizedBox(height: 4),
                  ShimmerBox(width: 60, height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton for application cards (user avatar + info + status badge)
class ShimmerApplicationCard extends StatelessWidget {
  const ShimmerApplicationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 100, height: 14),
                      SizedBox(height: 4),
                      ShimmerBox(width: 70, height: 10),
                    ],
                  ),
                ),
                const ShimmerBox(width: 60, height: 22, borderRadius: 100),
              ],
            ),
            const SizedBox(height: 12),
            const ShimmerBox(width: double.infinity, height: 12),
            const SizedBox(height: 4),
            const ShimmerBox(width: 200, height: 12),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: ShimmerBox(width: double.infinity, height: 36, borderRadius: 100)),
                SizedBox(width: 8),
                Expanded(child: ShimmerBox(width: double.infinity, height: 36, borderRadius: 100)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton for chat/conversation list items
class ShimmerChatTile extends StatelessWidget {
  const ShimmerChatTile({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      ShimmerBox(width: 120, height: 14),
                      ShimmerBox(width: 40, height: 10),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const ShimmerBox(width: 180, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton for stat/analytics grid cards
class ShimmerStatGrid extends StatelessWidget {
  final int count;
  const ShimmerStatGrid({super.key, this.count = 4});

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
      children: List.generate(count, (_) => AppShimmer(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
        ),
      )),
    );
  }
}

/// A skeleton for profile detail screens (header + info sections)
class ShimmerProfileDetail extends StatelessWidget {
  const ShimmerProfileDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMarginHorizontal,
          AppSpacing.pageMarginVertical,
          AppSpacing.pageMarginHorizontal,
          AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
        ),
        children: [
          Center(
            child: Column(
              children: [
                Container(width: 80, height: 80, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(height: 12),
                const ShimmerBox(width: 140, height: 18),
                const SizedBox(height: 6),
                const ShimmerBox(width: 100, height: 12),
                const SizedBox(height: 8),
                const ShimmerBox(width: 200, height: 12),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (_) => Column(
              children: const [
                ShimmerBox(width: 40, height: 20),
                SizedBox(height: 4),
                ShimmerBox(width: 60, height: 10),
              ],
            )),
          ),
          const SizedBox(height: 24),
          const ShimmerBox(width: double.infinity, height: 44, borderRadius: 100),
          const SizedBox(height: 24),
          const ShimmerBox(width: 80, height: 14),
          const SizedBox(height: 8),
          const ShimmerBox(width: double.infinity, height: 60),
          const SizedBox(height: 24),
          const ShimmerBox(width: 80, height: 14),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(5, (i) => ShimmerBox(width: 60.0 + (i * 10), height: 28, borderRadius: 100)),
          ),
        ],
      ),
    );
  }
}

/// A skeleton for search results (cards + profile tiles)
class ShimmerSearchResults extends StatelessWidget {
  const ShimmerSearchResults({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const ShimmerBox(width: 100, height: 14),
          const SizedBox(height: 12),
          const ShimmerCampaignCard(),
          const SizedBox(height: 20),
          const ShimmerBox(width: 80, height: 14),
          const SizedBox(height: 12),
          ...List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ShimmerProfileTile(),
          )),
        ],
      ),
    );
  }
}

class _ShimmerProfileTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 100, height: 13),
                SizedBox(height: 4),
                ShimmerBox(width: 70, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A skeleton for settings list screens
class ShimmerSettingsList extends StatelessWidget {
  final int count;
  const ShimmerSettingsList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: List.generate(count, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
                const SizedBox(width: 12),
                const Expanded(child: ShimmerBox(width: 120, height: 14)),
                const ShimmerBox(width: 16, height: 16),
              ],
            ),
          ),
        )),
      ),
    );
  }
}

/// A skeleton for generic list items with icon + text
class ShimmerGenericListTile extends StatelessWidget {
  const ShimmerGenericListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 140, height: 14),
                  SizedBox(height: 4),
                  ShimmerBox(width: 90, height: 10),
                ],
              ),
            ),
            const ShimmerBox(width: 18, height: 18, borderRadius: 100),
          ],
        ),
      ),
    );
  }
}

/// A skeleton for card detail screens (cover image + details)
class ShimmerCardDetail extends StatelessWidget {
  const ShimmerCardDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMarginHorizontal,
          AppSpacing.pageMarginVertical,
          AppSpacing.pageMarginHorizontal,
          AppSpacing.pageMarginVertical + AppSpacing.bottomScreenPadding,
        ),
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
          ),
          const SizedBox(height: 20),
          const ShimmerBox(width: 200, height: 22),
          const SizedBox(height: 8),
          const ShimmerBox(width: 120, height: 12),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: ShimmerBox(width: double.infinity, height: 40, borderRadius: 100)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(width: double.infinity, height: 40, borderRadius: 100)),
            ],
          ),
          const SizedBox(height: 24),
          const ShimmerBox(width: 80, height: 14),
          const SizedBox(height: 8),
          const ShimmerBox(width: double.infinity, height: 14),
          const SizedBox(height: 4),
          const ShimmerBox(width: double.infinity, height: 14),
          const SizedBox(height: 4),
          const ShimmerBox(width: 220, height: 14),
          const SizedBox(height: 24),
          const ShimmerBox(width: 80, height: 14),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(4, (i) => ShimmerBox(width: 70.0 + (i * 12), height: 28, borderRadius: 100)),
          ),
        ],
      ),
    );
  }
}

/// A skeleton for influencer grid items (avatar + name)
class ShimmerInfluencerGrid extends StatelessWidget {
  const ShimmerInfluencerGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(width: 56, height: 56, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(height: 8),
            const ShimmerBox(width: 80, height: 12),
            const SizedBox(height: 4),
            const ShimmerBox(width: 60, height: 10),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                ShimmerBox(width: 30, height: 16),
                SizedBox(width: 12),
                ShimmerBox(width: 30, height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton for analytics/chart sections
class ShimmerAnalyticsScreen extends StatelessWidget {
  const ShimmerAnalyticsScreen({super.key});

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
        const ShimmerStatGrid(count: 4),
        const SizedBox(height: 24),
        AppShimmer(
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppShimmer(
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
          ),
        ),
      ],
    );
  }
}

/// A skeleton for chat room/message screen
class ShimmerChatRoom extends StatelessWidget {
  const ShimmerChatRoom({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
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
                  Container(width: 28, height: 28, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                ],
                Container(
                  width: isMe ? 180 : 200,
                  height: 44 + (i % 2) * 16.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ---------- showPremiumConfirmDialog ----------
Future<bool?> showPremiumConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  IconData? icon,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        icon: icon != null
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.error.withOpacity(0.12)
                      : AppColors.accent.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isDestructive ? AppColors.error : AppColors.accent,
                ),
              )
            : null,
        title: Text(
          title,
          style: AppTextStyles.h4.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    cancelLabel,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDestructive ? AppColors.error : AppColors.accent,
                    foregroundColor: isDestructive ? Colors.white : AppColors.accentOnDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

// ---------- showPremiumDialog ----------
Future<T?> showPremiumDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget>? actions,
  List<Widget> Function(BuildContext dialogContext)? actionsBuilder,
  IconData? icon,
  bool isDestructive = false,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogCtx) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        icon: icon != null
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.error.withValues(alpha: 0.12)
                      : AppColors.accent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isDestructive ? AppColors.error : AppColors.accent,
                ),
              )
            : null,
        title: Text(
          title,
          style: AppTextStyles.h4.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        content: content,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: actionsBuilder != null ? actionsBuilder(dialogCtx) : actions,
      );
    },
  );
}

bool isValidImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) return false;
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
}

class AppImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final Widget? fallback;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AppImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallback,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = fallback ?? Container(
      color: AppColors.surface2,
      width: width,
      height: height,
      child: Center(
        child: Icon(Iconsax.image, color: AppColors.textMuted, size: 24),
      ),
    );

    if (!isValidImageUrl(url)) {
      return placeholder;
    }

    final cleanUrl = url!.trim();

    Widget imageWidget = CachedNetworkImage(
      cacheManager: AppCacheManager.instance,
      imageUrl: cleanUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: width != null ? (width! * 2).toInt() : null,
      memCacheHeight: height != null ? (height! * 2).toInt() : null,
      placeholder: (context, url) => Container(
        color: AppColors.surface2,
        width: width,
        height: height,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => placeholder,
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

// ---------- PortfolioItemDetailSheet ----------
class PortfolioItemDetailSheet extends StatelessWidget {
  final Map<String, dynamic> item;

  const PortfolioItemDetailSheet({super.key, required this.item});

  static void show(BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PortfolioItemDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaUrl = item['media_url'] as String?;
    final postUrl = item['post_url'] as String?;
    final title = item['title'] ?? 'Untitled';
    final platform = item['platform'] ?? '';
    final desc = item['description'] ?? '';
    final er = item['engagement_rate'];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
            width: 1.2,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF26262B) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header title and close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Media Image
              if (mediaUrl != null && mediaUrl.trim().isNotEmpty) ...[
                GestureDetector(
                  onTap: () {
                    context.push('/image-viewer', extra: {
                      'urls': [mediaUrl],
                      'title': title,
                    });
                  },
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppImage(url: mediaUrl, fit: BoxFit.cover),
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'View Fullscreen',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Info Row (Platform & Engagement Rate)
              Row(
                children: [
                  if (platform.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.global, size: 12, color: AppColors.accent),
                          const SizedBox(width: 5),
                          Text(
                            platform,
                            style: AppTextStyles.label.copyWith(
                              fontSize: 11.5,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (er != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.trend_up, size: 12, color: AppColors.success),
                          const SizedBox(width: 5),
                          Text(
                            '$er% ER',
                            style: AppTextStyles.label.copyWith(
                              fontSize: 11.5,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'About this project',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Button
              if (postUrl != null && postUrl.trim().isNotEmpty) ...[
                AppButton(
                  label: 'View Original Post',
                  icon: Iconsax.link,
                  onTap: () async {
                    final uri = Uri.tryParse(postUrl.trim());
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
              AppButton(
                label: 'Close',
                isPrimary: false,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}