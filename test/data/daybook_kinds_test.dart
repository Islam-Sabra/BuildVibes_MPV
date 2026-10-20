import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The other kinds of post as daybook_cards and daybook_extras send them
/// (migrations 19 and 28), copied from the local database: a checklist as
/// Sara (one of its people), an announcement, an activity and a file.
const _space = 's-kct';
const _checklist = {
  'id': 'c1',
  'kind': 'checklist',
  'proof': null,
  'title': 'Handover check',
  'people': [
    {'id': 'p-sara', 'name': 'Sara Al-Mutairi'},
  ],
  'points': {'total': 5, 'ticked': 2},
  'status': 'live',
  'history': [
    {
      'at': '2026-10-19T13:26:37+00:00',
      'id': 'h1',
      'kind': 'ticked',
      'by_id': 'p-sara',
      'point': 'Ceiling paint',
      'by_name': 'Sara Al-Mutairi',
      'point_id': 'pt1',
    },
  ],
  'due_date': '2026-10-22',
  'needs_me': 'to_tick',
  'space_id': _space,
  'author_id': 'p-islam',
  'created_at': '2026-10-19T13:00:00+00:00',
  'author_name': 'Islam Ahmed',
  'history_more': false,
  'last_activity_at': '2026-10-19T13:26:37+00:00',
};

void main() {
  group('cards of the other kinds', () {
    test('a checklist: its people, progress, due, the tick line and the '
        'clip', () {
      final card = DaybookCard.fromJson(_checklist);
      final post = card.post;
      expect(post.isChecklist, isTrue);
      expect(post.people.single.name, 'Sara Al-Mutairi');
      expect((post.pointsTicked, post.pointsTotal), (2, 5));
      expect(post.dueDate, DateTime(2026, 10, 22));
      expect(card.need, DaybookNeed.toTick);
      final line = card.history.single;
      expect(line.kind, DaybookEventKind.ticked);
      expect(line.point, 'Ceiling paint');
      expect(line.pointId, 'pt1');
      expect(line.shown, isTrue);
    });

    test('an announcement: the pin while pinned, and my own Got it', () {
      final post = DaybookPost.fromJson({
        'id': 'a1',
        'kind': 'announcement',
        'title': 'Half day Friday',
        'status': 'live',
        'my_acks': ['got_it', 'something new'],
        'created_at': '2026-10-19T13:00:00+00:00',
        'pinned_until': '2026-10-21T13:00:00+00:00',
      });
      expect(post.myAcks, {DaybookAck.gotIt});
      expect(post.pinnedAt(DateTime.utc(2026, 10, 20)), isTrue);
      expect(post.pinnedAt(DateTime.utc(2026, 10, 22)), isFalse);
      // A cancelled one is never pinned.
      expect(
        post.shownAs(cancelled: true).pinnedAt(DateTime.utc(2026, 10, 20)),
        isFalse,
      );
    });

    test('an activity: start, end, place and people; with no end it lasts '
        'an hour', () {
      final post = DaybookPost.fromJson({
        'id': 'v1',
        'kind': 'activity',
        'title': 'Site walk',
        'status': 'live',
        'place': 'Gate office',
        'people': [
          {'id': 'p-omar', 'name': 'Omar Haddad'},
        ],
        'created_at': '2026-10-19T13:00:00+00:00',
        'starts_at': '2026-10-20T04:00:00+00:00',
      });
      expect(post.isActivity, isTrue);
      expect(post.place, 'Gate office');
      expect(post.activityEnd, DateTime.utc(2026, 10, 20, 5));
    });

    test('a file: the Library file, what it replaces, NEW VERSION', () {
      final post = DaybookPost.fromJson({
        'id': 'f1',
        'kind': 'file',
        'title': 'M-201 Ground floor plan',
        'status': 'live',
        'created_at': '2026-10-19T13:00:00+00:00',
        'stamp': {'kind': 'new_version', 'at': '2026-10-19T13:00:00+00:00'},
        'file': {
          'id': 'lf2',
          'name': 'M-201.pdf',
          'mime': 'application/pdf',
          'path': '$_space/library/lf2/M-201.pdf',
          'bytes': 2400000,
          'rev_label': 'Rev D',
          'replaces': {'name': 'M-201.pdf', 'rev_label': 'Rev C'},
          'has_newer': false,
        },
      });
      final file = post.file!;
      expect(post.newVersion, isTrue);
      expect(file.isPdf, isTrue);
      expect(file.replacesRev, 'Rev C');
      expect(file.revLabel, 'Rev D');
      expect(file.bytes, 2400000);
    });

    test('every acknowledgement line kind is read; an unknown one is kept '
        'for paging but never drawn', () {
      for (final (json, kind) in [
        ('got_it', DaybookEventKind.gotIt),
        ('received', DaybookEventKind.received),
        ('on_my_way', DaybookEventKind.onMyWay),
        ('in_my_calendar', DaybookEventKind.inMyCalendar),
        ('unticked', DaybookEventKind.unticked),
      ]) {
        final e = DaybookEvent.fromJson({
          'id': json,
          'kind': json,
          'at': '2026-10-19T13:00:00+00:00',
        });
        expect(e.kind, kind);
        expect(e.shown, isTrue);
      }
      expect(
        DaybookEvent.fromJson({
          'id': 'x',
          'kind': 'whatever',
          'at': '2026-10-19T13:00:00+00:00',
        }).shown,
        isFalse,
      );
    });
  });

  test('daybook_extras: pinned announcements and today\'s activities', () {
    final extras = DaybookExtras.fromRows([
      {
        'id': 'a1',
        'reason': 'pinned',
        'post': {
          'id': 'a1',
          'kind': 'announcement',
          'title': 'Half day',
          'created_at': '2026-10-19T13:00:00+00:00',
        },
      },
      {
        'id': 'v1',
        'reason': 'activity',
        'post': {
          'id': 'v1',
          'kind': 'activity',
          'title': 'Site walk',
          'created_at': '2026-10-18T13:00:00+00:00',
          'starts_at': '2026-10-19T04:00:00+00:00',
        },
      },
    ]);
    expect(extras.pinned.single.id, 'a1');
    expect(extras.activities.single.id, 'v1');
  });

  test('a point and a face read as checklist_points and post_acks_for '
      'send them', () {
    final point = DaybookPoint.fromJson({
      'id': 'pt1',
      'text': 'Ceiling paint',
      'ticked_by': 'p-sara',
      'ticked_at': '2026-10-19T13:26:37+00:00',
    });
    expect(point.ticked, isTrue);
    expect(point.tickedById, 'p-sara');
    expect(DaybookPoint.fromJson({'id': 'pt2', 'text': 'Doors'}).ticked, false);
    final face = DaybookAckFace.fromJson({
      'profile_id': 'p-omar',
      'name': 'Omar Haddad',
      'kind': 'received',
      'at': '2026-10-19T13:26:37+00:00',
    });
    expect(face.kind, DaybookAck.received);
    expect(face.name, 'Omar Haddad');
  });

  group('create_space_post takes only what fits the kind', () {
    final start = DateTime.utc(2026, 10, 20, 4);
    NewSpacePost post(String kind) => NewSpacePost(
      id: 'n1',
      spaceId: _space,
      kind: kind,
      title: '  Site walk  ',
      body: ' ',
      place: 'Gate office',
      dueDate: DateTime(2026, 10, 22),
      pinnedUntil: DateTime.utc(2026, 10, 21),
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
      libraryFileId: 'lf1',
      people: const ['p-omar'],
      points: const [(id: 'pt1', text: ' Doors ')],
      photoPaths: const ['$_space/posts/n1/a.jpg'],
    );

    test('a checklist: people, points (trimmed), due; no place or pin', () {
      final p = post(DaybookPost.checklistKind).toParams();
      expect(p['p_title'], 'Site walk');
      expect(p['p_body'], isNull);
      expect(p['p_people'], ['p-omar']);
      expect(p['p_points'], [
        {'id': 'pt1', 'text': 'Doors'},
      ]);
      expect(p['p_due'], '2026-10-22');
      expect(p['p_place'], isNull);
      expect(p['p_pinned_until'], isNull);
      expect(p['p_starts_at'], isNull);
      expect(p['p_library_file'], isNull);
    });

    test('an announcement: the pin only', () {
      final p = post(DaybookPost.announcementKind).toParams();
      expect(p['p_pinned_until'], '2026-10-21T00:00:00.000Z');
      expect(p['p_people'], isEmpty);
      expect(p['p_points'], isEmpty);
      expect(p['p_due'], isNull);
    });

    test('an activity: start, end, place and people', () {
      final p = post(DaybookPost.activityKind).toParams();
      expect(p['p_starts_at'], '2026-10-20T04:00:00.000Z');
      expect(p['p_ends_at'], '2026-10-20T05:00:00.000Z');
      expect(p['p_place'], 'Gate office');
      expect(p['p_people'], ['p-omar']);
      expect(p['p_due'], isNull);
    });

    test('a file: the Library file; photos go as the post\'s files', () {
      final p = post(DaybookPost.fileKind).toParams();
      expect(p['p_library_file'], 'lf1');
      expect(p['p_files'], [
        {'path': '$_space/posts/n1/a.jpg', 'mime': 'image/jpeg'},
      ]);
      expect(p['p_people'], isEmpty);
    });
  });

  test('my_spaces: each Space\'s last activity (migration 28), or none', () {
    final row = {
      'space_id': _space,
      'name': 'Kuwait City Tower',
      'pass': 'lead',
      'is_admin': true,
    };
    expect(SpaceSummary.fromJson(row).lastActivityAt, isNull);
    expect(
      SpaceSummary.fromJson({
        ...row,
        'last_activity_at': '2026-10-19T13:26:37+00:00',
      }).lastActivityAt,
      DateTime.utc(2026, 10, 19, 13, 26, 37),
    );
  });
}
