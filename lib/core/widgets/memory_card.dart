import 'package:flutter/material.dart';

import '../theme/closer_icons.dart';
import '../theme/closer_theme.dart';
import 'closer_photo.dart';
import 'member_avatar.dart';

/// A journal photo memory: large rounded photo, caption, uploader and date.
class MemoryCard extends StatelessWidget {
  const MemoryCard({
    super.key,
    required this.uploaderName,
    required this.dateLabel,
    required this.onTap,
    this.image,
    this.caption,
    this.location,
    this.isPinned = false,
    this.uploaderImage,
    this.placeholderVariant = 0,
    this.heroTag,
  });

  final ImageProvider? image;
  final String? caption;
  final String? location;
  final String uploaderName;
  final ImageProvider? uploaderImage;
  final String dateLabel;
  final bool isPinned;
  final VoidCallback onTap;
  final int placeholderVariant;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    Widget photo = CloserPhoto(
      image: image,
      placeholderVariant: placeholderVariant,
    );
    if (heroTag != null) photo = Hero(tag: heroTag!, child: photo);

    return Semantics(
      button: true,
      label:
          'Photo by $uploaderName, $dateLabel'
          '${caption != null ? ': $caption' : ''}'
          '${isPinned ? ', pinned' : ''}',
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        borderRadius: CloserRadii.lgAll,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(aspectRatio: 4 / 3, child: photo),
                  if (isPinned)
                    Positioned(
                      top: CloserSpacing.sm,
                      right: CloserSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CloserIcons.pinFilled,
                          size: 16,
                          color: c.accentStrong,
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(CloserSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption != null && caption!.isNotEmpty) ...[
                      Text(caption!, style: context.text.titleSmall),
                      const SizedBox(height: CloserSpacing.xxs),
                    ],
                    if (location != null) ...[
                      Text(location!, style: context.text.bodySmall),
                      const SizedBox(height: CloserSpacing.xs),
                    ],
                    Row(
                      children: [
                        MemberAvatar(
                          name: uploaderName,
                          image: uploaderImage,
                          size: 22,
                        ),
                        const SizedBox(width: CloserSpacing.xs),
                        Expanded(
                          child: Text(
                            uploaderName,
                            style: context.text.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          dateLabel,
                          style: context.text.labelSmall?.copyWith(
                            color: c.textTertiary,
                          ),
                        ),
                      ],
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
