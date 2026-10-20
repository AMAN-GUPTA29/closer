import 'package:flutter/material.dart';

import '../models/group_type.dart';
import '../theme/closer_theme.dart';
import 'closer_photo.dart';

enum WidgetPreviewSize { small, wide }

/// In-app preview of what a native home-screen widget looks like for one
/// group. This is only a preview; the real widgets are native (Phase 5).
class WidgetPreviewCard extends StatelessWidget {
  const WidgetPreviewCard({
    super.key,
    required this.groupName,
    required this.groupType,
    required this.subtitle,
    this.image,
    this.size = WidgetPreviewSize.small,
    this.placeholderVariant = 0,
    this.cover,
  });

  final String groupName;
  final GroupType groupType;
  final String subtitle;
  final ImageProvider? image;
  final WidgetPreviewSize size;
  final int placeholderVariant;

  /// The group's real cover (e.g. its newest photo); wins over [image].
  final Widget? cover;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final wide = size == WidgetPreviewSize.wide;
    return Semantics(
      label: 'Widget preview for $groupName: $subtitle',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: wide ? 2.1 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: CloserRadii.lgAll,
            border: Border.all(color: c.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child:
                      cover ??
                      CloserPhoto(
                        image: image,
                        placeholderVariant: placeholderVariant,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CloserSpacing.sm,
                  CloserSpacing.xs,
                  CloserSpacing.sm,
                  CloserSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium?.copyWith(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
