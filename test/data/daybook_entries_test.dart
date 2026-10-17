import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// daybook_page's rows (migration 23, review 45 M1–M3), as the server
/// sends them: (id, created_at, kind, entry).
void main() {
  test('a post: its first files, "more", and the last give-to', () {
    final r = DaybookRecord.fromRow({
      'id': 'p1',
      'created_at': '2026-10-15T05:14:00+00:00',
      'kind': 'post',
      'entry': {
        'id': 'p1',
        'kind': 'work_item',
        'status': 'live',
        'title': 'Sleeves at grid C7 before the pour',
        'created_at': '2026-10-15T05:14:00+00:00',
        'needs_me': false,
        'attachments': [
          {'library_file_id': 'f1', 'name': 'M-201.pdf', 'rev_label': 'Rev C'},
          {'library_file_id': 'f2', 'name': 'Spec.pdf'},
        ],
        'attachments_more': true,
        'given_to': {
          'from_id': 'o',
          'from_name': 'Omar Haddad',
          'to_id': 'r',
          'to_name': 'Rakesh Nair',
          'at': '2026-10-15T09:30:00+00:00',
        },
      },
    })!;
    final post = r as DaybookPost;
    expect(post.at, DateTime.utc(2026, 10, 15, 5, 14));
    expect(post.postId, 'p1');
    expect(post.attachments.map((a) => (a.name, a.revLabel)), [
      ('M-201.pdf', 'Rev C'),
      ('Spec.pdf', null),
    ]);
    expect(post.attachmentsMore, isTrue);
    expect(post.givenTo!.fromName, 'Omar Haddad');
    expect(post.givenTo!.toName, 'Rakesh Nair');
    expect(post.givenTo!.at, DateTime.utc(2026, 10, 15, 9, 30));
  });

  test('a sign-off: the quote, photos, note, outcome and the clip', () {
    final r = DaybookRecord.fromRow({
      'id': 'e1',
      'created_at': '2026-10-15T06:40:00+00:00',
      'kind': 'sign_off',
      'entry': {
        'id': 'e1',
        'post_id': 'p1',
        'space_id': 's',
        'ref': 'KCT-021',
        'title': 'Sleeves at grid C7 before the pour',
        'post_status': 'live',
        'item_status': 'done',
        'actor_id': 'o',
        'actor_name': 'Omar Haddad',
        'note': 'All six fixed and checked with MEP.',
        'at': '2026-10-15T06:40:00+00:00',
        'photos': [
          {
            'path': 's/p1/a.jpg',
            'taken_at': '2026-10-15T06:39:00+00:00',
            'place': 'Level 2',
          },
        ],
        'outcome': {'kind': 'done'},
        'needs_me': true,
      },
    })!;
    final s = r as DaybookSignOff;
    expect(s.id, 'e1');
    expect(s.postId, 'p1');
    expect(s.title, 'Sleeves at grid C7 before the pour');
    expect(s.actorName, 'Omar Haddad');
    expect(s.photos.single.path, 's/p1/a.jpg');
    expect(s.photos.single.place, 'Level 2');
    expect(s.outcome.kind, DaybookOutcomeKind.done);
    expect(s.needsMe, isTrue);
  });

  test('each outcome after a sign-off', () {
    DaybookOutcome outcome(Map<String, dynamic> json) =>
        (DaybookRecord.fromRow({
                  'kind': 'sign_off',
                  'entry': {
                    'id': 'e',
                    'post_id': 'p',
                    'at': '2026-10-15T06:40:00+00:00',
                    'outcome': json,
                  },
                })!
                as DaybookSignOff)
            .outcome;
    final checked = outcome({
      'kind': 'checked',
      'by_id': 'i',
      'by_name': 'Islam Ahmed',
      'at': '2026-10-15T07:12:00+00:00',
    });
    expect(checked.kind, DaybookOutcomeKind.checked);
    expect(checked.byName, 'Islam Ahmed');
    expect(checked.at, DateTime.utc(2026, 10, 15, 7, 12));
    final back = outcome({
      'kind': 'sent_back',
      'reason': 'photo_missing',
      'by_name': 'Islam Ahmed',
      'at': '2026-10-15T07:12:00+00:00',
    });
    expect(back.kind, DaybookOutcomeKind.sentBack);
    expect(back.reason, SendBackReason.photoMissing);
    expect(outcome({'kind': 'cancelled'}).kind, DaybookOutcomeKind.cancelled);
    // No outcome said: still done; no clip unless the server says so.
    expect(outcome({}).kind, DaybookOutcomeKind.done);
  });

  test('an update, and a kind this version does not know', () {
    final u =
        DaybookRecord.fromRow({
              'kind': 'update',
              'entry': {
                'id': 'e2',
                'post_id': 'p1',
                'title': 'Cable tray hangers, level 4',
                'actor_id': 'r',
                'actor_name': 'Rakesh Nair',
                'note': 'Half done',
                'at': '2026-10-15T10:00:00+00:00',
              },
            })!
            as DaybookUpdate;
    expect(u.title, 'Cable tray hangers, level 4');
    expect(u.note, 'Half done');
    expect(u.photos, isEmpty);
    expect(
      DaybookRecord.fromRow({
        'kind': 'something_new',
        'entry': <String, dynamic>{},
      }),
      isNull,
    );
    expect(DaybookRecord.fromRow({'kind': 'post'}), isNull);
  });
}
