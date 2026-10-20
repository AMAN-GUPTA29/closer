import 'package:flutter/material.dart';

import '../theme/closer_theme.dart';

/// The Keeploom mark: two interlocking rounded shapes (coral and plum) with
/// an ivory "seed" where they overlap: the moment that is kept. Optional
/// wordmark and tagline beneath. Drawn as vectors, so it is sharp at any
/// size; the geometry matches `tool/keeploom_logo.py`, which generates the
/// launcher icons and splash from the same numbers.
class KeeploomLogo extends StatelessWidget {
  const KeeploomLogo({
    super.key,
    this.size = 72,
    this.showWordmark = false,
    this.showTagline = false,
    this.wordmarkColor,
  });

  static const name = 'Keeploom';
  static const tagline = 'Keep what brings you closer.';

  final double size;
  final bool showWordmark;
  final bool showTagline;
  final Color? wordmarkColor;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final mark = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: KeeploomMarkPainter(
          coral: CloserPalette.coral,
          plum: CloserPalette.plum,
          seed: CloserPalette.ivory,
        ),
      ),
    );
    if (!showWordmark) {
      return Semantics(label: name, image: true, child: mark);
    }
    return Semantics(
      label: showTagline ? '$name. $tagline' : name,
      image: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          SizedBox(height: size * 0.18),
          Text(
            name,
            style: context.text.displaySmall?.copyWith(
              fontSize: size * 0.5,
              letterSpacing: -0.5,
              color: wordmarkColor ?? c.textPrimary,
            ),
          ),
          if (showTagline) ...[
            const SizedBox(height: CloserSpacing.xxs),
            Text(
              tagline,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: (wordmarkColor ?? c.textSecondary).withValues(
                  alpha: wordmarkColor == null ? 1 : 0.9,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Paints the mark into a square canvas (100x100 design units).
class KeeploomMarkPainter extends CustomPainter {
  const KeeploomMarkPainter({
    required this.coral,
    required this.plum,
    required this.seed,
  });

  final Color coral;
  final Color plum;
  final Color seed;

  static const _coral = [
    Offset(10, 24),
    Offset(54, 10),
    Offset(58, 62),
    Offset(16, 74),
  ];
  static const _plum = [
    Offset(36, 38),
    Offset(88, 30),
    Offset(82, 86),
    Offset(40, 90),
  ];
  static const _seed = [
    Offset(39, 42),
    Offset(55, 39),
    Offset(57, 56),
    Offset(49, 65),
    Offset(41, 60),
  ];

  static Path _rounded(List<Offset> pts, double radius, double scale) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final p0 = pts[(i - 1 + pts.length) % pts.length] * scale;
      final p1 = pts[i] * scale;
      final p2 = pts[(i + 1) % pts.length] * scale;
      final v1 = p0 - p1;
      final v2 = p2 - p1;
      final r = [
        radius * scale,
        v1.distance / 2.2,
        v2.distance / 2.2,
      ].reduce((a, b) => a < b ? a : b);
      final a = p1 + v1 / v1.distance * r;
      final b = p1 + v2 / v2.distance * r;
      if (i == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      path.quadraticBezierTo(p1.dx, p1.dy, b.dx, b.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    final coralPath = _rounded(_coral, 13, s);
    final plumPath = _rounded(_plum, 13, s);
    final overlap = Path.combine(PathOperation.intersect, coralPath, plumPath);
    canvas
      ..drawPath(coralPath, Paint()..color = coral)
      ..drawPath(plumPath, Paint()..color = plum)
      // Plum over coral, slightly darker than plum alone.
      ..drawPath(
        overlap,
        Paint()..color = Color.lerp(plum, const Color(0xFF000000), 0.16)!,
      )
      ..drawPath(_rounded(_seed, 6, s), Paint()..color = seed);
  }

  @override
  bool shouldRepaint(KeeploomMarkPainter old) =>
      old.coral != coral || old.plum != plum || old.seed != seed;
}
