import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_providers.dart';
import 'auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(authRepositoryProvider).isConfigured;
    if (_sent) {
      return AuthScaffold(
        children: [
          const SizedBox(height: CloserSpacing.xxl),
          EmptyState(
            icon: CloserIcons.mailSent,
            title: 'Check your inbox',
            // Do not confirm whether the account exists.
            message:
                'If an account exists for ${_email.text.trim()}, we sent a '
                'link to reset your password. Open it on this phone.',
            action: CloserButton(
              label: 'Back to sign in',
              onPressed: () => context.go(Routes.signIn),
            ),
          ),
        ],
      );
    }
    return AuthScaffold(
      children: [
        const AuthHeader(
          title: 'Reset your password',
          subtitle: 'Enter your email and we will send you a reset link.',
        ),
        const BackendNotice(),
        Form(
          key: _form,
          child: CloserTextField(
            controller: _email,
            hint: 'Email',
            icon: CloserIcons.email,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _submit(),
            enabled: configured,
          ),
        ),
        const SizedBox(height: CloserSpacing.lg),
        FormErrorText(_error),
        CloserButton(
          label: 'Send reset link',
          isLoading: _busy,
          onPressed: configured ? _submit : null,
        ),
        const SizedBox(height: CloserSpacing.sm),
        Center(
          child: Text(
            'The link expires after a short time for your security.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ),
      ],
    );
  }
}
