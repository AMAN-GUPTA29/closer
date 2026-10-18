import 'package:closer/core/errors/app_failure.dart';
import 'package:closer/features/auth/presentation/sign_in_screen.dart';
import 'package:closer/features/auth/presentation/sign_up_screen.dart';
import 'package:closer/features/auth/presentation/verify_email_screen.dart';
import 'package:closer/features/home/presentation/home_screen.dart';
import 'package:closer/features/journal/presentation/all_journal_screen.dart';
import 'package:closer/features/notifications/presentation/notifications_screen.dart';
import 'package:closer/features/onboarding/presentation/onboarding_screen.dart';
import 'package:closer/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());
  tearDown(() => repo.dispose());

  testWidgets('onboarding leads to sign up and sign in', (tester) async {
    await pumpCloserApp(tester, repository: repo, groups: memoryGroups());
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Share little\nmoments.\nStay close.'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.text('Welcome to Keeploom'), findsOneWidget);

    // The sign-up screen's own "Sign In" link.
    await tester.ensureVisible(find.text('Sign In'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('onboarding pages can be swiped', (tester) async {
    await pumpCloserApp(tester, repository: repo, groups: memoryGroups());
    expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Private by\ndesign.'), findsOneWidget);
  });

  testWidgets('sign-in validates fields before calling the backend', (
    tester,
  ) async {
    await pumpCloserApp(tester, repository: repo, groups: memoryGroups());
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(InkWell, 'Sign In').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('wrong credentials show a friendly error', (tester) async {
    await pumpCloserApp(tester, repository: repo, groups: memoryGroups());
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'alex@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass1');
    await tester.tap(find.widgetWithText(InkWell, 'Sign In').last);
    await tester.pumpAndSettle();
    expect(find.text('That email and password do not match.'), findsOneWidget);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('successful sign-in opens Home, tabs work, sign-out returns', (
    tester,
  ) async {
    await pumpCloserApp(tester, repository: repo, groups: memoryGroups());
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'alex@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(InkWell, 'Sign In').last);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Start your first group'), findsOneWidget);
    expect(find.text('Create a group'), findsOneWidget);

    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.byType(AllJournalScreen), findsOneWidget);

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);

    // "Add" opens a sheet instead of switching tabs.
    await tester.tap(find.byTooltip('Share a memory'));
    await tester.pumpAndSettle();
    expect(find.text('Share a memory'), findsOneWidget);
    // No groups yet: the sheet points to creating one. Dismiss it.
    expect(find.text('Create a group'), findsWidgets);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('alex@example.com'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Sign out'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(InkWell, 'Sign out').last);
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(repo.calls, contains('signOut'));
  });

  testWidgets('sign-up needing confirmation goes to verify email', (
    tester,
  ) async {
    await pumpCloserApp(tester, repository: repo, groups: memoryGroups());
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Sam Lee');
    await tester.enterText(find.byType(TextFormField).at(1), '@Sam.Lee');
    await tester.enterText(find.byType(TextFormField).at(2), 'sam@example.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'goodpass1');
    await tester.ensureVisible(find.widgetWithText(InkWell, 'Sign Up'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    expect(repo.lastUsername, 'sam.lee', reason: 'sent normalised');
    expect(find.textContaining('sam@example.com'), findsOneWidget);

    await tester.tap(find.text('Resend confirmation email'));
    await tester.pump();
    expect(repo.calls, contains('resend:sam@example.com'));
    expect(find.textContaining('Resend in'), findsOneWidget);
    // Let the cooldown timer finish so the test ends cleanly.
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('network failures are shown, not swallowed', (tester) async {
    repo.nextFailure = const NetworkFailure();
    await pumpCloserApp(tester, repository: repo, groups: memoryGroups());
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'alex@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(InkWell, 'Sign In').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('offline'), findsOneWidget);
  });

  testWidgets('without a backend, forms are disabled and preview is offered', (
    tester,
  ) async {
    await pumpCloserApp(tester, config: unconfiguredConfig);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Backend not connected'), findsOneWidget);
    expect(
      find.text('Google and Apple sign-in are not set up yet.'),
      findsOneWidget,
    );
    final field = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(field.enabled, isFalse);

    await tester.tap(find.text('Preview the app (debug only)'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    // Let the preview data's simulated latency (member faces) finish.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('legal summary opens from the auth footer', (tester) async {
    await pumpCloserApp(tester, repository: repo, groups: memoryGroups());
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('In short'), findsOneWidget);
    expect(find.textContaining('draft summary'), findsOneWidget);
  });
}
