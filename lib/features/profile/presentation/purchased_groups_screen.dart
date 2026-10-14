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
import '../../purchases/purchases.dart';

/// Groups with Closer Memories (entitlements belong to groups, so this
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
      ref.invalidate(myGroupsProvider);
      if (mounted) setState(() => _message = 'Purchases are up to date.');
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(myGroupsProvider);
    final service = ref.watch(purchaseServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchased groups'),
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
              Text(
                'Closer Memories belongs to a group: everyone in it keeps every '
                'photo, whoever bought it.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: CloserSpacing.lg),
              if (premium.isEmpty)
                const EmptyState(
                  icon: CloserIcons.crown,
                  title: 'No Closer Memories groups yet',
                  message:
                      'Upgrade a group from its Details tab to keep its whole '
                      'story.',
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
              const SizedBox(height: CloserSpacing.xl),
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
                icon: const Icon(CloserIcons.retry),
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
