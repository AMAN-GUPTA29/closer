/// Build-time configuration supplied with `--dart-define` or
/// `--dart-define-from-file=.env.json`. Only client-safe values belong here:
/// the Supabase URL and its publishable (anon) key. Never pass service-role
/// keys or other secrets to the app.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.googleAuthEnabled,
    required this.appleAuthEnabled,
    required this.supportEmail,
    required this.authRedirectUrl,
    this.inviteLinkBase = '',
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      googleAuthEnabled: bool.fromEnvironment('GOOGLE_AUTH_ENABLED'),
      appleAuthEnabled: bool.fromEnvironment('APPLE_AUTH_ENABLED'),
      supportEmail: String.fromEnvironment('SUPPORT_EMAIL'),
      authRedirectUrl: String.fromEnvironment(
        'AUTH_REDIRECT_URL',
        defaultValue: defaultAuthRedirectUrl,
      ),
      inviteLinkBase: String.fromEnvironment('INVITE_LINK_BASE'),
    );
  }

  /// Custom-scheme callback registered in AndroidManifest.xml and Info.plist.
  static const defaultAuthRedirectUrl = 'com.keeploom.app://auth-callback';

  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool googleAuthEnabled;
  final bool appleAuthEnabled;
  final String supportEmail;
  final String authRedirectUrl;

  /// Address of the public website (site/), e.g. https://keeploom.pages.dev.
  final String inviteLinkBase;

  /// Where invite links point, so chat apps make them tappable. Null until
  /// the website is configured; invites then use the custom scheme.
  Uri? get inviteWebBase {
    final uri = Uri.tryParse(inviteLinkBase.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }

  /// True when both client values are present and the URL is well formed.
  bool get isSupabaseConfigured {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return false;
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }
}
