import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../journal/application/content_providers.dart';
import 'username_field.dart';

/// Shown once to anyone without a username (Google sign-in, older accounts,
/// or a name that was taken while their email was being confirmed).
class ChooseUsernameScreen extends ConsumerStatefulWidget {
  const ChooseUsernameScreen({super.key});

  @override
  ConsumerState<ChooseUsernameScreen> createState() =>
      _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends ConsumerState<ChooseUsernameScreen> {
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(text: _suggestion());
  bool _busy = false;
  String? _error;

  String _suggestion() {
    final name = ref.read(myProfileProvider).value?.displayName ?? '';
    final s = Validators.normalizeUsername(name.replaceAll(RegExp(r'\s+'), '.'))
        .replaceAll(RegExp(r'[^a-z0-9._]'), '');
    return Validators.username(s) == null ? s : '';
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileActionsProvider).setUsername(_username.text);
      // The router moves on once the profile has a username.
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      children: [
        const AuthHeader(
          title: 'Pick a username',
          subtitle:
              'It’s how people in your groups recognise you. '
              'You can change it later in your profile.',
        ),
        Form(
          key: _form,
          child: UsernameField(
            controller: _username,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(height: CloserSpacing.lg),
        FormErrorText(_error),
        CloserButton(label: 'Continue', isLoading: _busy, onPressed: _save),
        const SizedBox(height: CloserSpacing.sm),
        Center(
          child: TextButton(
            onPressed: _busy
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ),
      ],
    );
  }
}
