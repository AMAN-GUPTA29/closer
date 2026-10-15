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

  // Group screens sit above the shell (no bottom bar) but keep Home below.
  static const createGroup = '/home/create';
  static const joinGroup = '/home/join';
  static String group(String id) => '/home/groups/$id';
  static String invite(String id) => '/home/groups/$id/invite';
  static String members(String id) => '/home/groups/$id/members';
  static String groupSettings(String id) => '/home/groups/$id/settings';
  static String upgrade(String id) => '/home/groups/$id/upgrade';
  static String allPhotos(String id) => '/home/groups/$id/photos';
  static String newMoment(String id, {String? photoId}) =>
      '/home/groups/$id/moments/new${photoId == null ? '' : '?photo=$photoId'}';
  static String editMoment(String id, String milestoneId) =>
      '/home/groups/$id/moments/$milestoneId';

  static const notificationPreferences = '/notifications/preferences';
  static const editProfile = '/profile/edit';
  static const purchases = '/profile/purchases';
  static const deleteAccount = '/profile/delete';
  static const widgetSetup = '/profile/widgets';
  static String addMemory(String id, {String? source}) =>
      '/home/groups/$id/add${source == null ? '' : '?source=$source'}';

  /// Routes reachable without a session.
  static const _public = {welcome, signIn, signUp, forgotPassword, verifyEmail};

  static bool isPublic(String path) => _public.contains(path);
  static bool isAlwaysAllowed(String path) => path.startsWith(legal);
}

/// Pure redirect policy used by the router (unit tested).
///
/// Returns the path to redirect to, or `null` to stay on [path].
/// When [hasPendingInvite] is true (an invite link arrived), signed-in users
/// are taken to the Join screen first.
String? resolveRedirect(
  AuthStatus status,
  String path, {
  bool hasPendingInvite = false,
}) {
  if (Routes.isAlwaysAllowed(path)) return null;
  switch (status) {
    case SignedOut():
      return Routes.isPublic(path) ? null : Routes.welcome;
    case PasswordRecovery():
      return path == Routes.updatePassword ? null : Routes.updatePassword;
    case SignedIn(:final user) when !user.emailConfirmed:
      return path == Routes.verifyEmail ? null : Routes.verifyEmail;
    case SignedIn() || PreviewSession():
      if (hasPendingInvite && path != Routes.joinGroup) {
        return Routes.joinGroup;
      }
      if (Routes.isPublic(path) || path == Routes.updatePassword) {
        return Routes.home;
      }
      return null;
  }
}
