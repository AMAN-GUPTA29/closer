import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/routes.dart';
import '../../core/theme/closer_icons.dart';
import '../../core/theme/closer_theme.dart';
import '../../core/widgets/widgets.dart';
import '../groups/application/group_providers.dart';
import '../groups/domain/group_models.dart';
import '../groups/presentation/group_widgets.dart';
import 'purchases.dart';

/// Explains Basic vs Keeploom Memories for one group and starts a purchase.
/// The group only becomes Premium after the server confirms it.
class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  bool _buying = false;
  bool _restoring = false;
  String? _message;

  Future<void> _buy(Group group) async {
    setState(() {
      _buying = true;
      _message = null;
    });
    final outcome = await ref
        .read(purchaseServiceProvider)
        .buyMemories(group.id);
    if (!mounted) return;
    setState(() {
      _buying = false;
      _message = switch (outcome) {
        PurchaseOutcome.unlocked => null,
        PurchaseOutcome.cancelled => 'Purchase cancelled. Nothing was charged.',
        PurchaseOutcome.pending =>
          'Your purchase is waiting for approval. ${group.name} will upgrade '
              'as soon as it’s approved.',
        PurchaseOutcome.failed =>
          'The purchase didn’t go through. You haven’t been charged.',
      };
    });
    if (outcome == PurchaseOutcome.unlocked) {
      ref
        ..invalidate(groupProvider(group.id))
        ..invalidate(myGroupsProvider);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _message = null;
    });
    try {
      await ref.read(purchaseServiceProvider).restore();
      ref.invalidate(groupProvider(widget.groupId));
      if (mounted) setState(() => _message = 'Purchases are up to date.');
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keeploom Memories'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.group(widget.groupId)),
        ),
      ),
      body: SafeArea(
        child: AsyncBody(
          value: group,
          onRetry: () => ref.invalidate(groupProvider(widget.groupId)),
          builder: _body,
        ),
      ),
    );
  }

  Widget _body(Group group) {
    final c = context.closerColors;
    final service = ref.watch(purchaseServiceProvider);
    final product = ref.watch(_productProvider);
    if (group.isPremium) {
      return EmptyState(
        icon: CloserIcons.crown,
        title: '${group.name} keeps every memory',
        message:
            'Keeploom Memories is active for everyone in this group, including '
            'people who join later.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(CloserSpacing.gutter),
      children: [
        Icon(CloserIcons.crown, color: c.premium, size: 40),
        const SizedBox(height: CloserSpacing.sm),
        Text(
          'Keep every memory from this group',
          style: context.text.headlineMedium,
        ),
        const SizedBox(height: CloserSpacing.xs),
        Text(
          'Basic lets you share the moment. Keeploom Memories lets you keep the '
          'story.',
          style: context.text.bodyLarge,
        ),
        const SizedBox(height: CloserSpacing.xl),
        _Compare(
          label: 'Basic',
          points: [
            'Latest ${Group.basicPhotoLimit} photos',
            'The oldest photo is removed when a new one is shared',
          ],
        ),
        const SizedBox(height: CloserSpacing.md),
        const _Compare(
          label: 'Keeploom Memories',
          highlight: true,
          points: [
            'Every photo, kept for the whole group',
            'Pin favourite memories to the top',
            'One purchase for this group — everyone in it gets it',
          ],
        ),
        const SizedBox(height: CloserSpacing.xl),
        if (service.unavailableReason != null) ...[
          NoticeCard(message: service.unavailableReason!),
          const SizedBox(height: CloserSpacing.md),
        ],
        if (_message != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(_message!, style: context.text.bodyMedium),
          ),
          const SizedBox(height: CloserSpacing.md),
        ],
        CloserButton(
          label: product.value == null
              ? 'Upgrade ${group.name}'
              : 'Upgrade for ${product.value!.priceLabel}',
          icon: const Icon(CloserIcons.sparkle),
          isLoading: _buying,
          onPressed: service.unavailableReason == null
              ? () => _buy(group)
              : null,
        ),
        const SizedBox(height: CloserSpacing.sm),
        CloserButton.ghost(
          label: 'Restore purchases',
          expand: true,
          isLoading: _restoring,
          onPressed: service.unavailableReason == null ? _restore : null,
        ),
        const SizedBox(height: CloserSpacing.md),
        Text(
          'One-time purchase for this group only. Other groups stay as they '
          'are. If a purchase is refunded, the group keeps its photos for '
          '30 days before Basic limits apply again.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

final _productProvider = FutureProvider.autoDispose<StoreProduct?>(
  (ref) => ref.watch(purchaseServiceProvider).memoriesProduct(),
);

class _Compare extends StatelessWidget {
  const _Compare({
    required this.label,
    required this.points,
    this.highlight = false,
  });

  final String label;
  final List<String> points;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return Container(
      padding: const EdgeInsets.all(CloserSpacing.md),
      decoration: BoxDecoration(
        color: highlight ? c.background : c.surfaceMuted,
        borderRadius: CloserRadii.lgAll,
        border: Border.all(
          color: highlight ? c.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.titleMedium),
          const SizedBox(height: CloserSpacing.xs),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    highlight ? CloserIcons.success : CloserIcons.clock,
                    size: 18,
                    color: highlight ? c.accentStrong : c.textTertiary,
                  ),
                  const SizedBox(width: CloserSpacing.xs),
                  Expanded(child: Text(p, style: context.text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
