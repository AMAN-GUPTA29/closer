import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/auth_models.dart';

abstract interface class AuthRepository {
  bool get isConfigured;
  AuthUser? get currentUser;
  Stream<AuthEvent> get events;

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
    String? username,
  });
  Future<void> signIn({required String email, required String password});
  Future<void> signInWithProvider(SocialProvider provider);
  Future<void> sendPasswordReset(String email);
  Future<void> resendVerification(String email);
  Future<void> updatePassword(String newPassword);

  /// Re-reads the user from the server (e.g. after confirming email).
  Future<AuthUser?> refreshUser();
  Future<void> signOut();
}

/// Used when SUPABASE_URL / SUPABASE_ANON_KEY were not supplied at build time.
class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  static const _failure = NotConfiguredFailure(
    'Sign-in is not available in this build because the Keeploom backend '
    'is not configured yet.',
  );

  @override
  bool get isConfigured => false;
  @override
  AuthUser? get currentUser => null;
  @override
  Stream<AuthEvent> get events => const Stream.empty();

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
    String? username,
  }) => Future.error(_failure);
  @override
  Future<void> signIn({required String email, required String password}) =>
      Future.error(_failure);
  @override
  Future<void> signInWithProvider(SocialProvider provider) =>
      Future.error(_failure);
  @override
  Future<void> sendPasswordReset(String email) => Future.error(_failure);
  @override
  Future<void> resendVerification(String email) => Future.error(_failure);
  @override
  Future<void> updatePassword(String newPassword) => Future.error(_failure);
  @override
  Future<AuthUser?> refreshUser() async => null;
  @override
  Future<void> signOut() async {}
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth, this._config);

  final sb.GoTrueClient _auth;
  final AppConfig _config;

  @override
  bool get isConfigured => true;

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthEvent> get events => _auth.onAuthStateChange.map(
    (state) => AuthEvent(
      user: _map(state.session?.user),
      isPasswordRecovery: state.event == sb.AuthChangeEvent.passwordRecovery,
    ),
  );

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
    String? username,
  }) => _guard(() async {
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      // The server stores the username if it's still free; otherwise the
      // app asks for another one after sign-in.
      data: {'display_name': displayName.trim(), 'username': ?username},
      emailRedirectTo: _config.authRedirectUrl,
    );
    return SignUpResult(needsEmailConfirmation: res.session == null);
  });

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithPassword(email: email.trim(), password: password),
      );

  @override
  Future<void> signInWithProvider(SocialProvider provider) => _guard(() async {
    final enabled = switch (provider) {
      SocialProvider.google => _config.googleAuthEnabled,
      SocialProvider.apple => _config.appleAuthEnabled,
    };
    if (!enabled) throw const NotConfiguredFailure();
    await _auth.signInWithOAuth(
      switch (provider) {
        SocialProvider.google => sb.OAuthProvider.google,
        SocialProvider.apple => sb.OAuthProvider.apple,
      },
      redirectTo: _config.authRedirectUrl,
      authScreenLaunchMode: sb.LaunchMode.externalApplication,
    );
  });

  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () => _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: _config.authRedirectUrl,
    ),
  );

  @override
  Future<void> resendVerification(String email) => _guard(
    () => _auth.resend(
      type: sb.OtpType.signup,
      email: email.trim(),
      emailRedirectTo: _config.authRedirectUrl,
    ),
  );

  @override
  Future<void> updatePassword(String newPassword) =>
      _guard(() => _auth.updateUser(sb.UserAttributes(password: newPassword)));

  @override
  Future<AuthUser?> refreshUser() => _guard(() async {
    if (_auth.currentSession == null) return null;
    final res = await _auth.refreshSession();
    return _map(res.user);
  });

  @override
  Future<void> signOut() => _guard(() => _auth.signOut());

  AuthUser? _map(sb.User? user) {
    if (user == null) return null;
    final name = user.userMetadata?['display_name'];
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      emailConfirmed: user.emailConfirmedAt != null,
      displayName: name is String ? name : null,
    );
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AppFailure {
      rethrow;
    } on sb.AuthRetryableFetchException {
      throw const NetworkFailure();
    } on sb.AuthException catch (e) {
      throw authFailureFromCode(e.code, statusCode: e.statusCode);
    } on SocketException {
      throw const NetworkFailure();
    } on TimeoutException {
      throw const NetworkFailure();
    } catch (_) {
      throw const UnexpectedFailure();
    }
  }
}

/// Maps Supabase Auth error codes to friendly messages. Kept pure for tests.
AppFailure authFailureFromCode(String? code, {String? statusCode}) {
  final message = switch (code) {
    'invalid_credentials' => 'That email and password do not match.',
    'email_not_confirmed' => 'Please confirm your email address first.',
    'user_already_exists' || 'email_exists' =>
      'An account with this email already exists. Try signing in.',
    'weak_password' => 'Choose a stronger password.',
    'same_password' => 'Choose a password you have not used here before.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Too many attempts. Please wait a minute and try again.',
    'signup_disabled' => 'New sign-ups are currently closed.',
    'email_address_invalid' => 'Enter a valid email address.',
    'otp_expired' => 'That link has expired. Request a new one.',
    'provider_disabled' => 'This sign-in method is not enabled yet.',
    'user_banned' => 'This account is not able to sign in.',
    _ =>
      statusCode == '429'
          ? 'Too many attempts. Please wait a minute and try again.'
          : 'We could not complete that. Please try again.',
  };
  return AuthFailure(message, code: code);
}
