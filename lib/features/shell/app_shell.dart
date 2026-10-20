import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/connectivity.dart';
import '../../core/routing/routes.dart';
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

/// Entry point for sharing a memory: the share screen, where the group is
/// chosen along with the photos.
Future<void> showAddMemorySheet(BuildContext context) =>
    GoRouter.of(context).push<void>(Routes.share);
