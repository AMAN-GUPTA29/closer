import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/group_type.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/greeting.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_models.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/domain/group_models.dart';
import '../../journal/application/content_providers.dart';
import '../../journal/domain/journal_models.dart';
import '../../photos/presentation/photo_widgets.dart';
import '../../profile/presentation/profile_widgets.dart';

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
                            'Your Groups',
                            style: context.text.titleLarge,
                          ),
                        ),
                      ),
                      CloserIconButton(
                        icon: CloserIcons.plus,
                        semanticLabel: 'Create a group',
                        filled: true,
                        size: 36,
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
                      itemCount: value.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: CloserSpacing.sm),
                      itemBuilder: (context, i) => _GroupTile(value[i]),
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
            child: MyAvatar(fallbackName: name, size: 44),
          ),
        ),
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile(this.group);

  final Group group;

  String get _activity {
    final now = DateTime.now();
    if (group.hasCounter) {
      return daysTogetherLabel(daysTogether(group.relationshipStartDate!, now));
    }
    return 'Active ${relativeTime(group.lastActivityAt, now)}';
  }

  @override
  Widget build(BuildContext context) {
    return GroupCard(
      name: group.name,
      type: group.type,
      memberCount: group.memberCount,
      activity: _activity,
      placeholderVariant: group.placeholderVariant,
      isPremium: group.isPremium,
      coverWidget: GroupCover(group: group),
      onTap: () => context.push(Routes.group(group.id)),
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

/// The newest photos across all groups, as on the Keeploom board. Hidden
/// until there is something to show; taps open the Journal tab.
class _RecentMoments extends ConsumerWidget {
  const _RecentMoments();

  static const _size = 104.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = [
      for (final e in ref.watch(journalProvider(null)).value?.entries ?? [])
        if (e is PhotoEntry) e.photo,
    ].take(8).toList();
    if (photos.isEmpty) return const SizedBox.shrink();
    void openJournal() => StatefulNavigationShell.of(context).goBranch(1);
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
          SizedBox(
            height: _size,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: CloserSpacing.gutter,
              ),
              itemCount: photos.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: CloserSpacing.sm),
              itemBuilder: (context, i) => SizedBox.square(
                dimension: _size,
                child: ClipRRect(
                  borderRadius: CloserRadii.mdAll,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: openJournal,
                      child: PhotoImage(photo: photos[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
