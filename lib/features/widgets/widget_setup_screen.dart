import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/routes.dart';
import '../../core/sync/app_sync.dart';
import '../../core/theme/closer_icons.dart';
import '../../core/theme/closer_theme.dart';
import '../../core/widgets/widgets.dart';
import '../groups/application/group_providers.dart';
import '../groups/presentation/group_widgets.dart';
import '../photos/presentation/photo_widgets.dart';
import 'widget_sync.dart';

/// Whether this device can add widgets from inside the app (Android 8+
/// launchers). Overridden in tests.
final canPinWidgetProvider = Provider<bool>((ref) => Platform.isAndroid);

/// Asks the launcher to add a Keeploom widget. Overridden in tests.
final pinWidgetProvider = Provider<Future<bool> Function()>(
  (ref) =>
      () => HomeWidgetPlatform().requestPin(),
);

/// Screen 14: previews, how to add widgets, how configuration works, and
/// troubleshooting.
class WidgetSetupScreen extends ConsumerWidget {
  const WidgetSetupScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    // Make sure widgets have the latest groups before the picker opens.
    final groups = ref.read(myGroupsProvider).value;
    if (groups != null) {
      try {
        await ref
            .read(widgetSyncProvider)
            .syncAll(groups, coverBytes: (_) async => null);
      } catch (_) {
        // Covers arrive with the next background sync.
      }
    }
    final ok = await ref.read(pinWidgetProvider)();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Confirm on the next screen, then choose a group for the widget.'
              : 'Your launcher can’t add widgets from apps. Add it from the '
                    'home screen instead (steps below).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(myGroupsProvider);
    final canPin = ref.watch(canPinWidgetProvider);
    final isIos = !canPin && Platform.isIOS;
    final c = context.closerColors;

    final steps = isIos
        ? const [
            'Touch and hold an empty area of your Home Screen until the apps jiggle.',
            'Tap the + button in the top corner and search for Keeploom.',
            'Choose a size and tap Add Widget.',
            'Touch and hold the new widget, tap Edit Widget, and choose a group.',
          ]
        : const [
            'Touch and hold an empty area of your home screen.',
            'Tap Widgets and find Keeploom.',
            'Drag the Keeploom widget onto your home screen.',
            'Choose which group it shows.',
          ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home screen widgets'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.profile),
        ),
      ),
      body: AsyncBody(
        value: groups,
        onRetry: () => ref.invalidate(myGroupsProvider),
        builder: (list) => ListView(
          padding: const EdgeInsets.all(CloserSpacing.gutter),
          children: [
            Semantics(
              header: true,
              child: Text(
                'Your people, on your home screen',
                style: context.text.headlineMedium,
              ),
            ),
            const SizedBox(height: CloserSpacing.xs),
            Text(
              'Each widget shows one group’s newest photo. Add as many as you '
              'like — one for your partner, one for family, or two for the '
              'same group. Changing one never changes the others.',
              style: context.text.bodyMedium?.copyWith(fontSize: 14.5),
            ),
            const SizedBox(height: CloserSpacing.md),
            if (list.isEmpty)
              const NoticeCard(
                message: 'Create or join a group first — widgets show a group.',
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: CloserSpacing.sm,
                crossAxisSpacing: CloserSpacing.sm,
                childAspectRatio: 1.05,
                children: [
                  for (final g in list.take(2))
                    WidgetPreviewCard(
                      groupName: g.name,
                      groupType: g.type,
                      subtitle: WidgetSnapshot.subtitleFor(g, DateTime.now()),
                      placeholderVariant: g.placeholderVariant,
                      cover: GroupCover(group: g),
                    ),
                ],
              ),
            const SizedBox(height: CloserSpacing.md),
            if (canPin) ...[
              CloserButton(
                label: 'Add a widget',
                onPressed: list.isEmpty ? null : () => _add(context, ref),
              ),
              const SizedBox(height: CloserSpacing.lg),
            ],
            Semantics(
              header: true,
              child: Text(
                canPin ? 'Or add it yourself' : 'How to add one',
                style: context.text.labelMedium?.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: CloserSpacing.sm),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: CloserSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.line),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: context.text.labelSmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: CloserSpacing.sm),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: context.text.bodyMedium?.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: CloserSpacing.md),
            Semantics(
              header: true,
              child: Text(
                'If something looks wrong',
                style: context.text.labelMedium?.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: CloserSpacing.sm),
            for (final tip in const [
              'A new photo can take a minute or two to appear — your phone '
                  'decides when widgets refresh. Opening Keeploom refreshes them.',
              '“Tap to choose a group” means the widget isn’t set up yet: tap it.',
              '“No longer available” means you left the group or it was '
                  'deleted. Tap the widget to choose another group.',
              'Signed out? Widgets hide your photos until you sign in again.',
              'Battery saver can delay updates. Widgets never refresh on their '
                  'own in the background to save battery.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: CloserSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        CloserIcons.help,
                        size: 16,
                        color: c.textTertiary,
                      ),
                    ),
                    const SizedBox(width: CloserSpacing.xs),
                    Expanded(child: Text(tip, style: context.text.bodySmall)),
                  ],
                ),
              ),
            SizedBox(
              height: MediaQuery.paddingOf(context).bottom + CloserSpacing.lg,
            ),
          ],
        ),
      ),
    );
  }
}
