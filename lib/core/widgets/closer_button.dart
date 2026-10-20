import 'package:flutter/material.dart';

import '../theme/closer_theme.dart';

enum CloserButtonVariant { primary, secondary, ghost, danger }

/// The primary call-to-action button: a coral→rose pill (primary), a white
/// outlined pill (secondary), a text button (ghost) or a destructive pill.
///
/// When [onPressed] is null or [isLoading] is true the button is disabled.
class CloserButton extends StatelessWidget {
  const CloserButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CloserButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.semanticLabel,
  });

  const CloserButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.semanticLabel,
  }) : variant = CloserButtonVariant.secondary;

  const CloserButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    this.semanticLabel,
  }) : variant = CloserButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final CloserButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final bool expand;
  final String? semanticLabel;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final isPrimary = variant == CloserButtonVariant.primary;
    final isGhost = variant == CloserButtonVariant.ghost;

    final foreground = switch (variant) {
      CloserButtonVariant.primary => c.onPrimary,
      CloserButtonVariant.danger => Colors.white,
      CloserButtonVariant.secondary => c.textPrimary,
      CloserButtonVariant.ghost => c.textPrimary,
    };

    final content = AnimatedSwitcher(
      duration: CloserMotion.of(context, CloserMotion.fast),
      child: isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: foreground,
              ),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  IconTheme(
                    data: IconThemeData(color: foreground, size: 20),
                    child: icon!,
                  ),
                  const SizedBox(width: CloserSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
    );

    final decoration = BoxDecoration(
      borderRadius: CloserRadii.pillAll,
      gradient: isPrimary ? c.accentGradient : null,
      color: switch (variant) {
        CloserButtonVariant.primary => null,
        // Dark mode's danger red is light (for text); white labels need a
        // deep red fill in both themes (5.4:1).
        CloserButtonVariant.danger => const Color(0xFFB4232F),
        CloserButtonVariant.secondary => c.surface,
        CloserButtonVariant.ghost => Colors.transparent,
      },
      border: variant == CloserButtonVariant.secondary
          ? Border.all(color: c.line)
          : null,
      // Flat buttons: no glow and no shadow.
      boxShadow: null,
    );

    final button = Semantics(
      button: true,
      enabled: _enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: CloserMotion.of(context, CloserMotion.fast),
        opacity: onPressed == null ? 0.45 : 1,
        child: DecoratedBox(
          decoration: decoration,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: CloserRadii.pillAll,
              onTap: _enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: isGhost ? 48 : 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CloserSpacing.xl,
                  ),
                  child: Center(widthFactor: 1, child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A round icon button with a mandatory accessibility label and an optional
/// badge dot (e.g. unread notifications).
class CloserIconButton extends StatelessWidget {
  const CloserIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.filled = false,
    this.tonal = false,
    this.showBadge = false,
    this.size = 44,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// Filled buttons use the accent gradient (e.g. the "+" create button).
  final bool filled;

  /// Blush background, no shadow (e.g. the Home bell).
  final bool tonal;
  final bool showBadge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        child: Opacity(
          opacity: onPressed == null ? 0.45 : 1,
          child: SizedBox(
            width: size < 48 ? 48 : size,
            height: size < 48 ? 48 : size,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: filled ? c.accentGradient : null,
                      color: filled
                          ? null
                          : tonal
                          ? c.accentSoft
                          : c.surface,
                      boxShadow: filled
                          ? CloserElevation.accentGlow
                          : tonal
                          ? CloserElevation.none
                          : CloserElevation.low,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onPressed,
                        child: SizedBox(
                          width: size,
                          height: size,
                          child: Icon(
                            icon,
                            size: size * 0.5,
                            color: filled ? c.onAccent : c.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showBadge)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: c.accentStrong,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
