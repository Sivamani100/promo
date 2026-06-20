import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ---------- AppButton ----------
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isPrimary;
  final IconData? icon;
  final double? width;

  const AppButton({super.key, required this.label, this.onTap, this.isLoading = false, this.isPrimary = true, this.icon, this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      child: isPrimary
          ? ElevatedButton(
              onPressed: isLoading ? null : onTap,
              child: _buildContent(),
            )
          : OutlinedButton(
              onPressed: isLoading ? null : onTap,
              child: _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentOnDark));
    }
    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(label)],
      );
    }
    return Text(label);
  }
}

// ---------- AppTextField ----------
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final int? maxLines;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? suffix;
  final Widget? prefixIcon;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.suffix,
    this.prefixIcon,
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
          validator: validator,
          onChanged: onChanged,
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            prefixIcon: prefixIcon,
            border: maxLines != null && maxLines! > 1
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg), borderSide: BorderSide(color: AppColors.border))
                : null,
            enabledBorder: maxLines != null && maxLines! > 1
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg), borderSide: BorderSide(color: AppColors.border))
                : null,
            focusedBorder: maxLines != null && maxLines! > 1
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg), borderSide: BorderSide(color: AppColors.textPrimary, width: 1.5))
                : null,
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
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover, errorWidget: (_, _, _) => _fallback())
          : _fallback(),
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
      color: AppColors.accent,
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
class StatCard extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    List<Color>? resolvedGradient;
    Color? resolvedBorder;
    Color? resolvedText;
    Color? resolvedLabel;
    Color? resolvedIcon;

    if (preset != null) {
      switch (preset!) {
        case StatCardPreset.indigo:
          resolvedGradient = isDark 
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)] 
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)];
          resolvedBorder = isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE);
          resolvedText = isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5);
          resolvedLabel = resolvedText.withOpacity(0.85);
          resolvedIcon = resolvedText;
          break;
        case StatCardPreset.rose:
          resolvedGradient = isDark 
              ? [const Color(0xFF500730), const Color(0xFF700B48)] 
              : [const Color(0xFFFDF2F8), const Color(0xFFFCE7F3)];
          resolvedBorder = isDark ? const Color(0xFF9D174D) : const Color(0xFFFBCFE8);
          resolvedText = isDark ? const Color(0xFFFBCFE8) : const Color(0xFFDB2777);
          resolvedLabel = resolvedText.withOpacity(0.85);
          resolvedIcon = resolvedText;
          break;
        case StatCardPreset.emerald:
          resolvedGradient = isDark 
              ? [const Color(0xFF064E3B), const Color(0xFF065F46)] 
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)];
          resolvedBorder = isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0);
          resolvedText = isDark ? const Color(0xFFA7F3D0) : const Color(0xFF059669);
          resolvedLabel = resolvedText.withOpacity(0.85);
          resolvedIcon = resolvedText;
          break;
        case StatCardPreset.amber:
          resolvedGradient = isDark 
              ? [const Color(0xFF451A03), const Color(0xFF78350F)] 
              : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)];
          resolvedBorder = isDark ? const Color(0xFF92400E) : const Color(0xFFFFD8A8);
          resolvedText = isDark ? const Color(0xFFFFD8A8) : const Color(0xFFD97706);
          resolvedLabel = resolvedText.withOpacity(0.85);
          resolvedIcon = resolvedText;
          break;
        case StatCardPreset.cyan:
          resolvedGradient = isDark 
              ? [const Color(0xFF0C4A6E), const Color(0xFF075985)] 
              : [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)];
          resolvedBorder = isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD);
          resolvedText = isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0284C7);
          resolvedLabel = resolvedText.withOpacity(0.85);
          resolvedIcon = resolvedText;
          break;
        case StatCardPreset.purple:
          resolvedGradient = isDark 
              ? [const Color(0xFF3B0764), const Color(0xFF581C87)] 
              : [const Color(0xFFFAF5FF), const Color(0xFFF3E8FF)];
          resolvedBorder = isDark ? const Color(0xFF7E22CE) : const Color(0xFFE9D5FF);
          resolvedText = isDark ? const Color(0xFFE9D5FF) : const Color(0xFF9333EA);
          resolvedLabel = resolvedText.withOpacity(0.85);
          resolvedIcon = resolvedText;
          break;
      }
    }

    final bg = backgroundColor ?? AppColors.surface;
    final grads = gradientColors ?? resolvedGradient;
    final borderCol = borderColor ?? resolvedBorder ?? AppColors.border;
    final valColor = textColor ?? resolvedText ?? AppColors.textPrimary;
    final lblColor = labelColor ?? resolvedLabel ?? AppColors.textSecondary;
    final icColor = iconColor ?? resolvedIcon ?? AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: grads == null ? bg : null,
        gradient: grads != null ? LinearGradient(
          colors: grads,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: borderCol, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: AppTextStyles.captionSm.copyWith(color: lblColor), overflow: TextOverflow.ellipsis)),
              Icon(icon, size: 18, color: icColor),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.h2.copyWith(
                fontSize: 28,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: valColor,
              ),
            ),
          ),
        ],
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

  const CampaignCardWidget({super.key, required this.card, this.onTap, this.matchScore});

  @override
  Widget build(BuildContext context) {
    final brand = card['brand'] as Map<String, dynamic>?;
    final category = card['category'] as String? ?? '';
    final categoryColor = AppColors.getCategoryColor(category);
    final nicheTags = (card['niche_tags'] as List<dynamic>?)?.cast<String>() ?? [];

    return GestureDetector(
      onTap: onTap,
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
            // Cover image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Container(
                    color: AppColors.surface2,
                    child: card['cover_image_url'] != null
                        ? CachedNetworkImage(imageUrl: card['cover_image_url'], fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                        : Center(child: Icon(Iconsax.volume_high, size: 40, color: AppColors.borderSubtle)),
                  ),
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: categoryColor, borderRadius: BorderRadius.circular(100)),
                      child: Text(category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.black)),
                    ),
                  ),
                  if (matchScore != null && matchScore! > 0)
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.9), borderRadius: BorderRadius.circular(100)),
                        child: Text('Match: +$matchScore', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.black)),
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
                  if (brand != null)
                    GestureDetector(
                      onTap: () {
                        if (brand['id'] != null) {
                          context.push('/influencer/brands/${brand['id']}');
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          AppAvatar(url: brand['avatar_url'], fallbackText: brand['display_name'] ?? 'B', size: 24),
                          const SizedBox(width: 8),
                          Text(brand['display_name'] ?? 'Brand', style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(card['title'] ?? '', style: AppTextStyles.h4.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(card['description'] ?? '', style: AppTextStyles.caption.copyWith(fontSize: 12, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (nicheTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: nicheTags.take(3).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.borderSubtle)),
                        child: Text('#${tag.toLowerCase()}', style: AppTextStyles.captionSm.copyWith(fontSize: 10, color: AppColors.textSecondary)),
                      )).toList(),
                    ),
                  ],
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
                    children: [
                      Text('BUDGET', style: AppTextStyles.captionSm.copyWith(fontSize: 9)),
                      Text(card['budget_range'] ?? 'Open', style: AppTextStyles.label.copyWith(fontSize: 13)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(100)),
                    child: Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentOnDark)),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return Image.asset(
      'assets/Verification badge.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}