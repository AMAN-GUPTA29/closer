import 'package:flutter/material.dart';

/// Raw palette sampled from the Closer concept board
/// (`docs/design/closer-ui-concept-board.png`). Prefer the semantic
/// [CloserColors] extension in widgets instead of these constants.
abstract final class CloserPalette {
  static const ivory = Color(0xFFFFF8F5);
  static const ivoryDeep = Color(0xFFFBEFEA);
  static const blush = Color(0xFFFDE8EC);
  static const blushDeep = Color(0xFFF9D3DB);
  static const coral = Color(0xFFF36B7F);
  static const coralLight = Color(0xFFF89A8E);
  static const rose = Color(0xFFE84F6D);
  static const roseDark = Color(0xFFC93A58);
  static const plum = Color(0xFF2B1A2E);
  static const plumSoft = Color(0xFF5B4A5C);
  static const mauve = Color(0xFF8E7D8C);
  static const mist = Color(0xFFEFE3E3);
  static const white = Color(0xFFFFFFFF);
  static const lavender = Color(0xFFE9DDF5);
  static const lavenderDeep = Color(0xFF8C6BC8);
  static const sky = Color(0xFF5B8DEF);
  static const gold = Color(0xFFF5B54A);
  static const sage = Color(0xFF4FA37A);

  static const nightBg = Color(0xFF1A1119);
  static const nightSurface = Color(0xFF261A25);
  static const nightSurfaceHigh = Color(0xFF33232F);
  static const nightText = Color(0xFFF7ECEE);
  static const nightTextSoft = Color(0xFFC9B8C4);
  static const nightLine = Color(0xFF433340);
}

/// Semantic colour roles used by Closer components, available through
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
    required this.accentGradient,
    required this.heroScrim,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentStrong;
  final Color accentSoft;
  final Color onAccent;
  final Color line;
  final Color danger;
  final Color success;
  final Color premium;
  final Color coupleTint;
  final Color familyTint;
  final Color friendsTint;

  /// The coral → rose gradient used on primary buttons and highlights.
  final LinearGradient accentGradient;

  /// Dark gradient laid over photos so white text stays legible.
  final LinearGradient heroScrim;

  static const light = CloserColors(
    background: CloserPalette.ivory,
    surface: CloserPalette.white,
    surfaceMuted: CloserPalette.ivoryDeep,
    textPrimary: CloserPalette.plum,
    textSecondary: CloserPalette.plumSoft,
    textTertiary: CloserPalette.mauve,
    accent: CloserPalette.coral,
    accentStrong: CloserPalette.rose,
    accentSoft: CloserPalette.blush,
    onAccent: CloserPalette.white,
    line: CloserPalette.mist,
    danger: Color(0xFFC53030),
    success: CloserPalette.sage,
    premium: CloserPalette.gold,
    coupleTint: CloserPalette.coral,
    familyTint: CloserPalette.lavenderDeep,
    friendsTint: CloserPalette.sky,
    accentGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [CloserPalette.coralLight, CloserPalette.rose],
    ),
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
    surfaceMuted: CloserPalette.nightSurfaceHigh,
    textPrimary: CloserPalette.nightText,
    textSecondary: CloserPalette.nightTextSoft,
    textTertiary: Color(0xFF9C8B98),
    accent: Color(0xFFF67F91),
    accentStrong: CloserPalette.coral,
    accentSoft: Color(0xFF4A2733),
    onAccent: CloserPalette.white,
    line: CloserPalette.nightLine,
    danger: Color(0xFFF07070),
    success: Color(0xFF6CC497),
    premium: CloserPalette.gold,
    coupleTint: Color(0xFFF67F91),
    familyTint: Color(0xFFB79BE6),
    friendsTint: Color(0xFF86AAF3),
    accentGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [CloserPalette.coralLight, CloserPalette.coral],
    ),
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
      accentGradient: LinearGradient.lerp(
        accentGradient,
        other.accentGradient,
        t,
      )!,
      heroScrim: LinearGradient.lerp(heroScrim, other.heroScrim, t)!,
    );
  }
}
