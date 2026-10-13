import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A painted coastal-sunset scene used as the onboarding hero and as the
/// placeholder for photos that are loading or missing. It is vector art, so
/// it ships no image assets and scales to any size.
///
/// [variant] picks one of several palettes/compositions so placeholder grids
/// do not look identical.
class SunsetArt extends StatelessWidget {
  const SunsetArt({super.key, this.variant = 0, this.showFigures = false});

  final int variant;

  /// Draws two small silhouettes on the shore (used by the hero).
  final bool showFigures;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _SunsetPainter(
          _palettes[variant.abs() % _palettes.length],
          variant.abs(),
          showFigures,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  static const _palettes = [
    _Palette(
      sky: [Color(0xFF6E5B9A), Color(0xFFE9879A), Color(0xFFFBC28E)],
      sun: Color(0xFFFFE3B0),
      sea: [Color(0xFF7B6FA3), Color(0xFF3E3A66)],
      land: Color(0xFF2E2440),
    ),
    _Palette(
      sky: [Color(0xFF4F7CC4), Color(0xFF9DC1E8), Color(0xFFF6D7C3)],
      sun: Color(0xFFFFF1D6),
      sea: [Color(0xFF3C8DAE), Color(0xFF1F5874)],
      land: Color(0xFF2B4A3A),
    ),
    _Palette(
      sky: [Color(0xFFB2557A), Color(0xFFF08C7D), Color(0xFFFFD08A)],
      sun: Color(0xFFFFF0C2),
      sea: [Color(0xFFC0697C), Color(0xFF5C2E4A)],
      land: Color(0xFF3A1F33),
    ),
    _Palette(
      sky: [Color(0xFF8A6FB8), Color(0xFFD9A3C8), Color(0xFFF9E1D0)],
      sun: Color(0xFFFFF5E6),
      sea: [Color(0xFF8C86B8), Color(0xFF4A4778)],
      land: Color(0xFF3B3157),
    ),
  ];
}

class _Palette {
  const _Palette({
    required this.sky,
    required this.sun,
    required this.sea,
    required this.land,
  });

  final List<Color> sky;
  final Color sun;
  final List<Color> sea;
  final Color land;
}

class _SunsetPainter extends CustomPainter {
  _SunsetPainter(this.p, this.seed, this.figures);

  final _Palette p;
  final int seed;
  final bool figures;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.62;

    // Sky
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.sky,
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );

    // Sun with glow
    final sunCenter = Offset(w * (0.55 + 0.08 * (seed % 3 - 1)), horizon);
    final sunR = math.min(w, h) * 0.13;
    canvas.drawCircle(
      sunCenter,
      sunR * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [p.sun.withValues(alpha: 0.55), p.sun.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: sunR * 2.6)),
    );
    canvas.drawCircle(sunCenter, sunR, Paint()..color = p.sun);

    // Sea
    final seaRect = Rect.fromLTWH(0, horizon, w, h - horizon);
    canvas.drawRect(
      seaRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.sea,
        ).createShader(seaRect),
    );

    // Sun reflection
    final shimmer = Paint()..color = p.sun.withValues(alpha: 0.35);
    for (var i = 0; i < 5; i++) {
      final y = horizon + (h - horizon) * (0.08 + i * 0.12);
      final half = sunR * (1.1 - i * 0.16);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(sunCenter.dx, y),
            width: half * 2,
            height: 3,
          ),
          const Radius.circular(2),
        ),
        shimmer,
      );
    }

    // Headland / rocks in the foreground
    final land = Path()
      ..moveTo(0, h * 0.78)
      ..quadraticBezierTo(w * 0.18, h * 0.70, w * 0.38, h * 0.80)
      ..quadraticBezierTo(w * 0.55, h * 0.88, w * 0.72, h * 0.86)
      ..quadraticBezierTo(w * 0.88, h * 0.84, w, h * 0.90)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(land, Paint()..color = p.land);

    // Distant hills on the left horizon
    final hills = Path()
      ..moveTo(0, horizon)
      ..quadraticBezierTo(w * 0.12, horizon - h * 0.07, w * 0.28, horizon)
      ..close();
    canvas.drawPath(hills, Paint()..color = p.land.withValues(alpha: 0.55));

    if (figures) _drawFigures(canvas, Offset(w * 0.33, h * 0.78), h * 0.075);
  }

  void _drawFigures(Canvas canvas, Offset base, double unit) {
    final paint = Paint()..color = p.land;
    for (final dx in [-0.42, 0.42]) {
      final c = base.translate(dx * unit, 0);
      canvas.drawCircle(c.translate(0, -unit * 1.25), unit * 0.28, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c.translate(0, -unit * 0.55),
            width: unit * 0.78,
            height: unit * 1.0,
          ),
          Radius.circular(unit * 0.35),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SunsetPainter old) =>
      old.p != p || old.seed != seed || old.figures != figures;
}
