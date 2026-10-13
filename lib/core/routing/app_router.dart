import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/presentation/update_password_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/dev/component_gallery_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/journal/presentation/journal_screen.dart';
import '../../features/legal/legal_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/shell/app_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final status = ValueNotifier<AuthStatus>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => status.value = next);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.welcome,
    refreshListenable: status,
    debugLogDiagnostics: false,
    redirect: (context, state) =>
        resolveRedirect(status.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: Routes.welcome,
        pageBuilder: (context, state) => _fade(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: Routes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (context, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (context, state) =>
            VerifyEmailScreen(email: state.uri.queryParameters['email']),
      ),
      GoRoute(
        path: Routes.updatePassword,
        builder: (context, state) => const UpdatePasswordScreen(),
      ),
      GoRoute(
        path: '${Routes.legal}/:doc',
        builder: (context, state) =>
            LegalScreen(doc: LegalDoc.parse(state.pathParameters['doc'])),
      ),
      if (kDebugMode)
        GoRoute(
          path: Routes.componentGallery,
          builder: (context, state) => const ComponentGalleryScreen(),
        ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.journal,
                builder: (context, state) => const JournalScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.notifications,
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    status.dispose();
  });
  return router;
});

Page<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionsBuilder: (context, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
);
