import 'package:closer/core/errors/app_failure.dart';
import 'package:closer/core/models/group_type.dart';
import 'package:closer/core/widgets/milestone_card.dart';
import 'package:closer/features/groups/data/in_memory_groups_repository.dart';
import 'package:closer/features/journal/data/in_memory_content_backend.dart';
import 'package:closer/features/journal/domain/journal_models.dart';
import 'package:closer/features/journal/presentation/journal_list.dart';
import 'package:closer/features/notifications/domain/notification_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/photo_fakes.dart';

void main() {
  group('Milestone model', () {
    test('parses rows and highlights round numbers', () {
      final m = Milestone.fromJson({
        'id': 'm1',
        'group_id': 'g1',
        'title': '100 days together',
        'type': 'days_together',
        'event_date': '2024-04-12',
        'description': null,
        'cover_photo_id': null,
        'cover': {'thumb_path': 'g1/p/thumb.jpg'},
        'created_by': 'u1',
        'theme': 'heart',
        'is_pinned': true,
      });
      expect(m.type, MilestoneType.daysTogether);
      expect(m.theme, MilestoneTheme.heart);
      expect(m.eventDate, DateTime(2024, 4, 12));
      expect(m.highlightNumber, '100');
      expect(m.coverThumbPath, 'g1/p/thumb.jpg');
      expect(
        Milestone.fromJson({
          'id': 'm',
          'group_id': 'g',
          'title': 'Our 2nd trip',
          'event_date': '2024-01-01',
          'type': 'weird',
          'theme': 'weird',
        }).highlightNumber,
        isNull,
      );
    });

    test('drafts trim text and drop empty descriptions', () {
      final json = MilestoneDraft(
        title: '  Reunion  ',
        type: MilestoneType.reunion,
        eventDate: DateTime(2024, 12, 22),
        theme: MilestoneTheme.celebration,
        description: '   ',
      ).toJson();
      expect(json['title'], 'Reunion');
      expect(json['description'], isNull);
      expect(json['event_date'], '2024-12-22');
      expect(json['theme'], 'celebration');
    });

    test('templates: hearts are for couples', () {
      for (final t in [GroupType.friends, GroupType.family]) {
        expect(
          MilestoneTemplate.forGroup(t)
              .any((x) => x.theme == MilestoneTheme.heart),
          isFalse,
        );
      }
      expect(
        MilestoneTemplate.forGroup(GroupType.couple).first.theme,
        MilestoneTheme.heart,
      );
    });
  });

  group('Journal entries', () {
    test('parse photo, milestone and skip unknown kinds', () {
      final photo = JournalEntry.fromJson({
        'kind': 'photo',
        'id': 'p1',
        'group_id': 'g1',
        'occurred_at': '2024-04-12T10:00:00Z',
        'photo': {
          'id': 'p1',
          'group_id': 'g1',
          'storage_path': 'a',
          'thumb_path': 'b',
          'uploaded_at': '2024-04-12T10:00:00Z',
        },
      });
      expect(photo, isA<PhotoEntry>());
      final milestone = JournalEntry.fromJson({
        'kind': 'milestone',
        'id': 'm1',
        'group_id': 'g1',
        'occurred_at': '2024-04-12T23:59:59Z',
        'milestone': {
          'id': 'm1',
          'group_id': 'g1',
          'title': 'Trip',
          'event_date': '2024-04-12',
        },
      });
      expect(milestone, isA<MilestoneEntry>());
      expect(
        entryDay(milestone!),
        DateTime(2024, 4, 12),
        reason: 'milestones use their calendar date, never a shifted instant',
      );
      expect(
        JournalEntry.fromJson({
          'kind': 'poll',
          'occurred_at': '2024-01-01T00:00:00Z',
        }),
        isNull,
      );
    });
  });

  group('Couple countdowns', () {
    test('next round number and next anniversary', () {
      final start = DateTime(2024, 1, 1);
      final cds = coupleCountdowns(start, DateTime(2024, 4, 1)); // day 92
      expect(cds.first.label, '100 days together');
      expect(cds.first.daysLeft, 8);
      expect(cds.first.date, DateTime(2024, 4, 9));
      expect(cds.last.label, '1st anniversary');
      expect(cds.last.date, DateTime(2025, 1, 1));
    });

    test('an anniversary today counts down to the next one', () {
      final cds = coupleCountdowns(
        DateTime(2022, 6, 15),
        DateTime(2024, 6, 15),
      );
      final anniversary = cds.firstWhere(
        (c) => c.label.contains('anniversary'),
      );
      expect(anniversary.label, '3rd anniversary');
      expect(anniversary.date, DateTime(2025, 6, 15));
    });

    test('29 February anniversaries fall on 28 February', () {
      final cds = coupleCountdowns(
        DateTime(2024, 2, 29),
        DateTime(2024, 10, 1),
      );
      expect(
        cds.firstWhere((c) => c.label.contains('anniversary')).date,
        DateTime(2025, 2, 28),
      );
    });

    test('future start dates have no countdowns', () {
      expect(
        coupleCountdowns(DateTime(2030, 1, 1), DateTime(2024, 1, 1)),
        isEmpty,
      );
    });
  });

  group('Notifications', () {
    test('parse and describe without captions', () {
      final n = AppNotification.fromJson({
        'id': 7,
        'group_id': 'g1',
        'kind': 'photo_added',
        'created_at': '2024-05-01T10:00:00Z',
        'read_at': null,
        'photo_id': 'p1',
        'milestone_id': null,
        'actor': {'display_name': 'Emma'},
        'photo': null,
        'milestone': null,
      });
      expect(n.isUnread, isTrue);
      expect(n.message('My Love'), 'Emma shared a new photo in My Love');
      expect(
        n.photoThumbPath,
        isNull,
        reason: 'removed photos degrade gracefully',
      );
      expect(
        AppNotification.fromJson({
          'id': 8,
          'group_id': 'g1',
          'kind': 'something_new',
          'created_at': '2024-05-01T10:00:00Z',
        }).message('Crew'),
        'New activity in Crew',
      );
    });

    test('preferences round-trip', () {
      const p = NotificationPreferences(photos: false);
      expect(NotificationPreferences.fromJson(p.toJson()), p);
    });
  });

  group('In-memory content rules (mirror the server)', () {
    late InMemoryGroupsRepository groups;
    late InMemoryContentBackend content;
    late String g;

    setUp(() async {
      groups = InMemoryGroupsRepository(currentUserId: 'alice');
      content = InMemoryContentBackend(groups);
      g = await groups.createGroup(name: 'Crew', type: GroupType.friends);
    });

    MilestoneDraft draft(String title, DateTime date, {String? cover}) =>
        MilestoneDraft(
          title: title,
          type: MilestoneType.custom,
          eventDate: date,
          theme: MilestoneTheme.neutral,
          coverPhotoId: cover,
        );

    test(
      'deleted cover photos never leave broken milestone references',
      () async {
        final ids = await seedPhotos(groups, g, 1);
        final m = await content.createMilestone(
          g,
          draft('Trip', DateTime(2024), cover: ids.single),
        );
        expect((await content.milestones(g)).single.coverThumbPath, isNotNull);
        await groups.deletePhoto(ids.single);
        final after = (await content.milestones(g)).single;
        expect(after.id, m.id);
        expect(after.coverPhotoId, isNull);
        expect(after.coverThumbPath, isNull);
      },
    );

    test('covers must come from the same group', () async {
      final other = await groups.createGroup(
        name: 'Other',
        type: GroupType.family,
      );
      final ids = await seedPhotos(groups, other, 1);
      await expectLater(
        content.createMilestone(
          g,
          draft('Bad', DateTime(2024), cover: ids.single),
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('journal mixes photos and past milestones only', () async {
      await seedPhotos(groups, g, 2);
      await content.createMilestone(g, draft('Past', DateTime(2020)));
      await content.createMilestone(
        g,
        draft('Future', DateTime.now().add(const Duration(days: 30))),
      );
      final page = await content.journal(groupId: g);
      expect(page.entries.whereType<PhotoEntry>(), hasLength(2));
      expect(
        page.entries.whereType<MilestoneEntry>().map((e) => e.milestone.title),
        ['Past'],
      );
      expect(page.entries.last, isA<MilestoneEntry>(), reason: 'oldest last');
    });

    test('only the creator or owner edits a milestone', () async {
      groups.addMember(g, 'bob', 'Bob');
      final m = await content.createMilestone(g, draft('Mine', DateTime(2024)));
      groups.currentUserId = 'bob';
      await expectLater(
        content.updateMilestone(m.id, draft('Hijack', DateTime(2024))),
        throwsA(isA<PermissionFailure>()),
      );
      await expectLater(
        content.deleteMilestone(m.id),
        throwsA(isA<PermissionFailure>()),
      );
    });
  });
}
