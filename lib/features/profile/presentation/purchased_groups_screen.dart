import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/presentation/group_widgets.dart';
import '../../photos/presentation/photo_widgets.dart';
import '../../../core/utils/dates.dart';
import '../../groups/domain/group_models.dart';
import '../../purchases/purchases.dart';

final unassignedPurchasesProvider =
    FutureProvider.autoDispose<List<UnassignedPurchase>>(
      (ref) => ref.watch(purchaseServiceProvider).unassignedPurchases(),
    );

/// Groups with Keeploom Memories (entitlements belong to groups, so this
/// includes groups upgraded by other members) and purchase restoration.
class PurchasedGroupsScreen extends ConsumerStatefulWidget {
  const PurchasedGroupsScreen({super.key});

  @override
  ConsumerState<PurchasedGroupsScreen> createState() =>
      _PurchasedGroupsScreenState();
}

class _PurchasedGroupsScreenState extends ConsumerState<PurchasedGroupsScreen> {
  bool _restoring = false;
  String? _message;

  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _message = null;
    });
    try {
      await ref.read(purchaseServiceProvider).restore();
      ref
        ..invalidate(myGroupsProvider)
        ..invalidate(unassignedPurchasesProvider);
      if (mounted) setState(() => _message = 'Purchases are up to date.');
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _apply(UnassignedPurchase p, List<Group> groups) async {
    final candidates = groups.where((g) => !g.isPremium).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All your groups already keep every memory.'),
        ),
      );
      return;
    }
    final chosen = await showModalBottomSheet<Group>(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            CloserSpacing.gutter,
            0,
            CloserSpacing.gutter,
            CloserSpacing.xl,
          ),
          children: [
            Text(
              'Which group should keep every memory?',
              style: sheet.text.titleLarge,
            ),
            const SizedBox(height: CloserSpacing.sm),
            for (final g in candidates)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  g.type.icon,
                  color: g.type.tint(sheet.closerColors),
                ),
                title: Text(g.name, style: sheet.text.titleSmall),
                onTap: () => Navigator.of(sheet).pop(g),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _restoring = true);
    final outcome = await ref
        .read(purchaseServiceProvider)
        .applyPurchase(p.transactionId, chosen.id);
    if (!mounted) return;
    setState(() {
      _restoring = false;
      _message = switch (outcome) {
        PurchaseOutcome.unlocked => '${chosen.name} now keeps every memory.',
        PurchaseOutcome.pending =>
          'Still confirming with the store. Try again in a minute.',
        _ => 'That purchase couldn’t be applied. Contact support if this persists.',
      };
    });
    ref
      ..invalidate(myGroupsProvider)
      ..invalidate(unassignedPurchasesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(myGroupsProvider);
    final unassigned = ref.watch(unassignedPurchasesProvider).value ?? const [];
    final service = ref.watch(purchaseServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keeploom Memories'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.profile),
        ),
      ),
      body: AsyncBody(
        value: groups,
        onRetry: () => ref.invalidate(myGroupsProvider),
        builder: (all) {
          final premium = all.where((g) => g.isPremium).toList();
          return ListView(
            padding: const EdgeInsets.all(CloserSpacing.gutter),
            children: [
              if (premium.isNotEmpty || unassigned.isNotEmpty) ...[
                Text(
                  'Keeploom Memories belongs to a group: everyone in it keeps '
                  'every photo, whoever bought it.',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: CloserSpacing.lg),
              ],
              for (final p in unassigned) ...[
                NoticeCard(
                  icon: CloserIcons.crown,
                  title: 'Unused Keeploom Memories purchase',
                  message:
                      'Bought ${formatMediumDate(p.purchasedAt.toLocal())}. '
                      'Choose the group it should unlock.',
                ),
                const SizedBox(height: CloserSpacing.xs),
                CloserButton(
                  label: 'Choose a group',
                  isLoading: _restoring,
                  onPressed: () => _apply(p, all),
                ),
                const SizedBox(height: CloserSpacing.lg),
              ],
              if (premium.isEmpty)
                const EmptyState(
                  icon: CloserIcons.crown,
                  title: 'No upgraded groups yet',
                  message:
                      'Upgrade a group from its Details tab and everyone in it '
                      'keeps every photo.',
                )
              else
                for (final g in premium)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CloserSpacing.sm),
                    child: GroupCard(
                      name: g.name,
                      type: g.type,
                      memberCount: g.memberCount,
                      isPremium: true,
                      activity: '${g.photoCount} photos kept',
                      coverWidget: GroupCover(group: g),
                      onTap: () => context.push(Routes.group(g.id)),
                    ),
                  ),
              const SizedBox(height: CloserSpacing.md),
              if (service.unavailableReason != null) ...[
                NoticeCard(message: service.unavailableReason!),
                const SizedBox(height: CloserSpacing.sm),
              ],
              if (_message != null) ...[
                Text(_message!, style: context.text.bodyMedium),
                const SizedBox(height: CloserSpacing.sm),
              ],
              CloserButton.secondary(
                label: 'Restore purchases',
                isLoading: _restoring,
                onPressed: service.unavailableReason == null ? _restore : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
