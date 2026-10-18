import 'package:flutter/material.dart';

/// Keeploom brand palette (`docs/design/Keeploom Brand Identity Board.png`,
/// `docs/design/Keeploom App Design Showcase.png`). Widgets use the semantic
/// [CloserColors] roles, never these raw values.
abstract final class CloserPalette {
  // Light
  static const ivory = Color(0xFFFFF7F1);
  static const ivoryDeep = Color(0xFFF8EDE7);
  static const blush = Color(0xFFFCE8EC);
  static const peach = Color(0xFFFDCABA);
  static const coral = Color(0xFFF5767A);
  static const coralEnd = Color(0xFFF04468);
  static const plum = Color(0xFF6B3F55);
  static const charcoal = Color(0xFF2E2A2A);
  static const mauve = Color(0xFF786B79);
  static const mauveSoft = Color(0xFF8A7D8B);
  static const border = Color(0xFFF0E2E3);
  static const white = Color(0xFFFFFFFF);

  /// Coral text on light surfaces: >= 4.5:1 on ivory and blush (WCAG AA);
  /// the brand coral itself is only used for fills and large marks.
  static const coralText = Color(0xFFB8304F);

  /// Button gradient, deepened from coral -> coralEnd so white labels keep
  /// >= 3:1 contrast across the whole gradient.
  static const buttonStart = Color(0xFFEE5F70);
  static const buttonEnd = Color(0xFFE23A5E);

  // Dark
  static const nightBg = Color(0xFF0E0810);
  static const nightSurface = Color(0xFF1A1620);
  static const nightCard = Color(0xFF241D2A);
  static const nightCoral = Color(0xFFFF687B);
  static const nightPlum = Color(0xFFB982A6);
  static const nightText = Color(0xFFFFF7F4);
  static const nightTextSoft = Color(0xFFC2B5C5);
  static const nightTextMuted = Color(0xFF9D8FA0);
  static const nightLine = Color(0xFF3B303F);
  static const nightBlush = Color(0xFF3A2230);

  // Group-type tints and status colours.
  static const lavenderDeep = Color(0xFF8C6BC8);
  static const sky = Color(0xFF5B8DEF);
  static const gold = Color(0xFFF5B54A);
  static const sage = Color(0xFF4FA37A);
}

/// Semantic colour roles used by every component, available through
/// `Theme.of(context).extension<CloserColors>()` or `context.closerColors`.
@immutable
class CloserColors extends ThemeExtension<CloserColors> {
  const CloserColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.onAccent,
    required this.line,
    required this.danger,
    required this.success,
    required this.premium,
    required this.coupleTint,
    required this.familyTint,
    required this.friendsTint,
    required this.brandPlum,
    required this.peach,
    required this.accentGradient,
    required this.heroScrim,
  });

  final Color background;

  /// Cards, sheets, dialogs, inputs and the navigation dock.
  final Color surface;

  /// Elevated / secondary fills (dark: the "card" tone).
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;

  /// Hints and inactive icons (>= 3:1; not for body text).
  final Color textTertiary;

  /// Brand coral for fills, borders, focus rings and large marks.
  final Color accent;

  /// Coral for text and small icons (contrast-safe).
  final Color accentStrong;

  /// Blush highlight behind selected items.
  final Color accentSoft;
  final Color onAccent;
  final Color line;
  final Color danger;
  final Color success;
  final Color premium;
  final Color coupleTint;
  final Color familyTint;
  final Color friendsTint;

  /// Second brand colour (logo, decorative accents).
  final Color brandPlum;
  final Color peach;
  final LinearGradient accentGradient;

  /// Dark gradient laid over photos so white text stays legible.
  final LinearGradient heroScrim;

  static const _button = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [CloserPalette.buttonStart, CloserPalette.buttonEnd],
  );

  static const light = CloserColors(
    background: CloserPalette.ivory,
    surface: CloserPalette.white,
    surfaceMuted: CloserPalette.ivoryDeep,
    textPrimary: CloserPalette.charcoal,
    textSecondary: CloserPalette.mauve,
    textTertiary: CloserPalette.mauveSoft,
    accent: CloserPalette.coral,
    accentStrong: CloserPalette.coralText,
    accentSoft: CloserPalette.blush,
    onAccent: CloserPalette.white,
    line: CloserPalette.border,
    danger: Color(0xFFC53030),
    success: Color(0xFF2E8A5E),
    premium: CloserPalette.gold,
    coupleTint: CloserPalette.coral,
    familyTint: CloserPalette.lavenderDeep,
    friendsTint: CloserPalette.sky,
    brandPlum: CloserPalette.plum,
    peach: CloserPalette.peach,
    accentGradient: _button,
    heroScrim: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x00000000), Color(0x33000000), Color(0xB3000000)],
      stops: [0.35, 0.6, 1],
    ),
  );

  static const dark = CloserColors(
    background: CloserPalette.nightBg,
    surface: CloserPalette.nightSurface,
    surfaceMuted: CloserPalette.nightCard,
    textPrimary: CloserPalette.nightText,
    textSecondary: CloserPalette.nightTextSoft,
    textTertiary: CloserPalette.nightTextMuted,
    accent: CloserPalette.nightCoral,
    accentStrong: CloserPalette.nightCoral,
    accentSoft: CloserPalette.nightBlush,
    onAccent: CloserPalette.white,
    line: CloserPalette.nightLine,
    danger: Color(0xFFFF8A80),
    success: Color(0xFF6CC497),
    premium: CloserPalette.gold,
    coupleTint: CloserPalette.nightCoral,
    familyTint: Color(0xFFB79BE6),
    friendsTint: Color(0xFF86AAF3),
    brandPlum: CloserPalette.nightPlum,
    peach: CloserPalette.peach,
    accentGradient: _button,
    heroScrim: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x00000000), Color(0x40000000), Color(0xCC000000)],
      stops: [0.35, 0.6, 1],
    ),
  );

  @override
  CloserColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentStrong,
    Color? accentSoft,
    Color? onAccent,
    Color? line,
    Color? danger,
    Color? success,
    Color? premium,
    Color? coupleTint,
    Color? familyTint,
    Color? friendsTint,
    Color? brandPlum,
    Color? peach,
    LinearGradient? accentGradient,
    LinearGradient? heroScrim,
  }) {
    return CloserColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      line: line ?? this.line,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      premium: premium ?? this.premium,
      coupleTint: coupleTint ?? this.coupleTint,
      familyTint: familyTint ?? this.familyTint,
      friendsTint: friendsTint ?? this.friendsTint,
      brandPlum: brandPlum ?? this.brandPlum,
      peach: peach ?? this.peach,
      accentGradient: accentGradient ?? this.accentGradient,
      heroScrim: heroScrim ?? this.heroScrim,
    );
  }

  @override
  CloserColors lerp(ThemeExtension<CloserColors>? other, double t) {
    if (other is! CloserColors) return this;
    return CloserColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      line: Color.lerp(line, other.line, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      premium: Color.lerp(premium, other.premium, t)!,
      coupleTint: Color.lerp(coupleTint, other.coupleTint, t)!,
      familyTint: Color.lerp(familyTint, other.familyTint, t)!,
      friendsTint: Color.lerp(friendsTint, other.friendsTint, t)!,
      brandPlum: Color.lerp(brandPlum, other.brandPlum, t)!,
      peach: Color.lerp(peach, other.peach, t)!,
      accentGradient: LinearGradient.lerp(
        accentGradient,
        other.accentGradient,
        t,
      )!,
      heroScrim: LinearGradient.lerp(heroScrim, other.heroScrim, t)!,
    );
  }
}
