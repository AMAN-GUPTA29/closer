import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/presentation/group_widgets.dart';
import 'group_photos_tab.dart';

/// Grid of every photo the group keeps.
class AllPhotosScreen extends ConsumerWidget {
  const AllPhotosScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupProvider(groupId));
    return Scaffold(
      appBar: AppBar(
        title: Text(group.value?.name ?? 'Photos'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.group(groupId)),
        ),
      ),
      body: AsyncBody(
        value: group,
        onRetry: () => ref.invalidate(groupProvider(groupId)),
        builder: (g) => GroupPhotosTab(group: g),
      ),
    );
  }
}
