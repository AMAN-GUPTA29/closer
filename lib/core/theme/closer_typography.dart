import 'package:flutter/material.dart';

/// Font families bundled in `assets/fonts` (SIL Open Font License).
abstract final class CloserFonts {
  /// UI font: Plus Jakarta Sans (variable weight).
  static const sans = 'PlusJakartaSans';

  /// Editorial serif for greetings, page titles and counters: Fraunces
  /// (variable; Impeccable redesign).
  static const serif = 'Fraunces';
  static const display = serif;
}

/// Builds a style for a bundled variable font. Both [FontWeight] and the
/// `wght` axis are set so the weight renders correctly on every engine.
TextStyle closerStyle({
  required double size,
  required FontWeight weight,
  double? height,
  double letterSpacing = 0,
  String family = CloserFonts.sans,
}) {
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [
      FontVariation('wght', weight.value.toDouble()),
      if (family == CloserFonts.serif)
        FontVariation('opsz', size.clamp(9, 144).toDouble()),
    ],
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// Keeploom type scale. Minimum body size is 14 for legibility.
abstract final class CloserTypography {
  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: closerStyle(
        size: 64,
        weight: FontWeight.w400,
        height: 1.0,
        family: CloserFonts.display,
        letterSpacing: -1.9,
      ).copyWith(color: primary),
      displayMedium: closerStyle(
        size: 40,
        weight: FontWeight.w400,
        height: 1.05,
        family: CloserFonts.display,
        letterSpacing: -1,
      ).copyWith(color: primary),
      displaySmall: closerStyle(
        size: 34,
        weight: FontWeight.w400,
        height: 1.1,
        family: CloserFonts.display,
        letterSpacing: -0.7,
      ).copyWith(color: primary),
      headlineLarge: closerStyle(
        size: 30,
        weight: FontWeight.w400,
        height: 1.15,
        family: CloserFonts.display,
        letterSpacing: -0.6,
      ).copyWith(color: primary),
      headlineMedium: closerStyle(
        size: 26,
        weight: FontWeight.w400,
        height: 1.2,
        family: CloserFonts.display,
        letterSpacing: -0.4,
      ).copyWith(color: primary),
      headlineSmall: closerStyle(
        size: 20,
        weight: FontWeight.w400,
        height: 1.25,
        family: CloserFonts.display,
      ).copyWith(color: primary),
      titleLarge: closerStyle(
        size: 18,
        weight: FontWeight.w600,
        height: 1.3,
      ).copyWith(color: primary),
      titleMedium: closerStyle(
        size: 16,
        weight: FontWeight.w600,
        height: 1.35,
      ).copyWith(color: primary),
      titleSmall: closerStyle(
        size: 14,
        weight: FontWeight.w600,
        height: 1.35,
      ).copyWith(color: primary),
      bodyLarge: closerStyle(
        size: 16,
        weight: FontWeight.w500,
        height: 1.5,
      ).copyWith(color: primary),
      bodyMedium: closerStyle(
        size: 14,
        weight: FontWeight.w500,
        height: 1.5,
      ).copyWith(color: secondary),
      bodySmall: closerStyle(
        size: 13,
        weight: FontWeight.w500,
        height: 1.4,
      ).copyWith(color: secondary),
      labelLarge: closerStyle(
        size: 16,
        weight: FontWeight.w600,
        height: 1.2,
      ).copyWith(color: primary),
      labelMedium: closerStyle(
        size: 13,
        weight: FontWeight.w600,
        height: 1.2,
      ).copyWith(color: secondary),
      labelSmall: closerStyle(
        size: 12,
        weight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.2,
      ).copyWith(color: secondary),
    );
  }
}
