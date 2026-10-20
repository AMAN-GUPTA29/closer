import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/theme/appearance.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/notifications/push/push_service.dart';
import 'features/widgets/background_refresh.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  final config = AppConfig.fromEnvironment();
  // Read before the first frame so the chosen theme never flashes.
  final prefs = await SharedPreferences.getInstance();

  if (config.isSupabaseConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  if (FirebaseConfig.isConfigured) {
    // Must be registered before runApp; refreshes widgets for pushes that
    // arrive while the app is in the background.
    FirebaseMessaging.onBackgroundMessage(closerBackgroundMessage);
  }

  runApp(
    ProviderScope(
      // Screens show explicit retry buttons; never retry silently.
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        appearanceStoreProvider.overrideWithValue(PrefsAppearanceStore(prefs)),
      ],
      child: const CloserApp(),
    ),
  );
}
