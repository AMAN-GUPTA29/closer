import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/closer_icons.dart';
import '../../core/theme/closer_theme.dart';
import '../../core/widgets/widgets.dart';

/// Bottom-navigation shell: Home, Journal, Add, Notifications, Profile.
/// "Add" is an action (share a memory), not a tab.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _addSlot = 2;

  int get _selected => shell.currentIndex >= _addSlot
      ? shell.currentIndex + 1
      : shell.currentIndex;

  void _onSelect(BuildContext context, int slot) {
    if (slot == _addSlot) {
      showAddMemorySheet(context);
      return;
    }
    final branch = slot > _addSlot ? slot - 1 : slot;
    shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (i) => _onSelect(context, i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(CloserIcons.home),
            selectedIcon: Icon(CloserIcons.homeActive),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(CloserIcons.journal),
            selectedIcon: Icon(CloserIcons.journalActive),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(CloserIcons.add),
            selectedIcon: Icon(CloserIcons.addActive),
            label: 'Add',
            tooltip: 'Share a memory',
          ),
          NavigationDestination(
            icon: Icon(CloserIcons.notifications),
            selectedIcon: Icon(CloserIcons.notificationsActive),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(CloserIcons.profile),
            selectedIcon: Icon(CloserIcons.profileActive),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Entry point for sharing a memory. Until a user has a group there is
/// nowhere to share to, so the sheet explains that.
Future<void> showAddMemorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CloserSpacing.gutter,
          0,
          CloserSpacing.gutter,
          CloserSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Share a memory', style: context.text.headlineSmall),
            const SizedBox(height: CloserSpacing.xs),
            Text(
              'Photos are shared into a group. Create or join a group first, '
              'then come back here to share.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: CloserSpacing.xl),
            CloserButton.secondary(
              label: 'Got it',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
