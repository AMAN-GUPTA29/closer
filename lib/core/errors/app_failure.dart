/// Structured, user-presentable failures. Messages must never contain
/// tokens, passwords, captions or other private data.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// Human-friendly text safe to show in the UI.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message =
        'You appear to be offline. Check your connection and try again.',
  ]);
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {this.code});

  final String? code;
}

class NotConfiguredFailure extends AppFailure {
  const NotConfiguredFailure([
    super.message = 'This feature is not configured in this build yet. See docs/environment-setup.md.',
  ]);
}

class PermissionFailure extends AppFailure {
  const PermissionFailure([super.message = 'You do not have access to this.']);
}

class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure([
    super.message = 'Something went wrong. Please try again.',
  ]);
}

/// Failure raised by a trusted backend function (`closer:<key>` messages).
class BackendFailure extends AppFailure {
  const BackendFailure(super.message, {required this.key});

  /// The machine-readable reason, e.g. `group_full`.
  final String key;
}
