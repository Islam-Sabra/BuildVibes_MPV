import 'dart:async';

import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/core/l10n/bv_time.dart';
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/activity/needs_card.dart';
import 'package:buildvibes/features/work/daybook_card.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_card_history.dart';
import 'package:buildvibes/shared/widgets/bv_photo_strip.dart';
import 'package:buildvibes/shared/widgets/bv_pinned_note.dart';
import 'package:buildvibes/shared/widgets/bv_popover_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

/// The Space's daybook as [me] (Islam by default).
Future<FakeDaybookRepository> _open(
  WidgetTester tester,
  String lang, {
  required List<DaybookCard> posts,
  String me = DaybookSamples.islam,
  DateTime? now,
  DaybookExtras extras = const DaybookExtras(),
  Map<String, List<DaybookAckFace>> acks = const {},
  Map<String, List<DaybookPostFile>> files = const {},
}) async {
  final s = DaybookSamples(lang);
  final fake = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = posts
    ..extrasBySpace[DaybookSamples.space] = extras
    ..acksByPost.addAll(acks)
    ..filesByPost.addAll(files);
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail()
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: fake,
    now: now ?? DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return fake;
}

/// A route's way in or out; a photo still loading spins, so no settling.
Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Finder _card(String id) => find.byKey(Key('daybook-card-$id'));

/// The ids of the history lines [id]'s card shows.
List<String> _lines(WidgetTester tester, String id) => [
  for (final h in tester.widgetList<BvCardHistory>(
    find.descendant(of: _card(id), matching: find.byType(BvCardHistory)),
  ))
    for (final l in h.lines) l.id,
];

DaybookEvent _tick(
  String id,
  DaybookEventKind kind,
  DateTime at, {
  String by = DaybookSamples.sara,
  String point = 'pt-0',
}) => DaybookEvent(id: id, kind: kind, at: at, byId: by, pointId: point);

/// The labels of the open long-press menu.
List<String> _menu(WidgetTester tester) => [
  for (final i
      in tester
          .widget<BvSlipMenu<Object?>>(find.byKey(const Key('slip-menu')))
          .items)
    i.label,
];

void main() {
  setUpAll(() => initializeDateFormatting());

  group('review 50 F42, F43: a tick taken back', () {
    final ten = DateTime(2026, 10, 15, 10);
    // Newest first, as the server sends the history.
    test('tick, untick, tick: no line (the point shows who ticked it)', () {
      final hidden = DaybookCardView.hiddenLines([
        _tick('c', DaybookEventKind.ticked, ten.add(const Duration(hours: 2))),
        _tick(
          'b',
          DaybookEventKind.unticked,
          ten.add(const Duration(hours: 1)),
        ),
        _tick('a', DaybookEventKind.ticked, ten),
      ]);
      expect(hidden, {'a', 'b', 'c'});
    });

    test('an untick five minutes after the tick: one line', () {
      final hidden = DaybookCardView.hiddenLines([
        _tick(
          'b',
          DaybookEventKind.unticked,
          ten.add(const Duration(minutes: 5)),
        ),
        _tick('a', DaybookEventKind.ticked, ten),
      ]);
      expect(hidden, {'a'});
    });

    test('the same person taking it back within a minute: no line', () {
      final hidden = DaybookCardView.hiddenLines([
        _tick(
          'b',
          DaybookEventKind.unticked,
          ten.add(const Duration(seconds: 40)),
        ),
        _tick('a', DaybookEventKind.ticked, ten),
      ]);
      expect(hidden, {'a', 'b'});
    });

    test('someone else taking it back within a minute: one line', () {
      final hidden = DaybookCardView.hiddenLines([
        _tick(
          'b',
          DaybookEventKind.unticked,
          ten.add(const Duration(seconds: 40)),
          by: DaybookSamples.omar,
        ),
        _tick('a', DaybookEventKind.ticked, ten),
      ]);
      expect(hidden, {'a'});
    });

    test('each point on its own: only the latest untick of each', () {
      final hidden = DaybookCardView.hiddenLines([
        _tick(
          'd',
          DaybookEventKind.unticked,
          ten.add(const Duration(minutes: 9)),
          point: 'pt-1',
        ),
        _tick(
          'c',
          DaybookEventKind.ticked,
          ten.add(const Duration(minutes: 1)),
          point: 'pt-1',
        ),
        _tick(
          'b',
          DaybookEventKind.unticked,
          ten.add(const Duration(minutes: 8)),
        ),
        _tick('a', DaybookEventKind.ticked, ten),
      ]);
      expect(hidden, {'a', 'c'});
    });
  });

  group('review 50 F53: an Arabic stamp in 12-hour mode', () {
    final words = DaybookWords(_l10n('ar'), 'ar', use24: false);
    final time = BvTime(_l10n('ar'), 'ar', use24: false);
    final at = DateTime(2026, 10, 15, 22, 58);
    for (final (name, short) in [
      ('Islam Ahmed', 'ISLAM A'),
      ('إسلام أحمد', 'إسلام أ'),
    ]) {
      test('with "$name": the period touches the time', () {
        final line = words.stampLine(name, at);
        // The time and its period are one unit; the name is its own.
        expect(line, contains(rtlRun('10:58 مساءً')));
        expect(line, '${inOwnDirection(short)} · ${time.clock(at)}');
        // Never "مساءً ISLAM A": nothing but the time beside the period.
        expect(line.indexOf('مساءً'), greaterThan(line.indexOf('10:58')));
      });
    }

    test('24-hour: no period, nothing changes', () {
      final line = DaybookWords(
        _l10n('ar'),
        'ar',
        use24: true,
      ).stampLine('Islam Ahmed', at);
      expect(line, '${inOwnDirection('ISLAM A')} · 22:58');
    });
  });

  group('review 50 F52: "لـ " and a space before every name', () {
    final ar = _l10n('ar');
    final words = DaybookWords(ar, 'ar', use24: false);
    final now = DateTime(2026, 10, 13, 9);

    test('a Latin and an Arabic owner in the Arabic UI, as typed', () {
      for (final lang in ['en', 'ar']) {
        final s = DaybookSamples(lang);
        final post = s.cableTrays().post;
        final meta = words.meta(post, me: DaybookSamples.islam, now: now);
        expect(meta, startsWith('لـ '));
        // The name exactly as its owner typed it.
        expect(meta, contains(s.omarName));
        // "لك" for yourself.
        expect(
          words.meta(post, me: DaybookSamples.omar, now: now),
          startsWith(ar.daybookForYou),
        );
        expect(ar.daybookForYou, 'لك');
      }
    });

    test('every Arabic "for" before a name takes "لـ " and a space', () {
      expect(ar.daybookForPerson('Omar Haddad'), 'لـ Omar Haddad');
      expect(ar.daybookForPerson('عمر حداد'), 'لـ عمر حداد');
      expect(ar.daybookForYouAnd('Omar'), 'لك ولـ Omar');
      expect(ar.daybookToTeam('MEP'), '· لـ MEP');
      expect(ar.spacesRightLocked('X', 'Omar'), contains('لـ Omar'));
      expect(ar.spacesRightOpened('X', 'Omar'), contains('لـ Omar'));
    });

    test('a Needs you row keeps the name as typed, in both scripts', () {
      for (final name in ['Omar Haddad', 'عمر حداد']) {
        final row = needsTitle(
          ar,
          NeedsCard(
            kind: NeedsKind.forYou,
            spaceId: DaybookSamples.space,
            spaceName: 'KCT',
            at: now,
            workItemTitle: 'Cable trays',
            actorName: name,
          ),
        );
        expect(row, contains(inOwnDirection(name)));
      }
    });

    for (final owner in ['en', 'ar']) {
      testWidgets(
        'on a card in the Arabic UI, a ${owner == 'en' ? 'Latin' : 'Arabic'} '
        'owner name',
        (tester) async {
          final card = DaybookSamples(owner).cableTrays();
          await _open(tester, 'ar', posts: [card]);
          final meta = words.meta(
            card.post,
            me: DaybookSamples.islam,
            now: DaybookSamples.thursday,
          );
          expect(meta, startsWith('لـ '));
          expect(
            find.descendant(
              of: _card(card.id),
              matching: find.text(meta, findRichText: true),
            ),
            findsOneWidget,
          );
        },
      );
    }
  });

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    group('review 50 F48: who received it, with the time [$lang]', () {
      testWidgets('one summary line, no Received lines; a tap lists each '
          'with their time, newest first', (tester) async {
        final received = s.m201Received();
        final card = s.m201();
        await _open(
          tester,
          lang,
          posts: [
            DaybookCard(
              post: card.post,
              lastActivityAt: card.lastActivityAt,
              history: [
                for (final a in received.reversed)
                  DaybookEvent(
                    id: 'rcv-${a.profileId}',
                    kind: DaybookEventKind.received,
                    at: a.at,
                    byId: a.profileId,
                    byName: a.name,
                  ),
              ],
            ),
          ],
          acks: {DaybookSamples.m201Id: received},
        );
        expect(find.byKey(const Key('received-by')), findsOneWidget);
        // F50: the card's kind word says what it is for.
        expect(
          find.descendant(
            of: _card(DaybookSamples.m201Id),
            matching: find.textContaining(
              l10n.daybookKindFileWord,
              findRichText: true,
            ),
          ),
          findsWidgets,
        );
        expect(l10n.daybookKindFileWord, lang == 'en' ? '· file' : '· ملف');
        final lines = _lines(tester, DaybookSamples.m201Id);
        expect(lines, isNot(contains('rcv-${DaybookSamples.omar}')));
        expect(lines, isNot(contains('rcv-${DaybookSamples.rakesh}')));
        await tester.tap(find.byKey(const Key('received-by')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('acks-sheet')), findsOneWidget);
        final time = BvTime(l10n, lang, use24: false);
        final omar = find.byKey(const Key('ack-row-${DaybookSamples.omar}'));
        expect(
          find.descendant(of: omar, matching: find.text(s.omarName)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: omar,
            matching: find.text(time.clock(received.first.at)),
          ),
          findsOneWidget,
        );
        final rakesh = find.byKey(
          const Key('ack-row-${DaybookSamples.rakesh}'),
        );
        expect(
          tester.getTopLeft(rakesh).dy,
          lessThan(tester.getTopLeft(omar).dy),
        );
      });
    });

    group('review 50 F46: a cancelled activity [$lang]', () {
      testWidgets('cancelled an hour before: the time struck through, no '
          'countdown, no actions', (tester) async {
        final walk = s.siteWalkCard();
        final before = DateTime(2026, 10, 16, 6, 1);
        await _open(
          tester,
          lang,
          me: DaybookSamples.omar,
          now: before,
          posts: [
            DaybookCard(
              post: walk.post.shownAs(cancelled: true),
              lastActivityAt: walk.lastActivityAt,
            ),
          ],
        );
        final when = tester.widget<Text>(
          find.descendant(
            of: _card(DaybookSamples.siteWalkId),
            matching: find.byKey(const Key('activity-when')),
          ),
        );
        final words = DaybookWords(l10n, lang, use24: false);
        // Only the time: no "starts in".
        expect(
          when.data,
          BvTime(
            l10n,
            lang,
            use24: false,
          ).range(walk.post.startsAt!, walk.post.endsAt!),
        );
        expect(
          when.data,
          isNot(
            words.activityWhen(walk.post.startsAt!, walk.post.endsAt, before),
          ),
        );
        expect(when.style?.decoration, TextDecoration.lineThrough);
        expect(find.byKey(const Key('ack-on_my_way')), findsNothing);
        expect(find.byKey(const Key('ack-in_my_calendar')), findsNothing);
      });
    });

    group('review 50 F44: the pinned announcement\'s menu [$lang]', () {
      DaybookPost pinned({
        String author = DaybookSamples.sara,
        Set<DaybookAck> myAcks = const {},
      }) => DaybookPost(
        id: DaybookSamples.halfDayId,
        kind: DaybookPost.announcementKind,
        createdAt: DateTime(2026, 10, 15, 8),
        title: s.halfDay,
        authorId: author,
        authorName: s.saraName,
        pinnedUntil: DateTime(2026, 10, 17),
        myAcks: myAcks,
      );

      Future<FakeDaybookRepository> openPinned(
        WidgetTester tester, {
        required DaybookPost post,
        String me = DaybookSamples.sara,
      }) => _open(
        tester,
        lang,
        me: me,
        posts: [
          DaybookCard(post: post, lastActivityAt: post.createdAt),
          s.rebar(),
        ],
        extras: DaybookExtras(pinned: [post]),
      );

      testWidgets('its author, folded and in full: Edit, Unpin, Cancel', (
        tester,
      ) async {
        await openPinned(tester, post: pinned());
        // The author sees it folded.
        await tester.longPress(find.byType(BvPinnedLine));
        await tester.pumpAndSettle();
        expect(_menu(tester), [
          l10n.daybookEdit,
          l10n.pageEdit,
          l10n.daybookUnpin,
          // Slice 7: Sara is a Lead.
          l10n.templateSave,
          l10n.daybookCancelPost,
        ]);
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('slip-menu')), findsNothing);
        // A tap still opens it.
        await tester.tap(find.byType(BvPinnedLine));
        await tester.pumpAndSettle();
        expect(find.byType(BvPinnedNote), findsOneWidget);
        await tester.longPress(find.byType(BvPinnedNote));
        await tester.pumpAndSettle();
        expect(_menu(tester), [
          l10n.daybookEdit,
          l10n.pageEdit,
          l10n.daybookUnpin,
          // Slice 7: Sara is a Lead.
          l10n.templateSave,
          l10n.daybookCancelPost,
        ]);
      });

      testWidgets('Unpin sends only the pin; it is a card on its day, not at '
          'Now', (tester) async {
        final daybook = await openPinned(tester, post: pinned());
        await tester.longPress(find.byType(BvPinnedLine));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.daybookUnpin));
        await tester.pumpAndSettle();
        expect(daybook.calls, [
          'edit ${DaybookSamples.halfDayId} {"pinned_until":null}',
        ]);
      });

      testWidgets('unpinned since: a card on its day, never moved to Now by '
          'the unpin', (tester) async {
        final post = DaybookPost(
          id: DaybookSamples.halfDayId,
          kind: DaybookPost.announcementKind,
          createdAt: DateTime(2026, 10, 15, 8),
          title: s.halfDay,
          authorId: DaybookSamples.sara,
          authorName: s.saraName,
        );
        final unpinned = DateTime(2026, 10, 15, 10, 20);
        await _open(
          tester,
          lang,
          posts: [
            DaybookCard(
              post: post,
              // The server counts the unpin as activity.
              lastActivityAt: unpinned,
              history: [
                DaybookEvent.fromJson({
                  'id': 'unpin',
                  'kind': 'edited',
                  'at': unpinned.toIso8601String(),
                  'by_id': DaybookSamples.sara,
                  'changes': {
                    'pinned_until': {'from': '2026-10-17', 'to': null},
                  },
                }),
              ],
            ),
            s.rebar(),
          ],
        );
        // Above the 10:05 card: at 8:00, where it was posted.
        expect(
          tester.getTopLeft(_card(DaybookSamples.halfDayId)).dy,
          lessThan(tester.getTopLeft(_card('post-rebar')).dy),
        );
      });

      testWidgets('Edit opens it at Now, filled, with its pin; Save sends '
          'only what changed', (tester) async {
        final daybook = await openPinned(tester, post: pinned());
        await tester.longPress(find.byType(BvPinnedLine));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.daybookEdit));
        await tester.pumpAndSettle();
        final title = find.byKey(const Key('writing-title'));
        expect(tester.widget<TextField>(title).controller!.text, s.halfDay);
        await tester.enterText(title, '${s.halfDay} !');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('writing-post')));
        await tester.pumpAndSettle();
        expect(daybook.calls, [
          'edit ${DaybookSamples.halfDayId} {"title":"${s.halfDay} !"}',
        ]);
      });

      testWidgets('anyone else: only a Lead\'s Save as template (slice 7); '
          'a tap still opens it', (tester) async {
        await openPinned(
          tester,
          post: pinned(myAcks: const {DaybookAck.gotIt}),
          me: DaybookSamples.omar,
        );
        await tester.tap(find.byType(BvPinnedLine));
        await tester.pumpAndSettle();
        expect(find.byType(BvPinnedNote), findsOneWidget);
        await tester.longPress(find.byType(BvPinnedNote));
        await tester.pumpAndSettle();
        // The sample Space gives everyone a Lead's pass.
        expect(_menu(tester), [l10n.templateSave]);
      });

      testWidgets('an admin, for an author who has left: Unpin and Cancel, '
          'never Edit (review 62 N2)', (tester) async {
        await openPinned(
          tester,
          post: pinned(author: 'p-left'),
          me: DaybookSamples.islam,
        );
        await tester.longPress(find.byType(BvPinnedNote));
        await tester.pumpAndSettle();
        expect(_menu(tester), [
          l10n.daybookUnpin,
          l10n.templateSave,
          l10n.daybookCancelPost,
        ]);
      });

      testWidgets('after an edit Omar sees it in full again, until he taps '
          'Got it', (tester) async {
        final post = s.halfDayPost(
          myAcks: const {DaybookAck.gotIt},
          editedAt: DateTime(2026, 10, 15, 9, 30),
        );
        final daybook = await _open(
          tester,
          lang,
          me: DaybookSamples.omar,
          posts: [
            DaybookCard(
              post: post,
              lastActivityAt: post.createdAt,
              history: [
                DaybookEvent(
                  id: 'gotit-omar',
                  kind: DaybookEventKind.gotIt,
                  at: DateTime(2026, 10, 15, 9),
                  byId: DaybookSamples.omar,
                  byName: s.omarName,
                ),
              ],
            ),
          ],
          extras: DaybookExtras(pinned: [post]),
        );
        expect(find.byType(BvPinnedNote), findsOneWidget);
        final hold = Completer<void>();
        daybook.holdMarks = hold;
        await tester.tap(find.byKey(const Key('ack-got_it')));
        await tester.pump();
        expect(find.byType(BvPinnedLine), findsOneWidget);
        hold.complete();
        await tester.pumpAndSettle();
      });
    });

    group('review 50 F51: a post\'s photos on its card [$lang]', () {
      const id = DaybookSamples.handoverId;
      // Islam's checklist, with its photos (the card's cover is the first).
      DaybookCard checklist() {
        final h = s.handover().post;
        return DaybookCard(
          post: DaybookPost(
            id: id,
            kind: DaybookPost.checklistKind,
            createdAt: h.createdAt,
            title: h.title,
            authorId: h.authorId,
            authorName: h.authorName,
            people: h.people,
            coverPath: '${DaybookSamples.space}/posts/$id/0.jpg',
          ),
          lastActivityAt: h.createdAt,
        );
      }

      List<DaybookPostFile> photos(int n) => [
        for (var i = 0; i < n; i++)
          DaybookPostFile(
            mime: 'image/jpeg',
            path: '${DaybookSamples.space}/posts/$id/$i.jpg',
          ),
      ];

      testWidgets('two photos: the first large, the second beside it; a tap '
          'opens them to swipe', (tester) async {
        final card = checklist();
        await _open(tester, lang, posts: [card], files: {id: photos(2)});
        final strip = find.descendant(
          of: _card(id),
          matching: find.byType(BvPhotoStrip),
        );
        expect(strip, findsOneWidget);
        expect(tester.widget<BvPhotoStrip>(strip).photos, hasLength(2));
        expect(
          tester.getSize(find.byKey(const Key('photo-strip-0'))).width,
          greaterThan(
            tester.getSize(find.byKey(const Key('photo-strip-1'))).width,
          ),
        );
        await tester.tap(find.byKey(const Key('photo-strip-1')));
        await _pumpRoute(tester);
        final viewer = tester.widget<BvPhotoViewer>(find.byType(BvPhotoViewer));
        expect(viewer.images, hasLength(2));
        // At the photo tapped.
        expect(viewer.first, 1);
        expect(find.byType(PageView), findsOneWidget);
        await tester.tap(find.byKey(const Key('photo-viewer-close')));
        await _pumpRoute(tester);
        expect(find.byType(BvPhotoViewer), findsNothing);
      });

      testWidgets('ten photos: three on the card, never a count; all ten in '
          'the viewer', (tester) async {
        await _open(
          tester,
          lang,
          posts: [checklist()],
          files: {id: photos(10)},
        );
        expect(find.byKey(const Key('photo-strip-2')), findsOneWidget);
        expect(find.byKey(const Key('photo-strip-3')), findsNothing);
        expect(find.textContaining('10'), findsNothing);
        await tester.tap(find.byKey(const Key('photo-strip-0')));
        await _pumpRoute(tester);
        expect(
          tester.widget<BvPhotoViewer>(find.byType(BvPhotoViewer)).images,
          hasLength(10),
        );
      });
    });
  }

  test('the Space pass and member checks need a known member', () {
    // The admin's Cancel for a gone author reads the Space's members: one
    // not among them has left.
    final people = DaybookSamples('en').people();
    expect(people.member('p-left'), isNull);
    expect(people.member(DaybookSamples.sara), isA<SpaceMember>());
  });
}
