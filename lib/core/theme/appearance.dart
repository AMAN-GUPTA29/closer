import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the chosen appearance is remembered between launches.
abstract interface class AppearanceStore {
  ThemeMode? read();
  Future<void> write(ThemeMode mode);
}

/// Device preferences (the real app; set up in `main.dart`).
class PrefsAppearanceStore implements AppearanceStore {
  PrefsAppearanceStore(this._prefs);

  static const key = 'keeploom.appearance';
  final SharedPreferences _prefs;

  @override
  ThemeMode? read() => switch (_prefs.getString(key)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => null,
  };

  @override
  Future<void> write(ThemeMode mode) => _prefs.setString(key, mode.name);
}

/// Tests and previews: nothing touches the device.
class MemoryAppearanceStore implements AppearanceStore {
  MemoryAppearanceStore([this.value]);

  ThemeMode? value;

  @override
  ThemeMode? read() => value;

  @override
  Future<void> write(ThemeMode mode) async => value = mode;
}

final appearanceStoreProvider = Provider<AppearanceStore>(
  (ref) => MemoryAppearanceStore(),
);

/// Light, Dark or System (default). Changing it re-themes the app at once.
final appearanceProvider = NotifierProvider<AppearanceController, ThemeMode>(
  AppearanceController.new,
);

class AppearanceController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      ref.read(appearanceStoreProvider).read() ?? ThemeMode.system;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(appearanceStoreProvider).write(mode);
  }
}

/// Status and navigation bar icons that match the active theme, with the
/// app drawing edge to edge behind transparent bars.
SystemUiOverlayStyle systemBarsFor(Brightness brightness, Color navBar) {
  final dark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: brightness, // iOS
    systemNavigationBarColor: navBar.withValues(alpha: 0),
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}
