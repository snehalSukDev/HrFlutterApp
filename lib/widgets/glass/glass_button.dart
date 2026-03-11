import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass_container.dart';

class GlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final double width;
  final double height;
  final Color? color;

  const GlassButton({
    super.key,
    this.onPressed,
    required this.label,
    this.icon,
    this.isPrimary = true,
    this.width = double.infinity,
    this.height = 50,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = color ??
        (isPrimary
            ? theme.primaryColor
            : (isDark ? Colors.white : Colors.black));

    final textColor =
        isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black);

    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        child: GlassContainer(
          borderRadius: BorderRadius.circular(12),
          padding: EdgeInsets.zero,
          opacity: onPressed == null ? 0.05 : (isPrimary ? 0.8 : 0.1),
          blur: 10,
          color: onPressed == null
              ? Colors.grey.withValues(alpha: 0.1)
              : baseColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: onPressed == null ? Colors.grey : textColor),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: onPressed == null ? Colors.grey : textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
