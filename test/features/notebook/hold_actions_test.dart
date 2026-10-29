// Review 106 T4: on hold, the status icons are the actions. One entry
// held: its status row shows all five (Pin · Reminder · Feed · Space ·
// Message), the used ones filled, the unused ones outlined (the card fill
// with a line ring), "Tap to do it" at the row's start. A tap does it
// straight away (Pin pins or unpins, Reminder opens the time picker, Feed,
// Space and Message their share steps); then the selection ends. The bar
// is Move to… · Duplicate · Delete: Share left the bar. Two or more held:
// no icon rows; the bar is Pin · Move to… · Duplicate · Delete. A screen
// reader hears an unused icon as its action, a used one as its status and
// its action. In English and Arabic.
import 'dart:ui' show Tristate;

import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> _hold(WidgetTester tester, String id) async {
  await tester.ensureVisible(_key('note-head-$id'));
  await tester.pumpAndSettle();
  await tester.longPress(_key('note-head-$id'));
  await tester.pumpAndSettle();
}

const _page = '/notebook/pages/${FakeNotebookRepository.myNotesId}';
const _kinds = ['pinned', 'reminder', 'feed', 'space', 'message'];

final _now = NotebookSamples.now;
final _spaceAt = DateTime(_now.year, _now.month, _now.day, 8, 45);

/// a: pinned and shared to a Space; b: nothing.
List<Note> _notes() => [
  Note(
    id: 'a',
    kind: NoteKind.text,
    title: 'Before the site walk',
    blocks: const [PageTodo('a-1', 'Print A-501 Rev D')],
    body: 'Before the site walk',
    pinned: true,
    shares: [
      NoteShare(target: NoteShareTarget.space, at: _spaceAt, name: 'KCT Tower'),
    ],
    createdAt: DateTime(_now.year, _now.month, _now.day, 9, 15),
    pageId: FakeNotebookRepository.myNotesId,
  ),
  Note(
    id: 'b',
    kind: NoteKind.text,
    title: 'Pump booked 2 pm',
    blocks: const [PageText('b-1', 'Gate 2, driver calls 30 min before')],
    body: 'Pump booked 2 pm',
    createdAt: DateTime(_now.year, _now.month, _now.day, 9, 5),
    pageId: FakeNotebookRepository.myNotesId,
  ),
];

Future<FakeNotebookRepository> _open(WidgetTester tester, String lang) async {
  final repo = FakeNotebookRepository(notes: _notes());
  final spaces = FakeSpaceRepository(now: _now)
    ..details['space-kct'] = const SpaceDetail(
      id: 'space-kct',
      name: 'KCT Tower',
      myPass: SpacePass.lead,
      iAmAdmin: true,
      myRights: MemberRights(createItems: true),
    )
    ..spaces.add(
      const SpaceSummary(
        id: 'space-kct',
        name: 'KCT Tower',
        pass: SpacePass.lead,
        isAdmin: true,
      ),
    );
  await pumpApp(
    tester,
    language: lang,
    now: _now,
    notebook: repo,
    spaces: spaces,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(_page);
  await tester.pumpAndSettle();
  return repo;
}

BoxDecoration _disc(WidgetTester tester, String id, String kind) =>
    tester.widget<DecoratedBox>(_key('note-status-$id-$kind-disc')).decoration
        as BoxDecoration;

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final words = DaybookWords(l10n, lang, use24: false);

    group('T4 one entry held [$lang]', () {
      testWidgets('its row shows all five: used filled, unused outlined; '
          '"Tap to do it" at the start', (tester) async {
        await _open(tester, lang);
        await _hold(tester, 'b');
        for (final k in _kinds) {
          expect(_key('note-status-b-$k'), findsOneWidget, reason: k);
          final disc = _disc(tester, 'b', k);
          expect(disc.color, BvColors.surfaceElevated, reason: k);
          expect((disc.border! as Border).top.color, BvColors.borderSubtle);
        }
        final hint = find.descendant(
          of: _key('note-status-b-row'),
          matching: find.text(l10n.notebookTapToDo),
        );
        expect(hint, findsOneWidget);
        final at = tester.getRect(hint);
        final pin = tester.getRect(_key('note-status-b-pinned'));
        if (lang == 'ar') {
          expect(at.left, greaterThanOrEqualTo(pin.right));
        } else {
          expect(at.right, lessThanOrEqualTo(pin.left));
        }
        // The other entry, not held, keeps its own status icons only.
        expect(_key('note-status-a-feed'), findsNothing);
      });

      testWidgets('used ones are filled', (tester) async {
        await _open(tester, lang);
        await _hold(tester, 'a');
        expect(_disc(tester, 'a', 'pinned').color, BvColors.surfaceSubtle);
        expect(_disc(tester, 'a', 'space').color, BvColors.surfaceSubtle);
        expect(_disc(tester, 'a', 'feed').color, BvColors.surfaceElevated);
      });

      testWidgets(
        'the bar is Move to… · Duplicate · Delete: no Share, no Pin',
        (tester) async {
          await _open(tester, lang);
          await _hold(tester, 'b');
          for (final k in [
            'select-move',
            'select-duplicate',
            'select-delete',
          ]) {
            expect(_key(k), findsOneWidget, reason: k);
          }
          expect(_key('select-share'), findsNothing);
          expect(_key('select-pin'), findsNothing);
        },
      );

      testWidgets('Pin pins at once, and the selection ends', (tester) async {
        final repo = await _open(tester, lang);
        await _hold(tester, 'b');
        await _tap(tester, _key('note-status-b-pinned'));
        expect(repo.calls, contains('pin:b:true'));
        expect(_key('selection-bar'), findsNothing);
        expect(_key('note-status-b-pinned'), findsOneWidget);
        expect(_key('note-status-b-feed'), findsNothing);
      });

      testWidgets('a used Pin unpins', (tester) async {
        final repo = await _open(tester, lang);
        await _hold(tester, 'a');
        await _tap(tester, _key('note-status-a-pinned'));
        expect(repo.calls, contains('pin:a:false'));
        expect(_key('selection-bar'), findsNothing);
      });

      testWidgets('Reminder opens the time picker', (tester) async {
        await _open(tester, lang);
        await _hold(tester, 'b');
        await _tap(tester, _key('note-status-b-reminder'));
        expect(find.byType(Dialog), findsOneWidget);
      });

      testWidgets('Feed opens its preview; Space and Message their steps', (
        tester,
      ) async {
        await _open(tester, lang);
        await _hold(tester, 'b');
        await _tap(tester, _key('note-status-b-feed'));
        expect(_key('share-preview'), findsOneWidget);
        expect(_key('share-menu'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_key('selection-bar'), findsNothing);

        await _hold(tester, 'b');
        await _tap(tester, _key('note-status-b-space'));
        expect(_key('share-space-space-kct'), findsOneWidget);
        await tester.tapAt(
          tester.getBottomLeft(_key('line-popover-barrier')) +
              const Offset(4, -4),
        );
        await tester.pumpAndSettle();

        await _hold(tester, 'b');
        await _tap(tester, _key('note-status-b-message'));
        expect(_key('share-find-field'), findsOneWidget);
      });

      testWidgets('a screen reader hears an unused icon as its action, a '
          'used one as its status and its action', (tester) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, lang);
        await _hold(tester, 'a');
        expect(
          tester.getSemantics(_key('note-status-a-feed')).label,
          l10n.notebookActFeed,
        );
        expect(
          tester.getSemantics(_key('note-status-a-message')).label,
          l10n.notebookActMessage,
        );
        expect(
          tester.getSemantics(_key('note-status-a-reminder')).label,
          l10n.notebookActRemind,
        );
        expect(
          tester.getSemantics(_key('note-status-a-space')).label,
          l10n.notebookStatusThen(
            l10n.notebookStatusSpace('KCT Tower', words.time.clock(_spaceAt)),
            l10n.notebookShareAgain,
          ),
        );
        expect(
          tester.getSemantics(_key('note-status-a-pinned')).label,
          l10n.notebookStatusThen(l10n.notebookPinnedLabel, l10n.daybookUnpin),
        );
        expect(
          tester
              .getSemantics(_key('note-status-a-feed'))
              .flagsCollection
              .isButton,
          isTrue,
        );
        expect(
          tester
              .getSemantics(_key('note-status-a-feed'))
              .flagsCollection
              .isSelected,
          isNot(Tristate.isTrue),
        );
        semantics.dispose();
      });
    });

    group('T4 two or more held [$lang]', () {
      testWidgets('no icon rows; the bar is Pin · Move to… · Duplicate · '
          'Delete; Pin pins them all and the selection ends', (tester) async {
        final repo = await _open(tester, lang);
        await _hold(tester, 'b');
        await _tap(tester, _key('note-head-a'));
        expect(_key('note-status-b-row'), findsNothing);
        expect(_key('note-status-a-row'), findsNothing);
        expect(_key('note-status-b-feed'), findsNothing);
        for (final k in [
          'select-pin',
          'select-move',
          'select-duplicate',
          'select-delete',
        ]) {
          expect(_key(k), findsOneWidget, reason: k);
        }
        expect(_key('select-share'), findsNothing);
        await _tap(tester, _key('select-pin'));
        expect(repo.calls, contains('pin:b:true'));
        expect(repo.calls.where((c) => c == 'pin:a:true'), isEmpty);
        expect(_key('selection-bar'), findsNothing);
      });
    });
  }
}
