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
    this.showChevron = false,
  });

  final String title;
  final String dateLabel;
  final String? highlight;
  final String? highlightCaption;

  /// Not shown in the compact row; the detail sheet shows it.
  final String? description;
  final MilestoneTheme theme;
  final bool isPinned;
  final ImageProvider? cover;
  final VoidCallback? onTap;
  final int placeholderVariant;

  /// A chevron on the right (lists that open details); otherwise a pin
  /// marks pinned moments.
  final bool showChevron;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ScaleTransition(
                      scale: Tween(begin: 0.6, end: 1.0).animate(scale),
                      child: Icon(_icon, color: accent, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: context.text.headlineSmall?.copyWith(
                              fontSize: 19,
                              height: 1.25,
                            ),
                          ),
                          Text(
                            widget.isPinned
                                ? '${widget.dateLabel} · pinned'
                                : widget.dateLabel,
                            style: context.text.bodySmall?.copyWith(
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.showChevron)
                      Icon(
                        CloserIcons.chevronRight,
                        color: c.textPrimary,
                        size: 18,
                      )
                    else if (widget.isPinned)
                      Icon(CloserIcons.pin, color: c.textSecondary, size: 16),
                  ],
                ),
                if (widget.cover != null) ...[
                  const SizedBox(height: CloserSpacing.sm),
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
