import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// daybook_cards' rows (migration 26, review 53 Part A), as the local seed
/// returns them: (id, last_activity_at, card).
Map<String, dynamic> _row({
  Object? needsMe = 'to_check',
  Object? proof = const {
    'at': '2026-10-18T06:40:00+00:00',
    'by': {'id': 'o', 'name': 'Omar Haddad'},
    'note': 'All six fixed and checked with MEP.',
    'photos': [
      {
        'path': 's/p/proof.jpg',
        'place': 'Level 2, grid C7',
        'taken_at': '2026-10-18T06:39:00+00:00',
      },
    ],
    'outcome': {
      'at': '2026-10-18T06:40:00+00:00',
      'kind': 'done',
      'by_id': 'o',
      'by_name': 'Omar Haddad',
    },
    'event_id': 'e2',
  },
  List<Object> history = const [],
  bool more = false,
}) => {
  'id': 'p1',
  'last_activity_at': '2026-10-18T06:40:00+00:00',
  'card': {
    'id': 'p1',
    'item': {
      'ref': 'KCT-003',
      'status': 'done',
      'done_at': '2026-10-18T06:40:00+00:00',
      'owner_id': 'o',
      'owner_name': 'Omar Haddad',
    },
    'kind': 'work_item',
    'place': 'Level 2, grid C7',
    'proof': proof,
    'stamp': {
      'at': '2026-10-18T06:40:00+00:00',
      'kind': 'done',
      'by_name': 'Omar Haddad',
    },
    'title': 'Sleeves at grid C7 before the pour',
    'points': {'total': 2, 'ticked': 0},
    'status': 'live',
    'history': history,
    'due_date': '2026-10-18',
    'has_page': false,
    'needs_me': needsMe,
    'space_id': 's',
    'author_id': 'a',
    'created_at': '2026-10-18T05:14:00+00:00',
    'attachments': [
      {'name': 'M-201.pdf', 'rev_label': 'Rev C', 'library_file_id': 'f1'},
    ],
    'author_name': 'Islam Ahmed',
    'history_more': more,
    'last_activity_at': '2026-10-18T06:40:00+00:00',
  },
};

void main() {
  test('a card: the post, its last activity, the proof and its stamp', () {
    final card = DaybookCardsPage.fromRows([_row()]).cards.single;
    expect(card.id, 'p1');
    expect(card.lastActivityAt, DateTime.utc(2026, 10, 18, 6, 40));
    expect(card.post.title, 'Sleeves at grid C7 before the pour');
    expect(card.post.item!.ref, 'KCT-003');
    expect(card.post.item!.status, WorkStatus.done);
    expect(card.post.pointsTotal, 2);
    expect(card.post.attachments.single.revLabel, 'Rev C');
    final proof = card.proof!;
    expect(proof.eventId, 'e2');
    expect(proof.byName, 'Omar Haddad');
    expect(proof.note, 'All six fixed and checked with MEP.');
    expect(proof.photos.single.path, 's/p/proof.jpg');
    expect(proof.photos.single.place, 'Level 2, grid C7');
    expect(proof.outcome.kind, DaybookOutcomeKind.done);
    expect(proof.outcome.byId, 'o');
  });

  test('the cursor is the last card\'s activity and id', () {
    final page = DaybookCardsPage.fromRows([_row()]);
    expect(page.lastAt, DateTime.utc(2026, 10, 18, 6, 40));
    expect(page.lastId, 'p1');
    expect(DaybookCardsPage.fromRows(const []).lastAt, isNull);
  });

  test('history lines of every kind, newest first, and "more"', () {
    final card = DaybookCardsPage.fromRows([
      _row(
        more: true,
        history: [
          {
            'at': '2026-10-18T07:10:00+00:00',
            'id': 'e5',
            'kind': 'reassigned',
            'by_id': 'a',
            'by_name': 'Islam Ahmed',
            'from_id': 'o',
            'from_name': 'Omar Haddad',
            'to_id': 'r',
            'to_name': 'Rakesh Nair',
          },
          {
            'at': '2026-10-18T07:05:00+00:00',
            'id': 'e4',
            'kind': 'edited',
            'by_id': 'a',
            'by_name': 'Islam Ahmed',
            'changes': {
              'due': {
                'to': '2026-10-18',
                'from': '2026-10-22',
                'to_at': '2026-10-18T11:00:00+00:00',
              },
            },
          },
          {
            'at': '2026-10-18T06:50:00+00:00',
            'id': 'e3',
            'kind': 'sent_back',
            'by_id': 'a',
            'by_name': 'Islam Ahmed',
            'reason': 'photo_missing',
          },
          {
            'at': '2026-10-18T06:40:00+00:00',
            'id': 'e2',
            'kind': 'done',
            'note': 'All six fixed.',
            'by_id': 'o',
            'by_name': 'Omar Haddad',
            'photos': [
              {'path': 's/p/proof.jpg'},
            ],
          },
          {
            'at': '2026-10-18T05:14:00+00:00',
            'id': 'e1',
            'kind': 'raised',
            'by_id': 'a',
            'by_name': 'Islam Ahmed',
          },
          {
            'at': '2026-10-18T05:00:00+00:00',
            'id': 'e0',
            'kind': 'a_kind_from_later',
          },
        ],
      ),
    ]).cards.single;
    expect(card.historyMore, isTrue);
    expect(card.history.map((e) => e.kind), [
      DaybookEventKind.reassigned,
      DaybookEventKind.edited,
      DaybookEventKind.sentBack,
      DaybookEventKind.done,
      DaybookEventKind.raised,
      DaybookEventKind.unknown,
    ]);
    final given = card.history[0];
    expect((given.fromName, given.toName), ('Omar Haddad', 'Rakesh Nair'));
    final edit = card.history[1].dueEdit!;
    expect(edit.from, DateTime(2026, 10, 22));
    expect(edit.to, DateTime(2026, 10, 18));
    expect(card.history[2].reason, SendBackReason.photoMissing);
    expect(card.history[3].photos.single.path, 's/p/proof.jpg');
    // The card's header says who raised it; an unknown kind isn't drawn.
    expect(card.history.where((e) => e.shown).length, 4);
  });

  test('needs_me: each value, and one this version does not know', () {
    DaybookNeed? need(Object? v) =>
        DaybookCardsPage.fromRows([_row(needsMe: v)]).cards.single.need;
    expect(need('to_sign'), DaybookNeed.toSign);
    expect(need('to_check'), DaybookNeed.toCheck);
    expect(need('give_to'), DaybookNeed.giveTo);
    expect(need('to_tick'), DaybookNeed.toTick);
    expect(need(null), isNull);
    expect(need('to_bless'), DaybookNeed.unknown);
  });

  test('each outcome of the proof, and no proof', () {
    DaybookOutcome outcome(Map<String, Object?> o) =>
        DaybookCardsPage.fromRows([
          _row(
            proof: {
              'at': '2026-10-18T06:40:00+00:00',
              'by': {'id': 'o', 'name': 'Omar Haddad'},
              'outcome': o,
            },
          ),
        ]).cards.single.proof!.outcome;
    expect(
      outcome({
        'kind': 'checked',
        'by_id': 'a',
        'by_name': 'Islam Ahmed',
        'at': '2026-10-18T07:00:00+00:00',
      }).kind,
      DaybookOutcomeKind.checked,
    );
    final back = outcome({
      'kind': 'sent_back',
      'reason': 'not_as_asked',
      'note': 'One is short.',
      'by_id': 'a',
      'by_name': 'Islam Ahmed',
      'at': '2026-10-18T07:00:00+00:00',
    });
    expect(back.kind, DaybookOutcomeKind.sentBack);
    expect(back.reason, SendBackReason.notAsAsked);
    expect(back.note, 'One is short.');
    expect(
      outcome({'kind': 'cancelled', 'by_id': 'a'}).kind,
      DaybookOutcomeKind.cancelled,
    );
    expect(
      DaybookCardsPage.fromRows([_row(proof: null)]).cards.single.proof,
      isNull,
    );
  });
}
