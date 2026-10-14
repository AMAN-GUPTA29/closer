import 'package:flutter/material.dart';

import '../theme/closer_icons.dart';
import '../theme/closer_theme.dart';
import 'closer_photo.dart';

/// Visual themes for milestone cards. Hearts are reserved for couples;
/// friends and family get celebratory or neutral treatments.
enum MilestoneTheme { heart, celebration, neutral }

/// A special-moment card with large display typography. When [highlight] is
/// set (e.g. "100"), it is shown as the hero number; otherwise the title is.
class MilestoneCard extends StatefulWidget {
  const MilestoneCard({
    super.key,
    required this.title,
    required this.dateLabel,
    this.highlight,
    this.highlightCaption,
    this.description,
    this.theme = MilestoneTheme.neutral,
    this.isPinned = false,
    this.cover,
    this.onTap,
    this.placeholderVariant = 0,
  });

  final String title;
  final String dateLabel;
  final String? highlight;
  final String? highlightCaption;
  final String? description;
  final MilestoneTheme theme;
  final bool isPinned;
  final ImageProvider? cover;
  final VoidCallback? onTap;
  final int placeholderVariant;

  @override
  State<MilestoneCard> createState() => _MilestoneCardState();
}

class _MilestoneCardState extends State<MilestoneCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: CloserMotion.slow,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CloserMotion.reduced(context)) {
      _intro.value = 1;
    } else if (!_intro.isAnimating && _intro.value == 0) {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.theme) {
    MilestoneTheme.heart => CloserIcons.heart,
    MilestoneTheme.celebration => CloserIcons.confetti,
    MilestoneTheme.neutral => CloserIcons.star,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final (bg, accent) = switch (widget.theme) {
      MilestoneTheme.heart => (c.accentSoft, c.accentStrong),
      MilestoneTheme.celebration => (
        c.premium.withValues(alpha: 0.16),
        const Color(0xFFD9822B),
      ),
      MilestoneTheme.neutral => (c.surfaceMuted, c.familyTint),
    };

    final scale = CurvedAnimation(
      parent: _intro,
      curve: CloserMotion.emphasized,
    );

    return Semantics(
      button: widget.onTap != null,
      label:
          '${widget.highlight != null ? '${widget.highlight} ${widget.highlightCaption ?? ''}, ' : ''}'
          '${widget.title}, ${widget.dateLabel}'
          '${widget.isPinned ? ', pinned' : ''}',
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: CloserRadii.xlAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(CloserSpacing.xl),
            child: Column(
              children: [
                Row(
                  children: [
                    const Spacer(),
                    if (widget.isPinned)
                      Icon(CloserIcons.pinFilled, color: accent, size: 18),
                  ],
                ),
                ScaleTransition(
                  scale: Tween(begin: 0.6, end: 1.0).animate(scale),
                  child: Icon(_icon, color: accent, size: 36),
                ),
                const SizedBox(height: CloserSpacing.sm),
                if (widget.highlight != null) ...[
                  Text(
                    widget.highlight!,
                    style: context.text.displayLarge?.copyWith(color: accent),
                  ),
                  if (widget.highlightCaption != null)
                    Text(
                      widget.highlightCaption!,
                      style: context.text.titleMedium?.copyWith(color: accent),
                    ),
                  const SizedBox(height: CloserSpacing.sm),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: context.text.titleSmall,
                  ),
                ] else
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: context.text.displayMedium?.copyWith(
                      fontSize: 30,
                      color: c.textPrimary,
                    ),
                  ),
                const SizedBox(height: CloserSpacing.xxs),
                Text(
                  widget.dateLabel,
                  style: context.text.labelMedium?.copyWith(color: accent),
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: CloserSpacing.sm),
                  Text(
                    widget.description!,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium,
                  ),
                ],
                if (widget.cover != null) ...[
                  const SizedBox(height: CloserSpacing.md),
                  ClipRRect(
                    borderRadius: CloserRadii.lgAll,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CloserPhoto(
                        image: widget.cover,
                        placeholderVariant: widget.placeholderVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
