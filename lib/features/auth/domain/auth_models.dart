import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.emailConfirmed,
    this.displayName,
  });

  final String id;
  final String email;
  final bool emailConfirmed;
  final String? displayName;

  /// Name used in greetings; falls back to the email's local part.
  String get friendlyName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name.split(' ').first;
    return email.split('@').first;
  }

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.emailConfirmed == emailConfirmed &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, email, emailConfirmed, displayName);
}

/// An auth change reported by the backend.
@immutable
class AuthEvent {
  const AuthEvent({required this.user, this.isPasswordRecovery = false});

  final AuthUser? user;

  /// True when the user opened a password-reset link and must now choose a
  /// new password.
  final bool isPasswordRecovery;
}

/// The app-level session state the router reacts to.
sealed class AuthStatus {
  const AuthStatus();
}

class SignedOut extends AuthStatus {
  const SignedOut();
}

class SignedIn extends AuthStatus {
  const SignedIn(this.user);
  final AuthUser user;
}

/// The user followed a reset link and is signed in only to set a password.
class PasswordRecovery extends AuthStatus {
  const PasswordRecovery(this.user);
  final AuthUser user;
}

/// Debug-only exploration of the UI when no backend is configured.
/// Never available in release builds.
class PreviewSession extends AuthStatus {
  const PreviewSession();

  static const user = AuthUser(
    id: 'preview',
    email: 'preview@closer.local',
    emailConfirmed: true,
    displayName: 'Preview',
  );
}

class SignUpResult {
  const SignUpResult({required this.needsEmailConfirmation});
  final bool needsEmailConfirmation;
}

enum SocialProvider { google, apple }
