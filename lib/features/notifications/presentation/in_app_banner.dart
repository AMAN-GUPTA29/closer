import 'package:flutter/material.dart';

import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';

/// What the in-app banner shows for a new notification.
@immutable
class BannerContent {
  const BannerContent({
    required this.id,
    required this.message,
    required this.groupId,
  });

  final int id;
  final String message;
  final String groupId;
}

/// A notification that arrives while the app is open: slides in at the top,
/// opens its group when tapped, can be swiped away and hides itself after a
/// few seconds (the caller owns the timer).
class InAppNotificationBanner extends StatelessWidget {
  const InAppNotificationBanner({
    super.key,
    required this.content,
    required this.onTap,
    required this.onDismiss,
  });

  final BannerContent? content;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final current = content;
    return SafeArea(
      bottom: false,
      child: AnimatedSwitcher(
        duration: CloserMotion.of(context, CloserMotion.medium),
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween(
            begin: const Offset(0, -1.2),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: current == null
            ? const SizedBox(key: ValueKey('none'), width: double.infinity)
            : Padding(
                key: ValueKey(current.id),
                padding: const EdgeInsets.fromLTRB(
                  CloserSpacing.sm,
                  CloserSpacing.xs,
                  CloserSpacing.sm,
                  0,
                ),
                child: Dismissible(
                  key: ValueKey('banner-${current.id}'),
                  direction: DismissDirection.up,
                  onDismissed: (_) => onDismiss(),
                  child: Semantics(
                    liveRegion: true,
                    button: true,
                    label:
                        'New notification: ${current.message}. '
                        'Double tap to open.',
                    excludeSemantics: true,
                    child: Material(
                      color: c.surface,
                      elevation: 6,
                      shadowColor: Colors.black26,
                      borderRadius: CloserRadii.lgAll,
                      child: InkWell(
                        borderRadius: CloserRadii.lgAll,
                        onTap: onTap,
                        child: Padding(
                          padding: const EdgeInsets.all(CloserSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: c.accentSoft,
                                  borderRadius: CloserRadii.mdAll,
                                ),
                                child: Icon(
                                  CloserIcons.heart,
                                  color: c.accentStrong,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: CloserSpacing.sm),
                              Expanded(
                                child: Text(
                                  current.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodyMedium?.copyWith(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                CloserIcons.chevronRight,
                                color: c.textTertiary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
