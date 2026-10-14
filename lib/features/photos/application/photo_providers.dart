import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../auth/application/auth_providers.dart';
import '../../groups/application/group_providers.dart';
import '../data/photos_backend.dart';
import '../domain/photo_models.dart';
import 'photo_upload.dart';

/// Photos backend for the session. In Preview mode the in-memory groups
/// backend also stores photos, so both share one instance.
final photosBackendProvider = Provider<PhotosBackend>((ref) {
  final groups = ref.watch(groupsBackendProvider);
  if (groups is PhotosBackend) return groups as PhotosBackend;
  if (!ref.watch(authRepositoryProvider).isConfigured) {
    return const UnconfiguredPhotosBackend();
  }
  return SupabasePhotosBackend(sb.Supabase.instance.client);
});

final imageProcessorProvider = Provider<ImageProcessor>(
  (ref) => const NativeImageProcessor(),
);

enum PhotoSource { gallery, camera }

/// Picks raw image bytes. Overridden in tests.
typedef PhotoPicker = Future<Uint8List?> Function(PhotoSource source);

final photoPickerProvider = Provider<PhotoPicker>((ref) {
  final picker = ImagePicker();
  return (source) async {
    final file = await picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // Full quality here; our own compression runs afterwards.
      requestFullMetadata: true,
    );
    return file?.readAsBytes();
  };
});

/// Resolved image for a photo variant (signed URL + disk cache in Supabase).
final photoImageProvider = FutureProvider.autoDispose
    .family<ImageProvider, (Photo, PhotoVariant)>(
      (ref, key) => ref.watch(photosBackendProvider).image(key.$1, key.$2),
    );

/// A group's journal photos, newest first, loaded page by page.
class PhotoFeed {
  const PhotoFeed({
    required this.photos,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<Photo> photos;
  final bool hasMore;
  final bool loadingMore;

  PhotoFeed copyWith({List<Photo>? photos, bool? hasMore, bool? loadingMore}) =>
      PhotoFeed(
        photos: photos ?? this.photos,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

final groupPhotosProvider = AsyncNotifierProvider.autoDispose
    .family<GroupPhotos, PhotoFeed, String>(GroupPhotos.new);

class GroupPhotos extends AsyncNotifier<PhotoFeed> {
  GroupPhotos(this.groupId);

  final String groupId;
  static const pageSize = 30;

  @override
  Future<PhotoFeed> build() async {
    final page = await ref
        .watch(photosBackendProvider)
        .photos(groupId, limit: pageSize);
    return PhotoFeed(photos: page.photos, hasMore: page.hasMore);
  }

  /// Appends the next page; keeps existing items so scroll position holds.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(photosBackendProvider)
          .photos(
            groupId,
            before: PhotoCursor.after(current.photos.last),
            limit: pageSize,
          );
      state = AsyncData(
        PhotoFeed(
          photos: [...current.photos, ...page.photos],
          hasMore: page.hasMore,
        ),
      );
    } catch (_) {
      // Keep what we have; the user can scroll again to retry.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final photoActionsProvider = Provider<PhotoActions>(PhotoActions.new);

class PhotoActions {
  PhotoActions(this._ref);

  final Ref _ref;

  PhotosBackend get _backend => _ref.read(photosBackendProvider);

  void _refresh(String groupId) {
    _ref
      ..invalidate(groupPhotosProvider(groupId))
      ..invalidate(groupProvider(groupId))
      ..invalidate(myGroupsProvider);
  }

  Future<UploadResult> upload({
    required String groupId,
    required String clientUploadId,
    required PreparedPhoto photo,
    String? caption,
    DateTime? takenAt,
    void Function(UploadStage stage)? onStage,
  }) async {
    final result = await PhotoUploader(_backend).upload(
      groupId: groupId,
      clientUploadId: clientUploadId,
      photo: photo,
      caption: caption,
      takenAt: takenAt,
      onStage: onStage,
    );
    _refresh(groupId);
    return result;
  }

  Future<void> delete(Photo photo) async {
    await _backend.deletePhoto(photo.id);
    _refresh(photo.groupId);
  }

  Future<void> setPinned(Photo photo, bool pinned) async {
    await _backend.setPinned(photo.id, pinned);
    _ref.invalidate(groupPhotosProvider(photo.groupId));
  }
}
