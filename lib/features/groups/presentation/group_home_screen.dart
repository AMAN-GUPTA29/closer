import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/group_type.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../../journal/presentation/journal_list.dart';
import '../../journal/presentation/milestone_views.dart';
import '../application/group_providers.dart';
import '../../journal/application/content_providers.dart';
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
    final images = <String, ImageProvider>{};
    for (final m in members.value?.take(6) ?? const <GroupMember>[]) {
      final path = m.avatarPath;
      if (path == null) continue;
      final image = ref.watch(avatarImageProvider(path)).value;
      if (image != null) images[m.displayName] = image;
    }
    final c = context.closerColors;

    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: c.background,
            foregroundColor: c.textPrimary,
            titleSpacing: 0,
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(CloserIcons.back),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(Routes.home),
            ),
            title: Text(group.name, overflow: TextOverflow.ellipsis),
            actions: [
              _GroupMenu(group: group),
              const SizedBox(width: CloserSpacing.xxs),
            ],
          ),
          SliverToBoxAdapter(
            child: _Header(
              group: group,
              memberNames: names,
              memberImages: images,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.only(right: 22),
                labelStyle: context.text.titleSmall?.copyWith(fontSize: 15),
                labelColor: c.textPrimary,
                unselectedLabelColor: c.textSecondary,
                indicatorColor: c.textPrimary,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: c.line,
                tabs: const [
                  Tab(text: 'Journal'),
                  Tab(text: 'Moments'),
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
                  header: (context) => pinnedSlivers(context, ref, group),
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
                    backgroundColor: c.primary,
                    foregroundColor: c.onPrimary,
                    elevation: 2,
                    shape: const CircleBorder(),
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

/// The group's typeset header: the couple counter in the serif, or the
/// group type and its people for friends and family.
class _Header extends StatelessWidget {
  const _Header({
    required this.group,
    required this.memberNames,
    this.memberImages = const {},
  });

  final Group group;
  final List<String> memberNames;
  final Map<String, ImageProvider> memberImages;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final now = DateTime.now();
    final days = group.hasCounter
        ? daysTogether(group.relationshipStartDate!, now)
        : null;
    final membersLabel =
        '${group.type.label} · ${group.memberCount} '
        '${group.memberCount == 1 ? 'member' : 'members'}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CloserSpacing.gutter,
        CloserSpacing.xxs,
        CloserSpacing.gutter,
        CloserSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (days != null) ...[
            Semantics(
              label: daysTogetherLabel(days),
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$days', style: context.text.displayLarge),
                  const SizedBox(width: CloserSpacing.sm),
                  Flexible(
                    child: Text(
                      days == 1 ? 'day together' : 'days together',
                      style: context.text.headlineSmall?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CloserSpacing.xxs),
            Text(
              'Since ${formatLongDate(group.relationshipStartDate!)}'
              ' · ${(days ~/ 100 + 1) * 100} days on '
              '${formatDayMonth(now.add(Duration(days: (days ~/ 100 + 1) * 100 - days)), now)}',
              style: context.text.bodyMedium?.copyWith(fontSize: 14),
            ),
          ] else
            Row(
              children: [
                if (memberNames.isNotEmpty) ...[
                  AvatarStack(
                    names: memberNames,
                    images: memberImages,
                    size: 30,
                  ),
                  const SizedBox(width: CloserSpacing.sm),
                ],
                Flexible(
                  child: Text(membersLabel, style: context.text.bodyMedium),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _GroupAction { camera, photos, invite, members, settings }

/// Everything the old action row offered, in one overflow menu.
class _GroupMenu extends StatelessWidget {
  const _GroupMenu({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_GroupAction>(
      tooltip: 'Group options',
      icon: const Icon(CloserIcons.more),
      onSelected: (a) => switch (a) {
        _GroupAction.camera => context.push(
          Routes.addMemory(group.id, source: 'camera'),
        ),
        _GroupAction.photos => context.push(Routes.allPhotos(group.id)),
        _GroupAction.invite => context.push(Routes.invite(group.id)),
        _GroupAction.members => context.push(Routes.members(group.id)),
        _GroupAction.settings => context.push(Routes.groupSettings(group.id)),
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _GroupAction.camera,
          child: Text('Take a photo'),
        ),
        PopupMenuItem(
          value: _GroupAction.photos,
          enabled: group.photoCount > 0,
          child: const Text('All photos'),
        ),
        PopupMenuItem(
          value: _GroupAction.invite,
          enabled: !group.isFull,
          child: Text(
            group.isFull ? 'Invite (this couple group is complete)' : 'Invite',
          ),
        ),
        const PopupMenuItem(
          value: _GroupAction.members,
          child: Text('Members'),
        ),
        const PopupMenuItem(
          value: _GroupAction.settings,
          child: Text('Group settings'),
        ),
      ],
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final rows = <(String, String)>[
      ('Type', group.type.label),
      (
        'Members',
        '${group.memberCount}${group.type.maxMembers != null ? ' of ${group.type.maxMembers}' : ''}',
      ),
      ('Your role', group.isOwner ? 'Owner' : 'Member'),
      if (group.relationshipStartDate != null)
        ('Together since', formatMediumDate(group.relationshipStartDate!))
      else
        ('Created', formatMediumDate(group.createdAt.toLocal())),
      (
        'Photos kept',
        group.isPremium
            ? 'Every photo'
            : '${group.photoCount} of ${Group.basicPhotoLimit} (Basic)',
      ),
    ];
    Widget link(IconData icon, String label, String route) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: CloserSpacing.md),
      minTileHeight: 54,
      horizontalTitleGap: 14,
      leading: Icon(icon, color: c.textPrimary, size: 19),
      title: Text(label, style: context.text.bodyLarge?.copyWith(fontSize: 15)),
      trailing: Icon(CloserIcons.chevronRight, color: c.textPrimary, size: 18),
      onTap: () => context.push(route),
    );
    return ListView(
      padding: const EdgeInsets.all(CloserSpacing.gutter),
      children: [
        SectionCard(
          dividerIndent: CloserSpacing.md,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CloserSpacing.md,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Text(label, style: context.text.bodyMedium),
                    const SizedBox(width: CloserSpacing.md),
                    Expanded(
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: context.text.bodyLarge?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: CloserSpacing.sm),
        SectionCard(
          dividerIndent: CloserSpacing.md,
          children: [
            link(
              CloserIcons.settings,
              'Group settings',
              Routes.groupSettings(group.id),
            ),
            link(CloserIcons.user, 'Members', Routes.members(group.id)),
          ],
        ),
        if (!group.isPremium) ...[
          const SizedBox(height: CloserSpacing.md),
          Container(
            padding: const EdgeInsets.all(CloserSpacing.md),
            decoration: BoxDecoration(
              borderRadius: CloserRadii.lgAll,
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(CloserIcons.crown, color: c.textPrimary, size: 17),
                    const SizedBox(width: CloserSpacing.xs),
                    Text('Keeploom Memories', style: context.text.titleSmall),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  group.type == GroupType.couple
                      ? 'Keep every photo from ${group.name}, for both of you.'
                      : 'Keep every photo from ${group.name}, for everyone in it.',
                  style: context.text.headlineSmall?.copyWith(
                    fontSize: 19,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: CloserSpacing.sm),
                CloserButton(
                  label: 'See Keeploom Memories',
                  onPressed: () => context.push(Routes.upgrade(group.id)),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
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
      ColoredBox(
        color: background,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CloserSpacing.gutter),
          child: tabBar,
        ),
      );

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar != tabBar || old.background != background;
}
