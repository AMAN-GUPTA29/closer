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

/// Keeploom's bottom bar: four tabs on the page ground behind a hairline,
/// with a flat round "share a memory" button in the middle. The Add button
/// is an action, not a tab, so it never shows a selected state.
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
  static const double _addSize = 52;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    Widget slot(int i) => Expanded(
      child: _DockButton(
        item: items[i],
        selected: i == selectedIndex,
        onTap: () => onSelect(i),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: CloserSpacing.xs),
        child: SizedBox(
          height: dockHeight,
          child: Row(
            children: [
              const SizedBox(width: CloserSpacing.xs),
              slot(0),
              slot(1),
              _AddButton(onTap: onAdd, size: _addSize),
              slot(2),
              slot(3),
              const SizedBox(width: CloserSpacing.xs),
            ],
          ),
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
    final color = selected ? c.textPrimary : c.textSecondary;
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
            // The active tab: a short coral line above its icon.
            AnimatedContainer(
              duration: duration,
              width: 20,
              height: 2,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: selected ? c.accent : Colors.transparent,
                borderRadius: CloserRadii.pillAll,
              ),
            ),
            SizedBox(
              width: 44,
              height: 26,
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
                          border: Border.all(color: c.background, width: 1.5),
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
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.3),
              style: context.text.labelMedium?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.primary),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox.square(
                dimension: size,
                child: Icon(CloserIcons.plus, color: c.onPrimary, size: 26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
