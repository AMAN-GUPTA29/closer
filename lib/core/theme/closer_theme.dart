import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'closer_colors.dart';
import 'closer_tokens.dart';
import 'closer_typography.dart';

export 'closer_colors.dart';
export 'closer_tokens.dart';
export 'closer_typography.dart';

abstract final class CloserTheme {
  static ThemeData get light => _build(CloserColors.light, Brightness.light);
  static ThemeData get dark => _build(CloserColors.dark, Brightness.dark);

  static ThemeData _build(CloserColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accentStrong,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.textPrimary,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceMuted,
      surfaceContainerHighest: c.surfaceMuted,
      outline: c.line,
      outlineVariant: c.line,
    );
    final text = CloserTypography.textTheme(c.textPrimary, c.textSecondary);

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: CloserRadii.mdAll,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      fontFamily: CloserFonts.sans,
      textTheme: text,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CloserSpacing.md,
          vertical: CloserSpacing.md,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: c.textTertiary),
        labelStyle: text.bodyMedium,
        floatingLabelStyle: text.bodyMedium?.copyWith(color: c.accentStrong),
        prefixIconColor: c.textTertiary,
        suffixIconColor: c.textTertiary,
        border: border(c.line),
        enabledBorder: border(c.line),
        focusedBorder: border(c.accent, 1.5),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger, 1.5),
        errorStyle: text.bodySmall?.copyWith(color: c.danger),
        errorMaxLines: 3,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentStrong,
          textStyle: text.titleSmall,
          minimumSize: const Size(48, 48),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.accentSoft,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? c.accentStrong
                : c.textTertiary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? c.accentStrong
                : c.textTertiary,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.background),
        shape: const RoundedRectangleBorder(borderRadius: CloserRadii.mdAll),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: CloserRadii.xlAll),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(CloserRadii.xl),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accentStrong,
        linearTrackColor: c.accentSoft,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

extension CloserThemeContext on BuildContext {
  CloserColors get closerColors =>
      Theme.of(this).extension<CloserColors>() ?? CloserColors.light;
  TextTheme get text => Theme.of(this).textTheme;
}
