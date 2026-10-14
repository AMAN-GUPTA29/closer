import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/connectivity.dart';
import '../../core/routing/routes.dart';
import '../groups/application/group_providers.dart';

import '../../core/theme/closer_icons.dart';
import '../../core/theme/closer_theme.dart';
import '../../core/widgets/widgets.dart';

/// Bottom-navigation shell: Home, Journal, Add, Notifications, Profile.
/// "Add" is an action (share a memory), not a tab.
class AppShell extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).value ?? true;
    return Scaffold(
      body: Column(
        children: [
          AnimatedSize(
            duration: CloserMotion.of(context, CloserMotion.medium),
            child: online
                ? const SizedBox(width: double.infinity)
                : SafeArea(bottom: false, child: const OfflineBanner()),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: !online,
              child: shell,
            ),
          ),
        ],
      ),
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

/// Entry point for sharing a memory: choose which group it goes to.
Future<void> showAddMemorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => const _AddMemorySheet(),
  );
}

class _AddMemorySheet extends ConsumerWidget {
  const _AddMemorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(myGroupsProvider);
    void go(String route) {
      Navigator.of(context).pop();
      GoRouter.of(context).push(route);
    }

    return SafeArea(
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
            switch (groups) {
              AsyncData(:final value) when value.isEmpty => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Photos are shared into a group. Create or join one '
                    'first.',
                    style: context.text.bodyMedium,
                  ),
                  const SizedBox(height: CloserSpacing.lg),
                  CloserButton(
                    label: 'Create a group',
                    onPressed: () => go(Routes.createGroup),
                  ),
                ],
              ),
              AsyncData(:final value) => ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text('Choose a group', style: context.text.bodyMedium),
                    const SizedBox(height: CloserSpacing.sm),
                    for (final g in value)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          g.type.icon,
                          color: g.type.tint(context.closerColors),
                        ),
                        title: Text(g.name, style: context.text.titleSmall),
                        trailing: const Icon(CloserIcons.chevronRight),
                        onTap: () => go(Routes.addMemory(g.id)),
                      ),
                  ],
                ),
              ),
              AsyncError() => Text(
                'Your groups couldn’t be loaded. Try again from Home.',
                style: context.text.bodyMedium,
              ),
              _ => const Padding(
                padding: EdgeInsets.all(CloserSpacing.xl),
                child: LoadingState(),
              ),
            },
          ],
        ),
      ),
    );
  }
}
