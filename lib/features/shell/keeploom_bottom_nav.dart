import 'package:flutter/material.dart';

import '../../core/theme/closer_icons.dart';
import '../../core/theme/closer_theme.dart';

/// One tab in the dock.
class DockItem {
  const DockItem({
    required this.icon,
    required this.label,
    this.tooltip,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final String? tooltip;

  /// Shows a small unread dot (Alerts).
  final bool badge;
}

/// Keeploom's floating navigation dock: four tabs on a rounded surface with a
/// raised circular "share a memory" button in the middle. The Add button is
/// an action, not a tab, so it never shows a selected state.
class KeeploomBottomNav extends StatelessWidget {
  const KeeploomBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
  }) : assert(items.length == 4);

  /// Left two and right two tabs.
  final List<DockItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  static const double dockHeight = 64;
  static const double _addSize = 56;
  static const double _raise = 16;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget slot(int i) => Expanded(
      child: _DockButton(
        item: items[i],
        selected: i == selectedIndex,
        onTap: () => onSelect(i),
      ),
    );
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: CloserSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CloserSpacing.md,
          _raise,
          CloserSpacing.md,
          CloserSpacing.xxs,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: dockHeight,
              decoration: BoxDecoration(
                color: dark ? c.surfaceMuted : c.surface,
                borderRadius: CloserRadii.xlAll,
                border: Border.all(color: c.line),
                boxShadow: dark ? CloserElevation.none : CloserElevation.medium,
              ),
              child: Row(
                children: [
                  slot(0),
                  slot(1),
                  const SizedBox(width: _addSize + CloserSpacing.xl),
                  slot(2),
                  slot(3),
                ],
              ),
            ),
            Positioned(
              top: -_raise,
              child: _AddButton(onTap: onAdd, size: _addSize),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DockItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    // Secondary (not tertiary) text keeps 12 px labels at >= 4.5:1.
    final color = selected ? c.accentStrong : c.textSecondary;
    final duration = CloserMotion.of(context, CloserMotion.fast);
    return Semantics(
      button: true,
      selected: selected,
      label: item.badge
          ? '${item.tooltip ?? item.label}, unread'
          : item.tooltip ?? item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: CloserRadii.lgAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: duration,
              width: 44,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? c.accentSoft : Colors.transparent,
                borderRadius: CloserRadii.pillAll,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(item.icon, size: 22, color: color),
                  if (item.badge)
                    Positioned(
                      top: 2,
                      right: 9,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? c.surfaceMuted
                                : c.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              // Never fade (a faded end lowers contrast); shrink instead.
              textScaler: MediaQuery.textScalerOf(context).clamp(
                maxScaleFactor: 1.3,
              ),
              style: context.text.labelMedium?.copyWith(
                color: color,
                // Heavier strokes keep thin 12 px glyphs crisp and legible.
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, required this.size});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return Tooltip(
      message: 'Share a memory',
      child: Semantics(
        button: true,
        label: 'Share a memory',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: c.accentGradient,
            // Neutral, restrained shadow: a coloured glow washed out the
            // neighbouring tab labels.
            boxShadow: CloserElevation.low,
            border: Border.all(color: c.background, width: 3),
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox.square(
                dimension: size,
                child: Icon(CloserIcons.plus, color: c.onAccent, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
