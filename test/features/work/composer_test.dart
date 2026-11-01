// Review 110 D (CP1–CP4) and G: the composer, simple by default. It takes
// the whole screen; its bar is # · + · camera · Send; # and + open
// round-icon grids in place of the keyboard, sized by the phone's text
// size; each kind shows only its own default lines and extras; the kind
// it opens on is the last one used in this Space (Note the first time).
// In English and Arabic.
import 'package:buildvibes/features/work/daybook_composer.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_space_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

final _now = DaybookSamples.thursday;

/// Islam (Lead) in the sample Space; [lastKind] is the kind last posted
/// here on this phone (none: the first time).
Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  String? lastKind,
  double textScale = 1,
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    composerKind: lastKind,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail()
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = s.d1(),
    now: _now,
    overrides: [
      pickDueProvider.overrideWithValue(
        (context, {required now, day, at}) async =>
            (day: DateTime(2026, 10, 16), at: DateTime(2026, 10, 16, 14)),
      ),
    ],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  await _tap(tester, _key('post-bar-notepad'));
  // The phone's text size (the largest: 2), for the composer.
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.pumpAndSettle();
  return app;
}

DaybookPostDraft? _draft(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Navigator).first),
).read(daybookDraftProvider(DaybookSamples.space));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('CP1 the composer takes the whole screen [$lang]', () {
      testWidgets('no Space header, no Work · Chat, no day line; × · the '
          'kind\'s name over the Space\'s; no Drafts (W9)', (tester) async {
        await _open(tester, lang, lastKind: 'work_item');
        expect(_key('composer'), findsOneWidget);
        expect(find.byType(BvSpaceHeader), findsNothing);
        expect(_key('space-switch'), findsNothing);
        expect(_key('daybook-masthead'), findsNothing);
        expect(
          find.descendant(
            of: _key('composer-top'),
            matching: find.text(l10n.cpNewWorkItem),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('composer-top'),
            matching: find.textContaining(s.spaceName),
          ),
          findsOneWidget,
        );
        expect(_key('composer-close'), findsOneWidget);
        expect(_key('composer-drafts'), findsNothing);
        expect(find.text('Drafts'), findsNothing);
        // No template here for a work item: no Templates either.
        expect(_key('composer-templates'), findsNothing);
        // The kind's name once only: no kind chips over the title.
        expect(_key('writing-kinds'), findsNothing);
        expect(find.text(l10n.daybookWorkItem), findsNothing);
      });

      testWidgets('one bar: # (the kind\'s icon) · + · camera · Send; no '
          'paperclip, no clock', (tester) async {
        await _open(tester, lang, lastKind: 'work_item');
        for (final k in [
          'writing-kind',
          'writing-add',
          'writing-camera',
          'writing-post',
        ]) {
          expect(_key(k), findsOneWidget, reason: k);
        }
        expect(_key('writing-attach'), findsNothing);
        expect(_key('writing-later'), findsNothing);
      });

      testWidgets('× returns to the Space and keeps what was written as its '
          'draft', (tester) async {
        await _open(tester, lang, lastKind: 'work_item');
        await tester.enterText(_key('writing-title'), 'Cracked tile');
        await tester.pumpAndSettle();
        await _tap(tester, _key('composer-close'));
        expect(_key('composer'), findsNothing);
        expect(find.byType(BvSpaceHeader), findsOneWidget);
        expect(_key('daybook-draft'), findsOneWidget);
        await _tap(tester, _key('daybook-draft'));
        expect(_key('composer'), findsOneWidget);
        expect(
          tester.widget<TextField>(_key('writing-title')).controller?.text,
          'Cracked tile',
        );
        await _tap(tester, _key('composer-close'));
        expect(_key('composer'), findsNothing);
        expect(_draft(tester)?.title, 'Cracked tile');
      });
    });

    group('CP1 default lines, by kind [$lang]', () {
      testWidgets('a work item: For, and Team under it; nothing else', (
        tester,
      ) async {
        await _open(tester, lang, lastKind: 'work_item');
        expect(_key('writing-who'), findsOneWidget);
        expect(_key('writing-to'), findsOneWidget);
        expect(
          tester.getTopLeft(_key('writing-to')).dy,
          greaterThan(tester.getTopLeft(_key('writing-who')).dy),
        );
        expect(_key('writing-place-row'), findsNothing);
        expect(_key('writing-due-row'), findsNothing);
      });

      testWidgets('a note: Team only', (tester) async {
        await _open(tester, lang);
        expect(_key('writing-to'), findsOneWidget);
        expect(_key('writing-who'), findsNothing);
      });

      testWidgets('a scheduled activity: When and Team', (tester) async {
        await _open(tester, lang, lastKind: 'activity');
        expect(_key('writing-when-row'), findsOneWidget);
        expect(_key('writing-to'), findsOneWidget);
        expect(_key('writing-who'), findsNothing);
      });
    });

    group('G1 the kind it opens on [$lang]', () {
      testWidgets('Note the first time', (tester) async {
        await _open(tester, lang);
        expect(
          find.descendant(
            of: _key('composer-top'),
            matching: find.text(l10n.cpNewNote),
          ),
          findsOneWidget,
        );
      });

      testWidgets('then the last one posted in this Space', (tester) async {
        await _open(tester, lang);
        await _tap(tester, _key('writing-kind'));
        await _tap(tester, _key('composer-kind-announcement'));
        await tester.enterText(_key('writing-title'), 'Gate 3 closed');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-post'));
        expect(_key('composer'), findsNothing);
        await _tap(tester, _key('post-bar-notepad'));
        expect(
          find.descendant(
            of: _key('composer-top'),
            matching: find.text(l10n.cpNewAnnouncement),
          ),
          findsOneWidget,
        );
      });
    });

    group('CP2 # the kinds [$lang]', () {
      testWidgets('a grid in place of the keyboard: Note · Work item · '
          'Announcement · Scheduled activity · Walk; the chosen one filled; '
          'a tap picks it and brings the keyboard back', (tester) async {
        await _open(tester, lang, lastKind: 'work_item');
        await _tap(tester, _key('writing-kind'));
        expect(_key('composer-kinds'), findsOneWidget);
        expect(find.text(l10n.cpWhatPosting), findsOneWidget);
        for (final k in ['note', 'work_item', 'announcement', 'activity']) {
          expect(_key('composer-kind-$k'), findsOneWidget, reason: k);
        }
        expect(_key('composer-kind-walk'), findsOneWidget);
        // Review 109: a Lead is offered Check-in too.
        expect(_key('composer-kind-check_in'), findsOneWidget);
        expect(
          tester
              .widget<BvIconGridTile>(_key('composer-kind-work_item'))
              .selected,
          isTrue,
        );
        // No keyboard while the grid shows.
        expect(tester.testTextInput.isVisible, isFalse);
        await _tap(tester, _key('composer-kind-note'));
        expect(_key('composer-kinds'), findsNothing);
        expect(
          find.descendant(
            of: _key('composer-top'),
            matching: find.text(l10n.cpNewNote),
          ),
          findsOneWidget,
        );
      });

      testWidgets('4 to a row', (tester) async {
        await _open(tester, lang, lastKind: 'work_item');
        await _tap(tester, _key('writing-kind'));
        double row(String k) => tester.getTopLeft(_key('composer-kind-$k')).dy;
        expect(row('activity'), row('note'));
        expect(row('walk'), greaterThan(row('note')));
      });

      testWidgets('at the largest text size, 3 to a row', (tester) async {
        await _open(tester, lang, lastKind: 'work_item', textScale: 2);
        await _tap(tester, _key('writing-kind'));
        double row(String k) => tester.getTopLeft(_key('composer-kind-$k')).dy;
        expect(row('announcement'), row('note'));
        expect(row('activity'), greaterThan(row('note')));
        // The circles grow with the text.
        expect(
          tester.getSize(_key('composer-kind-note-circle')).width,
          greaterThan(BvIconGridTile.circle),
        );
      });
    });

    // The founder's table (part D), with Pin on an announcement and People
    // on an activity (W9). Template is no longer in + (W9).
    group('CP3 + the extras, each kind its own [$lang]', () {
      final kinds = <String, List<String>>{
        'note': ['photos', 'file', 'place', 'bullets', 'table'],
        'work_item': [
          'place',
          'due',
          'tag',
          'photos',
          'file',
          'checklist',
          'bullets',
          'table',
          'task_table',
        ],
        'announcement': ['photos', 'file', 'bullets', 'table', 'pin'],
        'activity': ['place', 'people', 'photos', 'file', 'bullets'],
      };
      for (final MapEntry(key: kind, value: extras) in kinds.entries) {
        testWidgets('$kind: exactly ${extras.join(' · ')}', (tester) async {
          await _open(tester, lang, lastKind: kind);
          await _tap(tester, _key('writing-add'));
          expect(_key('composer-extras'), findsOneWidget);
          final tiles = find.descendant(
            of: _key('composer-extras'),
            matching: find.byType(BvIconGridTile),
          );
          expect([
            for (final t in tester.widgetList<BvIconGridTile>(tiles))
              '${t.key}'.replaceAll(RegExp(r"^\[<'composer-extra-|'>\]$"), ''),
          ], extras);
        });
      }

      testWidgets('a work item\'s 9: a row of 5, then a row of 4', (
        tester,
      ) async {
        await _open(tester, lang, lastKind: 'work_item');
        await _tap(tester, _key('writing-add'));
        double row(String k) => tester.getTopLeft(_key('composer-extra-$k')).dy;
        expect(row('file'), row('place'));
        expect(row('checklist'), greaterThan(row('place')));
        expect(row('task_table'), row('checklist'));
      });
    });

    group('CP4 what was added [$lang]', () {
      testWidgets('a due time as a chip with ×, under the default lines; × '
          'takes it off', (tester) async {
        await _open(tester, lang, lastKind: 'work_item');
        await _tap(tester, _key('writing-add'));
        await _tap(tester, _key('composer-extra-due'));
        expect(_key('composer-extras'), findsNothing);
        expect(_key('writing-due-chip'), findsOneWidget);
        expect(
          tester.getTopLeft(_key('writing-due-chip')).dy,
          greaterThan(tester.getTopLeft(_key('writing-to')).dy),
        );
        await _tap(tester, _key('writing-due-chip-clear'));
        expect(_key('writing-due-chip'), findsNothing);
      });

      testWidgets('switching the kind keeps the title and words, and drops '
          'what the new kind doesn\'t take, with one line', (tester) async {
        await _open(tester, lang, lastKind: 'work_item');
        await tester.enterText(_key('writing-title'), 'Cracked tile');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-add'));
        await _tap(tester, _key('composer-extra-due'));
        await _tap(tester, _key('writing-kind'));
        await _tap(tester, _key('composer-kind-announcement'));
        final draft = _draft(tester)!;
        expect(draft.title, 'Cracked tile');
        expect(draft.dueDate, isNull);
        expect(
          find.text(
            l10n.cpRemoved(
              l10n.daybookRowDue,
              kindName(l10n, DaybookKind.announcement),
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('For opens Give to, as before', (tester) async {
        await _open(tester, lang, lastKind: 'work_item');
        await _tap(tester, _key('writing-who'));
        await _tap(
          tester,
          find.descendant(
            of: find.byType(BvGiveToPicker),
            matching: find.text(s.omarName),
          ),
        );
        expect(
          find.descendant(
            of: _key('writing-who'),
            matching: find.text(s.omarName),
          ),
          findsOneWidget,
        );
      });
    });
  }
}
