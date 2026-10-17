/// Form validators. Each returns `null` when valid, otherwise a message.
abstract final class Validators {
  static final _email = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$");

  static const minPasswordLength = 8;
  static const maxDisplayNameLength = 40;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  /// Requires 8+ characters with at least one letter and one number.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Choose a password.';
    if (v.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    if (!RegExp('[A-Za-z]').hasMatch(v) || !RegExp('[0-9]').hasMatch(v)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  static String? existingPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() other) {
    return (value) {
      if ((value ?? '').isEmpty) return 'Repeat your password.';
      if (value != other()) return 'Passwords do not match.';
      return null;
    };
  }

  static final _usernameShape = RegExp(r'^[a-z0-9][a-z0-9._]{1,18}[a-z0-9_]$');

  /// "@Alex.Kim " -> "alex.kim" (same rule as public.normalize_username).
  static String normalizeUsername(String value) {
    var v = value.trim();
    if (v.startsWith('@')) v = v.substring(1);
    return v.trim().toLowerCase();
  }

  /// 3–20 of a–z, 0–9, "." and "_"; starts with a letter or digit, doesn't
  /// end with "." and has no "..". Uniqueness is checked by the server.
  static String? username(String? value) {
    final v = normalizeUsername(value ?? '');
    if (v.isEmpty) return 'Choose a username.';
    if (v.length < 3) return 'Use at least 3 characters.';
    if (v.length > 20) return 'Keep it to 20 characters or fewer.';
    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(v)) {
      return 'Use letters, numbers, dots and underscores only.';
    }
    if (!_usernameShape.hasMatch(v) || v.contains('..')) {
      return 'Start with a letter or number; no dot at the end or two in a row.';
    }
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Tell us what to call you.';
    if (v.length > maxDisplayNameLength) {
      return 'Keep it under $maxDisplayNameLength characters.';
    }
    return null;
  }
}
