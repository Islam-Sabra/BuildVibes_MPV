// Slice 8 (review 83): My notebook, Put in a Space, Save to my notebook
// and My calendar, in English and Arabic.
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_target.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_day_divider.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/dm_fakes.dart';
import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
}

/// Send is on: the action colour (F106).
bool _sendOn(WidgetTester tester) =>
    tester.widget<GestureDetector>(_key('writing-post')).onTap != null;

/// The to-do's day and time, chosen with the phone's pickers.
final _pickFour = pickDueProvider.overrideWithValue(
  (context, {required now, day, at}) async =>
      (day: DateTime(2026, 10, 15), at: DateTime(2026, 10, 15, 16)),
);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<Note> notes = const [],
  List<CalendarRow> rows = const [],
  FakeSpaceRepository? spaces,
  FakeDaybookRepository? daybook,
  FakeDmRepository? dm,
  String path = '/notebook/pages/page-my-notes',
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(notes: notes, rows: rows),
    spaces: spaces,
    daybook: daybook,
    dm: dm,
    overrides: [_pickFour],
  );
  await _go(tester, path);
  return app;
}

FakeSpaceRepository _spaces(DaybookSamples s) => FakeSpaceRepository()
  ..spaces.addAll([
    SpaceSummary(
      id: DaybookSamples.space,
      name: s.spaceName,
      pass: SpacePass.lead,
      isAdmin: true,
    ),
    const SpaceSummary(
      id: 'space-viewer',
      name: 'Khiran villas',
      pass: SpacePass.viewer,
      isAdmin: false,
    ),
  ])
  ..details[DaybookSamples.space] = s.detail()
  ..spacePeople[DaybookSamples.space] = s.people();

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final n = NotebookSamples(lang);

    testWidgets('Home\'s notebook icon opens My notebook: an empty one '
        'shows New entry, what it is for and + New page [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        now: NotebookSamples.now,
        notebook: FakeNotebookRepository(pages: const []),
      );
      // Review 84 N1: the notebook glyph, never the work item's list-checks.
      final icon = tester.widget<Icon>(
        find.descendant(of: _key('home-notebook'), matching: find.byType(Icon)),
      );
      expect(icon.icon, BvIcons.notebook);
      expect(icon.icon, isNot(BvIcons.workItems));
      await _tap(tester, _key('home-notebook'));
      expect(find.text(l10n.notebookTitle), findsOneWidget);
      expect(_key('notebook-new-entry'), findsOneWidget);
      expect(_key('notebook-empty'), findsOneWidget);
      expect(find.text(l10n.notebookEmptyTitle), findsOneWidget);
      expect(_key('notebook-new-page'), findsOneWidget);
    });

    testWidgets('PG4: pinned entries first; then today\'s, newest first, '
        'each with its kind and time; yesterday under its day [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, notes: n.notes());
      final words = DaybookWords(
        l10n,
        Localizations.localeOf(
          tester.element(find.byType(Scaffold).first),
        ).toLanguageTag(),
        use24: false,
      );
      expect(find.text(l10n.notebookPinnedLabel), findsOneWidget);
      expect(find.text(n.pumpWords), findsOneWidget);
      double top(String id) => tester.getTopLeft(_key('note-$id')).dy;
      expect(top('note-pump'), lessThan(top('note-voice')));
      expect(top('note-voice'), lessThan(top('note-walk')));
      expect(top('note-walk'), lessThan(top('note-sleeves')));
      expect(
        find.text(words.compactDate(DateTime(2026, 10, 15))),
        findsOneWidget,
      );
      await tester.drag(_key('notebook-list'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(top('note-sleeves'), lessThan(top('note-yesterday')));
      expect(
        find.text(words.compactDate(DateTime(2026, 10, 14))),
        findsOneWidget,
      );
      // The to-do's kind on its head.
      expect(
        find.descendant(
          of: _key('note-head-note-sleeves'),
          matching: find.text(l10n.notebookTodo),
        ),
        findsOneWidget,
      );
      expect(find.text(n.walkPoints[2]), findsOneWidget);
      expect(_key('chat-voice-note-voice'), findsOneWidget);
    });

    testWidgets('F107: write a note, a to-do list and a dated note in '
        'place, each sent by save_note as a page [$lang]', (tester) async {
      final app = await _open(tester, lang);
      final kept = app.notebook.kept;

      await _tap(tester, _key('page-write'));
      expect(_key('note-writing-card'), findsOneWidget);
      await tester.enterText(_key('note-title'), 'Check the pump hose');
      await tester.pumpAndSettle();
      await _tap(tester, _key('writing-post'));
      final note = kept.values.single;
      expect(note.title, 'Check the pump hose');
      expect(note.kind, NoteKind.text);
      expect(note.isPage, isTrue);
      expect(note.body, 'Check the pump hose');

      await _tap(tester, _key('page-write'));
      await tester.enterText(_key('note-title'), n.walkTitle);
      await _tap(tester, _key('note-tool-categories'));
      await _tap(tester, _key('note-category-todo'));
      for (final (i, p) in n.walkPoints.take(2).indexed) {
        final line = find.descendant(
          of: _key('note-page'),
          matching: find.byType(TextField),
        );
        await tester.enterText(line.last, p);
        await tester.pumpAndSettle();
        if (i == 0) {
          await tester.testTextInput.receiveAction(TextInputAction.next);
          await tester.pumpAndSettle();
        }
      }
      expect(_sendOn(tester), isTrue);
      await _tap(tester, _key('writing-post'));
      final list = kept.values.firstWhere((x) => x.title == n.walkTitle);
      expect([
        for (final b in list.blocks!)
          if (b is PageTodo) b.text,
      ], n.walkPoints.take(2));

      await _tap(tester, _key('page-write'));
      await tester.enterText(_key('note-title'), n.sleevesTodo);
      await tester.pumpAndSettle();
      await _tap(tester, _key('note-tool-date'));
      await _tap(tester, _key('writing-post'));
      final dated = kept.values.firstWhere((x) => x.title == n.sleevesTodo);
      expect(dated.dueAt, DateTime(2026, 10, 15, 16));
      expect(
        app.notebook.calls.where((c) => c.startsWith('save:')),
        hasLength(3),
      );
    });

    testWidgets('tick a to-do and a checklist\'s point [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang, notes: [n.todo(), n.checklist()]);
      await _tap(tester, _key('note-done-note-sleeves'));
      expect(app.notebook.calls, contains('done:note-sleeves:true'));
      expect(app.notebook.kept['note-sleeves']!.done, isTrue);
      await _tap(tester, _key('note-point-note-walk-2'));
      expect(
        [for (final p in app.notebook.kept['note-walk']!.points) p.done],
        [true, true, true],
      );
    });

    testWidgets('no signal: a note shows at once, waits on the phone, and '
        'goes with the next change [$lang]', (tester) async {
      final app = await _open(tester, lang);
      app.notebook.offline = true;
      await _tap(tester, _key('page-write'));
      await tester.enterText(_key('note-title'), 'Rebar delivery 3 pm');
      await tester.pumpAndSettle();
      await _tap(tester, _key('writing-post'));
      expect(find.text('Rebar delivery 3 pm'), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsOneWidget);
      expect(app.notebook.kept, isEmpty);
      expect(app.prefs.getString('notebook_waiting:user-1'), isNotNull);

      app.notebook.offline = false;
      await _tap(tester, _key('page-write'));
      await tester.enterText(_key('note-title'), 'Crane at 6');
      await tester.pumpAndSettle();
      await _tap(tester, _key('writing-post'));
      expect(app.notebook.kept, hasLength(2));
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      expect(app.prefs.getString('notebook_waiting:user-1'), isNull);
    });

    testWidgets('a note deleted on another phone: its waiting edit is '
        'dropped [$lang]', (tester) async {
      final app = await _open(tester, lang, notes: [n.yesterday()]);
      app.notebook
        ..kept.remove('note-yesterday')
        ..deleted.add('note-yesterday');
      await _tap(tester, _key('note-note-yesterday'));
      await tester.enterText(_key('note-title'), 'Changed');
      await tester.pumpAndSettle();
      await _tap(tester, _key('writing-post'));
      expect(app.notebook.calls, contains('save:note-yesterday'));
      expect(_key('note-note-yesterday'), findsNothing);
      expect(app.prefs.getString('notebook_waiting:user-1'), isNull);
    });

    testWidgets('hold Voice while writing: a voice block in the entry, its '
        'recording to Storage, then save_entry [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _tap(tester, _key('page-write'));
      await tester.enterText(_key('note-title'), 'Pump hose');
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(_key('note-tool-voice')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 3));
      expect(_key('chat-recording'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      await _tap(tester, _key('writing-post'));
      final upload = app.notebook.calls.firstWhere(
        (c) => c.startsWith('upload:'),
      );
      final id = upload.substring('upload:'.length);
      expect(app.notebook.calls, contains('save:$id'));
      final entry = app.notebook.kept[id]!;
      final voice = entry.blocks!.whereType<PageVoice>().single;
      expect(voice.path, 'user-1/$id/voice.m4a');
      expect(voice.durationMs, greaterThanOrEqualTo(3000));
      expect(entry.pageId, FakeNotebookRepository.myNotesId);
    });

    testWidgets('Save to my notebook on a held direct message [$lang]', (
      tester,
    ) async {
      final dm = FakeDmRepository()
        ..pages['t-omar'] = DmThreadPage(
          threadId: 't-omar',
          person: const DmPerson(id: 'p-omar', name: 'Omar Haddad'),
          state: DmState.open,
          messages: [
            DmMessage(
              id: 'm1',
              fromMe: false,
              kind: ChatKind.text,
              createdAt: DateTime(2026, 10, 15, 10, 40),
              body: 'At the gate at 7?',
            ),
          ],
        );
      final app = await _open(tester, lang, dm: dm, path: '/messages/t-omar');
      await tester.longPress(_key('chat-message-m1'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('dm-action-notebook'));
      expect(find.text(l10n.notebookSaved), findsOneWidget);
      final saved = app.notebook.kept.values.single;
      expect(saved.body, 'At the gate at 7?');
      expect(saved.kind, NoteKind.text);
    });

    testWidgets('My calendar from the notebook: the week from Sunday with '
        'dots, today\'s rows then Friday\'s, labels, the clip, a Space\'s '
        'colour [$lang]', (tester) async {
      final app = await _open(tester, lang, rows: n.rows(), path: '/notebook');
      await _tap(tester, _key('notebook-calendar'));
      expect(find.text(l10n.calendarTitle), findsOneWidget);
      expect(find.text(l10n.calendarSubtitle), findsOneWidget);
      // Kuwait's week starts on Sunday: 11 to 17 October, one read.
      expect(app.notebook.calls, contains('calendar:10-11'));
      double x(int day) => tester.getCenter(_key('calendar-day-10-$day')).dx;
      if (lang == 'ar') {
        expect(x(11), greaterThan(x(17)));
      } else {
        expect(x(11), lessThan(x(17)));
      }
      expect(find.text(l10n.calendarDueToday), findsOneWidget);
      expect(find.text(l10n.calendarDueForYou), findsOneWidget);
      expect(find.text(l10n.notebookTodo), findsOneWidget);
      expect(find.text(l10n.calendarScheduled), findsNWidgets(2));
      expect(find.text(l10n.calendarAllDay), findsOneWidget);
      expect(_key('calendar-row-clip'), findsNWidgets(2));
      expect(find.byType(BvDayDivider), findsOneWidget);
      // Monday's work item is before the chosen day: not listed.
      expect(_key('calendar-row-post-fire'), findsNothing);
      await _tap(tester, _key('calendar-day-10-12'));
      expect(_key('calendar-row-post-fire'), findsOneWidget);
      expect(find.text(l10n.calendarToCheck), findsOneWidget);
      // By day, whatever order the server sends; all day first on a day.
      double y(String id) => tester.getTopLeft(_key('calendar-row-$id')).dy;
      expect(y('post-fire'), lessThan(y('note-lift')));
      expect(y('note-lift'), lessThan(y('post-sleeves-check')));
      expect(y('post-sleeves-check'), lessThan(y('post-rebar')));
    });

    testWidgets('My calendar: swipe for the next week; an empty week says so '
        '[$lang]', (tester) async {
      final app = await _open(tester, lang, rows: n.rows(), path: '/notebook');
      await _tap(tester, _key('notebook-calendar'));
      await tester.fling(
        _key('calendar-week'),
        Offset(lang == 'ar' ? 300 : -300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(app.notebook.calls, contains('calendar:10-18'));
      expect(_key('calendar-empty'), findsOneWidget);
      expect(find.text(l10n.calendarEmpty), findsOneWidget);
    });

    testWidgets('My calendar: a to-do row goes back to the notebook; a work '
        'item opens its card in the Space [$lang]', (tester) async {
      final s = DaybookSamples(lang);
      await _open(
        tester,
        lang,
        rows: n.rows(),
        spaces: _spaces(s),
        daybook: FakeDaybookRepository()
          ..posts[DaybookSamples.space] = const [],
        path: '/notebook',
      );
      await _tap(tester, _key('notebook-calendar'));
      await _tap(tester, _key('calendar-row-note-sleeves'));
      expect(find.text(l10n.notebookTitle), findsOneWidget);
      await _tap(tester, _key('notebook-calendar'));
      await _tap(tester, _key('calendar-row-post-rebar'));
      expect(
        tester.widget<SpaceScreen>(find.byType(SpaceScreen)).target,
        const DaybookTarget('post-rebar'),
      );
    });
  }
}
