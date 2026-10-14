import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:exif/exif.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../core/errors/app_failure.dart';
import '../data/photos_backend.dart';
import '../domain/photo_models.dart';

/// Supported input formats (detected from file contents, not names).
enum ImageType { jpeg, png, heic, webp }

/// Largest original file we accept before compression.
const maxInputBytes = 30 * 1024 * 1024;

/// Identifies an image by its magic bytes. Returns null when unsupported.
ImageType? detectImageType(Uint8List b) {
  bool at(int offset, List<int> sig) {
    if (b.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (at(0, [0xFF, 0xD8, 0xFF])) return ImageType.jpeg;
  if (at(0, [0x89, 0x50, 0x4E, 0x47])) return ImageType.png;
  if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
    return ImageType.webp;
  }
  if (at(4, [0x66, 0x74, 0x79, 0x70])) {
    final brand = String.fromCharCodes(b.sublist(8, 12));
    if (const {
      'heic',
      'heix',
      'hevc',
      'heim',
      'heis',
      'mif1',
      'msf1',
    }.contains(brand)) {
      return ImageType.heic;
    }
  }
  return null;
}

/// Validates raw picked bytes; throws a friendly [AppFailure] when unusable.
void validateInput(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const UnexpectedFailure('That file is empty.');
  }
  if (bytes.length > maxInputBytes) {
    throw const UnexpectedFailure(
      'That photo is larger than 30 MB. Please choose a smaller one.',
    );
  }
  if (detectImageType(bytes) == null) {
    throw const UnexpectedFailure(
      'That file type isn’t supported. Choose a JPEG, PNG, HEIC or WebP photo.',
    );
  }
}

/// Parses EXIF "2024:04:12 18:31:07" as local time.
DateTime? parseExifDate(String? value) {
  if (value == null) return null;
  final m = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
      .firstMatch(value.trim());
  if (m == null) return null;
  final p = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
  if (p[0] < 1900 || p[1] < 1 || p[1] > 12 || p[2] < 1 || p[2] > 31) {
    return null;
  }
  return DateTime(p[0], p[1], p[2], p[3], p[4], p[5]);
}

/// Turns picked image bytes into an upload-ready original and thumbnail.
abstract interface class ImageProcessor {
  Future<PreparedPhoto> prepare(Uint8List raw);
}

/// Re-encodes as JPEG (short side ≤ 2560 px, thumbnail ≤ 480 px) and drops
/// EXIF metadata such as GPS location. Capture time is read first.
class NativeImageProcessor implements ImageProcessor {
  const NativeImageProcessor();

  static const originalShortSide = 2560;
  static const thumbShortSide = 480;

  @override
  Future<PreparedPhoto> prepare(Uint8List raw) async {
    validateInput(raw);
    DateTime? takenAt;
    try {
      final tags = await readExifFromBytes(raw);
      takenAt = parseExifDate(
        (tags['EXIF DateTimeOriginal'] ?? tags['Image DateTime'])?.printable,
      );
    } catch (_) {
      // Missing or broken EXIF is fine.
    }

    final original = await FlutterImageCompress.compressWithList(
      raw,
      minWidth: originalShortSide,
      minHeight: originalShortSide,
      quality: 85,
      keepExif: false,
    );
    final thumbnail = await FlutterImageCompress.compressWithList(
      original,
      minWidth: thumbShortSide,
      minHeight: thumbShortSide,
      quality: 75,
      keepExif: false,
    );
    if (original.isEmpty || thumbnail.isEmpty) {
      throw const UnexpectedFailure('We couldn’t read that photo.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(original);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = (descriptor.width, descriptor.height);
    descriptor.dispose();
    buffer.dispose();

    return PreparedPhoto(
      original: original,
      thumbnail: thumbnail,
      width: size.$1,
      height: size.$2,
      takenAt: takenAt,
    );
  }
}

/// Runs the upload protocol: reserve → store original → store thumbnail →
/// finalize. Every step is safe to repeat, so [upload] can simply be called
/// again with the same [clientUploadId] after a failure.
class PhotoUploader {
  PhotoUploader(this._backend);

  final PhotosBackend _backend;

  Future<UploadResult> upload({
    required String groupId,
    required String clientUploadId,
    required PreparedPhoto photo,
    String? caption,
    DateTime? takenAt,
    void Function(UploadStage stage)? onStage,
  }) async {
    onStage?.call(UploadStage.preparing);
    final trimmed = caption?.trim();
    final slot = await _backend.requestUpload(
      groupId,
      clientUploadId: clientUploadId,
      caption: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      takenAt: takenAt,
      width: photo.width,
      height: photo.height,
      byteSize: photo.original.length,
    );
    if (slot.alreadyActive) {
      onStage?.call(UploadStage.done);
      return UploadResult(photoId: slot.photoId, removedCount: 0);
    }
    onStage?.call(UploadStage.uploadingPhoto);
    await _backend.putObject(slot.storagePath, photo.original);
    onStage?.call(UploadStage.uploadingThumbnail);
    await _backend.putObject(slot.thumbPath, photo.thumbnail);
    onStage?.call(UploadStage.finishing);
    final result = await _backend.finalize(slot.photoId);
    if (result.removedCount > 0) {
      // Removed photos' files are deleted by the server-side queue.
      await _backend.requestCleanup();
    }
    onStage?.call(UploadStage.done);
    return result;
  }
}
