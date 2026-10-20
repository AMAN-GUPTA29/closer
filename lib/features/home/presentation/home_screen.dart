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
                  CloserSpacing.xs,
                  CloserSpacing.gutter,
                  0,
                ),
                sliver: SliverToBoxAdapter(child: _Header(name: name)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  CloserSpacing.gutter,
                  CloserSpacing.md,
                  CloserSpacing.gutter,
                  0,
                ),
                sliver: SliverToBoxAdapter(child: _Greeting(name: name)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  CloserSpacing.gutter,
                  CloserSpacing.xl,
                  CloserSpacing.xs,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Your people',
                            style: context.text.titleMedium?.copyWith(
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ),
                      if (groups.value?.isNotEmpty ?? false)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: context.closerColors.textPrimary,
                            textStyle: context.text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () => context.push(Routes.allGroups),
                          child: Text(
                            'See all ${groups.value!.length}',
                            semanticsLabel: 'See all',
                          ),
                        ),
                      IconButton(
                        tooltip: 'Create a group',
                        icon: const Icon(CloserIcons.plus),
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
                      CloserSpacing.xxs,
                      CloserSpacing.gutter,
                      0,
                    ),
                    sliver: SliverList.separated(
                      itemCount: value.length.clamp(0, homeGroupLimit),
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, i) => GroupListTile(value[i]),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      CloserSpacing.xs,
                      0,
                      CloserSpacing.gutter,
                      CloserSpacing.xs,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: context.closerColors.textPrimary,
                          ),
                          icon: const Icon(CloserIcons.invite, size: 18),
                          label: const Text('Join a group with a code'),
                          onPressed: () => context.push(Routes.joinGroup),
                        ),
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
    final c = context.closerColors;
    return Row(
      children: [
        const KeeploomLogo(size: 26),
        const SizedBox(width: CloserSpacing.xs),
        Expanded(
          child: Text(
            KeeploomLogo.name,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
          excludeSemantics: true,
          child: Tooltip(
            message: 'Notifications',
            child: InkResponse(
              radius: 24,
              onTap: () => context.go(Routes.notifications),
              child: SizedBox.square(
                dimension: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(CloserIcons.notifications, color: c.textPrimary),
                    if (unread > 0)
                      Positioned(
                        top: 12,
                        right: 13,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.background, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Profile',
          excludeSemantics: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go(Routes.profile),
            child: MyAvatar(fallbackName: name, size: 36, brand: true),
          ),
        ),
      ],
    );
  }
}

/// "Evening, Alex." in the serif, with one fact from the user's own data
/// underneath (the newest photo, and the couple counter when there is one).
class _Greeting extends ConsumerWidget {
  const _Greeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.closerColors;
    final groups = ref.watch(myGroupsProvider).value ?? const [];
    final latest = [
      for (final e in ref.watch(journalProvider(null)).value?.entries ?? [])
        if (e is PhotoEntry) e.photo,
    ].firstOrNull;
    final couple = groups.where((g) => g.hasCounter).firstOrNull;
    final strong = context.text.bodyLarge?.copyWith(
      color: c.textPrimary,
      fontWeight: FontWeight.w600,
      fontSize: 15,
    );
    final spans = <InlineSpan>[];
    if (latest != null) {
      final group = groups.where((g) => g.id == latest.groupId).firstOrNull;
      spans.addAll([
        TextSpan(text: latest.uploaderName ?? 'Someone', style: strong),
        TextSpan(
          text: ' shared a photo${group == null ? '' : ' in ${group.name}'}. ',
        ),
      ]);
    }
    if (couple != null) {
      final days = daysTogether(couple.relationshipStartDate!, DateTime.now());
      spans.addAll([
        const TextSpan(text: 'Together '),
        TextSpan(text: '$days ${days == 1 ? 'day' : 'days'}', style: strong),
        const TextSpan(text: ' today.'),
      ]);
    }
    if (spans.isEmpty) {
      spans.add(const TextSpan(text: 'Your people, your moments.'));
    }
    final first = name.split(' ').first;
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            first.isEmpty
                ? '${shortGreetingFor(DateTime.now())}.'
                : '${shortGreetingFor(DateTime.now())}, $first.',
            style: context.text.displaySmall,
          ),
          const SizedBox(height: CloserSpacing.xs),
          Text.rich(
            TextSpan(children: spans),
            style: context.text.bodyLarge?.copyWith(
              color: c.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
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

/// "Kept this week": the newest photos across all groups as tall tiles
/// labelled by day. Before the first photo it offers to share one.
class _RecentMoments extends ConsumerWidget {
  const _RecentMoments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.closerColors;
    final photos = [
      for (final e in ref.watch(journalProvider(null)).value?.entries ?? [])
        if (e is PhotoEntry) e.photo,
    ].take(4).toList();
    void openJournal() => StatefulNavigationShell.of(context).goBranch(1);
    final now = DateTime.now();
    String day(DateTime t) {
      final d = DateTime(t.year, t.month, t.day);
      final today = DateTime(now.year, now.month, now.day);
      if (d == today) return 'Today';
      if (today.difference(d).inDays == 1) return 'Yesterday';
      return weekdayShort(t);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CloserSpacing.gutter,
        CloserSpacing.md,
        CloserSpacing.gutter,
        CloserSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Kept this week',
                    style: context.text.titleMedium?.copyWith(fontSize: 17),
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: c.textPrimary,
                  textStyle: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: openJournal,
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: CloserSpacing.xxs),
          if (photos.isEmpty)
            Semantics(
              button: true,
              label: 'Share a moment',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => showAddMemorySheet(context),
                borderRadius: CloserRadii.lgAll,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: CloserSpacing.md,
                    vertical: CloserSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: CloserRadii.lgAll,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CloserIcons.plus, color: c.textPrimary),
                      const SizedBox(height: CloserSpacing.xs),
                      Text('Share a moment', style: context.text.titleSmall),
                      Text(
                        'New photos from all your groups show up here.',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: CloserSpacing.xs),
                  Expanded(
                    child: i < photos.length
                        ? Semantics(
                            button: true,
                            label: 'Photo, ${day(photos[i].uploadedAt)}',
                            excludeSemantics: true,
                            child: InkWell(
                              onTap: openJournal,
                              borderRadius: CloserRadii.mdAll,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AspectRatio(
                                    aspectRatio: 3 / 4,
                                    child: ClipRRect(
                                      borderRadius: CloserRadii.mdAll,
                                      child: PhotoImage(photo: photos[i]),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    day(photos[i].uploadedAt.toLocal()),
                                    style: context.text.bodySmall?.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
