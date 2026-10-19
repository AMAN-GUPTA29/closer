import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/presentation/group_widgets.dart';
import '../../journal/application/content_providers.dart';
import '../../photos/presentation/photo_widgets.dart';
import '../domain/notification_models.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    if (n.isUnread) {
      try {
        await ref.read(contentBackendProvider).markNotificationsRead([n.id]);
        ref.invalidate(notificationsProvider);
      } catch (_) {
        // Opening the group matters more than the read marker.
      }
    }
    if (context.mounted) context.push(Routes.group(n.groupId));
  }

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(contentBackendProvider).markNotificationsRead();
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);
    final groups = {
      for (final g in ref.watch(myGroupsProvider).value ?? const <Group>[])
        g.id: g,
    };
    final welcomeAt = ref.watch(myProfileProvider).value?.createdAt;
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: unread > 0 ? () => _markAll(context, ref) : null,
            child: const Text('Mark all read'),
          ),
          IconButton(
            tooltip: 'Notification preferences',
            icon: const Icon(CloserIcons.settings),
            onPressed: () => context.push(Routes.notificationPreferences),
          ),
        ],
      ),
      body: AsyncBody(
        value: items,
        onRetry: () => ref.invalidate(notificationsProvider),
        builder: (list) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          String section(DateTime t) {
            final l = t.toLocal();
            final d = DateTime(l.year, l.month, l.day);
            return d == today ? 'Today' : 'Earlier';
          }

          final rows = <Widget>[];
          String? last;
          for (final n in list) {
            final s = section(n.createdAt);
            if (s != last) {
              rows.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CloserSpacing.gutter,
                    CloserSpacing.lg,
                    CloserSpacing.gutter,
                    CloserSpacing.sm,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(s, style: context.text.titleLarge),
                  ),
                ),
              );
              last = s;
            }
            rows.add(
              _NotificationTile(
                n: n,
                group: groups[n.groupId],
                onTap: () => _open(context, ref, n),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: CloserSpacing.xl),
                    child: EmptyState(
                      icon: CloserIcons.notifications,
                      title: 'You are all caught up',
                      message:
                          'New photos, members and special moments from your '
                          'groups will show up here.',
                    ),
                  ),
                ...rows,
                const SizedBox(height: CloserSpacing.md),
                _WelcomeTile(at: welcomeAt),
                SizedBox(
                  height:
                      CloserSpacing.xxxl * 2 +
                      MediaQuery.paddingOf(context).bottom,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.n,
    required this.group,
    required this.onTap,
  });

  final AppNotification n;
  final Group? group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final text = n.message(group?.name ?? 'a group');
    final leading = switch (n.kind) {
      NotificationKind.milestoneAdded => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
        child: Icon(CloserIcons.heart, color: c.accentStrong, size: 22),
      ),
      _ => MemberAvatar(name: n.actorName ?? '?', size: 44),
    };
    final time = relativeTime(n.createdAt, DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CloserSpacing.md,
        vertical: CloserSpacing.xxs,
      ),
      child: Semantics(
        button: true,
        label: '${n.isUnread ? 'Unread. ' : ''}$text, $time',
        excludeSemantics: true,
        child: Material(
          color: n.isUnread ? c.accentSoft : Colors.transparent,
          borderRadius: CloserRadii.xlAll,
          child: InkWell(
            borderRadius: CloserRadii.xlAll,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(CloserSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  const SizedBox(width: CloserSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text,
                          style: context.text.bodyMedium?.copyWith(
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: CloserSpacing.xxs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(time, style: context.text.bodyMedium),
                            ),
                            if (n.photoThumbPath != null && group != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: CloserSpacing.xxs,
                                ),
                                child: ClipRRect(
                                  borderRadius: CloserRadii.mdAll,
                                  child: SizedBox.square(
                                    dimension: 56,
                                    child: ThumbByPath(
                                      groupId: group!.id,
                                      path: n.photoThumbPath!,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 20,
                    height: 72,
                    child: n.isUnread
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: c.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The first message everyone gets: a welcome from Keeploom.
class _WelcomeTile extends StatelessWidget {
  const _WelcomeTile({required this.at});

  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final when = at;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CloserSpacing.md,
        vertical: CloserSpacing.xxs,
      ),
      child: Semantics(
        label:
            'System. Welcome to ${KeeploomLogo.name}!'
            '${when == null ? '' : ' ${relativeTime(when, DateTime.now())}'}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(CloserSpacing.md),
          decoration: BoxDecoration(
            // Dark: a lifted card, as on the board; light: plain.
            color: Theme.of(context).brightness == Brightness.dark
                ? c.surfaceMuted
                : null,
            borderRadius: CloserRadii.xlAll,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                  boxShadow: CloserElevation.low,
                ),
                child: const KeeploomLogo(size: 34),
              ),
              const SizedBox(width: CloserSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System', style: context.text.titleMedium),
                    Text(
                      'Welcome to ${KeeploomLogo.name}!',
                      style: context.text.bodyLarge,
                    ),
                    if (when != null)
                      Text(
                        relativeTime(when, DateTime.now()),
                        style: context.text.bodyMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
