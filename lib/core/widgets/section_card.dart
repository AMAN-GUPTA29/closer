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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: CloserRadii.xlAll,
        boxShadow: dark ? CloserElevation.none : CloserElevation.low,
      ),
      child: Material(
        color: dark ? c.surfaceMuted : c.surface,
        shape: const RoundedRectangleBorder(borderRadius: CloserRadii.xlAll),
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
