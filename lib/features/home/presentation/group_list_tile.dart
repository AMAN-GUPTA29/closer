import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/domain/group_models.dart';
import '../../journal/application/content_providers.dart';
import '../../journal/domain/journal_models.dart';
import '../../photos/presentation/photo_widgets.dart';

/// A group row (Home and All groups): cover, name, then who is in it and
/// what happened last, as on the Keeploom concept.
class GroupListTile extends ConsumerWidget {
  const GroupListTile(this.group, {super.key, this.detailed = false});

  final Group group;

  /// "Family · 4 people · active just now" (Your groups) instead of faces.
  final bool detailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMembersProvider(group.id)).value ?? const [];
    final me = ref.watch(currentUserIdProvider);
    final others = [
      for (final m in members)
        if (m.userId != me) m,
    ];
    final now = DateTime.now();
    final photos = [
      for (final e in ref.watch(journalProvider(null)).value?.entries ?? [])
        if (e is PhotoEntry && e.photo.groupId == group.id) e.photo,
    ];
    final fresh = photos
        .where(
          (p) =>
              p.uploaderId != me &&
              now.difference(p.uploadedAt.toLocal()).inHours < 24,
        )
        .length;

    String firstName(String? name) =>
        (name ?? '').trim().split(' ').firstOrNull ?? '';

    final String activity;
    var faces = true;
    if (group.hasCounter) {
      final partner = members.where((m) => m.userId != me).firstOrNull;
      final days = daysTogether(group.relationshipStartDate!, now);
      activity = partner == null
          ? daysTogetherLabel(days)
          : 'You and ${firstName(partner.displayName)} · $days '
                '${days == 1 ? 'day' : 'days'}';
      faces = false;
    } else if (detailed) {
      final n = group.memberCount;
      activity =
          '${group.type.label} · $n ${n == 1 ? 'person' : 'people'} · '
          'active ${relativeTime(group.lastActivityAt, now)}';
      faces = false;
    } else if (photos.isNotEmpty) {
      final last = photos.first;
      final who = last.uploaderId == me ? 'You' : firstName(last.uploaderName);
      activity = '$who, ${relativeTime(last.uploadedAt, now)}';
    } else {
      activity = 'Active ${relativeTime(group.lastActivityAt, now)}';
    }

    return GroupCard(
      members: faces && others.isNotEmpty ? MemberFaces(others) : null,
      name: group.name,
      type: group.type,
      memberCount: group.memberCount,
      activity: activity,
      showCount: faces,
      badge: fresh > 0 ? '$fresh new' : null,
      placeholderVariant: group.placeholderVariant,
      isPremium: group.isPremium,
      coverWidget: GroupCover(group: group),
      onTap: () => context.push(Routes.group(group.id)),
    );
  }
}

/// Up to six overlapping member photos (initials when there is none).
class MemberFaces extends ConsumerWidget {
  const MemberFaces(this.members, {super.key});

  final List<GroupMember> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = <String, ImageProvider>{};
    for (final m in members.take(6)) {
      final path = m.avatarPath;
      if (path == null) continue;
      final image = ref.watch(avatarImageProvider(path)).value;
      if (image != null) images[m.displayName] = image;
    }
    return AvatarStack(
      names: [for (final m in members) m.displayName],
      images: images,
      size: 28,
      showOverflow: false,
    );
  }
}
