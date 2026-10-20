import 'package:flutter/material.dart';

import '../models/group_type.dart';
import '../theme/closer_icons.dart';
import '../theme/closer_theme.dart';
import 'closer_photo.dart';

/// A row card for the Home group list, as on the Keeploom board: a large
/// rounded cover, the group name with a chevron, member faces with a count,
/// and a latest-activity line.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.name,
    required this.type,
    required this.memberCount,
    required this.onTap,
    this.cover,
    this.coverWidget,
    this.members,
    this.activity,
    this.isPremium = false,
    this.placeholderVariant = 0,
  });

  final String name;
  final GroupType type;
  final int memberCount;
  final VoidCallback onTap;
  final ImageProvider? cover;

  /// Custom cover (e.g. a lazily resolved private photo); wins over [cover].
  final Widget? coverWidget;

  /// Overlapping member faces (an [AvatarStack]), shown before the count.
  final Widget? members;

  /// e.g. "182 days together", "Active 2h ago".
  final String? activity;
  final bool isPremium;
  final int placeholderVariant;

  static const double coverSize = 64;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final membersLabel =
        '$memberCount ${memberCount == 1 ? 'member' : 'members'}';
    final meta = context.text.bodyMedium?.copyWith(fontSize: 13.5);

    // A list row, not a card: cover, name, faces and one line of activity
    // (Impeccable redesign). Rows sit on the page ground between rules.
    return Semantics(
      button: true,
      label:
          '$name, ${type.label} group, $membersLabel'
          '${activity != null ? ', $activity' : ''}'
          '${isPremium ? ', Keeploom Memories' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: CloserRadii.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CloserSpacing.sm),
          child: Row(
            children: [
              SizedBox.square(
                dimension: coverSize,
                child: ClipRRect(
                  borderRadius: CloserRadii.mdAll,
                  child:
                      coverWidget ??
                      CloserPhoto(
                        image: cover,
                        placeholderVariant: placeholderVariant,
                      ),
                ),
              ),
              const SizedBox(width: CloserSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium,
                          ),
                        ),
                        if (type == GroupType.couple) ...[
                          const SizedBox(width: 6),
                          Icon(CloserIcons.heart, size: 15, color: c.accent),
                        ],
                        if (isPremium) ...[
                          const SizedBox(width: CloserSpacing.xxs),
                          Icon(CloserIcons.crown, size: 15, color: c.premium),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (members != null) ...[
                          members!,
                          const SizedBox(width: CloserSpacing.xs),
                        ],
                        // Faces already show who is here; the count is
                        // only written out when there are no faces yet.
                        if (members == null)
                          Flexible(
                            child: Text(
                              membersLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: meta,
                            ),
                          ),
                        if (activity != null) ...[
                          if (members == null) Text(' · ', style: meta),
                          Flexible(
                            flex: 2,
                            child: Text(
                              activity!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: meta,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CloserSpacing.xs),
              Icon(CloserIcons.chevronRight, color: c.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
