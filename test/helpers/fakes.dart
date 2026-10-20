import 'dart:typed_data';
import 'dart:async';

import 'package:closer/app/app.dart';
import 'package:closer/core/config/app_config.dart';
import 'package:closer/core/errors/app_failure.dart';
import 'package:closer/core/network/connectivity.dart';
import 'package:closer/core/sync/app_sync.dart';
import 'package:closer/core/sync/realtime_feed.dart';
import 'package:closer/features/notifications/push/push_service.dart';
import 'package:closer/features/widgets/widget_sync.dart';
import 'package:closer/core/theme/closer_theme.dart';
import 'package:closer/features/auth/application/auth_providers.dart';
import 'package:closer/features/auth/data/auth_repository.dart';
import 'package:closer/features/auth/domain/auth_models.dart';
import 'package:closer/features/groups/application/group_providers.dart';
import 'package:closer/features/groups/data/groups_repository.dart';
import 'package:closer/features/groups/data/in_memory_groups_repository.dart';
import 'package:closer/features/invitations/application/invite_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

const testConfig = AppConfig(
  supabaseUrl: 'https://example.supabase.co',
  supabaseAnonKey: 'test-anon-key',
  googleAuthEnabled: false,
  appleAuthEnabled: false,
  privacyPolicyUrl: '',
  termsUrl: '',
  supportEmail: '',
  authRedirectUrl: AppConfig.defaultAuthRedirectUrl,
);

const unconfiguredConfig = AppConfig(
  supabaseUrl: '',
  supabaseAnonKey: '',
  googleAuthEnabled: false,
  appleAuthEnabled: false,
  privacyPolicyUrl: '',
  termsUrl: '',
  supportEmail: '',
  authRedirectUrl: AppConfig.defaultAuthRedirectUrl,
);

const testUser = AuthUser(
  id: 'u1',
  email: 'alex@example.com',
  emailConfirmed: true,
  displayName: 'Alex Kim',
);

/// In-memory AuthRepository that behaves like a configured backend.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser}) : _user = initialUser;

  final _events = StreamController<AuthEvent>.broadcast();
  AuthUser? _user;

  /// Accepted credentials for [signIn].
  String validEmail = testUser.email;
  String validPassword = 'secret123';
  bool signUpNeedsConfirmation = true;
  AppFailure? nextFailure;
  final calls = <String>[];

  void emit(AuthEvent event) {
    _user = event.user;
    _events.add(event);
  }

  Future<void> dispose() => _events.close();

  Future<void> _maybeFail() async {
    final f = nextFailure;
    if (f != null) {
      nextFailure = null;
      throw f;
    }
  }

  @override
  bool get isConfigured => true;
  @override
  AuthUser? get currentUser => _user;
  @override
  Stream<AuthEvent> get events => _events.stream;

  /// Username passed to the last sign-up.
  String? lastUsername;

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
    String? username,
  }) async {
    calls.add('signUp:$email');
    lastUsername = username;
    await _maybeFail();
    if (!signUpNeedsConfirmation) {
      emit(
        AuthEvent(
          user: AuthUser(
            id: 'new',
            email: email,
            emailConfirmed: true,
            displayName: displayName,
          ),
        ),
      );
    }
    return SignUpResult(needsEmailConfirmation: signUpNeedsConfirmation);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    await _maybeFail();
    if (email != validEmail || password != validPassword) {
      throw const AuthFailure(
        'That email and password do not match.',
        code: 'invalid_credentials',
      );
    }
    emit(const AuthEvent(user: testUser));
  }

  @override
  Future<void> signInWithProvider(SocialProvider provider) async {
    calls.add('oauth:${provider.name}');
    await _maybeFail();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    calls.add('reset:$email');
    await _maybeFail();
  }

  @override
  Future<void> resendVerification(String email) async {
    calls.add('resend:$email');
    await _maybeFail();
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    calls.add('updatePassword');
    await _maybeFail();
  }

  @override
  Future<AuthUser?> refreshUser() async => _user;

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    emit(const AuthEvent(user: null));
  }
}

/// Pumps the full app with overridden config, auth and groups backends.
/// Links can be injected through [links] to simulate deep links.
Future<void> pumpCloserApp(
  WidgetTester tester, {
  AuthRepository? repository,
  AppConfig config = testConfig,
  GroupsBackend? groups,
  Stream<Uri>? links,
  List<Override> extra = const [],
  bool online = true,
  FakeWidgetPlatform? widgets,
  PushService? push,
  RealtimeFeed? feed,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        if (repository != null)
          authRepositoryProvider.overrideWithValue(repository),
        if (groups != null) groupsBackendProvider.overrideWithValue(groups),
        incomingLinksProvider.overrideWithValue(
          links ?? const Stream<Uri>.empty(),
        ),
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
        realtimeFeedProvider.overrideWithValue(
          feed ?? const NoopRealtimeFeed(),
        ),
        pushServiceProvider.overrideWithValue(push ?? const NoopPushService()),
        widgetSyncProvider.overrideWithValue(
          WidgetSync(widgets ?? FakeWidgetPlatform()),
        ),
        ...extra,
      ],
      child: const CloserApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// In-memory groups backend for the signed-in [testUser].
InMemoryGroupsRepository memoryGroups({String userId = 'u1'}) =>
    InMemoryGroupsRepository(
      currentUserId: userId,
      currentUserName: 'Alex Kim',
    );

/// Wraps a single widget in a themed MaterialApp for component tests.
Widget themed(Widget child) {
  return MaterialApp(
    theme: CloserTheme.light,
    home: Scaffold(body: child),
  );
}

/// In-memory stand-in for home_widget storage and native widget refresh.
class FakeWidgetPlatform implements WidgetPlatform {
  final values = <String, String>{};
  final images = <String, int>{};
  final refreshes = <String?>[];

  @override
  Future<void> save(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<String?> writeImage(String groupId, Uint8List? bytes) async {
    if (bytes == null) {
      images.remove(groupId);
      return null;
    }
    images[groupId] = bytes.length;
    return '/widgets/$groupId.jpg';
  }

  @override
  Future<void> deleteImage(String groupId) async => images.remove(groupId);

  @override
  Future<void> refresh({String? groupId}) async => refreshes.add(groupId);
}

/// Opens the group page's "Group options" menu and picks [item].
Future<void> openGroupMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('Group options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}
