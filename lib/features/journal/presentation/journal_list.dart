import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/group_type.dart';
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
import 'milestone_views.dart';

/// Calendar day a journal entry belongs to, in local time. Milestones use
/// their own calendar date so time zones can never shift them.
DateTime entryDay(JournalEntry e) => switch (e) {
  MilestoneEntry(:final milestone) => milestone.eventDate,
  PhotoEntry(:final photo) => () {
    final d = photo.displayDate.toLocal();
    return DateTime(d.year, d.month, d.day);
  }(),
};

/// Newest-first journal of photos and milestones with day headers and
/// infinite scroll. [groupId] null shows all of the user's groups.
class JournalList extends ConsumerWidget {
  const JournalList({
    super.key,
    required this.groupId,
    this.header,
    this.emptyState,
  });

  final String? groupId;

  /// Extra slivers above the entries (e.g. pinned memories).
  final List<Widget> Function(BuildContext context)? header;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(journalProvider(groupId));
    final groups = {
      for (final g in ref.watch(myGroupsProvider).value ?? const <Group>[])
        g.id: g,
    };
    return AsyncBody(
      value: feed,
      onRetry: () => ref.invalidate(journalProvider(groupId)),
      builder: (data) {
        // An empty journal shows the empty state even when a header exists
        // (pinned items are entries too, so nothing is hidden).
        if (data.entries.isEmpty) {
          return emptyState ??
              const EmptyState(
                icon: CloserIcons.journal,
                title: 'No memories yet',
                message: 'Photos and special moments will appear here.',
              );
        }
        final extra = header?.call(context) ?? const <Widget>[];
        final items = <Widget>[];
        DateTime? lastDay;
        final photos = data.entries
            .whereType<PhotoEntry>()
            .map((e) => e.photo)
            .toList();
        for (final e in data.entries) {
          final day = entryDay(e);
          if (day != lastDay) {
            items.add(_DayHeader(day));
            lastDay = day;
          }
          final group = groups[e.groupId];
          items.add(
            Padding(
              padding: const EdgeInsets.only(bottom: CloserSpacing.sm),
              child: switch (e) {
                PhotoEntry(:final photo) => _PhotoMemory(
                  photo: photo,
                  group: group,
                  showGroup: groupId == null,
                  onTap: group == null
                      ? null
                      : () => openPhotoViewer(
                          context,
                          ref,
                          photos: photos,
                          index: photos.indexOf(photo),
                          group: group,
                          currentUserId: ref.read(currentUserIdProvider),
                        ),
                ),
                MilestoneEntry(:final milestone) => MilestoneView(
                  milestone: milestone,
                  group: group,
                  showGroup: groupId == null,
                ),
              },
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(journalProvider(groupId).future),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 800) {
                ref.read(journalProvider(groupId).notifier).loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              key: PageStorageKey('journal-${groupId ?? 'all'}'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                ...extra,
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CloserSpacing.gutter,
                  ),
                  sliver: SliverList.list(children: items),
                ),
                if (data.loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(CloserSpacing.lg),
                      child: LoadingState(),
                    ),
                  ),
                if (!data.hasMore && data.entries.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(CloserSpacing.lg),
                      child: Text(
                        groupId != null &&
                                groups[groupId] != null &&
                                !groups[groupId]!.isPremium
                            ? 'That’s everything this Basic group keeps.'
                            : 'That’s the beginning of your story.',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        MediaQuery.paddingOf(context).bottom +
                        CloserSpacing.xxxl * 2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.day);

  final DateTime day;

  /// "Today", "Yesterday", then "20 Oct 2026".
  static String _label(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    if (d == today) return 'Today';
    if (today.difference(d).inDays == 1) return 'Yesterday';
    return DateFormat('d MMM y').format(day);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(
          top: CloserSpacing.md,
          bottom: CloserSpacing.sm,
        ),
        child: Text(
          _label(day),
          style: context.text.labelMedium?.copyWith(
            color: context.closerColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PhotoMemory extends ConsumerWidget {
  const _PhotoMemory({
    required this.photo,
    required this.group,
    required this.showGroup,
    required this.onTap,
  });

  final Photo photo;
  final Group? group;
  final bool showGroup;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(photoImageProvider((photo, PhotoVariant.thumb)));
    return MemoryCard(
      image: image.value,
      caption: photo.caption,
      location: showGroup ? group?.name : null,
      uploaderName: photo.uploaderName ?? 'Former member',
      dateLabel: relativeTime(photo.uploadedAt, DateTime.now()),
      isPinned: photo.isPinned,
      showHeart: group?.type == GroupType.couple,
      placeholderVariant: photo.id.hashCode.abs() % 4,
      heroTag: 'photo-${photo.id}',
      onTap: onTap ?? () {},
    );
  }
}

/// "Pinned" section for a group journal: pinned milestones and photos.
List<Widget> pinnedSlivers(BuildContext context, WidgetRef ref, Group group) {
  final milestones =
      ref
          .watch(milestonesProvider(group.id))
          .value
          ?.where((m) => m.isPinned && !m.isUpcoming(DateTime.now()))
          .toList() ??
      const <Milestone>[];
  final photos = ref.watch(pinnedPhotosProvider(group.id)).value ?? const [];
  if (milestones.isEmpty && photos.isEmpty) return const [];
  return [
    for (final m in milestones)
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          CloserSpacing.gutter,
          CloserSpacing.md,
          CloserSpacing.gutter,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: MilestoneView(milestone: m, group: group),
        ),
      ),
    if (photos.isNotEmpty)
      SliverToBoxAdapter(
        child: SizedBox(
          height: 132,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              CloserSpacing.gutter,
              CloserSpacing.md,
              CloserSpacing.gutter,
              0,
            ),
            children: [
              for (final p in photos)
                Padding(
                  padding: const EdgeInsets.only(right: CloserSpacing.sm),
                  child: Semantics(
                    button: true,
                    label: 'Pinned photo',
                    child: GestureDetector(
                      onTap: () => openPhotoViewer(
                        context,
                        ref,
                        photos: photos,
                        index: photos.indexOf(p),
                        group: group,
                        currentUserId: ref.read(currentUserIdProvider),
                      ),
                      child: ClipRRect(
                        borderRadius: CloserRadii.mdAll,
                        child: SizedBox(
                          width: 116,
                          child: PhotoImage(photo: p),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
  ];
}

final pinnedPhotosProvider = FutureProvider.autoDispose
    .family<List<Photo>, String>(
      (ref, groupId) => ref.watch(photosBackendProvider).pinnedPhotos(groupId),
    );
