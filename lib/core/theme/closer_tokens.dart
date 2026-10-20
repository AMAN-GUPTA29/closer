import 'package:flutter/material.dart';

/// 4-pt spacing scale.
abstract final class CloserSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter used by every screen.
  static const double gutter = 20;
}

abstract final class CloserRadii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Soft, warm shadows. Kept subtle: cards should feel lifted, not floating.
abstract final class CloserElevation {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> low = [
    BoxShadow(color: Color(0x0F2E2A2A), blurRadius: 10, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(color: Color(0x142E2A2A), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Primary actions are flat in the Impeccable redesign (no glow).
  static const List<BoxShadow> accentGlow = none;
}

/// Motion tokens. Always resolve durations through [CloserMotion.of] so the
/// platform "reduce motion" setting is respected.
abstract final class CloserMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;

  /// Returns [Duration.zero] when the user asked the OS to reduce motion.
  static Duration of(BuildContext context, Duration base) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return reduce ? Duration.zero : base;
  }

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
