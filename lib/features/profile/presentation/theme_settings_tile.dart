import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/appearance.dart';
import '../../../core/theme/closer_theme.dart';

/// Light, Dark or System as one tonal segmented control (Keeploom concept).
/// Applies immediately and is remembered on this device.
class AppearanceSwitch extends ConsumerWidget {
  const AppearanceSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appearanceProvider);
    final c = context.closerColors;
    Widget segment(ThemeMode value, String label) {
      final selected = value == mode;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: '$label appearance',
          excludeSemantics: true,
          child: Material(
            color: selected ? c.background : Colors.transparent,
            borderRadius: CloserRadii.mdAll,
            child: InkWell(
              borderRadius: CloserRadii.mdAll,
              onTap: () => ref.read(appearanceProvider.notifier).set(value),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    label,
                    style: context.text.bodyMedium?.copyWith(
                      color: selected ? c.textPrimary : c.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: CloserRadii.lgAll,
      ),
      child: Row(
        children: [
          segment(ThemeMode.light, 'Light'),
          const SizedBox(width: 4),
          segment(ThemeMode.dark, 'Dark'),
          const SizedBox(width: 4),
          segment(ThemeMode.system, 'System'),
        ],
      ),
    );
  }
}

/// "Appearance" label above the [AppearanceSwitch].
class ThemeSettingsTile extends StatelessWidget {
  const ThemeSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, CloserSpacing.xs),
          child: Semantics(
            header: true,
            child: Text(
              'Appearance',
              style: context.text.labelMedium?.copyWith(
                color: context.closerColors.textSecondary,
              ),
            ),
          ),
        ),
        const AppearanceSwitch(),
      ],
    );
  }
}
