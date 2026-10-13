import 'package:flutter/material.dart';

import '../theme/closer_icons.dart';
import '../theme/closer_theme.dart';

/// The Closer mark: a white heart in a coral rounded square, optionally with
/// the wordmark beneath it.
class CloserLogo extends StatelessWidget {
  const CloserLogo({
    super.key,
    this.size = 72,
    this.showWordmark = false,
    this.wordmarkColor,
  });

  final double size;
  final bool showWordmark;
  final Color? wordmarkColor;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CloserPalette.coralLight, CloserPalette.rose],
        ),
        boxShadow: CloserElevation.accentGlow,
      ),
      child: Icon(CloserIcons.heart, color: Colors.white, size: size * 0.56),
    );

    return Semantics(
      label: 'Closer',
      image: true,
      excludeSemantics: true,
      child: showWordmark
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                mark,
                SizedBox(height: size * 0.22),
                Text(
                  'Closer',
                  style: context.text.displaySmall?.copyWith(
                    fontSize: size * 0.56,
                    color: wordmarkColor ?? c.textPrimary,
                  ),
                ),
              ],
            )
          : mark,
    );
  }
}
