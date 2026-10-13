import 'package:flutter/material.dart';

import '../theme/closer_theme.dart';
import 'closer_button.dart';

/// Shows a confirmation dialog and resolves to `true` only when the user
/// explicitly confirms. Use [destructive] for irreversible actions.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmationDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(
        CloserSpacing.xl,
        0,
        CloserSpacing.xl,
        CloserSpacing.xl,
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CloserButton(
              label: confirmLabel,
              variant: destructive
                  ? CloserButtonVariant.danger
                  : CloserButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: CloserSpacing.xs),
            CloserButton.ghost(
              label: cancelLabel,
              expand: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ],
    );
  }
}
