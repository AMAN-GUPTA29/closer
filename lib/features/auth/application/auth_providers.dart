import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.isSupabaseConfigured) return const UnconfiguredAuthRepository();
  return SupabaseAuthRepository(sb.Supabase.instance.client.auth, config);
});

/// Whether the debug-only preview mode may be offered: only in debug builds
/// and only when no backend is configured.
final previewModeAvailableProvider = Provider<bool>(
  (ref) => kDebugMode && !ref.watch(authRepositoryProvider).isConfigured,
);

final authControllerProvider = NotifierProvider<AuthController, AuthStatus>(
  AuthController.new,
);

class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.events.listen(_onEvent);
    ref.onDispose(sub.cancel);
    final user = repo.currentUser;
    return user == null ? const SignedOut() : SignedIn(user);
  }

  void _onEvent(AuthEvent event) {
    final user = event.user;
    if (user == null) {
      state = const SignedOut();
    } else if (event.isPasswordRecovery) {
      state = PasswordRecovery(user);
    } else if (state is PasswordRecovery) {
      // Stay in recovery until the new password is saved.
      state = PasswordRecovery(user);
    } else {
      state = SignedIn(user);
    }
  }

  void enterPreview() {
    if (ref.read(previewModeAvailableProvider)) {
      state = const PreviewSession();
    }
  }

  Future<void> refresh() async {
    final user = await ref.read(authRepositoryProvider).refreshUser();
    if (user != null && state is SignedIn) state = SignedIn(user);
  }

  /// Called after the new password was saved during recovery.
  void completePasswordRecovery() {
    final current = state;
    if (current is PasswordRecovery) state = SignedIn(current.user);
  }

  Future<void> signOut() async {
    if (state is! PreviewSession) {
      await ref.read(authRepositoryProvider).signOut();
    }
    state = const SignedOut();
  }
}
