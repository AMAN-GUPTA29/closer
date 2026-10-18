import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/group_type.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/greeting.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_models.dart';
import '../../groups/application/group_providers.dart';
import '../../journal/application/content_providers.dart';
import '../../journal/domain/journal_models.dart';
import '../../photos/presentation/photo_widgets.dart';
import '../../profile/presentation/profile_widgets.dart';
import '../../shell/app_shell.dart' show showAddMemorySheet;
import 'group_list_tile.dart';

/// Groups shown on Home before "See all".
const homeGroupLimit = 2;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider);
    final user = switch (status) {
      SignedIn(:final user) => user,
      PreviewSession() => PreviewSession.user,
      _ => null,
    };
    final name = user?.friendlyName ?? '';
    final groups = ref.watch(myGroupsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(myGroupsProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  CloserSpacing.gutter,
                  CloserSpacing.lg,
                  CloserSpacing.gutter,
                  CloserSpacing.md,
                ),
                sliver: SliverToBoxAdapter(child: _Header(name: name)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CloserSpacing.gutter,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Your groups',
                            style: context.text.titleLarge,
                          ),
                        ),
                      ),
                      if (groups.value?.isNotEmpty ?? false)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: context.closerColors.textSecondary,
                          ),
                          onPressed: () => context.push(Routes.allGroups),
                          child: const Text('See all'),
                        ),
                      const SizedBox(width: CloserSpacing.xxs),
                      CloserIconButton(
                        icon: CloserIcons.plus,
                        semanticLabel: 'Create a group',
                        filled: true,
                        size: 48,
                        onPressed: () => context.push(Routes.createGroup),
                      ),
                    ],
                  ),
                ),
              ),
              ...switch (groups) {
                AsyncData(:final value) when value.isEmpty => [
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyGroups(),
                  ),
                ],
                AsyncData(:final value) => [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      CloserSpacing.gutter,
                      CloserSpacing.md,
                      CloserSpacing.gutter,
                      CloserSpacing.md,
                    ),
                    sliver: SliverList.separated(
                      itemCount: value.length.clamp(0, homeGroupLimit),
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: CloserSpacing.sm),
                      itemBuilder: (context, i) => GroupListTile(value[i]),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      CloserSpacing.gutter,
                      0,
                      CloserSpacing.gutter,
                      CloserSpacing.xl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: CloserButton.secondary(
                        label: 'Join a group with a code',
                        icon: const Icon(CloserIcons.invite),
                        onPressed: () => context.push(Routes.joinGroup),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: _RecentMoments()),
                ],
                AsyncError(:final error) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _GroupsError(error: error),
                  ),
                ],
                _ => [
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: LoadingState(message: 'Loading your groups'),
                  ),
                ],
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greetingFor(DateTime.now()),
                  style: context.text.bodyLarge?.copyWith(
                    color: context.closerColors.textSecondary,
                  ),
                ),
                Text(
                  name,
                  style: context.text.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        CloserIconButton(
          icon: CloserIcons.notifications,
          semanticLabel: unread > 0
              ? 'Notifications, $unread unread'
              : 'Notifications',
          showBadge: unread > 0,
          tonal: true,
          onPressed: () => context.go(Routes.notifications),
        ),
        const SizedBox(width: CloserSpacing.xs),
        Semantics(
          button: true,
          label: 'Profile',
          excludeSemantics: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go(Routes.profile),
            child: MyAvatar(fallbackName: name, size: 48),
          ),
        ),
      ],
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: CloserIcons.heartOutline,
      title: 'Start your first group',
      message:
          'Create a private space for your partner, friends or family — '
          'or join one with an invite code.',
      action: CloserButton(
        label: 'Create a group',
        onPressed: () => context.push(Routes.createGroup),
      ),
      secondaryAction: CloserButton.secondary(
        label: 'Join with a code',
        onPressed: () => context.push(Routes.joinGroup),
      ),
    );
  }
}

class _GroupsError extends ConsumerWidget {
  const _GroupsError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (error is NotConfiguredFailure) {
      return EmptyState(
        icon: GroupType.couple.icon,
        title: 'Groups need the backend',
        message: (error as AppFailure).message,
      );
    }
    if (error is NetworkFailure) {
      return ErrorState.offline(
        onRetry: () => ref.invalidate(myGroupsProvider),
      );
    }
    return ErrorState(
      message: error is AppFailure
          ? (error as AppFailure).message
          : 'We couldn’t load your groups.',
      onRetry: () => ref.invalidate(myGroupsProvider),
    );
  }
}

/// The newest photos across all groups, as on the Keeploom board. Before
/// the first photo it shows a "share a moment" tile instead of an empty gap.
class _RecentMoments extends ConsumerWidget {
  const _RecentMoments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.closerColors;
    final photos = [
      for (final e in ref.watch(journalProvider(null)).value?.entries ?? [])
        if (e is PhotoEntry) e.photo,
    ].take(8).toList();
    void openJournal() => StatefulNavigationShell.of(context).goBranch(1);
    // Three tiles across, the next one peeking in.
    final tile =
        (MediaQuery.sizeOf(context).width - CloserSpacing.gutter * 2 - 24) / 3;
    Widget frame(Widget child, VoidCallback onTap, {String? label}) => SizedBox(
      width: tile,
      child: Semantics(
        button: true,
        label: label,
        child: ClipRRect(
          borderRadius: CloserRadii.lgAll,
          child: Material(
            color: c.accentSoft,
            child: InkWell(onTap: onTap, child: child),
          ),
        ),
      ),
    );
    final tiles = photos.isNotEmpty
        ? [for (final p in photos) frame(PhotoImage(photo: p), openJournal)]
        : [
            frame(
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: c.accentGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CloserIcons.plus, color: c.onAccent),
                  ),
                  const SizedBox(height: CloserSpacing.xs),
                  Text(
                    'Share a\nmoment',
                    textAlign: TextAlign.center,
                    style: context.text.labelMedium?.copyWith(
                      color: c.accentStrong,
                    ),
                  ),
                ],
              ),
              () => showAddMemorySheet(context),
              label: 'Share a moment',
            ),
            for (var i = 0; i < 2; i++)
              ExcludeSemantics(
                child: SizedBox(
                  width: tile,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: CloserRadii.lgAll,
                      border: Border.all(color: c.line, width: 1.5),
                    ),
                    child: Icon(
                      CloserIcons.gallery,
                      color: c.textTertiary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
          ];
    return Padding(
      padding: const EdgeInsets.only(bottom: CloserSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CloserSpacing.gutter,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Recent moments',
                      style: context.text.titleLarge,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: openJournal,
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          if (photos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CloserSpacing.gutter,
                0,
                CloserSpacing.gutter,
                CloserSpacing.sm,
              ),
              child: Text(
                'New photos from all your groups will show up here.',
                style: context.text.bodySmall,
              ),
            ),
          SizedBox(
            height: tile * 1.12,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: CloserSpacing.gutter,
              ),
              itemCount: tiles.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: CloserSpacing.sm),
              itemBuilder: (context, i) => tiles[i],
            ),
          ),
        ],
      ),
    );
  }
}
