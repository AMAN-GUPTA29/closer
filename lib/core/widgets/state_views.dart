import 'package:flutter/material.dart';

import '../theme/closer_icons.dart';
import '../theme/closer_theme.dart';
import 'closer_button.dart';

/// Centered progress indicator with an optional message.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: message ?? 'Loading',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (message != null) ...[
              const SizedBox(height: CloserSpacing.md),
              Text(message!, style: context.text.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly illustration + copy + optional action for empty screens.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.secondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CloserSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: c.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: c.accent),
            ),
            const SizedBox(height: CloserSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.headlineSmall,
            ),
            const SizedBox(height: CloserSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: CloserSpacing.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: action,
              ),
            ],
            if (secondaryAction != null) ...[
              const SizedBox(height: CloserSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: secondaryAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error message with a retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    this.offline = false,
  });

  /// Offline variant with connection-specific copy and icon.
  const ErrorState.offline({super.key, this.onRetry})
    : title = 'You are offline',
      message = 'Reconnect to see the latest memories.',
      offline = true;

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: offline ? CloserIcons.offline : CloserIcons.warning,
      title: title,
      message: message,
      action: onRetry == null
          ? null
          : CloserButton.secondary(
              label: 'Try again',
              icon: const Icon(CloserIcons.retry),
              onPressed: onRetry,
            ),
    );
  }
}

/// Thin banner shown at the top of a screen while the device is offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: c.textPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: CloserSpacing.md,
          vertical: CloserSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(CloserIcons.offline, size: 18, color: c.background),
            const SizedBox(width: CloserSpacing.xs),
            Expanded(
              child: Text(
                'Offline — showing what is saved on this phone.',
                style: context.text.bodySmall?.copyWith(color: c.background),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An inline notice card, e.g. "Backend not configured".
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.message,
    this.icon = CloserIcons.warning,
    this.title,
  });

  final String message;
  final String? title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return Container(
      padding: const EdgeInsets.all(CloserSpacing.md),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: CloserRadii.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.accentStrong, size: 22),
          const SizedBox(width: CloserSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: context.text.bodySmall?.copyWith(color: c.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
