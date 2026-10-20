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
    final accent = switch (widget.theme) {
      MilestoneTheme.heart => c.accent,
      MilestoneTheme.celebration => const Color(0xFFD9822B),
      MilestoneTheme.neutral => c.textSecondary,
    };
    final scale = CurvedAnimation(
      parent: _intro,
      curve: CloserMotion.emphasized,
    );
    final title = widget.highlight != null
        ? '${widget.highlight} ${widget.highlightCaption ?? ''}'.trim()
        : widget.title;

    return Semantics(
      button: widget.onTap != null,
      label:
          '${widget.highlight != null ? '${widget.highlight} ${widget.highlightCaption ?? ''}, ' : ''}'
          '${widget.title}, ${widget.dateLabel}'
          '${widget.isPinned ? ', pinned' : ''}',
      excludeSemantics: true,
      child: Material(
        color: c.surfaceMuted,
        borderRadius: CloserRadii.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CloserSpacing.md,
              CloserSpacing.md,
              CloserSpacing.md,
              CloserSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ScaleTransition(
                        scale: Tween(begin: 0.6, end: 1.0).animate(scale),
                        child: Icon(_icon, color: accent, size: 22),
                      ),
                    ),
                    const SizedBox(width: CloserSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.text.headlineSmall),
                          if (widget.highlight != null)
                            Text(widget.title, style: context.text.bodyMedium),
                          const SizedBox(height: 2),
                          Text(
                            widget.isPinned
                                ? '${widget.dateLabel} · pinned'
                                : widget.dateLabel,
                            style: context.text.bodyMedium,
                          ),
                          if (widget.description != null) ...[
                            const SizedBox(height: CloserSpacing.xs),
                            Text(
                              widget.description!,
                              style: context.text.bodyMedium?.copyWith(
                                color: c.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.isPinned)
                      Icon(
                        CloserIcons.pinFilled,
                        color: c.textSecondary,
                        size: 16,
                      ),
                  ],
                ),
                if (widget.cover != null) ...[
                  const SizedBox(height: CloserSpacing.md),
                  ClipRRect(
                    borderRadius: CloserRadii.mdAll,
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
