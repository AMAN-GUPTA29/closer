import 'package:flutter/material.dart';

import '../theme/closer_theme.dart';

/// One bullet point: a small coral dot and a line of body text.
class DotPoint extends StatelessWidget {
  const DotPoint(this.text, {super.key, this.style});

  final String text;

  /// Overrides the body style (e.g. a smaller size inside a panel).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final textStyle =
        style ?? context.text.bodyMedium?.copyWith(color: c.textPrimary);
    return Padding(
      padding: const EdgeInsets.only(bottom: CloserSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top:
                  ((textStyle?.fontSize ?? 14) * (textStyle?.height ?? 1.4)) /
                      2 -
                  2.5,
              left: 2,
              right: 10,
            ),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: textStyle)),
        ],
      ),
    );
  }
}
