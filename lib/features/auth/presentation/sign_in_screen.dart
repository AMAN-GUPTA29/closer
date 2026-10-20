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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text, password: _password.text);
      // The auth state change redirects to Home.
    } on AuthFailure catch (f) {
      if (!mounted) return;
      if (f.code == 'email_not_confirmed') {
        context.go(
          Uri(
            path: Routes.verifyEmail,
            queryParameters: {'email': _email.text.trim()},
          ).toString(),
        );
      } else {
        setState(() => _error = f.message);
      }
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(authRepositoryProvider).isConfigured;
    return AuthScaffold(
      children: [
        const AuthHeader(
          title: 'Welcome back',
          subtitle: 'Sign in to see your people and moments.',
        ),
        const BackendNotice(),
        SocialSignInButtons(onError: (f) => setState(() => _error = f.message)),
        const OrDivider(),
        Form(
          key: _form,
          child: Column(
            children: [
              CloserTextField(
                controller: _email,
                hint: 'Email',
                icon: CloserIcons.email,
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                enabled: configured,
              ),
              const SizedBox(height: CloserSpacing.sm),
              CloserTextField(
                controller: _password,
                hint: 'Password',
                icon: CloserIcons.lock,
                obscure: true,
                validator: Validators.existingPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                enabled: configured,
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push(
              Uri(
                path: Routes.forgotPassword,
                queryParameters: _email.text.trim().isEmpty
                    ? null
                    : {'email': _email.text.trim()},
              ).toString(),
            ),
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: CloserSpacing.xs),
        FormErrorText(_error),
        CloserButton(
          label: 'Sign In',
          isLoading: _busy,
          onPressed: configured ? _submit : null,
        ),
        const SizedBox(height: CloserSpacing.sm),
        AuthSwitchPrompt(
          prompt: 'New to Keeploom?',
          action: 'Create an account',
          onTap: () => context.go(Routes.signUp),
        ),
        const LegalFooter(),
      ],
    );
  }
}
