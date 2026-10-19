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

const _pad = EdgeInsets.symmetric(
  horizontal: CloserSpacing.md,
  vertical: CloserSpacing.xxs,
);

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
              'Choose what Keeploom tells you about. These apply to all of your '
              'groups.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: CloserSpacing.md),
            SectionCard(
              dividerIndent: CloserSpacing.md,
              children: [
                SwitchListTile(
                  contentPadding: _pad,
                  value: p.photos,
                  onChanged: (v) => _save(context, ref, p.copyWith(photos: v)),
                  title: Text('New photos', style: context.text.bodyLarge),
                  subtitle: Text(
                    'When someone shares a photo in your groups',
                    style: context.text.bodySmall,
                  ),
                ),
                SwitchListTile(
                  contentPadding: _pad,
                  value: p.members,
                  onChanged: (v) => _save(context, ref, p.copyWith(members: v)),
                  title: Text('New members', style: context.text.bodyLarge),
                  subtitle: Text(
                    'When someone joins one of your groups',
                    style: context.text.bodySmall,
                  ),
                ),
                SwitchListTile(
                  contentPadding: _pad,
                  value: p.milestones,
                  onChanged: (v) =>
                      _save(context, ref, p.copyWith(milestones: v)),
                  title: Text('Special moments', style: context.text.bodyLarge),
                  subtitle: Text(
                    'When someone adds a milestone',
                    style: context.text.bodySmall,
                  ),
                ),
                SwitchListTile(
                  contentPadding: _pad,
                  value: p.reminders,
                  onChanged: (v) =>
                      _save(context, ref, p.copyWith(reminders: v)),
                  title: Text('Reminders', style: context.text.bodyLarge),
                  subtitle: Text(
                    'The day before an upcoming special moment',
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CloserSpacing.md),
            SectionCard(
              children: [
                SwitchListTile(
                  contentPadding: _pad,
                  value: p.push,
                  onChanged: (v) => _save(context, ref, p.copyWith(push: v)),
                  title: Text(
                    'Phone notifications',
                    style: context.text.bodyLarge,
                  ),
                  subtitle: Text(
                    'Pop-ups on this phone. When off, everything still appears in '
                    'Alerts inside Keeploom.',
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
