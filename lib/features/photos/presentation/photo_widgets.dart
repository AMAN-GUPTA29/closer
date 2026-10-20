import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/closer_icons.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/presentation/group_widgets.dart';
import '../application/photo_providers.dart';
import '../domain/photo_models.dart';

/// Shows a private photo: resolves its image lazily, with the painted
/// placeholder while loading and a calm fallback on errors.
class PhotoImage extends ConsumerWidget {
  const PhotoImage({
    super.key,
    required this.photo,
    this.variant = PhotoVariant.thumb,
    this.fit = BoxFit.cover,
  });

  final Photo photo;
  final PhotoVariant variant;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(photoImageProvider((photo, variant)));
    return CloserPhoto(
      image: image.value,
      fit: fit,
      placeholderVariant: photo.id.hashCode.abs() % 4,
      semanticLabel:
          photo.caption ??
          'Photo shared by ${photo.uploaderName ?? 'a member'}',
    );
  }
}

/// Group cover: the newest photo's thumbnail when there is one.
class GroupCover extends ConsumerWidget {
  const GroupCover({super.key, required this.group, this.fit = BoxFit.cover});

  final Group group;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = group.latestThumbPath;
    if (path == null) {
      return CloserPhoto(placeholderVariant: group.placeholderVariant);
    }
    // A minimal Photo is enough to resolve the cover thumbnail.
    final cover = Photo(
      id: 'cover-$path',
      groupId: group.id,
      storagePath: path,
      thumbPath: path,
      uploadedAt: group.lastActivityAt,
    );
    final image = ref.watch(photoImageProvider((cover, PhotoVariant.thumb)));
    return CloserPhoto(
      image: image.value,
      fit: fit,
      placeholderVariant: group.placeholderVariant,
    );
  }
}

/// Opens the full-screen viewer for [photos] at [index], with delete and
/// pin actions where the user is allowed to use them.
Future<void> openPhotoViewer(
  BuildContext context,
  WidgetRef ref, {
  required List<Photo> photos,
  required int index,
  required Group group,
  required String? currentUserId,
}) {
  return PhotoViewer.show(
    context,
    initialIndex: index,
    items: [
      for (final p in photos)
        PhotoViewerItem(
          caption: p.caption,
          subtitle:
              '${p.uploaderName ?? 'Member'} · ${formatMediumDate(p.displayDate.toLocal())}',
          heroTag: 'photo-${p.id}',
          builder: (_) => PhotoImage(
            photo: p,
            variant: PhotoVariant.full,
            fit: BoxFit.contain,
          ),
        ),
    ],
    actionsFor: (i) {
      final p = photos[i];
      final canDelete = p.uploaderId == currentUserId || group.isOwner;
      return [
        if (group.isPremium)
          PhotoViewerAction(
            label: p.isPinned ? 'Unpin' : 'Pin to top',
            icon: CloserIcons.pin,
            onSelected: (ctx) async {
              try {
                await ref.read(photoActionsProvider).setPinned(p, !p.isPinned);
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (e) {
                if (ctx.mounted) showFailure(ctx, e);
              }
            },
          ),
        if (canDelete)
          PhotoViewerAction(
            label: 'Delete photo',
            icon: CloserIcons.trash,
            destructive: true,
            onSelected: (ctx) async {
              final ok = await showConfirmationDialog(
                ctx,
                title: 'Delete this photo?',
                message:
                    'It will be removed for everyone in ${group.name}. This '
                    'can’t be undone.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (!ok || !ctx.mounted) return;
              try {
                await ref.read(photoActionsProvider).delete(p);
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (e) {
                if (ctx.mounted) showFailure(ctx, e);
              }
            },
          ),
      ];
    },
  );
}

/// "7 of 10 photos" / "Keeps every photo" line for a group.
String photoHistoryLabel(Group group) => group.isPremium
    ? 'Keeploom Memories · keeps every photo'
    : 'Basic · ${group.photoCount} of ${Group.basicPhotoLimit} photos kept';

/// Small retention notice shown before sharing into a full Basic group.
class RetentionNotice extends StatelessWidget {
  const RetentionNotice({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return NoticeCard(
      icon: CloserIcons.clock,
      title: 'The oldest photo will be removed',
      message:
          '${group.name} keeps its latest ${Group.basicPhotoLimit} photos. '
          'Sharing this one permanently deletes the oldest photo for '
          'everyone. Upgrade to Keeploom Memories to keep them all.',
    );
  }
}

/// A private thumbnail known only by its storage path (covers, notifications).
class ThumbByPath extends ConsumerWidget {
  const ThumbByPath({
    super.key,
    required this.groupId,
    required this.path,
    this.fit = BoxFit.cover,
    this.placeholderVariant = 0,
  });

  final String groupId;
  final String path;
  final BoxFit fit;
  final int placeholderVariant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = Photo(
      id: 'path-$path',
      groupId: groupId,
      storagePath: path,
      thumbPath: path,
      uploadedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    final image = ref.watch(photoImageProvider((photo, PhotoVariant.thumb)));
    return CloserPhoto(
      image: image.value,
      fit: fit,
      placeholderVariant: placeholderVariant,
    );
  }
}
