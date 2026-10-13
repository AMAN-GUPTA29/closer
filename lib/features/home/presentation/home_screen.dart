import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/greeting.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_models.dart';

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

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                CloserSpacing.gutter,
                CloserSpacing.lg,
                CloserSpacing.gutter,
                CloserSpacing.md,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
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
                            Text(name, style: context.text.headlineMedium),
                          ],
                        ),
                      ),
                    ),
                    CloserIconButton(
                      icon: CloserIcons.notifications,
                      semanticLabel: 'Notifications',
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
                        child: MemberAvatar(name: name, size: 44),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: CloserSpacing.gutter,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your Groups',
                        style: context.text.titleLarge,
                      ),
                    ),
                    // Group creation arrives with the backend in Phase 2.
                    const CloserIconButton(
                      icon: CloserIcons.plus,
                      semanticLabel: 'Create a group (coming soon)',
                      filled: true,
                      size: 36,
                      onPressed: null,
                    ),
                  ],
                ),
              ),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: CloserIcons.heartOutline,
                title: 'Start your first group',
                message:
                    'Create a private space for your partner, friends or '
                    'family — or join one with an invite code.\n\n'
                    'Groups are coming in the next build.',
                action: CloserButton(label: 'Create a group', onPressed: null),
                secondaryAction: CloserButton.secondary(
                  label: 'Join with a code',
                  onPressed: null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
