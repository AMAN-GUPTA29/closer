import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/appearance.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';

/// Profile → Appearance: Light, Dark or System. Applies immediately and is
/// remembered on this device.
class ThemeSettingsTile extends ConsumerWidget {
  const ThemeSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appearanceProvider);
    final c = context.closerColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CloserSpacing.md,
        CloserSpacing.sm,
        CloserSpacing.md,
        CloserSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(CloserIcons.appearance, color: c.textPrimary, size: 22),
              const SizedBox(width: CloserSpacing.md),
              Text('Appearance', style: context.text.bodyLarge),
            ],
          ),
          const SizedBox(height: CloserSpacing.sm),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(CloserIcons.sun, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(CloserIcons.moon, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(CloserIcons.phone, size: 18),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(appearanceProvider.notifier).set(s.first),
          ),
        ],
      ),
    );
  }
}
