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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _markAll(context, ref),
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
          if (list.isEmpty) {
            return const EmptyState(
              icon: CloserIcons.notifications,
              title: 'You are all caught up',
              message:
                  'New photos, members and special moments from your groups '
                  'will show up here.',
            );
          }
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          String section(DateTime t) {
            final l = t.toLocal();
            final d = DateTime(l.year, l.month, l.day);
            if (d == today) return 'Today';
            if (d == today.subtract(const Duration(days: 1))) {
              return 'Yesterday';
            }
            return 'Earlier';
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
                    CloserSpacing.xs,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(s, style: context.text.titleMedium),
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
                ...rows,
                const SizedBox(height: CloserSpacing.xxl),
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
    return Semantics(
      button: true,
      label:
          '${n.isUnread ? 'Unread. ' : ''}$text, ${relativeTime(n.createdAt, DateTime.now())}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: n.isUnread ? c.accentSoft.withValues(alpha: 0.45) : null,
          padding: const EdgeInsets.symmetric(
            horizontal: CloserSpacing.gutter,
            vertical: CloserSpacing.sm,
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: CloserSpacing.sm),
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
                    const SizedBox(height: 2),
                    Text(
                      relativeTime(n.createdAt, DateTime.now()),
                      style: context.text.labelSmall?.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (n.photoThumbPath != null && group != null) ...[
                const SizedBox(width: CloserSpacing.sm),
                ClipRRect(
                  borderRadius: CloserRadii.smAll,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: ThumbByPath(
                      groupId: group!.id,
                      path: n.photoThumbPath!,
                    ),
                  ),
                ),
              ],
              if (n.isUnread) ...[
                const SizedBox(width: CloserSpacing.xs),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.accentStrong,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
