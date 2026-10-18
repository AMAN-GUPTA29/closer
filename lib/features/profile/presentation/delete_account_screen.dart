import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_widgets.dart' show FormErrorText;
import '../../journal/application/content_providers.dart';

/// Permanent account deletion with a typed confirmation.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  static const phrase = 'DELETE';

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  bool get _confirmed => _confirm.text.trim() == DeleteAccountScreen.phrase;

  Future<void> _delete() async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Delete your account?',
      message: 'This is permanent and can’t be undone.',
      confirmLabel: 'Delete my account',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileActionsProvider).deleteAccount();
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
      // Signing out sends the router to the Welcome screen.
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    const points = [
      'Your profile, photo and notification settings are deleted.',
      'You leave all your groups. Where you were the owner, ownership passes '
          'to the member who has been there longest.',
      'Groups where you are the only member are deleted, with their photos.',
      'Photos you shared in groups with other people stay there for them, '
          'without your name.',
      'Keeploom Memories purchases stay with their groups.',
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete account'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: _deleting
              ? null
              : () => context.canPop()
                    ? context.pop()
                    : context.go(Routes.profile),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(CloserSpacing.gutter),
          children: [
            Icon(CloserIcons.warning, color: c.danger, size: 40),
            const SizedBox(height: CloserSpacing.sm),
            Text('What happens', style: context.text.headlineSmall),
            const SizedBox(height: CloserSpacing.sm),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: CloserSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: c.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: CloserSpacing.sm),
                    Expanded(child: Text(p, style: context.text.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: CloserSpacing.xl),
            Text(
              'Type ${DeleteAccountScreen.phrase} to confirm',
              style: context.text.titleMedium,
            ),
            const SizedBox(height: CloserSpacing.sm),
            CloserTextField(
              controller: _confirm,
              hint: DeleteAccountScreen.phrase,
              textCapitalization: TextCapitalization.characters,
              enabled: !_deleting,
            ),
            const SizedBox(height: CloserSpacing.lg),
            FormErrorText(_error),
            CloserButton(
              label: 'Delete my account',
              variant: CloserButtonVariant.danger,
              icon: const Icon(CloserIcons.trash),
              isLoading: _deleting,
              onPressed: _confirmed ? _delete : null,
            ),
          ],
        ),
      ),
    );
  }
}
