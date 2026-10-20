import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/group_type.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/presentation/group_widgets.dart';
import '../../photos/application/photo_providers.dart';
import '../../photos/domain/photo_models.dart';
import '../../photos/presentation/photo_widgets.dart';
import '../application/content_providers.dart';
import '../domain/journal_models.dart';

extension MilestoneThemeIcon on MilestoneTheme {
  IconData get icon => switch (this) {
    MilestoneTheme.heart => CloserIcons.heart,
    MilestoneTheme.celebration => CloserIcons.confetti,
    MilestoneTheme.neutral => CloserIcons.star,
  };

  String get label => switch (this) {
    MilestoneTheme.heart => 'Heart',
    MilestoneTheme.celebration => 'Celebration',
    MilestoneTheme.neutral => 'Classic',
  };
}

/// A milestone card wired to the detail sheet.
class MilestoneView extends ConsumerWidget {
  const MilestoneView({
    super.key,
    required this.milestone,
    required this.group,
    this.showGroup = false,
    this.showChevron = false,
  });

  final Milestone milestone;
  final Group? group;
  final bool showGroup;
  final bool showChevron;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = milestone;
    final number = m.highlightNumber;
    final rest = number == null
        ? ''
        : m.title.trim().substring(number.length).trim();
    final cover = m.coverThumbPath == null
        ? null
        : ref
              .watch(
                photoImageProvider((
                  Photo(
                    id: 'path-${m.coverThumbPath}',
                    groupId: m.groupId,
                    storagePath: m.coverThumbPath!,
                    thumbPath: m.coverThumbPath!,
                    uploadedAt: DateTime.fromMillisecondsSinceEpoch(0),
                  ),
                  PhotoVariant.thumb,
                )),
              )
              .value;
    final context0 = showGroup && group != null ? group!.name : null;
    return MilestoneCard(
      highlight: number,
      highlightCaption: rest.isEmpty ? null : rest,
      title: number == null
          ? m.title
          : (m.description ?? context0 ?? 'A special moment'),
      dateLabel: context0 != null && number == null
          ? '${formatDayMonth(m.eventDate)} · $context0'
          : formatDayMonth(m.eventDate),
      showChevron: showChevron,
      description: number == null ? m.description : null,
      theme: m.theme,
      isPinned: m.isPinned,
      cover: cover,
      placeholderVariant: m.id.hashCode.abs() % 4,
      onTap: group == null
          ? null
          : () => showMilestoneSheet(context, ref, m, group!),
    );
  }
}

/// Bottom sheet with a milestone's details and the actions the user may take.
Future<void> showMilestoneSheet(
  BuildContext context,
  WidgetRef ref,
  Milestone m,
  Group group,
) {
  final myId = ref.read(currentUserIdProvider);
  final canEdit = m.createdBy == myId || group.isOwner;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          CloserSpacing.gutter,
          0,
          CloserSpacing.gutter,
          CloserSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(m.theme.icon, color: sheet.closerColors.accentStrong),
                const SizedBox(width: CloserSpacing.xs),
                Expanded(child: Text(m.title, style: sheet.text.headlineSmall)),
              ],
            ),
            const SizedBox(height: CloserSpacing.xxs),
            Text(
              '${formatMediumDate(m.eventDate)} · ${group.name}',
              style: sheet.text.bodyMedium,
            ),
            if (m.coverThumbPath != null) ...[
              const SizedBox(height: CloserSpacing.md),
              ClipRRect(
                borderRadius: CloserRadii.lgAll,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ThumbByPath(
                    groupId: group.id,
                    path: m.coverThumbPath!,
                  ),
                ),
              ),
            ],
            if (m.description != null) ...[
              const SizedBox(height: CloserSpacing.md),
              Text(m.description!, style: sheet.text.bodyLarge),
            ],
            const SizedBox(height: CloserSpacing.xl),
            if (canEdit) ...[
              CloserButton.secondary(
                label: 'Edit',
                icon: const Icon(CloserIcons.edit),
                onPressed: () {
                  Navigator.of(sheet).pop();
                  context.push(Routes.editMoment(group.id, m.id));
                },
              ),
              const SizedBox(height: CloserSpacing.sm),
              CloserButton.secondary(
                label: m.isPinned ? 'Unpin' : 'Pin to top',
                icon: const Icon(CloserIcons.pin),
                onPressed: () async {
                  Navigator.of(sheet).pop();
                  try {
                    await ref
                        .read(milestoneActionsProvider)
                        .setPinned(m, !m.isPinned);
                  } catch (e) {
                    if (context.mounted) showFailure(context, e);
                  }
                },
              ),
              const SizedBox(height: CloserSpacing.sm),
              CloserButton(
                label: 'Delete',
                variant: CloserButtonVariant.danger,
                icon: const Icon(CloserIcons.trash),
                onPressed: () async {
                  final ok = await showConfirmationDialog(
                    sheet,
                    title: 'Delete “${m.title}”?',
                    message:
                        'It will be removed for everyone in ${group.name}. '
                        'Photos stay in the journal.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (!ok) return;
                  if (sheet.mounted) Navigator.of(sheet).pop();
                  try {
                    await ref.read(milestoneActionsProvider).delete(m);
                  } catch (e) {
                    if (context.mounted) showFailure(context, e);
                  }
                },
              ),
            ] else
              Text(
                'Only the person who added this moment or the group owner '
                'can change it.',
                style: sheet.text.bodySmall,
              ),
          ],
        ),
      ),
    ),
  );
}

/// Milestones tab: couple counter + countdowns, upcoming and past moments.
class MilestonesTab extends ConsumerWidget {
  const MilestonesTab({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(milestonesProvider(group.id));
    final now = DateTime.now();
    return AsyncBody(
      value: list,
      onRetry: () => ref.invalidate(milestonesProvider(group.id)),
      builder: (milestones) {
        final upcoming = milestones.where((m) => m.isUpcoming(now)).toList()
          ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
        final past = milestones.where((m) => !m.isUpcoming(now)).toList();
        final rows = <(String, DateTime, int, Milestone?)>[
          if (group.hasCounter)
            for (final cd in coupleCountdowns(
              group.relationshipStartDate!,
              now,
            ))
              (cd.label, cd.date, cd.daysLeft, null),
          for (final m in upcoming)
            (m.title, m.eventDate, _daysUntil(m.eventDate, now), m),
        ];
        return ListView(
          padding: EdgeInsets.fromLTRB(
            CloserSpacing.gutter,
            CloserSpacing.xs,
            CloserSpacing.gutter,
            MediaQuery.paddingOf(context).bottom + CloserSpacing.xxl,
          ),
          children: [
            if (!group.hasCounter &&
                group.type == GroupType.couple &&
                group.relationshipStartDate == null &&
                group.isOwner) ...[
              const SizedBox(height: CloserSpacing.sm),
              NoticeCard(
                icon: CloserIcons.heart,
                title: 'Add your “together since” date',
                message:
                    'See how many days you’ve shared and count down to your '
                    'next anniversary. Set it in Group settings.',
              ),
            ],
            if (rows.isNotEmpty) ...[
              const _Label('Coming up'),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(),
                _UpcomingRow(
                  title: rows[i].$1,
                  date: rows[i].$2,
                  daysLeft: rows[i].$3,
                  onTap: rows[i].$4 == null
                      ? null
                      : () => showMilestoneSheet(
                          context,
                          ref,
                          rows[i].$4!,
                          group,
                        ),
                ),
              ],
            ],
            if (past.isEmpty) ...[
              const SizedBox(height: CloserSpacing.lg),
              EmptyState(
                icon: group.type == GroupType.couple
                    ? CloserIcons.heartOutline
                    : CloserIcons.confetti,
                title: 'No special moments yet',
                message: group.type == GroupType.couple
                    ? 'Celebrate 100 days, anniversaries and first trips.'
                    : 'Mark birthdays, reunions, trips and the moments that matter.',
              ),
            ] else ...[
              const _Label('Kept'),
              for (final m in past)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MilestoneView(
                    milestone: m,
                    group: group,
                    showChevron: true,
                  ),
                ),
            ],
            const SizedBox(height: CloserSpacing.md),
            CloserButton(
              label: 'Create a special moment',
              onPressed: () => context.push(Routes.newMoment(group.id)),
            ),
          ],
        );
      },
    );
  }

  static int _daysUntil(DateTime date, DateTime now) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
}

/// Small muted section label ("Coming up", "Kept").
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: CloserSpacing.lg, bottom: 4),
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

/// "200 days together ........ in 18 days · 7 Nov"
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({
    required this.title,
    required this.date,
    required this.daysLeft,
    this.onTap,
  });

  final String title;
  final DateTime date;
  final int daysLeft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.text.bodyLarge?.copyWith(fontSize: 15),
            ),
          ),
          const SizedBox(width: CloserSpacing.sm),
          Text(
            'in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}'
            ' · ${formatShortDayMonth(date)}',
            style: context.text.bodySmall?.copyWith(fontSize: 13.5),
          ),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
