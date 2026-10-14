import 'dart:convert';
import 'dart:typed_data';

import 'package:closer/features/groups/data/in_memory_groups_repository.dart';
import 'package:closer/features/photos/application/photo_upload.dart';
import 'package:closer/features/photos/domain/photo_models.dart';

/// A valid 1×1 PNG, so Image.memory can decode it in widget tests.
final tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/58BAwAI/AL+hc2rNAAAAABJRU5ErkJggg==',
);

/// Skips native compression; returns the input as both variants.
class FakeImageProcessor implements ImageProcessor {
  FakeImageProcessor({this.takenAt});

  final DateTime? takenAt;
  int calls = 0;

  @override
  Future<PreparedPhoto> prepare(Uint8List raw) async {
    calls++;
    validateInput(raw);
    return PreparedPhoto(
      original: raw,
      thumbnail: raw,
      width: 1,
      height: 1,
      takenAt: takenAt,
    );
  }
}

/// Uploads [count] photos to [groupId] as the repository's current user.
Future<List<String>> seedPhotos(
  InMemoryGroupsRepository repo,
  String groupId,
  int count, {
  String caption = 'Photo',
}) async {
  final ids = <String>[];
  for (var i = 0; i < count; i++) {
    final slot = await repo.requestUpload(
      groupId,
      clientUploadId:
          'seed-$groupId-${repo.hashCode}-$i-${DateTime.now().microsecondsSinceEpoch}',
      caption: '$caption ${i + 1}',
    );
    await repo.putObject(slot.storagePath, tinyPng);
    await repo.putObject(slot.thumbPath, tinyPng);
    await repo.finalize(slot.photoId);
    ids.add(slot.photoId);
  }
  return ids;
}
