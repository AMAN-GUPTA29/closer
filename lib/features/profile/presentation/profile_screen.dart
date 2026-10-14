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

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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
    final displayName = user?.displayName ?? user?.friendlyName ?? '';
    final support = config.supportEmail;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: CloserSpacing.gutter,
          vertical: CloserSpacing.md,
        ),
        children: [
          Center(child: MemberAvatar(name: displayName, size: 96)),
          const SizedBox(height: CloserSpacing.md),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall,
          ),
          Text(
            user?.email ?? '',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium,
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
          const SizedBox(height: CloserSpacing.xl),
          _Section(
            children: [
              const _Tile(
                icon: CloserIcons.edit,
                label: 'Edit profile',
                soon: true,
              ),
              const _Tile(
                icon: CloserIcons.notifications,
                label: 'Notification preferences',
                soon: true,
              ),
              const _Tile(
                icon: CloserIcons.crown,
                label: 'Purchased groups',
                soon: true,
              ),
            ],
          ),
          const SizedBox(height: CloserSpacing.md),
          _Section(
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
              if (kDebugMode)
                _Tile(
                  icon: CloserIcons.widgets,
                  label: 'Component gallery (debug)',
                  onTap: () => context.push(Routes.componentGallery),
                ),
            ],
          ),
          const SizedBox(height: CloserSpacing.md),
          _Section(
            children: [
              _Tile(
                icon: CloserIcons.signOut,
                label: 'Sign out',
                color: c.danger,
                onTap: () => _signOut(context, ref),
              ),
            ],
          ),
          const SizedBox(height: CloserSpacing.xl),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: CloserRadii.lgAll,
        boxShadow: CloserElevation.low,
      ),
      child: Material(
        color: c.surface,
        borderRadius: CloserRadii.lgAll,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(indent: 56),
              children[i],
            ],
          ],
        ),
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
    this.soon = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  /// Marks a setting that arrives in a later build; it is disabled.
  final bool soon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final enabled = onTap != null && !soon;
    final fg = color ?? (enabled ? c.textPrimary : c.textTertiary);
    final tag = soon ? 'Soon' : trailing;
    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      minTileHeight: 56,
      leading: Icon(icon, color: fg, size: 22),
      title: Text(label, style: context.text.bodyLarge?.copyWith(color: fg)),
      trailing: tag != null
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CloserSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: CloserRadii.pillAll,
              ),
              child: Text(tag, style: context.text.labelSmall),
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
