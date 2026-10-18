import 'package:flutter/material.dart';

/// Font families bundled in `assets/fonts` (SIL Open Font License).
abstract final class CloserFonts {
  /// UI font: Plus Jakarta Sans (variable weight).
  static const sans = 'PlusJakartaSans';

  /// Display sizes use the same family at heavier weights (Keeploom boards
  /// use a single geometric sans).
  static const display = sans;
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
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// Keeploom type scale. Minimum body size is 14 for legibility.
abstract final class CloserTypography {
  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: closerStyle(
        size: 56,
        weight: FontWeight.w800,
        height: 1.0,
        family: CloserFonts.display,
        letterSpacing: -1,
      ).copyWith(color: primary),
      displayMedium: closerStyle(
        size: 40,
        weight: FontWeight.w800,
        height: 1.05,
        family: CloserFonts.display,
        letterSpacing: -0.5,
      ).copyWith(color: primary),
      displaySmall: closerStyle(
        size: 32,
        weight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.6,
      ).copyWith(color: primary),
      headlineLarge: closerStyle(
        size: 28,
        weight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.4,
      ).copyWith(color: primary),
      headlineMedium: closerStyle(
        size: 24,
        weight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.3,
      ).copyWith(color: primary),
      headlineSmall: closerStyle(
        size: 20,
        weight: FontWeight.w700,
        height: 1.25,
      ).copyWith(color: primary),
      titleLarge: closerStyle(
        size: 18,
        weight: FontWeight.w700,
        height: 1.3,
      ).copyWith(color: primary),
      titleMedium: closerStyle(
        size: 16,
        weight: FontWeight.w700,
        height: 1.35,
      ).copyWith(color: primary),
      titleSmall: closerStyle(
        size: 14,
        weight: FontWeight.w700,
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
        weight: FontWeight.w700,
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
