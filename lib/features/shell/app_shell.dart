import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/connectivity.dart';
import '../../core/routing/routes.dart';
import '../groups/application/group_providers.dart';
import '../journal/application/content_providers.dart';
import 'keeploom_bottom_nav.dart';

import '../../core/theme/closer_icons.dart';
import '../../core/theme/closer_theme.dart';
import '../../core/widgets/widgets.dart';

/// Shell with Keeploom's floating dock: Home, Journal, [Add], Alerts,
/// Profile. "Add" is an action (share a memory), not a tab.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _onSelect(int branch) =>
      shell.goBranch(branch, initialLocation: branch == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).value ?? true;
    final unread = ref.watch(unreadCountProvider) > 0;
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
      bottomNavigationBar: KeeploomBottomNav(
        selectedIndex: shell.currentIndex,
        onSelect: _onSelect,
        onAdd: () => showAddMemorySheet(context),
        items: [
          const DockItem(icon: CloserIcons.home, label: 'Home'),
          const DockItem(icon: CloserIcons.journal, label: 'Journal'),
          DockItem(
            icon: CloserIcons.notifications,
            // Short so it never wraps at large system font sizes.
            label: 'Alerts',
            tooltip: 'Notifications',
            badge: unread,
          ),
          const DockItem(icon: CloserIcons.profile, label: 'Profile'),
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
