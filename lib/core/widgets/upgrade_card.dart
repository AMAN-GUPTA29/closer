import 'package:flutter/material.dart';

import '../theme/closer_icons.dart';
import '../theme/closer_theme.dart';
import 'closer_button.dart';

/// Promotes Keeploom Memories (group-level Premium). When [unavailableReason]
/// is set the purchase button is disabled and the reason is shown, so the
/// card never pretends a purchase is possible when billing is not set up.
class UpgradeCard extends StatelessWidget {
  const UpgradeCard({
    super.key,
    required this.groupName,
    required this.onUpgrade,
    this.priceLabel,
    this.isLoading = false,
    this.unavailableReason,
    this.photoLimit = 10,
  });

  final String groupName;
  final VoidCallback? onUpgrade;

  /// Localised store price, e.g. "$9.99". Hidden until the store provides it.
  final String? priceLabel;
  final bool isLoading;
  final String? unavailableReason;
  final int photoLimit;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return Container(
      padding: const EdgeInsets.all(CloserSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: CloserRadii.xlAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accentSoft, c.surface],
        ),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CloserIcons.crown, color: c.premium, size: 22),
              const SizedBox(width: CloserSpacing.xs),
              Text(
                'Keeploom Memories',
                style: context.text.labelLarge?.copyWith(color: c.accentStrong),
              ),
            ],
          ),
          const SizedBox(height: CloserSpacing.sm),
          Text(
            'Keep every memory from this group',
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: CloserSpacing.xs),
          Text(
            'Basic groups keep the latest $photoLimit photos. Upgrade '
            '$groupName once and everyone in it keeps the full story — '
            'every photo, milestone and moment.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: CloserSpacing.lg),
          if (unavailableReason != null) ...[
            Text(
              unavailableReason!,
              style: context.text.bodySmall?.copyWith(color: c.textTertiary),
            ),
            const SizedBox(height: CloserSpacing.sm),
          ],
          CloserButton(
            label: priceLabel == null
                ? 'Upgrade this group'
                : 'Upgrade for $priceLabel',
            icon: const Icon(CloserIcons.sparkle),
            isLoading: isLoading,
            onPressed: unavailableReason == null ? onUpgrade : null,
          ),
        ],
      ),
    );
  }
}
