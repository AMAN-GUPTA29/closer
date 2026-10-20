import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../groups/application/group_providers.dart';
import 'journal_list.dart';

/// Journal settings: what you're told about and where moments show up.
Future<void> _showSettings(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  builder: (sheet) {
    void go(String route) {
      Navigator.of(sheet).pop();
      GoRouter.of(context).push(route);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CloserSpacing.gutter,
          0,
          CloserSpacing.gutter,
          CloserSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Journal settings', style: sheet.text.headlineSmall),
            const SizedBox(height: CloserSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(CloserIcons.notifications),
              title: const Text('Notifications and reminders'),
              trailing: const Icon(CloserIcons.chevronRight),
              onTap: () => go(Routes.notificationPreferences),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(CloserIcons.widgets),
              title: const Text('Home screen widgets'),
              trailing: const Icon(CloserIcons.chevronRight),
              onTap: () => go(Routes.widgetSetup),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(CloserIcons.appearance),
              title: const Text('Appearance'),
              trailing: const Icon(CloserIcons.chevronRight),
              onTap: () {
                Navigator.of(sheet).pop();
                GoRouter.of(context).go(Routes.profile);
              },
            ),
          ],
        ),
      ),
    );
  },
);

/// Journal tab: memories and moments from all of the user's groups, with
/// a row of chips to look at one group at a time.
class AllJournalScreen extends ConsumerStatefulWidget {
  const AllJournalScreen({super.key});

  @override
  ConsumerState<AllJournalScreen> createState() => _AllJournalScreenState();
}

class _AllJournalScreenState extends ConsumerState<AllJournalScreen> {
  String? _groupId;

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(myGroupsProvider).value ?? const [];
    final hasGroups = groups.isNotEmpty;
    if (_groupId != null && groups.every((g) => g.id != _groupId)) {
      _groupId = null;
    }
    Widget chip(String label, String? id) => ChoiceChip(
      label: Text(label),
      selected: _groupId == id,
      showCheckmark: false,
      onSelected: (_) => setState(() => _groupId = id),
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: CloserSpacing.gutter,
        toolbarHeight: 64,
        title: Semantics(
          header: true,
          child: Text('Journal', style: context.text.headlineLarge),
        ),
        actions: [
          IconButton(
            tooltip: 'Journal settings',
            icon: const Icon(CloserIcons.settings),
            onPressed: () => _showSettings(context),
          ),
          const SizedBox(width: CloserSpacing.xxs),
        ],
      ),
      body: JournalList(
        key: ValueKey(_groupId),
        groupId: _groupId,
        header: groups.length < 2
            ? null
            : (context) => [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    CloserSpacing.gutter,
                    0,
                    CloserSpacing.gutter,
                    CloserSpacing.xxs,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: CloserSpacing.xs,
                      runSpacing: CloserSpacing.xs,
                      children: [
                        chip('All', null),
                        for (final g in groups) chip(g.name, g.id),
                      ],
                    ),
                  ),
                ),
              ],
        emptyState: _groupId != null
            ? EmptyState(
                icon: CloserIcons.journal,
                title: 'Nothing here yet',
                message: 'This group has no photos or moments yet.',
                action: CloserButton.secondary(
                  label: 'Show all groups',
                  onPressed: () => setState(() => _groupId = null),
                ),
              )
            : EmptyState(
                icon: CloserIcons.journal,
                title: 'No memories yet',
                message: hasGroups
                    ? 'Photos and special moments from all your groups will appear '
                          'here, newest first.'
                    : 'Create or join a group to start your journal.',
                action: hasGroups
                    ? null
                    : CloserButton(
                        label: 'Create a group',
                        onPressed: () => context.push(Routes.createGroup),
                      ),
              ),
      ),
    );
  }
}
