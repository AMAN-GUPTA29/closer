import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/group_type.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';

/// Selectable card for Couple / Family / Friends.
class GroupTypeOption extends StatelessWidget {
  const GroupTypeOption({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
    this.disabledReason,
  });

  final GroupType type;
  final bool selected;
  final VoidCallback onTap;

  /// When set, the option can't be chosen and this explains why.
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final tint = type.tint(c);
    final disabled = disabledReason != null;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      enabled: !disabled,
      label: '${type.label}. ${disabledReason ?? type.blurb}',
      excludeSemantics: true,
      child: Opacity(
        opacity: disabled ? 0.55 : 1,
        child: Material(
          color: selected ? c.accentSoft : c.surface,
          borderRadius: CloserRadii.lgAll,
          child: InkWell(
            borderRadius: CloserRadii.lgAll,
            onTap: disabled ? null : onTap,
            child: AnimatedContainer(
              duration: CloserMotion.of(context, CloserMotion.fast),
              padding: const EdgeInsets.all(CloserSpacing.md),
              decoration: BoxDecoration(
                borderRadius: CloserRadii.lgAll,
                border: Border.all(
                  color: selected ? c.accent : c.line,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.14),
                      borderRadius: CloserRadii.mdAll,
                    ),
                    child: Icon(type.icon, color: tint, size: 26),
                  ),
                  const SizedBox(width: CloserSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type.label, style: context.text.titleMedium),
                        Text(
                          disabledReason ?? type.blurb,
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: CloserMotion.of(context, CloserMotion.fast),
                    child: Icon(CloserIcons.success, color: c.accentStrong),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable field that opens a date picker (no future dates).
class RelationshipDateField extends StatelessWidget {
  const RelationshipDateField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: 'Together since',
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return Material(
      color: c.surface,
      borderRadius: CloserRadii.mdAll,
      child: InkWell(
        borderRadius: CloserRadii.mdAll,
        onTap: () => _pick(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CloserSpacing.md,
            vertical: CloserSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: CloserRadii.mdAll,
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Icon(CloserIcons.calendar, color: c.textTertiary, size: 22),
              const SizedBox(width: CloserSpacing.sm),
              Expanded(
                child: Text(
                  value == null ? 'Pick a date' : formatMediumDate(value!),
                  style: context.text.bodyLarge?.copyWith(
                    color: value == null ? c.textTertiary : c.textPrimary,
                  ),
                ),
              ),
              if (value != null)
                IconButton(
                  tooltip: 'Clear date',
                  icon: const Icon(CloserIcons.close, size: 20),
                  onPressed: () => onChanged(null),
                )
              else
                const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a snackbar for a failed action.
void showFailure(BuildContext context, Object error) {
  final message = error is AppFailure
      ? error.message
      : 'Something went wrong. Please try again.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Builds a screen body from an AsyncValue with standard loading/error views.
class AsyncBody<T> extends ConsumerWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (value) {
      AsyncData(:final value) => builder(value),
      AsyncError(:final error) when error is NetworkFailure =>
        ErrorState.offline(onRetry: onRetry),
      AsyncError(:final error) when error is PermissionFailure => ErrorState(
        title: 'Not available',
        message: error.message,
      ),
      AsyncError(:final error) => ErrorState(
        message: error is AppFailure
            ? error.message
            : 'Something went wrong. Please try again.',
        onRetry: onRetry,
      ),
      _ => const LoadingState(),
    };
  }
}
