import 'package:flutter/material.dart';

class SocialButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget icon;
  final Color buttonColor;
  final String label;
  final TextStyle? titleStyle;
  final bool mini;
  final double iconSize;
  final bool showLabel;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;

  const SocialButton({
    super.key,
    required this.onTap,
    required this.icon,
    required this.buttonColor,
    required this.label,
    this.titleStyle,
    this.mini = false,
    this.iconSize = 24.0,
    this.showLabel = true,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return mini
        ? ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: buttonColor,
              padding: padding ?? const EdgeInsets.all(20),
            ),
            child: icon,
          )
        : Container(
            padding: padding ?? const EdgeInsets.all(20.0),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: icon,
              label: showLabel
                  ? Text(
                      label,
                      style: titleStyle ??
                          const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                    )
                  : const SizedBox.shrink(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: buttonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: borderRadius ?? BorderRadius.circular(12),
                ),
              ),
            ),
          );
  }
}
