import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/domain/group_models.dart';
import '../../journal/application/content_providers.dart';
import '../../photos/presentation/photo_widgets.dart';

/// A group row (Home and All groups): cover, name, member faces, activity.
class GroupListTile extends ConsumerWidget {
  const GroupListTile(this.group, {super.key});

  final Group group;

  String get _activity {
    final now = DateTime.now();
    if (group.hasCounter) {
      return daysTogetherLabel(daysTogether(group.relationshipStartDate!, now));
    }
    return 'Active ${relativeTime(group.lastActivityAt, now)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMembersProvider(group.id)).value ?? const [];
    return GroupCard(
      members: members.isEmpty ? null : MemberFaces(members),
      name: group.name,
      type: group.type,
      memberCount: group.memberCount,
      activity: _activity,
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
      size: 22,
      showOverflow: false,
    );
  }
}
