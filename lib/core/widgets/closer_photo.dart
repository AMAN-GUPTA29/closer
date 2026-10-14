import 'package:flutter/material.dart';

import '../theme/closer_icons.dart';
import '../theme/closer_theme.dart';
import 'sunset_art.dart';

/// Displays a photo with a fade-in, a painted placeholder while loading or
/// when no image exists, and a calm fallback when the image fails.
class CloserPhoto extends StatelessWidget {
  const CloserPhoto({
    super.key,
    this.image,
    this.placeholderVariant = 0,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  final ImageProvider? image;
  final int placeholderVariant;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final placeholder = SunsetArt(variant: placeholderVariant);
    final img = image;
    if (img == null) {
      return Semantics(
        label: semanticLabel,
        image: semanticLabel != null,
        child: placeholder,
      );
    }
    return Image(
      image: img,
      fit: fit,
      semanticLabel: semanticLabel,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            placeholder,
            AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: CloserMotion.of(context, CloserMotion.medium),
              child: child,
            ),
          ],
        );
      },
      errorBuilder: (context, _, _) {
        final c = context.closerColors;
        return ColoredBox(
          color: c.surfaceMuted,
          child: Center(
            child: Icon(CloserIcons.gallery, color: c.textTertiary, size: 32),
          ),
        );
      },
    );
  }
}
