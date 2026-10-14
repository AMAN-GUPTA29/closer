import 'dart:typed_data';

import 'package:closer/core/errors/app_failure.dart';
import 'package:closer/core/models/group_type.dart';
import 'package:closer/features/groups/data/in_memory_groups_repository.dart';
import 'package:closer/features/groups/domain/group_models.dart';
import 'package:closer/features/photos/application/photo_upload.dart';
import 'package:closer/features/photos/domain/photo_models.dart';
import 'package:closer/features/photos/presentation/photo_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/photo_fakes.dart';

Uint8List bytes(List<int> head, [int pad = 16]) =>
    Uint8List.fromList([...head, ...List.filled(pad, 0)]);

void main() {
  group('Input validation', () {
    test('detects formats by content', () {
      expect(detectImageType(bytes([0xFF, 0xD8, 0xFF, 0xE0])), ImageType.jpeg);
      expect(detectImageType(tinyPng), ImageType.png);
      expect(
        detectImageType(
          bytes([
            0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, //
          ]),
        ),
        ImageType.webp,
      );
      expect(
        detectImageType(bytes([0, 0, 0, 0x18, ...'ftypheic'.codeUnits])),
        ImageType.heic,
      );
      expect(detectImageType(bytes('GIF89a'.codeUnits)), isNull);
      expect(detectImageType(Uint8List(2)), isNull);
    });

    test('rejects empty, oversized and unsupported files', () {
      expect(() => validateInput(Uint8List(0)), throwsA(isA<AppFailure>()));
      expect(
        () => validateInput(
          Uint8List(maxInputBytes + 1)..setAll(0, [0xFF, 0xD8, 0xFF]),
        ),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.message,
            'message',
            contains('30 MB'),
          ),
        ),
      );
      expect(
        () => validateInput(bytes('%PDF'.codeUnits)),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.message,
            'm',
            contains('supported'),
          ),
        ),
      );
      validateInput(tinyPng);
    });

    test('parses EXIF capture dates', () {
      expect(
        parseExifDate('2024:04:12 18:31:07'),
        DateTime(2024, 4, 12, 18, 31, 7),
      );
      expect(parseExifDate('0000:00:00 00:00:00'), isNull);
      expect(parseExifDate('garbage'), isNull);
      expect(parseExifDate(null), isNull);
    });
  });

  test('Photo.fromJson separates capture and upload time', () {
    final p = Photo.fromJson({
      'id': 'p1',
      'group_id': 'g1',
      'uploader_id': 'u1',
      'storage_path': 'g1/p1/original.jpg',
      'thumb_path': 'g1/p1/thumb.jpg',
      'caption': 'Sunset',
      'taken_at': '2024-04-10T18:00:00Z',
      'uploaded_at': '2024-04-12T09:00:00Z',
      'width': 2560,
      'height': 1920,
      'is_pinned': false,
      'profiles': {'display_name': 'Emma'},
    });
    expect(p.uploaderName, 'Emma');
    expect(p.displayDate, DateTime.utc(2024, 4, 10, 18));
    expect(p.pathFor(PhotoVariant.thumb), 'g1/p1/thumb.jpg');
  });

  group('Group retention helpers', () {
    Group g({int photos = 0, bool premium = false}) => Group(
      id: 'g',
      name: 'Crew',
      type: GroupType.friends,
      createdAt: DateTime(2024),
      lastActivityAt: DateTime(2024),
      memberCount: 2,
      myRole: MemberRole.owner,
      photoCount: photos,
      isPremium: premium,
    );

    test('warns only when a Basic group is full', () {
      expect(g(photos: 9).nextUploadRemovesOldest, isFalse);
      expect(g(photos: 10).nextUploadRemovesOldest, isTrue);
      expect(g(photos: 40, premium: true).nextUploadRemovesOldest, isFalse);
      expect(photoHistoryLabel(g(photos: 7)), 'Basic · 7 of 10 photos kept');
      expect(
        photoHistoryLabel(g(premium: true)),
        contains('keeps every photo'),
      );
    });
  });

  group('PhotoUploader protocol', () {
    late InMemoryGroupsRepository repo;
    late String groupId;
    final prepared = PreparedPhoto(
      original: tinyPng,
      thumbnail: tinyPng,
      width: 1,
      height: 1,
    );

    setUp(() async {
      repo = InMemoryGroupsRepository(currentUserId: 'alice');
      groupId = await repo.createGroup(name: 'Crew', type: GroupType.friends);
    });

    test('reserve → original → thumbnail → finalize', () async {
      final stages = <UploadStage>[];
      final result = await PhotoUploader(repo).upload(
        groupId: groupId,
        clientUploadId: 'u-1',
        photo: prepared,
        caption: '  Beach day  ',
        onStage: stages.add,
      );
      expect(stages, [
        UploadStage.preparing,
        UploadStage.uploadingPhoto,
        UploadStage.uploadingThumbnail,
        UploadStage.finishing,
        UploadStage.done,
      ]);
      final page = await repo.photos(groupId);
      expect(page.photos.single.id, result.photoId);
      expect(page.photos.single.caption, 'Beach day');
    });

    test('a failed upload can be retried without duplicates', () async {
      repo.failNextPut = true;
      await expectLater(
        PhotoUploader(repo)
            .upload(groupId: groupId, clientUploadId: 'u-2', photo: prepared),
        throwsA(isA<AppFailure>()),
      );
      expect((await repo.photos(groupId)).photos, isEmpty);
      await PhotoUploader(repo)
          .upload(groupId: groupId, clientUploadId: 'u-2', photo: prepared);
      // A second retry after success is also harmless.
      await PhotoUploader(repo)
          .upload(groupId: groupId, clientUploadId: 'u-2', photo: prepared);
      expect((await repo.photos(groupId)).photos, hasLength(1));
    });

    test('Basic keeps 10 and removes the oldest; Premium keeps all', () async {
      final ids = await seedPhotos(repo, groupId, 10);
      final result = await PhotoUploader(repo)
          .upload(groupId: groupId, clientUploadId: 'u-11', photo: prepared);
      expect(result.removedCount, 1);
      final page = await repo.photos(groupId);
      expect(page.photos, hasLength(10));
      expect(page.photos.map((p) => p.id), isNot(contains(ids.first)));
      expect(page.photos.first.id, result.photoId, reason: 'newest first');
      expect(
        repo.storedObjects.where((o) => o.contains('/${ids.first}/')),
        isEmpty,
        reason: 'removed photo objects are gone',
      );

      final premium = await repo.createGroup(
        name: 'Fam',
        type: GroupType.family,
      );
      repo.grantPremium(premium);
      await seedPhotos(repo, premium, 12);
      expect((await repo.photos(premium)).photos, hasLength(12));
      expect(
        (await repo.photos(groupId)).photos,
        hasLength(10),
        reason: 'Premium is isolated to its group',
      );
    });

    test('pagination walks newest to oldest without gaps', () async {
      await seedPhotos(repo, groupId, 7);
      final first = await repo.photos(groupId, limit: 3);
      final second = await repo.photos(
        groupId,
        before: PhotoCursor.after(first.photos.last),
        limit: 3,
      );
      final third = await repo.photos(
        groupId,
        before: PhotoCursor.after(second.photos.last),
        limit: 3,
      );
      final all = [...first.photos, ...second.photos, ...third.photos];
      expect(first.hasMore, isTrue);
      expect(third.hasMore, isFalse);
      expect(all.map((p) => p.id).toSet(), hasLength(7));
      for (var i = 1; i < all.length; i++) {
        expect(all[i].uploadedAt.isBefore(all[i - 1].uploadedAt), isTrue);
      }
    });

    test('pinning needs Premium', () async {
      final ids = await seedPhotos(repo, groupId, 1);
      await expectLater(
        repo.setPinned(ids.single, true),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
