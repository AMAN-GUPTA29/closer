import 'package:flutter/material.dart';

import '../theme/closer_icons.dart';
import '../theme/closer_theme.dart';
import 'closer_photo.dart';

/// A journal photo memory, as on the Keeploom showcase: a large rounded
/// photo, an optional caption, then "Name · time" with a heart for couples.
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
    this.showHeart = false,
    this.placeholderVariant = 0,
    this.heroTag,
  });

  final ImageProvider? image;
  final String? caption;

  /// Group name, shown after the time in the all-groups journal.
  final String? location;
  final String uploaderName;
  final String dateLabel;
  final bool isPinned;

  /// Decorative heart (couple groups only).
  final bool showHeart;
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
    final meta = [dateLabel, ?location].join(' · ');

    return Semantics(
      button: true,
      label:
          'Photo by $uploaderName, $dateLabel'
          '${location != null ? ', in $location' : ''}'
          '${caption != null ? ': $caption' : ''}'
          '${isPinned ? ', pinned' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: CloserRadii.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: CloserRadii.lgAll,
                    child: AspectRatio(aspectRatio: 4 / 3.2, child: photo),
                  ),
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
                padding: const EdgeInsets.fromLTRB(
                  2,
                  CloserSpacing.sm,
                  2,
                  CloserSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption != null && caption!.isNotEmpty) ...[
                      Text(caption!, style: context.text.titleMedium),
                      const SizedBox(height: 2),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: uploaderName,
                                  style: context.text.bodyMedium?.copyWith(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: ' · $meta',
                                  style: context.text.bodyMedium,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showHeart)
                          Icon(CloserIcons.heart, color: c.accent, size: 20),
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
