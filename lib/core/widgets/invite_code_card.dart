import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/closer_icons.dart';
import '../theme/closer_theme.dart';

/// Shows a group invitation code in spaced capitals with a copy action.
class InviteCodeCard extends StatelessWidget {
  const InviteCodeCard({
    super.key,
    required this.code,
    this.caption,
    this.onCopied,
  });

  final String code;

  /// e.g. "Share this code or link with your partner."
  final String? caption;

  /// Called after the code has been copied to the clipboard.
  final VoidCallback? onCopied;

  /// "CLOSER783" → "C L O S E R 7 8 3" for display only.
  static String spaced(String code) => code.toUpperCase().split('').join(' ');

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Invite code copied')));
    onCopied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return Column(
      children: [
        if (caption != null) ...[
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: CloserSpacing.md),
        ],
        Container(
          padding: const EdgeInsets.fromLTRB(
            CloserSpacing.xl,
            CloserSpacing.xs,
            CloserSpacing.xs,
            CloserSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: CloserRadii.lgAll,
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Invite code ${code.split('').join(' ')}',
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      spaced(code),
                      style: context.text.headlineSmall?.copyWith(
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy invite code',
                icon: Icon(CloserIcons.copy, color: c.textPrimary),
                onPressed: () => _copy(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
