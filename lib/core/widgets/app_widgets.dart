import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme_extension.dart';
import '../../widgets/store_animation.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.isDark,
  });

  final Widget child;
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    final colors = dark ? AppColors.dark : AppColors.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.15),
          radius: 1.55,
          colors: [colors.backgroundGlow, colors.background],
          stops: const [0, 1],
        ),
      ),
      child: child,
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeExtension.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.surfaceGlass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tokens.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? 0 : .06,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          disabledBackgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: .45),
          disabledForegroundColor:
              Theme.of(context).colorScheme.onPrimary.withValues(alpha: .72),
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final button = SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeExtension.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: tokens.glassBorder),
    );
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: tokens.surfaceGlass,
        constraints: const BoxConstraints(minHeight: 52),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.quantityLabel,
    this.minimum = 0,
    this.maximum = 999,
  })  : assert(minimum >= 0),
        assert(maximum >= minimum);

  final int value;
  final int minimum;
  final int maximum;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final String decreaseLabel;
  final String increaseLabel;
  final String quantityLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeExtension.of(context);
    return Semantics(
      label: quantityLabel,
      value: '$value',
      child: Container(
        constraints: const BoxConstraints(minWidth: 120, minHeight: 36),
        decoration: BoxDecoration(
          color: tokens.surfaceGlass,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QuantityAction(
              label: decreaseLabel,
              icon: Icons.remove,
              enabled: value > minimum && onDecrement != null,
              onPressed: value > minimum ? onDecrement : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$value',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            _QuantityAction(
              label: increaseLabel,
              icon: Icons.add,
              enabled: value < maximum && onIncrement != null,
              onPressed: value < maximum ? onIncrement : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityAction extends StatelessWidget {
  const _QuantityAction({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          tooltip: label,
          onPressed: enabled ? onPressed : null,
          icon: Icon(
            icon,
            color: enabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).disabledColor,
            size: 20,
          ),
        ),
      );
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.retryLabel,
    this.onRetry,
    this.isError = true,
    this.icon,
  }) : assert((retryLabel == null) == (onRetry == null));

  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final bool isError;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeExtension.of(context);
    final color =
        isError ? Theme.of(context).colorScheme.error : tokens.success;
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isError ? tokens.errorBanner : color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (retryLabel != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: tokens.success,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(retryLabel!),
            ),
        ],
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
  }) : assert(size >= 40);

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: math.max(size, 48),
        height: math.max(size, 48),
        child: Center(
          child: SizedBox(
            width: size,
            height: size,
            child: IconButton(
              tooltip: tooltip,
              onPressed: onPressed,
              style: IconButton.styleFrom(
                backgroundColor: AppThemeExtension.of(context).surfaceGlass,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              icon: Icon(icon),
            ),
          ),
        ),
      );
}

class CategoryBubble extends StatelessWidget {
  const CategoryBubble({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppThemeExtension.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary
                      : tokens.surfaceGlass,
                  shape: BoxShape.circle,
                  border:
                      selected ? null : Border.all(color: tokens.glassBorder),
                ),
                alignment: Alignment.center,
                child: icon,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  }) : assert((actionLabel == null) == (onAction == null));

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      );
}

class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (!WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    final highlight = AppThemeExtension.of(context).surfaceGlass;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final shift = -1 + 2 * _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(shift - 1, 0),
            end: Alignment(shift + 1, 0),
            colors: [base, highlight, base],
          ).createShader(bounds),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: base,
              borderRadius: widget.borderRadius,
            ),
            child: SizedBox(width: widget.width, height: widget.height),
          ),
        );
      },
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => StorePageError(
        title: title,
        message: message,
        retryLabel: retryLabel,
        onRetry: onRetry,
      );
}
