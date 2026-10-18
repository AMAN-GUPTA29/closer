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

  static const double coverSize = 120;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final membersLabel =
        '$memberCount ${memberCount == 1 ? 'member' : 'members'}';
    final activityColor = type == GroupType.couple ? c.accent : type.tint(c);
    final activityIcon = type == GroupType.couple
        ? CloserIcons.heart
        : type.icon;

    return Semantics(
      button: true,
      label:
          '$name, ${type.label} group, $membersLabel'
          '${activity != null ? ', $activity' : ''}'
          '${isPremium ? ', Keeploom Memories' : ''}',
      excludeSemantics: true,
      // The shadow sits behind the opaque Material; a shadow on a transparent
      // box inside it would tint the whole card grey.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: CloserRadii.xlAll,
          boxShadow: dark ? CloserElevation.none : CloserElevation.low,
        ),
        child: Material(
          // Dark: the lifted card tone, no outline (as on the board).
          color: dark ? c.surfaceMuted : c.surface,
          shape: const RoundedRectangleBorder(borderRadius: CloserRadii.xlAll),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(CloserSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: coverSize,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: CloserRadii.lgAll,
                          child:
                              coverWidget ??
                              CloserPhoto(
                                image: cover,
                                placeholderVariant: placeholderVariant,
                              ),
                        ),
                        if (type == GroupType.couple)
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Icon(
                              CloserIcons.heart,
                              size: 16,
                              color: Colors.white,
                              shadows: const [
                                Shadow(color: Color(0x66000000), blurRadius: 6),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CloserSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: CloserSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.text.titleLarge,
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
                              ),
                              Icon(
                                CloserIcons.chevronRight,
                                color: c.textTertiary,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: CloserSpacing.xs),
                          Row(
                            children: [
                              if (members != null) ...[
                                members!,
                                const SizedBox(width: CloserSpacing.xs),
                              ],
                              Flexible(
                                child: Text(
                                  membersLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          if (activity != null) ...[
                            const SizedBox(height: CloserSpacing.xs),
                            Row(
                              children: [
                                Icon(
                                  activityIcon,
                                  size: 16,
                                  color: activityColor,
                                ),
                                const SizedBox(width: CloserSpacing.xs),
                                Flexible(
                                  child: Text(
                                    activity!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
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
