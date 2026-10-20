import 'package:flutter/material.dart';

import '../theme/closer_theme.dart';

/// Rounded card grouping rows (Profile, Settings, preferences, members),
/// as on the Keeploom showcase: soft shadow in light, lifted tone in dark.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.children,
    this.dividerIndent = 56,
  });

  final List<Widget> children;

  /// Left inset of the dividers between rows (0 for full width).
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    // A flat tonal panel one step off the page (no shadow, no outline).
    return DecoratedBox(
      decoration: const BoxDecoration(borderRadius: CloserRadii.lgAll),
      child: Material(
        color: c.surfaceMuted,
        shape: const RoundedRectangleBorder(borderRadius: CloserRadii.lgAll),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(indent: dividerIndent),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
