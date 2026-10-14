import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_providers.dart';
import 'auth_widgets.dart';

/// Shown after the user opens a password-reset link.
class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password updated')));
      ref.read(authControllerProvider.notifier).completePasswordRecovery();
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: false,
      children: [
        const AuthHeader(
          title: 'Choose a new password',
          subtitle: 'You will use it the next time you sign in.',
        ),
        Form(
          key: _form,
          child: Column(
            children: [
              CloserTextField(
                controller: _password,
                hint: 'New password',
                icon: CloserIcons.lock,
                obscure: true,
                validator: Validators.newPassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: CloserSpacing.sm),
              CloserTextField(
                controller: _confirm,
                hint: 'Repeat new password',
                icon: CloserIcons.lock,
                obscure: true,
                validator: Validators.confirmPassword(() => _password.text),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: CloserSpacing.lg),
        FormErrorText(_error),
        CloserButton(
          label: 'Save password',
          isLoading: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: CloserSpacing.sm),
        Center(
          child: TextButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: Text('Cancel and sign out', style: context.text.titleSmall),
          ),
        ),
      ],
    );
  }
}
