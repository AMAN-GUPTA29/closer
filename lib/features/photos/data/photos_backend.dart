import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/backend_errors.dart';
import '../domain/photo_models.dart';

abstract interface class PhotosBackend {
  /// Newest first; pass [before] to load older photos.
  Future<PhotoPage> photos(String groupId, {PhotoCursor? before, int limit});

  /// Reserves (or, for a retried [clientUploadId], returns) an upload slot.
  Future<UploadSlot> requestUpload(
    String groupId, {
    required String clientUploadId,
    String? caption,
    DateTime? takenAt,
    int? width,
    int? height,
    int? byteSize,
  });

  /// Stores one object. Idempotent: an object that already exists counts as
  /// stored, so a retried upload continues where it stopped.
  Future<void> putObject(String path, Uint8List bytes);

  /// Makes the photo visible and applies retention on the server.
  Future<UploadResult> finalize(String photoId);

  /// Pinned (featured) photos of a group, newest first.
  Future<List<Photo>> pinnedPhotos(String groupId);

  Future<void> deletePhoto(String photoId);
  Future<void> updateCaption(String photoId, String? caption);
  Future<void> setPinned(String photoId, bool pinned);

  /// An image for display; private photos are fetched through short-lived
  /// signed URLs and cached on disk by photo id.
  Future<ImageProvider> image(Photo photo, PhotoVariant variant);

  /// Asks the server to process queued storage deletions (best effort).
  Future<void> requestCleanup();

  /// Raw thumbnail bytes for a storage path (home-screen widgets).
  Future<Uint8List> thumbnailBytes(String path);
}

class UnconfiguredPhotosBackend implements PhotosBackend {
  const UnconfiguredPhotosBackend();

  static const _failure = NotConfiguredFailure(
    'Photo sharing needs the Closer backend, which is not configured in this build.',
  );

  @override
  Future<PhotoPage> photos(
    String groupId, {
    PhotoCursor? before,
    int limit = 30,
  }) => Future.error(_failure);
  @override
  Future<UploadSlot> requestUpload(
    String groupId, {
    required String clientUploadId,
    String? caption,
    DateTime? takenAt,
    int? width,
    int? height,
    int? byteSize,
  }) => Future.error(_failure);
  @override
  Future<void> putObject(String path, Uint8List bytes) =>
      Future.error(_failure);
  @override
  Future<UploadResult> finalize(String photoId) => Future.error(_failure);
  @override
  Future<List<Photo>> pinnedPhotos(String groupId) => Future.error(_failure);
  @override
  Future<void> deletePhoto(String photoId) => Future.error(_failure);
  @override
  Future<void> updateCaption(String photoId, String? caption) =>
      Future.error(_failure);
  @override
  Future<void> setPinned(String photoId, bool pinned) => Future.error(_failure);
  @override
  Future<ImageProvider> image(Photo photo, PhotoVariant variant) =>
      Future.error(_failure);
  @override
  Future<void> requestCleanup() async {}
  @override
  Future<Uint8List> thumbnailBytes(String path) => Future.error(_failure);
}

class SupabasePhotosBackend implements PhotosBackend {
  SupabasePhotosBackend(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const bucket = 'photos';

  /// Signed URLs live for an hour; we reuse them for 50 minutes.
  static const signedUrlLifetime = Duration(hours: 1);
  static const _reuseFor = Duration(minutes: 50);

  final sb.SupabaseClient _db;
  final DateTime Function() _clock;
  final _signed = <String, (String, DateTime)>{};

  @override
  Future<PhotoPage> photos(
    String groupId, {
    PhotoCursor? before,
    int limit = 30,
  }) => guardBackend(() async {
    var query = _db
        .from('photos')
        .select(
          'id, group_id, uploader_id, storage_path, thumb_path, caption, '
          'taken_at, uploaded_at, width, height, is_pinned, '
          'profiles(display_name)',
        )
        .eq('group_id', groupId);
    if (before != null) {
      final ts = before.uploadedAt.toUtc().toIso8601String();
      // Keyset pagination: strictly older than the cursor (ties by id).
      query = query.or(
        'uploaded_at.lt.$ts,and(uploaded_at.eq.$ts,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('uploaded_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit + 1);
    final photos = rows.map(Photo.fromJson).toList();
    final hasMore = photos.length > limit;
    return PhotoPage(
      photos: hasMore ? photos.sublist(0, limit) : photos,
      hasMore: hasMore,
    );
  });

  @override
  Future<UploadSlot> requestUpload(
    String groupId, {
    required String clientUploadId,
    String? caption,
    DateTime? takenAt,
    int? width,
    int? height,
    int? byteSize,
  }) => guardBackend(() async {
    final rows = await _db.rpc<List<dynamic>>(
      'request_photo_upload',
      params: {
        'p_group_id': groupId,
        'p_client_upload_id': clientUploadId,
        'p_caption': caption,
        'p_taken_at': takenAt?.toUtc().toIso8601String(),
        'p_width': width,
        'p_height': height,
        'p_byte_size': byteSize,
      },
    );
    final row = rows.first as Map<String, dynamic>;
    return UploadSlot(
      photoId: row['photo_id'] as String,
      storagePath: row['storage_path'] as String,
      thumbPath: row['thumb_path'] as String,
      alreadyActive: row['status'] == 'active',
    );
  });

  @override
  Future<void> putObject(String path, Uint8List bytes) =>
      guardBackend(() async {
        try {
          await _db.storage
              .from(bucket)
              .uploadBinary(
                path,
                bytes,
                fileOptions: const sb.FileOptions(
                  contentType: 'image/jpeg',
                  upsert: false,
                ),
              );
        } on sb.StorageException catch (e) {
          final duplicate =
              e.statusCode == '409' ||
              e.message.toLowerCase().contains('already exists');
          if (!duplicate) rethrow;
        }
      });

  @override
  Future<UploadResult> finalize(String photoId) => guardBackend(() async {
    final json = await _db.rpc<Map<String, dynamic>>(
      'finalize_photo',
      params: {'p_photo_id': photoId},
    );
    final removed = (json['removed'] as List<dynamic>? ?? const []).length;
    return UploadResult(photoId: photoId, removedCount: removed);
  });

  @override
  Future<List<Photo>> pinnedPhotos(String groupId) => guardBackend(() async {
    final rows = await _db
        .from('photos')
        .select(
          'id, group_id, uploader_id, storage_path, thumb_path, caption, '
          'taken_at, uploaded_at, width, height, is_pinned, '
          'profiles(display_name)',
        )
        .eq('group_id', groupId)
        .eq('is_pinned', true)
        .order('uploaded_at', ascending: false)
        .limit(20);
    return rows.map(Photo.fromJson).toList();
  });

  @override
  Future<void> deletePhoto(String photoId) => guardBackend(
    () => _db.rpc<void>('delete_photo', params: {'p_photo_id': photoId}),
  );

  @override
  Future<void> updateCaption(String photoId, String? caption) =>
      guardBackend(() async {
        final trimmed = caption?.trim();
        await _db
            .from('photos')
            .update({
              'caption': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
            })
            .eq('id', photoId);
      });

  @override
  Future<void> setPinned(String photoId, bool pinned) => guardBackend(
    () => _db.rpc<void>(
      'set_photo_pinned',
      params: {'p_photo_id': photoId, 'p_pinned': pinned},
    ),
  );

  @override
  Future<ImageProvider> image(Photo photo, PhotoVariant variant) =>
      guardBackend(() async {
        final path = photo.pathFor(variant);
        final now = _clock();
        final cached = _signed[path];
        String url;
        if (cached != null && cached.$2.isAfter(now)) {
          url = cached.$1;
        } else {
          url = await _db.storage
              .from(bucket)
              .createSignedUrl(path, signedUrlLifetime.inSeconds);
          _signed[path] = (url, now.add(_reuseFor));
        }
        // Disk cache is keyed by photo id + variant, not the expiring URL.
        return CachedNetworkImageProvider(
          url,
          cacheKey: 'photo-${photo.id}-${variant.name}',
        );
      });

  @override
  Future<Uint8List> thumbnailBytes(String path) =>
      guardBackend(() => _db.storage.from(bucket).download(path));

  @override
  Future<void> requestCleanup() async {
    try {
      await _db.functions.invoke('cleanup-storage');
    } catch (_) {
      // Best effort: the scheduled job processes the queue anyway.
    }
  }
}
