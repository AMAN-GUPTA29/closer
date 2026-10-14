import '../../features/auth/domain/auth_models.dart';

/// Route paths. Keep in sync with deep-link docs (docs/architecture.md).
abstract final class Routes {
  static const welcome = '/welcome';
  static const signIn = '/auth/sign-in';
  static const signUp = '/auth/sign-up';
  static const forgotPassword = '/auth/forgot-password';
  static const verifyEmail = '/auth/verify-email';
  static const updatePassword = '/auth/update-password';
  static const legal = '/legal';

  static const home = '/home';
  static const journal = '/journal';
  static const notifications = '/notifications';
  static const profile = '/profile';

  static const componentGallery = '/dev/components';

  /// Routes reachable without a session.
  static const _public = {welcome, signIn, signUp, forgotPassword, verifyEmail};

  static bool isPublic(String path) => _public.contains(path);
  static bool isAlwaysAllowed(String path) => path.startsWith(legal);
}

/// Pure redirect policy used by the router (unit tested).
///
/// Returns the path to redirect to, or `null` to stay on [path].
String? resolveRedirect(AuthStatus status, String path) {
  if (Routes.isAlwaysAllowed(path)) return null;
  switch (status) {
    case SignedOut():
      return Routes.isPublic(path) ? null : Routes.welcome;
    case PasswordRecovery():
      return path == Routes.updatePassword ? null : Routes.updatePassword;
    case SignedIn(:final user) when !user.emailConfirmed:
      return path == Routes.verifyEmail ? null : Routes.verifyEmail;
    case SignedIn() || PreviewSession():
      if (Routes.isPublic(path) || path == Routes.updatePassword) {
        return Routes.home;
      }
      return null;
  }
}
