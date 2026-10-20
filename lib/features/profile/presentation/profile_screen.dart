import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_models.dart';
import '../../groups/application/group_providers.dart';
import '../../journal/application/content_providers.dart';
import 'profile_widgets.dart';
import 'theme_settings_tile.dart';

Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  final ok = await showConfirmationDialog(
    context,
    title: 'Sign out?',
    message: 'You can sign back in any time. Your groups stay as they are.',
    confirmLabel: 'Sign out',
  );
  if (!ok) return;
  try {
    await ref.read(authControllerProvider.notifier).signOut();
  } on AppFailure catch (f) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message)));
    }
  }
}

/// Profile, as on the Keeploom showcase: avatar, name and email, then the
/// account and help sections. Appearance, sign-out and account deletion
/// live behind the settings gear.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider);
    final config = ref.watch(appConfigProvider);
    final user = switch (status) {
      SignedIn(:final user) => user,
      PreviewSession() => PreviewSession.user,
      _ => null,
    };
    final c = context.closerColors;
    final profile = ref.watch(myProfileProvider).value;
    final displayName =
        profile?.displayName ?? user?.displayName ?? user?.friendlyName ?? '';
    final support = config.supportEmail;
    final pushOn = ref.watch(notificationPreferencesProvider).value?.push;
    final premium = (ref.watch(myGroupsProvider).value ?? const [])
        .where((g) => g.isPremium)
        .length;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: CloserSpacing.gutter,
        toolbarHeight: 64,
        title: Semantics(
          header: true,
          child: Text('Profile', style: context.text.headlineLarge),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(CloserIcons.settings),
            onPressed: () => context.push(Routes.settings),
          ),
          const SizedBox(width: CloserSpacing.xxs),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          CloserSpacing.gutter,
          CloserSpacing.xs,
          CloserSpacing.gutter,
          CloserSpacing.xxxl * 2 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            children: [
              MyAvatar(fallbackName: displayName, size: 72, brand: true),
              const SizedBox(width: CloserSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: context.text.titleLarge?.copyWith(fontSize: 20),
                    ),
                    if (profile?.username != null)
                      Text(
                        '@${profile!.username}',
                        style: context.text.bodyMedium?.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    Text(user?.email ?? '', style: context.text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          if (status is PreviewSession) ...[
            const SizedBox(height: CloserSpacing.md),
            const NoticeCard(
              title: 'Preview mode',
              message:
                  'You are exploring a debug build without an account. '
                  'Nothing is saved.',
            ),
          ],
          const _Label('Your space'),
          SectionCard(
            children: [
              _Tile(
                icon: CloserIcons.edit,
                label: 'Edit profile',
                onTap: () => context.push(Routes.editProfile),
              ),
              _Tile(
                icon: CloserIcons.notifications,
                label: 'Notifications',
                value: pushOn == null ? null : (pushOn ? 'On' : 'Off'),
                onTap: () => context.push(Routes.notificationPreferences),
              ),
              _Tile(
                icon: CloserIcons.widgets,
                label: 'Home screen widgets',
                onTap: () => context.push(Routes.widgetSetup),
              ),
              _Tile(
                icon: CloserIcons.crown,
                label: 'Keeploom Memories',
                value: premium == 0
                    ? 'None yet'
                    : '$premium ${premium == 1 ? 'group' : 'groups'}',
                onTap: () => context.push(Routes.purchases),
              ),
            ],
          ),
          const SizedBox(height: CloserSpacing.xl),
          const ThemeSettingsTile(),
          const _Label('Help'),
          SectionCard(
            children: [
              _Tile(
                icon: CloserIcons.help,
                label: 'Help & support',
                trailing: support.isEmpty ? 'Not set up' : null,
                onTap: support.isEmpty
                    ? null
                    : () => launchUrl(Uri(scheme: 'mailto', path: support)),
              ),
              _Tile(
                icon: CloserIcons.privacy,
                label: 'Privacy policy',
                onTap: () => context.push('${Routes.legal}/privacy'),
              ),
              _Tile(
                icon: CloserIcons.document,
                label: 'Terms of use',
                onTap: () => context.push('${Routes.legal}/terms'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Profile → ⚙: appearance and account actions.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider);
    final c = context.closerColors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.profile),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(CloserSpacing.gutter),
        children: [
          const ThemeSettingsTile(),
          const _Label('Account'),
          SectionCard(
            children: [
              _Tile(
                icon: CloserIcons.signOut,
                label: 'Sign out',
                onTap: () => _signOut(context, ref),
              ),
              if (status is SignedIn)
                _Tile(
                  icon: CloserIcons.trash,
                  label: 'Delete account',
                  color: c.danger,
                  onTap: () => context.push(Routes.deleteAccount),
                ),
            ],
          ),
          if (kDebugMode) ...[
            const SizedBox(height: CloserSpacing.md),
            SectionCard(
              children: [
                _Tile(
                  icon: CloserIcons.widgets,
                  label: 'Component gallery (debug)',
                  onTap: () => context.push(Routes.componentGallery),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.trailing,
    this.value,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  final String? trailing;

  /// Current setting shown on the right, e.g. "On".
  final String? value;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final enabled = onTap != null;
    final fg = color ?? c.textPrimary;
    final tag = trailing;
    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      minTileHeight: 54,
      horizontalTitleGap: 14,
      leading: Icon(icon, color: fg, size: 19),
      title: Text(
        label,
        style: context.text.bodyLarge?.copyWith(color: fg, fontSize: 15),
      ),
      trailing: value != null
          ? Text(value!, style: context.text.bodyMedium)
          : tag != null
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CloserSpacing.sm,
                vertical: CloserSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: CloserRadii.pillAll,
              ),
              child: Text(
                tag,
                style: context.text.labelMedium?.copyWith(color: c.textPrimary),
              ),
            )
          : (enabled && color == null
                ? Icon(
                    CloserIcons.chevronRight,
                    color: c.textTertiary,
                    size: 18,
                  )
                : null),
    );
  }
}

/// A small section label above a grouped list.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        4,
        CloserSpacing.xl,
        4,
        CloserSpacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: context.text.labelMedium?.copyWith(
            color: context.closerColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
