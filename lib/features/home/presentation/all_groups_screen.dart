import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/presentation/group_widgets.dart' show AsyncBody;
import 'group_list_tile.dart';

/// Home → Your groups → See all: every group, newest activity first.
class AllGroupsScreen extends ConsumerWidget {
  const AllGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(myGroupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your groups'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        actions: [
          IconButton(
            tooltip: 'Create a group',
            icon: const Icon(CloserIcons.plus),
            onPressed: () => context.push(Routes.createGroup),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myGroupsProvider.future),
        child: AsyncBody(
          value: groups,
          onRetry: () => ref.invalidate(myGroupsProvider),
          builder: (list) => ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              CloserSpacing.gutter,
              CloserSpacing.md,
              CloserSpacing.gutter,
              CloserSpacing.xl + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: list.length + 1,
            separatorBuilder: (_, _) =>
                const SizedBox(height: CloserSpacing.sm),
            itemBuilder: (context, i) => i < list.length
                ? GroupListTile(list[i])
                : Padding(
                    padding: const EdgeInsets.only(top: CloserSpacing.sm),
                    child: CloserButton.secondary(
                      label: 'Join a group with a code',
                      icon: const Icon(CloserIcons.invite),
                      onPressed: () => context.push(Routes.joinGroup),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
