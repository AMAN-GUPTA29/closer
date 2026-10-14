import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../groups/presentation/group_widgets.dart';
import '../../journal/application/content_providers.dart';
import '../domain/notification_models.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    NotificationPreferences prefs,
  ) async {
    try {
      await ref.read(contentBackendProvider).saveNotificationPreferences(prefs);
      ref.invalidate(notificationPreferencesProvider);
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification preferences'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.notifications),
        ),
      ),
      body: AsyncBody(
        value: prefs,
        onRetry: () => ref.invalidate(notificationPreferencesProvider),
        builder: (p) => ListView(
          padding: const EdgeInsets.all(CloserSpacing.gutter),
          children: [
            Text(
              'Choose what Closer tells you about. These apply to all of your '
              'groups.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: CloserSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: p.photos,
              onChanged: (v) => _save(context, ref, p.copyWith(photos: v)),
              title: Text('New photos', style: context.text.bodyLarge),
              subtitle: Text(
                'When someone shares a photo in your groups',
                style: context.text.bodySmall,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: p.members,
              onChanged: (v) => _save(context, ref, p.copyWith(members: v)),
              title: Text('New members', style: context.text.bodyLarge),
              subtitle: Text(
                'When someone joins one of your groups',
                style: context.text.bodySmall,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: p.milestones,
              onChanged: (v) => _save(context, ref, p.copyWith(milestones: v)),
              title: Text('Special moments', style: context.text.bodyLarge),
              subtitle: Text(
                'When someone adds a milestone',
                style: context.text.bodySmall,
              ),
            ),
            const SizedBox(height: CloserSpacing.lg),
            const NoticeCard(
              icon: CloserIcons.phone,
              message:
                  'Push notifications on your phone arrive in a later update. '
                  'For now these settings control the in-app list.',
            ),
          ],
        ),
      ),
    );
  }
}
