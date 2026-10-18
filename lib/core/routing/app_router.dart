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
import '../../features/groups/application/group_providers.dart';
import '../../features/groups/presentation/create_group_screen.dart';
import '../../features/groups/presentation/group_home_screen.dart';
import '../../features/groups/presentation/group_settings_screen.dart';
import '../../features/groups/presentation/members_screen.dart';
import '../../features/invitations/presentation/invite_screen.dart';
import '../../features/invitations/presentation/join_group_screen.dart';
import '../../features/journal/presentation/all_journal_screen.dart';
import '../../features/journal/presentation/special_moment_screen.dart';
import '../../features/notifications/presentation/notification_preferences_screen.dart';
import '../../features/photos/presentation/all_photos_screen.dart';
import '../../features/profile/presentation/delete_account_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/purchased_groups_screen.dart';
import '../../features/widgets/widget_setup_screen.dart';
import '../../features/photos/application/photo_providers.dart';
import '../../features/photos/presentation/add_memory_screen.dart';
import '../../features/purchases/upgrade_screen.dart';
import '../../features/home/presentation/all_groups_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/legal/legal_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/journal/application/content_providers.dart';
import '../../features/profile/presentation/choose_username_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/shell/app_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final status = ValueNotifier<AuthStatus>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => status.value = next);
  final pendingInvite = ValueNotifier<bool>(
    ref.read(pendingInviteProvider) != null,
  );
  ref.listen(
    pendingInviteProvider,
    (_, next) => pendingInvite.value = next != null,
  );

  final needsUsername = ValueNotifier<bool>(ref.read(needsUsernameProvider));
  ref.listen(needsUsernameProvider, (_, next) => needsUsername.value = next);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.welcome,
    refreshListenable: Listenable.merge([status, pendingInvite, needsUsername]),
    debugLogDiagnostics: false,
    redirect: (context, state) => resolveRedirect(
      status.value,
      state.matchedLocation,
      hasPendingInvite: pendingInvite.value,
      needsUsername: needsUsername.value,
    ),
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
        path: Routes.chooseUsername,
        builder: (context, state) => const ChooseUsernameScreen(),
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
                routes: [
                  GoRoute(
                    path: 'create',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => const CreateGroupScreen(),
                  ),
                  GoRoute(
                    path: 'join',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => JoinGroupScreen(
                      initialSecret:
                          state.uri.queryParameters['t'] ??
                          state.uri.queryParameters['code'],
                    ),
                  ),
                  GoRoute(
                    path: 'groups',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => const AllGroupsScreen(),
                  ),
                  GoRoute(
                    path: 'groups/:groupId',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => GroupHomeScreen(
                      groupId: state.pathParameters['groupId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'invite',
                        parentNavigatorKey: _rootKey,
                        builder: (context, state) => InviteScreen(
                          groupId: state.pathParameters['groupId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'members',
                        parentNavigatorKey: _rootKey,
                        builder: (context, state) => MembersScreen(
                          groupId: state.pathParameters['groupId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'add',
                        parentNavigatorKey: _rootKey,
                        builder: (context, state) => AddMemoryScreen(
                          groupId: state.pathParameters['groupId']!,
                          source: switch (state.uri.queryParameters['source']) {
                            'camera' => PhotoSource.camera,
                            'gallery' => PhotoSource.gallery,
                            _ => null,
                          },
                        ),
                      ),
                      GoRoute(
                        path: 'photos',
                        parentNavigatorKey: _rootKey,
                        builder: (context, state) => AllPhotosScreen(
                          groupId: state.pathParameters['groupId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'moments/new',
                        parentNavigatorKey: _rootKey,
                        builder: (context, state) => SpecialMomentScreen(
                          groupId: state.pathParameters['groupId']!,
                          coverPhotoId: state.uri.queryParameters['photo'],
                        ),
                      ),
                      GoRoute(
                        path: 'moments/:milestoneId',
                        parentNavigatorKey: _rootKey,
                        builder: (context, state) => SpecialMomentScreen(
                          groupId: state.pathParameters['groupId']!,
                          milestoneId: state.pathParameters['milestoneId'],
                        ),
                      ),
                      GoRoute(
                        path: 'upgrade',
                        parentNavigatorKey: _rootKey,
                        builder: (context, state) => UpgradeScreen(
                          groupId: state.pathParameters['groupId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'settings',
                        parentNavigatorKey: _rootKey,
                        builder: (context, state) => GroupSettingsScreen(
                          groupId: state.pathParameters['groupId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.journal,
                builder: (context, state) => const AllJournalScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.notifications,
                builder: (context, state) => const NotificationsScreen(),
                routes: [
                  GoRoute(
                    path: 'preferences',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) =>
                        const NotificationPreferencesScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'purchases',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => const PurchasedGroupsScreen(),
                  ),
                  GoRoute(
                    path: 'widgets',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => const WidgetSetupScreen(),
                  ),
                  GoRoute(
                    path: 'delete',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => const DeleteAccountScreen(),
                  ),
                ],
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
    pendingInvite.dispose();
  });
  return router;
});

Page<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionsBuilder: (context, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
);
