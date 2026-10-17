import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../profile/presentation/username_field.dart';
import '../application/auth_providers.dart';
import 'auth_widgets.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .signUp(
            email: _email.text,
            password: _password.text,
            displayName: _name.text,
            username: Validators.normalizeUsername(_username.text),
          );
      if (!mounted) return;
      if (result.needsEmailConfirmation) {
        context.go(
          Uri(
            path: Routes.verifyEmail,
            queryParameters: {'email': _email.text.trim()},
          ).toString(),
        );
      }
      // Otherwise the auth state change redirects to Home.
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
          title: 'Welcome to Closer',
          subtitle: 'Your people. Your moments. Always close.',
        ),
        const BackendNotice(),
        SocialSignInButtons(onError: (f) => setState(() => _error = f.message)),
        const OrDivider(),
        Form(
          key: _form,
          child: Column(
            children: [
              CloserTextField(
                controller: _name,
                hint: 'Your name',
                icon: CloserIcons.user,
                validator: Validators.displayName,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                maxLength: Validators.maxDisplayNameLength,
                enabled: configured,
              ),
              const SizedBox(height: CloserSpacing.sm),
              UsernameField(
                controller: _username,
                checkAvailability: false,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: CloserSpacing.sm),
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
                validator: Validators.newPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                enabled: configured,
              ),
            ],
          ),
        ),
        const SizedBox(height: CloserSpacing.xs),
        Text(
          'At least 8 characters with a letter and a number.',
          style: context.text.bodySmall?.copyWith(
            color: context.closerColors.textTertiary,
          ),
        ),
        const SizedBox(height: CloserSpacing.lg),
        FormErrorText(_error),
        CloserButton(
          label: 'Sign Up',
          isLoading: _busy,
          onPressed: configured ? _submit : null,
        ),
        const SizedBox(height: CloserSpacing.sm),
        AuthSwitchPrompt(
          prompt: 'Already have an account?',
          action: 'Sign In',
          onTap: () => context.go(Routes.signIn),
        ),
        const LegalFooter(),
      ],
    );
  }
}
