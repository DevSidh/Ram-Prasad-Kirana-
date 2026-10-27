import 'package:flutter/material.dart';

import 'app_colors.dart';

class AdminGradientBackground extends StatelessWidget {
  const AdminGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.pageStart, AppColors.pageEnd],
          ),
        ),
        child: child,
      );
}

class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              letterSpacing: 0.72,
              fontWeight: FontWeight.w700,
            ),
      );
}

enum AppStatusVariant { success, neutral, error, warning }

class AppStatusPill extends StatelessWidget {
  const AppStatusPill(
    this.label, {
    super.key,
    this.variant = AppStatusVariant.neutral,
    this.icon,
  });

  final String label;
  final AppStatusVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (variant) {
      AppStatusVariant.success => (
          AppColors.successBanner,
          AppColors.successText
        ),
      AppStatusVariant.neutral => (AppColors.pageEnd, AppColors.muted),
      AppStatusVariant.error => (AppColors.errorPill, AppColors.errorText),
      AppStatusVariant.warning => (
          AppColors.warningPill,
          AppColors.warningText
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.icon = Icons.check_circle_outline_rounded,
    this.variant = AppStatusVariant.success,
    this.trailing,
  });

  final String message;
  final IconData icon;
  final AppStatusVariant variant;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (variant) {
      AppStatusVariant.success => (
          AppColors.successBanner,
          AppColors.successBannerText
        ),
      AppStatusVariant.neutral => (AppColors.pageEnd, AppColors.muted),
      AppStatusVariant.error => (AppColors.errorPill, AppColors.errorText),
      AppStatusVariant.warning => (
          AppColors.warningPill,
          AppColors.warningText
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.banner),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class AppStatCard extends StatelessWidget {
  const AppStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? tint;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              offset: const Offset(0, 6),
              blurRadius: 24,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint ?? AppColors.thumbnailGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class AppRowCard extends StatelessWidget {
  const AppRowCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.tint,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Color? tint;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tint ?? AppColors.thumbnailGreen,
                borderRadius: BorderRadius.circular(AppRadii.thumbnail),
              ),
              alignment: Alignment.center,
              child: leading,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.row),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.row),
        child: child,
      ),
    );
  }
}

class AppSurface extends StatelessWidget {
  const AppSurface({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              offset: const Offset(0, 6),
              blurRadius: 24,
            ),
          ],
        ),
        child: child,
      );
}
