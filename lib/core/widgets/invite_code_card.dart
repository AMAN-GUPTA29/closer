import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/closer_theme.dart';

/// Shows a group invitation code in spaced capitals with a copy action.
class InviteCodeCard extends StatelessWidget {
  const InviteCodeCard({
    super.key,
    required this.code,
    this.caption,
    this.onCopied,
    this.detail,
  });

  final String code;

  /// e.g. "Share this code or link with your partner."
  final String? caption;

  /// Small line under the code, e.g. "Expires in 6 days · any number of people".
  final String? detail;

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caption != null) ...[
          Text(caption!, style: context.text.bodyMedium),
          const SizedBox(height: CloserSpacing.md),
        ],
        Tooltip(
          message: 'Copy invite code',
          child: Material(
            color: c.surfaceMuted,
            borderRadius: CloserRadii.lgAll,
            child: InkWell(
              borderRadius: CloserRadii.lgAll,
              onTap: () => _copy(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CloserSpacing.md,
                  22,
                  CloserSpacing.md,
                  18,
                ),
                child: Column(
                  children: [
                    Semantics(
                      label: 'Invite code ${code.split('').join(' ')}',
                      excludeSemantics: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          spaced(code),
                          style: context.text.headlineMedium?.copyWith(
                            fontFamily: context.text.bodyLarge?.fontFamily,
                            fontVariations: const [],
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        detail!,
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
