import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Firebase client options from --dart-define (client-safe identifiers, not
/// secrets). Using options instead of google-services.json keeps the build
/// working when Firebase isn't set up yet.
abstract final class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosBundleId = 'com.closerapp.closer';

  static String get appId => Platform.isIOS ? iosAppId : androidAppId;

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      projectId.isNotEmpty &&
      senderId.isNotEmpty &&
      appId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    iosBundleId: Platform.isIOS ? iosBundleId : null,
  );
}

/// What a push carries: ids only. Content is always fetched from the server.
class PushEvent {
  const PushEvent({required this.type, this.groupId, this.notificationId});

  factory PushEvent.fromData(Map<String, dynamic> data) => PushEvent(
    type: data['type'] as String? ?? 'unknown',
    groupId: data['group_id'] as String?,
    notificationId: int.tryParse('${data['notification_id']}'),
  );

  final String type;
  final String? groupId;
  final int? notificationId;
}

/// Device registration and incoming push events.
abstract interface class PushService {
  /// Requests permission, registers the token with the server and starts
  /// listening. Safe to call more than once.
  Future<void> start();

  /// Unregisters this device (sign-out) so pushes stop.
  Future<void> stop();

  /// Pushes received while the app is open.
  Stream<PushEvent> get foreground;

  /// Pushes the user tapped (including the one that launched the app).
  Stream<PushEvent> get opened;
}

class NoopPushService implements PushService {
  const NoopPushService();

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Stream<PushEvent> get foreground => const Stream.empty();
  @override
  Stream<PushEvent> get opened => const Stream.empty();
}

/// Registers tokens through trusted RPCs (`register_device`).
abstract interface class DeviceRegistry {
  Future<void> register(String token, String platform, String appVersion);
  Future<void> unregister(String token);
}

class SupabaseDeviceRegistry implements DeviceRegistry {
  SupabaseDeviceRegistry(this._db);

  final sb.SupabaseClient _db;

  @override
  Future<void> register(String token, String platform, String appVersion) =>
      _db.rpc<void>(
        'register_device',
        params: {
          'p_token': token,
          'p_platform': platform,
          'p_app_version': appVersion,
        },
      );

  @override
  Future<void> unregister(String token) =>
      _db.rpc<void>('unregister_device', params: {'p_token': token});
}

/// Firebase Cloud Messaging (Android directly, iOS through APNs).
class FirebasePushService implements PushService {
  FirebasePushService(this._registry, {this.appVersion = '1.0.0'});

  final DeviceRegistry _registry;
  final String appVersion;
  final _foreground = StreamController<PushEvent>.broadcast();
  final _opened = StreamController<PushEvent>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];
  String? _token;
  bool _started = false;

  static Future<void> ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: FirebaseConfig.options);
    }
  }

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await ensureFirebase();
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final platform = Platform.isIOS ? 'ios' : 'android';
      Future<void> register(String token) async {
        _token = token;
        await _registry.register(token, platform, appVersion);
      }

      final token = await messaging.getToken();
      if (token != null) await register(token);
      _subs
        ..add(messaging.onTokenRefresh.listen(register))
        ..add(
          FirebaseMessaging.onMessage.listen(
            (m) => _foreground.add(PushEvent.fromData(m.data)),
          ),
        )
        ..add(
          FirebaseMessaging.onMessageOpenedApp.listen(
            (m) => _opened.add(PushEvent.fromData(m.data)),
          ),
        );
      final initial = await messaging.getInitialMessage();
      if (initial != null) _opened.add(PushEvent.fromData(initial.data));
    } catch (_) {
      // Push is optional: the in-app list still works without it.
      _started = false;
    }
  }

  @override
  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _started = false;
    final token = _token;
    _token = null;
    if (token == null) return;
    try {
      await _registry.unregister(token);
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // The server also retires tokens that stop working.
    }
  }

  @override
  Stream<PushEvent> get foreground => _foreground.stream;

  @override
  Stream<PushEvent> get opened => _opened.stream;
}
