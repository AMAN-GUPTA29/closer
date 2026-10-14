import 'package:closer/core/config/app_config.dart';
import 'package:closer/core/models/group_type.dart';
import 'package:closer/core/routing/routes.dart';
import 'package:closer/core/utils/greeting.dart';
import 'package:closer/core/utils/validators.dart';
import 'package:closer/core/widgets/invite_code_card.dart';
import 'package:closer/core/widgets/member_avatar.dart';
import 'package:closer/features/auth/domain/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email(' alex@example.com '), isNull);
    });

    test('newPassword requires length, a letter and a number', () {
      expect(Validators.newPassword(''), isNotNull);
      expect(Validators.newPassword('abc1'), contains('8'));
      expect(Validators.newPassword('abcdefgh'), contains('number'));
      expect(Validators.newPassword('12345678'), contains('letter'));
      expect(Validators.newPassword('abcd1234'), isNull);
    });

    test('confirmPassword compares with the other field', () {
      final validator = Validators.confirmPassword(() => 'abcd1234');
      expect(validator(''), isNotNull);
      expect(validator('abcd12345'), 'Passwords do not match.');
      expect(validator('abcd1234'), isNull);
    });

    test('displayName', () {
      expect(Validators.displayName('  '), isNotNull);
      expect(Validators.displayName('x' * 41), isNotNull);
      expect(Validators.displayName('Alex'), isNull);
    });
  });

  group('AppConfig', () {
    test('is configured only with a valid URL and key', () {
      expect(testConfig.isSupabaseConfigured, isTrue);
      expect(unconfiguredConfig.isSupabaseConfigured, isFalse);
      const badUrl = AppConfig(
        supabaseUrl: 'not a url',
        supabaseAnonKey: 'k',
        googleAuthEnabled: false,
        appleAuthEnabled: false,
        privacyPolicyUrl: 'http://insecure.example.com',
        termsUrl: 'https://closer.example.com/terms',
        supportEmail: '',
        authRedirectUrl: AppConfig.defaultAuthRedirectUrl,
      );
      expect(badUrl.isSupabaseConfigured, isFalse);
      expect(badUrl.hasPrivacyPolicy, isFalse, reason: 'https only');
      expect(badUrl.hasTerms, isTrue);
    });

    test('fromEnvironment defaults to unconfigured', () {
      final config = AppConfig.fromEnvironment();
      expect(config.isSupabaseConfigured, isFalse);
      expect(config.authRedirectUrl, AppConfig.defaultAuthRedirectUrl);
    });
  });

  group('greetingFor', () {
    test('covers the day', () {
      expect(greetingFor(DateTime(2026, 1, 1, 7)), 'Good morning');
      expect(greetingFor(DateTime(2026, 1, 1, 13)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 19)), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 2)), 'Hello');
    });
  });

  group('resolveRedirect', () {
    const unconfirmed = AuthUser(
      id: 'u',
      email: 'a@b.co',
      emailConfirmed: false,
    );

    test('signed-out users only reach public routes', () {
      const s = SignedOut();
      expect(resolveRedirect(s, Routes.welcome), isNull);
      expect(resolveRedirect(s, Routes.signIn), isNull);
      expect(resolveRedirect(s, Routes.verifyEmail), isNull);
      expect(resolveRedirect(s, Routes.home), Routes.welcome);
      expect(resolveRedirect(s, Routes.profile), Routes.welcome);
      expect(resolveRedirect(s, Routes.updatePassword), Routes.welcome);
    });

    test('legal pages are always reachable', () {
      expect(resolveRedirect(const SignedOut(), '/legal/privacy'), isNull);
      expect(resolveRedirect(const SignedIn(testUser), '/legal/terms'), isNull);
    });

    test('signed-in users skip auth screens', () {
      const s = SignedIn(testUser);
      expect(resolveRedirect(s, Routes.welcome), Routes.home);
      expect(resolveRedirect(s, Routes.signUp), Routes.home);
      expect(resolveRedirect(s, Routes.home), isNull);
      expect(resolveRedirect(s, Routes.journal), isNull);
    });

    test('unconfirmed users must verify their email', () {
      const s = SignedIn(unconfirmed);
      expect(resolveRedirect(s, Routes.home), Routes.verifyEmail);
      expect(resolveRedirect(s, Routes.verifyEmail), isNull);
    });

    test('password recovery pins the update-password screen', () {
      const s = PasswordRecovery(testUser);
      expect(resolveRedirect(s, Routes.home), Routes.updatePassword);
      expect(resolveRedirect(s, Routes.updatePassword), isNull);
    });

    test('preview session behaves like signed in', () {
      const s = PreviewSession();
      expect(resolveRedirect(s, Routes.welcome), Routes.home);
      expect(resolveRedirect(s, Routes.notifications), isNull);
    });
  });

  group('GroupType', () {
    test('couple is capped at two members; others are open', () {
      expect(GroupType.couple.maxMembers, 2);
      expect(GroupType.family.maxMembers, isNull);
      expect(GroupType.friends.maxMembers, isNull);
    });

    test('parse round-trips database values', () {
      for (final t in GroupType.values) {
        expect(GroupType.parse(t.name), t);
      }
      expect(() => GroupType.parse('team'), throwsFormatException);
    });
  });

  group('display helpers', () {
    test('initials', () {
      expect(MemberAvatar.initialsOf('Alex Kim'), 'AK');
      expect(MemberAvatar.initialsOf('emma'), 'E');
      expect(MemberAvatar.initialsOf('  '), '?');
      expect(MemberAvatar.initialsOf('Mary Jane Watson'), 'MW');
    });

    test('avatar tint is deterministic', () {
      expect(MemberAvatar.tintFor('Alex'), MemberAvatar.tintFor('Alex'));
    });

    test('invite code spacing', () {
      expect(InviteCodeCard.spaced('closer783'), 'C L O S E R 7 8 3');
    });

    test('friendlyName falls back to email', () {
      const u = AuthUser(id: '1', email: 'sam@x.io', emailConfirmed: true);
      expect(u.friendlyName, 'sam');
      expect(testUser.friendlyName, 'Alex');
    });
  });
}
