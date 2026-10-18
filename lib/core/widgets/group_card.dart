import 'package:flutter/material.dart';

import '../models/group_type.dart';
import '../theme/closer_icons.dart';
import '../theme/closer_theme.dart';
import 'closer_photo.dart';

/// A row card for the Home group list: cover photo, name, type and member
/// count, and a latest-activity line.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.name,
    required this.type,
    required this.memberCount,
    required this.onTap,
    this.cover,
    this.coverWidget,
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

  /// e.g. "182 days together", "3 new memories", "New photo 2h ago".
  final String? activity;
  final bool isPremium;
  final int placeholderVariant;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final tint = type.tint(c);
    final members = '$memberCount ${memberCount == 1 ? 'member' : 'members'}';

    return Semantics(
      button: true,
      label:
          '$name, ${type.label} group, $members'
          '${activity != null ? ', $activity' : ''}'
          '${isPremium ? ', Keeploom Memories' : ''}',
      excludeSemantics: true,
      // The shadow sits behind the opaque Material; a shadow on a transparent
      // box inside it would tint the whole card grey.
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: CloserRadii.lgAll,
          boxShadow: CloserElevation.low,
        ),
        child: Material(
          color: c.surface,
          borderRadius: CloserRadii.lgAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(CloserSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    height: 80,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: CloserRadii.mdAll,
                          child:
                              coverWidget ??
                              CloserPhoto(
                                image: cover,
                                placeholderVariant: placeholderVariant,
                              ),
                        ),
                        if (type == GroupType.couple)
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: c.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CloserIcons.heart,
                                size: 14,
                                color: c.accent,
                              ),
                            ),
                          ),
                      ],
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
                            if (isPremium) ...[
                              const SizedBox(width: CloserSpacing.xxs),
                              Icon(
                                CloserIcons.crown,
                                size: 16,
                                color: c.premium,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${type.label} · $members',
                          style: context.text.bodySmall,
                        ),
                        if (activity != null) ...[
                          const SizedBox(height: CloserSpacing.xs),
                          Row(
                            children: [
                              Icon(type.icon, size: 14, color: tint),
                              const SizedBox(width: CloserSpacing.xxs),
                              Flexible(
                                child: Text(
                                  activity!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelSmall?.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    CloserIcons.chevronRight,
                    color: c.textTertiary,
                    size: 18,
                  ),
                  const SizedBox(width: CloserSpacing.xs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
