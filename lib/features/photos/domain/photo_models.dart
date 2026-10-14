import 'package:flutter/foundation.dart';

enum PhotoVariant { thumb, full }

/// An active photo in a group's journal.
@immutable
class Photo {
  const Photo({
    required this.id,
    required this.groupId,
    required this.storagePath,
    required this.thumbPath,
    required this.uploadedAt,
    this.uploaderId,
    this.uploaderName,
    this.caption,
    this.takenAt,
    this.width,
    this.height,
    this.isPinned = false,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    DateTime? ts(String key) {
      final v = json[key] as String?;
      return v == null ? null : DateTime.parse(v);
    }

    final profile = json['profiles'] as Map<String, dynamic>?;
    return Photo(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      uploaderId: json['uploader_id'] as String?,
      uploaderName: profile?['display_name'] as String?,
      storagePath: json['storage_path'] as String,
      thumbPath: json['thumb_path'] as String,
      caption: json['caption'] as String?,
      takenAt: ts('taken_at'),
      uploadedAt: ts('uploaded_at')!,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      isPinned: json['is_pinned'] as bool? ?? false,
    );
  }

  final String id;
  final String groupId;
  final String? uploaderId;
  final String? uploaderName;
  final String storagePath;
  final String thumbPath;
  final String? caption;

  /// When the photo was taken (EXIF or chosen by the uploader), if known.
  final DateTime? takenAt;

  /// When it was shared to the group.
  final DateTime uploadedAt;
  final int? width;
  final int? height;
  final bool isPinned;

  /// The date shown on journal cards: capture date when known.
  DateTime get displayDate => takenAt ?? uploadedAt;

  String pathFor(PhotoVariant v) =>
      v == PhotoVariant.thumb ? thumbPath : storagePath;

  @override
  bool operator ==(Object other) =>
      other is Photo &&
      other.id == id &&
      other.caption == caption &&
      other.isPinned == isPinned;

  @override
  int get hashCode => Object.hash(id, caption, isPinned);
}

/// Keyset cursor for newest-first pagination: (uploaded_at, id).
@immutable
class PhotoCursor {
  const PhotoCursor(this.uploadedAt, this.id);

  factory PhotoCursor.after(Photo p) => PhotoCursor(p.uploadedAt, p.id);

  final DateTime uploadedAt;
  final String id;
}

@immutable
class PhotoPage {
  const PhotoPage({required this.photos, required this.hasMore});

  final List<Photo> photos;
  final bool hasMore;
}

/// Compressed, ready-to-upload image data.
@immutable
class PreparedPhoto {
  const PreparedPhoto({
    required this.original,
    required this.thumbnail,
    required this.width,
    required this.height,
    this.takenAt,
  });

  final Uint8List original;
  final Uint8List thumbnail;
  final int width;
  final int height;

  /// Capture time read from EXIF, if present.
  final DateTime? takenAt;
}

/// What the server returned after an upload became visible.
@immutable
class UploadResult {
  const UploadResult({required this.photoId, required this.removedCount});

  final String photoId;

  /// Older photos removed by Basic retention because of this upload.
  final int removedCount;
}

enum UploadStage {
  preparing('Preparing photo', 0.1),
  uploadingPhoto('Uploading photo', 0.35),
  uploadingThumbnail('Uploading preview', 0.8),
  finishing('Finishing up', 0.92),
  done('Shared', 1);

  const UploadStage(this.label, this.progress);
  final String label;
  final double progress;
}

/// Reserved slot returned by `request_photo_upload`.
@immutable
class UploadSlot {
  const UploadSlot({
    required this.photoId,
    required this.storagePath,
    required this.thumbPath,
    required this.alreadyActive,
  });

  final String photoId;
  final String storagePath;
  final String thumbPath;
  final bool alreadyActive;
}
