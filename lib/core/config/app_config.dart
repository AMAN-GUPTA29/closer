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
    required this.privacyPolicyUrl,
    required this.termsUrl,
    required this.supportEmail,
    required this.authRedirectUrl,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      googleAuthEnabled: bool.fromEnvironment('GOOGLE_AUTH_ENABLED'),
      appleAuthEnabled: bool.fromEnvironment('APPLE_AUTH_ENABLED'),
      privacyPolicyUrl: String.fromEnvironment('PRIVACY_POLICY_URL'),
      termsUrl: String.fromEnvironment('TERMS_URL'),
      supportEmail: String.fromEnvironment('SUPPORT_EMAIL'),
      authRedirectUrl: String.fromEnvironment(
        'AUTH_REDIRECT_URL',
        defaultValue: defaultAuthRedirectUrl,
      ),
    );
  }

  /// Custom-scheme callback registered in AndroidManifest.xml and Info.plist.
  static const defaultAuthRedirectUrl = 'com.closerapp.closer://auth-callback';

  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool googleAuthEnabled;
  final bool appleAuthEnabled;
  final String privacyPolicyUrl;
  final String termsUrl;
  final String supportEmail;
  final String authRedirectUrl;

  /// True when both client values are present and the URL is well formed.
  bool get isSupabaseConfigured {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return false;
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  bool get hasPrivacyPolicy => _isHttpUrl(privacyPolicyUrl);
  bool get hasTerms => _isHttpUrl(termsUrl);

  static bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
