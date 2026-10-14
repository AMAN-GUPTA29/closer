import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_providers.dart';
import '../domain/auth_models.dart';
import 'auth_widgets.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  /// Email from the sign-up form when the user has no session yet.
  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _cooldown = 60;
  int _secondsLeft = 0;
  Timer? _timer;
  bool _busy = false;
  String? _message;
  String? _error;

  String? get _email {
    final status = ref.read(authControllerProvider);
    if (status is SignedIn) return status.user.email;
    return widget.email;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    final email = _email;
    if (email == null || email.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendVerification(email);
      if (!mounted) return;
      setState(() => _message = 'A new confirmation email is on its way.');
      _startCooldown();
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue() async {
    final status = ref.read(authControllerProvider);
    if (status is SignedIn) {
      try {
        await ref.read(authControllerProvider.notifier).refresh();
      } on AppFailure catch (f) {
        if (mounted) setState(() => _error = f.message);
      }
    } else {
      context.go(Routes.signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;
    final c = context.closerColors;
    return AuthScaffold(
      children: [
        const SizedBox(height: CloserSpacing.xl),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: c.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(CloserIcons.mailSent, color: c.accent, size: 40),
          ),
        ),
        const SizedBox(height: CloserSpacing.xl),
        Text(
          'Confirm your email',
          textAlign: TextAlign.center,
          style: context.text.headlineLarge,
        ),
        const SizedBox(height: CloserSpacing.xs),
        Text(
          email == null
              ? 'We sent you a confirmation link. Open it on this phone to '
                    'finish creating your account.'
              : 'We sent a confirmation link to $email. Open it on this '
                    'phone to finish creating your account.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: CloserSpacing.xxl),
        FormErrorText(_error),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: CloserSpacing.md),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: c.success),
              ),
            ),
          ),
        CloserButton(label: 'I have confirmed', onPressed: _continue),
        const SizedBox(height: CloserSpacing.sm),
        CloserButton.secondary(
          label: _secondsLeft > 0
              ? 'Resend in ${_secondsLeft}s'
              : 'Resend confirmation email',
          isLoading: _busy,
          onPressed: (email == null || _secondsLeft > 0) ? null : _resend,
        ),
        const SizedBox(height: CloserSpacing.sm),
        Center(
          child: TextButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Use a different email'),
          ),
        ),
      ],
    );
  }
}
