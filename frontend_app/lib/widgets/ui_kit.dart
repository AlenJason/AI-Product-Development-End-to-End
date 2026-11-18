import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 34 : 42,
        height: compact ? 34 : 42,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          Icons.auto_awesome,
          color: Colors.white,
          size: compact ? 20 : 24,
        ),
      ),
      const SizedBox(width: 9),
      Text.rich(
        TextSpan(
          text: 'SmartFit ',
          style: AppTextStyles.h3.copyWith(fontSize: compact ? 17 : 22),
          children: [
            const TextSpan(
              text: 'AI',
              style: TextStyle(color: AppColors.primary),
            ),
          ],
        ),
      ),
    ],
  );
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class NoticePanel extends StatelessWidget {
  const NoticePanel({
    super.key,
    required this.message,
    this.error = false,
    this.success = false,
    this.icon,
  });
  final String message;
  final bool error, success;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final color = error
        ? AppColors.danger
        : success
        ? AppColors.primaryDark
        : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: error
            ? const Color(0xFFFEF2F2)
            : success
            ? AppColors.primarySoft
            : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ??
                (error
                    ? Icons.error_outline
                    : success
                    ? Icons.verified_user_outlined
                    : Icons.info_outline),
            color: color,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h3),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppTextStyles.bodySmall),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: onPressed == null
          ? null
          : const LinearGradient(
              colors: [Color(0xFF22C55E), Color(0xFF15803D)],
            ),
      boxShadow: onPressed == null
          ? null
          : [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .16),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
    ),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: AppColors.border,
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    ),
  );
}

class ToneIcon extends StatelessWidget {
  const ToneIcon({
    super.key,
    required this.icon,
    this.blue = false,
    this.size = 46,
  });
  final IconData icon;
  final bool blue;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: blue ? const Color(0xFFEFF6FF) : AppColors.greenTint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(
      icon,
      color: blue ? AppColors.carbs : AppColors.primaryDark,
      size: size * .46,
    ),
  );
}

class ScreenHeading extends StatelessWidget {
  const ScreenHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
  });
  final String title, subtitle;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null) ...[ToneIcon(icon: icon!), const SizedBox(height: 18)],
      Text(title, style: AppTextStyles.h1.copyWith(fontSize: 26)),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
      ),
    ],
  );
}
