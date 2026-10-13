import 'package:closer/core/errors/app_failure.dart';
import 'package:closer/features/auth/application/auth_providers.dart';
import 'package:closer/features/auth/data/auth_repository.dart';
import 'package:closer/features/auth/domain/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  group('authFailureFromCode', () {
    test('maps known codes to friendly messages', () {
      expect(
        authFailureFromCode('invalid_credentials').message,
        contains('do not match'),
      );
      expect(
        authFailureFromCode('user_already_exists').message,
        contains('already exists'),
      );
      expect(
        authFailureFromCode('over_email_send_rate_limit').message,
        contains('Too many'),
      );
    });

    test('falls back safely and keeps the code', () {
      final f = authFailureFromCode('something_new') as AuthFailure;
      expect(f.code, 'something_new');
      expect(f.message, isNot(contains('something_new')));
      expect(
        authFailureFromCode(null, statusCode: '429').message,
        contains('Too many'),
      );
    });
  });

  group('UnconfiguredAuthRepository', () {
    test('reports not configured and refuses actions', () async {
      const repo = UnconfiguredAuthRepository();
      expect(repo.isConfigured, isFalse);
      expect(repo.currentUser, isNull);
      await expectLater(
        repo.signIn(email: 'a@b.co', password: 'x'),
        throwsA(isA<NotConfiguredFailure>()),
      );
    });
  });

  group('AuthController', () {
    late FakeAuthRepository repo;
    late ProviderContainer container;

    ProviderContainer build({AuthRepository? r, bool configured = true}) {
      final c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            configured ? testConfig : unconfiguredConfig,
          ),
          authRepositoryProvider.overrideWithValue(r ?? repo),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => repo = FakeAuthRepository());
    tearDown(() => repo.dispose());

    test('starts signed out without a user', () {
      container = build();
      expect(container.read(authControllerProvider), isA<SignedOut>());
    });

    test('starts signed in when a session exists', () {
      repo = FakeAuthRepository(initialUser: testUser);
      container = build();
      final s = container.read(authControllerProvider);
      expect(s, isA<SignedIn>());
      expect((s as SignedIn).user, testUser);
    });

    test('follows auth events, including password recovery', () async {
      container = build();
      container.listen(authControllerProvider, (_, _) {});

      repo.emit(const AuthEvent(user: testUser));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authControllerProvider), isA<SignedIn>());

      repo.emit(const AuthEvent(user: testUser, isPasswordRecovery: true));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authControllerProvider), isA<PasswordRecovery>());

      // A token refresh during recovery must not skip the password step.
      repo.emit(const AuthEvent(user: testUser));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authControllerProvider), isA<PasswordRecovery>());

      container
          .read(authControllerProvider.notifier)
          .completePasswordRecovery();
      expect(container.read(authControllerProvider), isA<SignedIn>());

      await container.read(authControllerProvider.notifier).signOut();
      expect(container.read(authControllerProvider), isA<SignedOut>());
      expect(repo.calls, contains('signOut'));
    });

    test('preview mode is refused when a backend is configured', () {
      container = build();
      container.read(authControllerProvider.notifier).enterPreview();
      expect(container.read(authControllerProvider), isA<SignedOut>());
    });

    test('preview mode is allowed in debug without a backend', () {
      container = build(
        r: const UnconfiguredAuthRepository(),
        configured: false,
      );
      expect(container.read(previewModeAvailableProvider), isTrue);
      container.read(authControllerProvider.notifier).enterPreview();
      expect(container.read(authControllerProvider), isA<PreviewSession>());
    });
  });
}
