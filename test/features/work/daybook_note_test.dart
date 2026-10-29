import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_writing_rows.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/opened_item.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _noteId = 'post-pour-note';
const _goneId = 'p-gone';

/// K5's note (2598:36260): Islam's, for information, Thursday 11:45.
DaybookPost _note(DaybookSamples s, {String authorId = DaybookSamples.islam}) =>
    DaybookPost(
      id: _noteId,
      kind: DaybookPost.noteKind,
      createdAt: DateTime(2026, 10, 15, 11, 45),
      title: s.t('Pour finished, level 3 slab', 'انتهى الصب، بلاطة الطابق 3'),
      body: s.t(
        'Pump left at 11:40. Curing starts tomorrow, 7 am.',
        'غادرت المضخة 11:40. تبدأ المعالجة غدًا 7 صباحًا.',
      ),
      authorId: authorId,
      authorName: authorId == DaybookSamples.islam ? s.islamName : null,
    );

/// The Space's daybook as [me] (Islam, a Space admin, by default).
Future<FakeDaybookRepository> _open(
  WidgetTester tester,
  String lang, {
  List<DaybookCard> posts = const [],
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  bool admin = true,
  DaybookExtras extras = const DaybookExtras(),
}) async {
  final s = DaybookSamples(lang);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail(pass: pass, admin: admin)
    ..spacePeople[DaybookSamples.space] = s.people();
  final fake = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = posts
    ..extrasBySpace[DaybookSamples.space] = extras;
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: spaces,
    daybook: fake,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder _card(String id) => find.byKey(Key('daybook-card-$id'));
Finder _in(String id, Finder f) => find.descendant(of: _card(id), matching: f);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    group('F58 the Note [$lang]', () {
      testWidgets('review 105 SP2: Note is the first kind chip; Work item '
          'is chosen first', (tester) async {
        await _open(tester, lang);
        await _tap(tester, find.byKey(const Key('post-bar-notepad')));
        final chips = tester.widget<BvKindChips<DaybookKind>>(
          find.byKey(const Key('writing-kinds')),
        );
        expect(chips.choices.first.value, DaybookKind.note);
        expect(chips.choices.first.label, l10n.daybookKindNote);
        expect(chips.choices.first.icon, kindIcon(DaybookKind.note));
        expect(chips.selected, DaybookKind.workItem);
      });

      testWidgets('a note posts with its words only: no who, nothing more '
          'to set', (tester) async {
        final daybook = await _open(tester, lang);
        await _tap(tester, find.byKey(const Key('post-bar-notepad')));
        await _tap(tester, find.byKey(Key('kind-chip-${DaybookKind.note}')));
        await tester.enterText(
          find.byKey(const Key('writing-title')),
          _note(s).title,
        );
        await tester.pumpAndSettle();
        final toolbar = tester.widget<BvWritingToolbar>(
          find.byType(BvWritingToolbar),
        );
        // Nothing more to set: + holds nothing.
        expect(toolbar.tools!.first.onTap, isNull);
        expect(toolbar.onPost, isNotNull);
        await _tap(tester, find.byKey(const Key('writing-post')));
        final sent = daybook.createdPosts.single;
        expect(sent.kind, DaybookPost.noteKind);
        final params = sent.toParams();
        expect(params['p_people'], isEmpty);
        expect(params['p_points'], isEmpty);
        expect(params['p_pinned_until'], isNull);
        expect(params['p_starts_at'], isNull);
        expect(params['p_library_file'], isNull);
      });

      testWidgets('K5: the card says "· note", its words, and no button', (
        tester,
      ) async {
        final post = _note(s, authorId: DaybookSamples.sara);
        await _open(
          tester,
          lang,
          posts: [DaybookCard(post: post, lastActivityAt: post.createdAt)],
        );
        expect(_in(_noteId, find.text(l10n.daybookKindNoteWord)), findsOne);
        expect(_in(_noteId, find.text(post.title)), findsOneWidget);
        expect(_in(_noteId, find.text(post.body!)), findsOneWidget);
        expect(_in(_noteId, find.byKey(const Key('ack-got_it'))), findsNothing);
        expect(
          _in(_noteId, find.byKey(const Key('ack-received'))),
          findsNothing,
        );
      });

      testWidgets('its author opens it: Edit, and Cancel on ⋯', (tester) async {
        final post = _note(s);
        await _open(
          tester,
          lang,
          posts: [DaybookCard(post: post, lastActivityAt: post.createdAt)],
        );
        await tester.tap(_card(_noteId));
        await tester.pumpAndSettle();
        final actions = await openedActions(tester);
        expect(actions, contains(l10n.daybookEdit));
        expect(actions, contains(l10n.daybookCancelPost));
      });

      testWidgets('someone else opens it: nothing to do', (tester) async {
        final post = _note(s, authorId: DaybookSamples.sara);
        await _open(
          tester,
          lang,
          me: DaybookSamples.lina,
          pass: SpacePass.crew,
          admin: false,
          posts: [DaybookCard(post: post, lastActivityAt: post.createdAt)],
        );
        await tester.tap(_card(_noteId));
        await tester.pumpAndSettle();
        expect(await openedActions(tester), isEmpty);
      });
    });

    group('N2 unpin for a gone author [$lang]', () {
      DaybookPost gonePin() => DaybookPost(
        id: DaybookSamples.halfDayId,
        kind: DaybookPost.announcementKind,
        createdAt: DateTime(2026, 10, 15, 8),
        title: s.halfDay,
        authorId: _goneId,
        pinnedUntil: DateTime(2026, 10, 17),
      );

      testWidgets('the Space admin gets Unpin and Cancel, never Edit, and '
          'Unpin sends only the pin', (tester) async {
        final post = gonePin();
        final daybook = await _open(
          tester,
          lang,
          posts: [DaybookCard(post: post, lastActivityAt: post.createdAt)],
          extras: DaybookExtras(pinned: [post]),
        );
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('pinned-${DaybookSamples.halfDayId}')),
            matching: find.text(post.title),
          ),
        );
        await tester.pumpAndSettle();
        final actions = await openedActions(tester);
        expect(actions, isNot(contains(l10n.daybookEdit)));
        expect(actions, contains(l10n.daybookCancelPost));
        await openedPick(tester, l10n.daybookUnpin);
        expect(daybook.calls, [
          'edit ${DaybookSamples.halfDayId} {"pinned_until":null}',
        ]);
      });

      testWidgets('a member who isn\'t an admin gets nothing', (tester) async {
        final post = gonePin();
        await _open(
          tester,
          lang,
          me: DaybookSamples.lina,
          pass: SpacePass.crew,
          admin: false,
          posts: [DaybookCard(post: post, lastActivityAt: post.createdAt)],
          extras: DaybookExtras(pinned: [post]),
        );
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('pinned-${DaybookSamples.halfDayId}')),
            matching: find.text(post.title),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.daybookUnpin), findsNothing);
        expect(find.text(l10n.daybookCancelPost), findsNothing);
      });
    });
  }

  group('my_ack_at (migration 29)', () {
    Map<String, dynamic> json(Object? myAckAt) => {
      'id': 'p1',
      'kind': 'announcement',
      'created_at': '2026-10-15T08:00:00Z',
      'title': 'Half day',
      'my_acks': ['got_it'],
      'my_ack_at': myAckAt,
    };

    test('reads when each acknowledgement was given', () {
      final post = DaybookPost.fromJson(
        json({'got_it': '2026-10-15T09:00:00Z', 'unknown': '2026-10-15'}),
      );
      expect(post.myAckAt, {DaybookAck.gotIt: DateTime.utc(2026, 10, 15, 9)});
    });

    test('missing or empty: none', () {
      expect(DaybookPost.fromJson(json(null)).myAckAt, isEmpty);
      expect(DaybookPost.fromJson(json(<String, dynamic>{})).myAckAt, isEmpty);
    });
  });
}
