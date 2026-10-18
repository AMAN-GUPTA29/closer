import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../../journal/presentation/journal_list.dart';
import '../../journal/presentation/milestone_views.dart';
import '../../photos/presentation/photo_widgets.dart';
import '../application/group_providers.dart';
import '../domain/group_models.dart';
import 'group_widgets.dart';

class GroupHomeScreen extends ConsumerWidget {
  const GroupHomeScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupProvider(groupId));
    return Scaffold(
      body: switch (group) {
        AsyncData(:final value) => _GroupHome(group: value),
        _ => SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(CloserIcons.back),
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.home),
                ),
              ),
              Expanded(
                child: AsyncBody(
                  value: group,
                  builder: (_) => const SizedBox.shrink(),
                  onRetry: () => ref.invalidate(groupProvider(groupId)),
                ),
              ),
            ],
          ),
        ),
      },
    );
  }
}

class _GroupHome extends ConsumerWidget {
  const _GroupHome({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMembersProvider(group.id));
    final names = members.value?.map((m) => m.displayName).toList() ?? [];
    final c = context.closerColors;

    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 340,
            backgroundColor: c.background,
            foregroundColor: Colors.white,
            leading: _RoundIconButton(
              icon: CloserIcons.back,
              tooltip: 'Back',
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(Routes.home),
            ),
            actions: [
              _RoundIconButton(
                icon: CloserIcons.settings,
                tooltip: 'Group settings',
                onPressed: () => context.push(Routes.groupSettings(group.id)),
              ),
              const SizedBox(width: CloserSpacing.xs),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _Hero(group: group, memberNames: names),
            ),
          ),
          SliverToBoxAdapter(child: _ActionRow(group: group)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                labelStyle: context.text.titleSmall,
                labelColor: c.accentStrong,
                unselectedLabelColor: c.textTertiary,
                indicatorColor: c.accentStrong,
                dividerColor: c.line,
                tabs: const [
                  Tab(text: 'Journal'),
                  Tab(text: 'Milestones'),
                  Tab(text: 'Details'),
                ],
              ),
              c.background,
            ),
          ),
        ],
        body: TabBarView(
          children: [
            Stack(
              children: [
                JournalList(
                  groupId: group.id,
                  header: (context) => [
                    ...pinnedSlivers(context, ref, group),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        CloserSpacing.gutter,
                        CloserSpacing.sm,
                        CloserSpacing.gutter,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                photoHistoryLabel(group),
                                style: context.text.bodySmall,
                              ),
                            ),
                            if (group.photoCount > 0)
                              TextButton(
                                onPressed: () =>
                                    context.push(Routes.allPhotos(group.id)),
                                child: const Text('All photos'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  emptyState: EmptyState(
                    icon: CloserIcons.gallery,
                    title: 'No memories yet',
                    message: 'Share the first photo with ${group.name}.',
                    action: CloserButton(
                      label: 'Share a photo',
                      icon: const Icon(CloserIcons.plus),
                      onPressed: () => context.push(Routes.addMemory(group.id)),
                    ),
                  ),
                ),
                // Journal-only shortcut, so it never covers other tabs' actions.
                Positioned(
                  right: CloserSpacing.gutter,
                  bottom:
                      MediaQuery.paddingOf(context).bottom + CloserSpacing.lg,
                  child: FloatingActionButton(
                    heroTag: 'share-${group.id}',
                    tooltip: 'Share a memory',
                    backgroundColor: c.accentStrong,
                    foregroundColor: Colors.white,
                    onPressed: () => context.push(Routes.addMemory(group.id)),
                    child: const Icon(CloserIcons.plus),
                  ),
                ),
              ],
            ),
            MilestonesTab(group: group),
            _DetailsTab(group: group),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.group, required this.memberNames});

  final Group group;
  final List<String> memberNames;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final days = group.hasCounter
        ? daysTogether(group.relationshipStartDate!, DateTime.now())
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        GroupCover(group: group),
        DecoratedBox(decoration: BoxDecoration(gradient: c.heroScrim)),
        Positioned(
          left: CloserSpacing.gutter,
          right: CloserSpacing.gutter,
          bottom: CloserSpacing.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              Text(
                '${group.type.label} · ${group.memberCount} '
                '${group.memberCount == 1 ? 'member' : 'members'}',
                style: context.text.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              if (days != null) ...[
                const SizedBox(height: CloserSpacing.sm),
                Semantics(
                  label: daysTogetherLabel(days),
                  excludeSemantics: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(CloserIcons.heart, color: c.accent, size: 30),
                      const SizedBox(width: CloserSpacing.xs),
                      Text(
                        '$days',
                        style: context.text.displayMedium?.copyWith(
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: CloserSpacing.xs),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            days == 1 ? 'day together' : 'days together',
                            style: context.text.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (memberNames.isNotEmpty) ...[
                const SizedBox(height: CloserSpacing.md),
                AvatarStack(names: memberNames, size: 34),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CloserSpacing.gutter,
        vertical: CloserSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Action(
            icon: CloserIcons.camera,
            label: 'Camera',
            onTap: () =>
                context.push(Routes.addMemory(group.id, source: 'camera')),
          ),
          _Action(
            icon: CloserIcons.plus,
            label: 'Add',
            onTap: () => context.push(Routes.addMemory(group.id)),
          ),
          _Action(
            icon: CloserIcons.invite,
            label: 'Invite',
            hint: group.isFull ? 'This couple group is complete' : null,
            onTap: group.isFull
                ? null
                : () => context.push(Routes.invite(group.id)),
          ),
          _Action(
            icon: CloserIcons.members,
            label: 'Members',
            onTap: () => context.push(Routes.members(group.id)),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final enabled = onTap != null;
    final color = enabled ? c.textPrimary : c.textTertiary;
    return Flexible(
      child: Tooltip(
        message: hint ?? label,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: hint == null ? label : '$label. $hint',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: CloserRadii.mdAll,
            onTap: onTap,
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 72, minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CloserSpacing.xxs,
                    vertical: CloserSpacing.xs,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: color, size: 24),
                      const SizedBox(height: CloserSpacing.xxs),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: context.text.labelMedium?.copyWith(color: color),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Type', group.type.label),
      (
        'Members',
        '${group.memberCount}${group.type.maxMembers != null ? ' of ${group.type.maxMembers}' : ''}',
      ),
      ('Your role', group.isOwner ? 'Owner' : 'Member'),
      ('Created', formatMediumDate(group.createdAt.toLocal())),
      if (group.relationshipStartDate != null)
        ('Together since', formatMediumDate(group.relationshipStartDate!)),
      ('Photo history', photoHistoryLabel(group)),
    ];
    return ListView(
      padding: const EdgeInsets.all(CloserSpacing.gutter),
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CloserSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(label, style: context.text.bodyMedium),
                ),
                Expanded(child: Text(value, style: context.text.bodyLarge)),
              ],
            ),
          ),
        const SizedBox(height: CloserSpacing.lg),
        CloserButton.secondary(
          label: 'Group settings',
          icon: const Icon(CloserIcons.settings),
          onPressed: () => context.push(Routes.groupSettings(group.id)),
        ),
        const SizedBox(height: CloserSpacing.lg),
        if (!group.isPremium)
          UpgradeCard(
            groupName: group.name,
            photoLimit: Group.basicPhotoLimit,
            onUpgrade: () => context.push(Routes.upgrade(group.id)),
          ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.black.withValues(alpha: 0.25),
        shape: const CircleBorder(),
        child: IconButton(
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          tooltip: tooltip,
          icon: Icon(icon, color: Colors.white, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, this.background);

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: background, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar != tabBar || old.background != background;
}
