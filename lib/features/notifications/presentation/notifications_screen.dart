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
        automaticallyImplyLeading: false,
        titleSpacing: CloserSpacing.gutter,
        toolbarHeight: 64,
        title: Semantics(
          header: true,
          child: Text('Alerts', style: context.text.headlineLarge),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.closerColors.textSecondary,
            ),
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
                    CloserSpacing.md,
                    CloserSpacing.gutter,
                    CloserSpacing.xxs,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      s,
                      style: context.text.labelMedium?.copyWith(
                        color: context.closerColors.textSecondary,
                      ),
                    ),
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
        child: Icon(CloserIcons.heart, color: c.accentStrong, size: 22),
      ),
      _ => MemberAvatar(name: n.actorName ?? '?', size: 40),
    };
    final time = relativeTime(n.createdAt, DateTime.now());
    // A plain row on the page ground: avatar, sentence, time, the photo when
    // there is one, and a coral dot while unread.
    return Semantics(
      button: true,
      label: '${n.isUnread ? 'Unread. ' : ''}$text, $time',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CloserSpacing.gutter,
            vertical: CloserSpacing.sm,
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: CloserSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      _emphasise(text, [?n.actorName, ?group?.name]),
                      style: context.text.bodyLarge?.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(time, style: context.text.bodyMedium),
                  ],
                ),
              ),
              if (n.photoThumbPath != null && group != null) ...[
                const SizedBox(width: CloserSpacing.sm),
                ClipRRect(
                  borderRadius: CloserRadii.smAll,
                  child: SizedBox.square(
                    dimension: 48,
                    child: ThumbByPath(
                      groupId: group!.id,
                      path: n.photoThumbPath!,
                    ),
                  ),
                ),
              ],
              SizedBox(
                width: 18,
                child: n.isUnread
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 8,
                          height: 8,
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
    return Semantics(
      label:
          'System. Welcome to ${KeeploomLogo.name}!'
          '${when == null ? '' : ' ${relativeTime(when, DateTime.now())}'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CloserSpacing.gutter,
          vertical: CloserSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const KeeploomLogo(size: 24),
            ),
            const SizedBox(width: CloserSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to ${KeeploomLogo.name}!',
                    style: context.text.bodyLarge?.copyWith(fontSize: 15),
                  ),
                  Text(
                    when == null
                        ? 'System'
                        : 'System · ${relativeTime(when, DateTime.now())}',
                    style: context.text.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sentence with people and group names in semibold (Keeploom concept).
TextSpan _emphasise(String text, List<String> names) {
  final spans = <TextSpan>[];
  var rest = text;
  while (rest.isNotEmpty) {
    var at = -1;
    var hit = '';
    for (final n in names) {
      if (n.isEmpty) continue;
      final i = rest.indexOf(n);
      if (i >= 0 && (at < 0 || i < at)) {
        at = i;
        hit = n;
      }
    }
    if (at < 0) {
      spans.add(TextSpan(text: rest));
      break;
    }
    if (at > 0) spans.add(TextSpan(text: rest.substring(0, at)));
    spans.add(
      TextSpan(
        text: hit,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
    rest = rest.substring(at + hit.length);
  }
  return TextSpan(children: spans);
}
