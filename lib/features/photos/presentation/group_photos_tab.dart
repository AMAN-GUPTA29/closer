import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/presentation/group_widgets.dart';
import '../application/photo_providers.dart';
import 'photo_widgets.dart';

/// Newest-first photo grid with infinite scroll. (The full journal with
/// milestones arrives in Phase 4.)
class GroupPhotosTab extends ConsumerWidget {
  const GroupPhotosTab({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(groupPhotosProvider(group.id));
    final myId = ref.watch(currentUserIdProvider);
    return AsyncBody(
      value: feed,
      onRetry: () => ref.invalidate(groupPhotosProvider(group.id)),
      builder: (data) {
        if (data.photos.isEmpty) {
          return EmptyState(
            icon: CloserIcons.gallery,
            title: 'No memories yet',
            message: 'Share the first photo with ${group.name}.',
            action: CloserButton(
              label: 'Share a photo',
              icon: const Icon(CloserIcons.plus),
              onPressed: () => context.push(Routes.addMemory(group.id)),
            ),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 600) {
              ref.read(groupPhotosProvider(group.id).notifier).loadMore();
            }
            return false;
          },
          child: CustomScrollView(
            key: PageStorageKey('photos-${group.id}'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  CloserSpacing.gutter,
                  CloserSpacing.md,
                  CloserSpacing.gutter,
                  CloserSpacing.xs,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    photoHistoryLabel(group),
                    style: context.text.bodySmall,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CloserSpacing.gutter,
                  vertical: CloserSpacing.xs,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: CloserSpacing.xs,
                    crossAxisSpacing: CloserSpacing.xs,
                  ),
                  itemCount: data.photos.length,
                  itemBuilder: (context, i) {
                    final p = data.photos[i];
                    return Semantics(
                      button: true,
                      label:
                          '${p.caption ?? 'Photo'} by ${p.uploaderName ?? 'a member'}'
                          '${p.isPinned ? ', pinned' : ''}',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => openPhotoViewer(
                          context,
                          ref,
                          photos: data.photos,
                          index: i,
                          group: group,
                          currentUserId: myId,
                        ),
                        child: ClipRRect(
                          borderRadius: CloserRadii.mdAll,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Hero(
                                tag: 'photo-${p.id}',
                                child: PhotoImage(photo: p),
                              ),
                              if (p.isPinned)
                                const Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Icon(
                                    CloserIcons.pinFilled,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (data.loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(CloserSpacing.lg),
                    child: LoadingState(),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      MediaQuery.paddingOf(context).bottom + CloserSpacing.xl,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
