import 'dart:convert';

import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/push/reminders.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/features/notebook/note_reminders.dart';
import 'package:buildvibes/features/notebook/notebook_screen.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/reminder_fakes.dart';

/// Remind me (slice 10, review 83 Q2, review 87): a note's reminder on
/// this phone.
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

/// The day and time the person picks.
PickedDue? _picked = (
  day: DateTime(2026, 10, 15),
  at: DateTime(2026, 10, 15, 16),
);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  required List<Note> notes,
  FakePhoneReminders? reminders,
  Map<String, Object> stored = const {},
  bool openNotebook = true,
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(notes: notes),
    reminders: reminders,
    stored: stored,
    overrides: [
      pickDueProvider.overrideWithValue(
        (context, {required now, day, at}) async => _picked,
      ),
    ],
  );
  if (openNotebook) await _go(tester, '/notebook/pages/page-my-notes');
  return app;
}

/// Review 100 Part 3b: an entry's Pin · Reminder are on its swipe toward
/// the end (mirrored in Arabic).
Future<void> _swipeOpen(WidgetTester tester, String id) async {
  final card = find.byKey(Key('note-$id'));
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  final rtl = Directionality.of(tester.element(card)) == TextDirection.rtl;
  // On its head row: a voice note's player keeps its own drag.
  final head =
      tester.getTopLeft(card) + Offset(tester.getSize(card).width / 2, 16);
  await tester.timedDragFrom(
    head,
    Offset(rtl ? -160 : 160, 0),
    const Duration(milliseconds: 300),
  );
  await tester.pumpAndSettle();
}

/// The open card's Reminder.
final _remindButton = find.byWidgetPredicate(
  (w) => '${w.key}'.contains('swipe-remind-'),
);

Future<void> _menu(WidgetTester tester, String id) => _swipeOpen(tester, id);

void main() {
  setUp(
    () =>
        _picked = (day: DateTime(2026, 10, 15), at: DateTime(2026, 10, 15, 16)),
  );

  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = NotebookSamples(lang);

    testWidgets('Remind me: a day and a time, kept with the note, set on '
        'this phone; the slip says when [$lang]', (tester) async {
      final app = await _open(tester, lang, notes: [s.todo()]);
      await _menu(tester, 'note-sleeves');
      expect(_remindButton, findsOneWidget);
      expect(find.text(l10n.notebookReminder), findsOneWidget);
      // A bell, not My calendar's glyph (review 88 S3).
      expect(
        find.descendant(
          of: _remindButton,
          matching: find.byIcon(BvIcons.remind),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _remindButton,
          matching: find.byIcon(BvIcons.calendar),
        ),
        findsNothing,
      );
      await _tap(tester, _remindButton);
      expect(
        app.notebook.kept['note-sleeves']!.remindAt,
        DateTime(2026, 10, 15, 16),
      );
      final set = app.reminders.onPhone['note-sleeves']!;
      expect(set.at, DateTime(2026, 10, 15, 16));
      expect(set.title, l10n.reminderTitle);
      expect(set.body, s.sleevesTodo);
      final line = tester.widget<Text>(
        find.descendant(
          of: _key('note-reminder-note-sleeves'),
          matching: find.byType(Text),
        ),
      );
      expect(line.data, startsWith(l10n.notebookReminderLine('')));
      expect(line.data, contains(l10n.daybookToday));
      expect(line.data, contains('4:00'));
      // In grey: the person's own time, not a due.
      expect(line.style?.color, BvColors.textSecondary);
    });

    testWidgets('Remind me with no time: that morning; a time gone by is '
        'refused [$lang]', (tester) async {
      _picked = (day: DateTime(2026, 10, 16), at: null);
      final app = await _open(tester, lang, notes: [s.todo()]);
      await _menu(tester, 'note-sleeves');
      await _tap(tester, _remindButton);
      expect(
        app.reminders.onPhone['note-sleeves']!.at,
        DateTime(2026, 10, 16, 9),
      );
      expect(find.textContaining(l10n.daybookTomorrow), findsWidgets);

      _picked = (day: DateTime(2026, 10, 15), at: DateTime(2026, 10, 15, 8));
      await _menu(tester, 'note-sleeves');
      await _tap(tester, _remindButton);
      expect(find.text(l10n.notebookRemindPast), findsOneWidget);
      expect(
        app.reminders.onPhone['note-sleeves']!.at,
        DateTime(2026, 10, 16, 9),
      );
    });

    testWidgets('Remove takes the reminder off the phone and the slip '
        '[$lang]', (tester) async {
      final note = s.todo().copyWith(
        remindAt: () => DateTime(2026, 10, 15, 16),
      );
      final app = await _open(tester, lang, notes: [note]);
      expect(app.reminders.onPhone, contains('note-sleeves'));
      expect(_key('note-reminder-note-sleeves'), findsOneWidget);
      _picked = (day: null, at: null);
      await _menu(tester, 'note-sleeves');
      await _tap(tester, _remindButton);
      expect(app.notebook.kept['note-sleeves']!.remindAt, isNull);
      expect(app.reminders.onPhone, isEmpty);
      expect(app.reminders.calls.last, 'cancel note-sleeves');
      expect(_key('note-reminder-note-sleeves'), findsNothing);
    });

    testWidgets('done or deleted: the reminder goes [$lang]', (tester) async {
      final at = DateTime(2026, 10, 15, 16);
      final app = await _open(
        tester,
        lang,
        notes: [
          s.todo().copyWith(remindAt: () => at),
          s.yesterday().copyWith(remindAt: () => at),
        ],
      );
      expect(app.reminders.onPhone.keys, {'note-sleeves', 'note-yesterday'});
      await _tap(tester, _key('note-done-note-sleeves'));
      expect(app.reminders.onPhone.keys, {'note-yesterday'});
      expect(_key('note-reminder-note-sleeves'), findsNothing);
      // Review 100 Part 3: held, then Delete on the selection bar.
      await tester.longPress(_key('note-note-yesterday'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('select-delete'));
      expect(app.reminders.onPhone, isEmpty);
    });

    testWidgets('every start sets again those still to come; never a voice '
        "note's, a done one's or one gone by [$lang]", (tester) async {
      final app = await _open(
        tester,
        lang,
        openNotebook: false,
        notes: [
          s.todo().copyWith(remindAt: () => DateTime(2026, 10, 15, 16)),
          s.checklist().copyWith(remindAt: () => DateTime(2026, 10, 15, 11)),
          s.voice().copyWith(remindAt: () => DateTime(2026, 10, 15, 17)),
          s.yesterday().copyWith(
            remindAt: () => DateTime(2026, 10, 15, 18),
            doneAt: () => DateTime(2026, 10, 15, 9),
          ),
        ],
        // This phone had set it before (a restart).
        stored: {
          remindersSetKey: jsonEncode({
            'user': 'user-1',
            'items': {
              'note-sleeves':
                  '${DateTime(2026, 10, 15, 16).toUtc().toIso8601String()} '
                  '${s.sleevesTodo}',
            },
          }),
        },
      );
      expect(app.reminders.calls, contains('set note-sleeves'));
      expect(app.reminders.onPhone.keys, {'note-sleeves'});
    });

    testWidgets("another account's reminders on this phone are taken off "
        '[$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        openNotebook: false,
        notes: [s.todo().copyWith(remindAt: () => DateTime(2026, 10, 15, 16))],
        stored: {
          remindersSetKey: jsonEncode({
            'user': 'someone-else',
            'items': {'their-note': '2026-10-16T06:00:00.000Z Their words'},
          }),
        },
      );
      expect(app.reminders.calls, contains('cancel their-note'));
      expect(app.reminders.onPhone.keys, {'note-sleeves'});
    });

    testWidgets('a tapped reminder opens My notebook [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        openNotebook: false,
        notes: [s.todo().copyWith(remindAt: () => DateTime(2026, 10, 15, 16))],
      );
      expect(find.byType(NotebookScreen), findsNothing);
      app.reminders.tap('note-sleeves');
      await tester.pumpAndSettle();
      expect(find.byType(NotebookScreen), findsOneWidget);
    });

    testWidgets('opened by a reminder: My notebook [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        openNotebook: false,
        notes: [s.todo()],
        reminders: FakePhoneReminders()..launched = 'note-sleeves',
      );
      expect(find.byType(NotebookScreen), findsOneWidget);
    });

    testWidgets("a voice note's swipe has no Reminder [$lang]", (tester) async {
      await _open(tester, lang, notes: [s.voice()]);
      await _menu(tester, s.voice().id);
      expect(_key('swipe-pin-${s.voice().id}'), findsOneWidget);
      expect(_remindButton, findsNothing);
    });
  }

  test("the reminder's words: a note's first line, a checklist's title or "
      'first point', () {
    final now = DateTime(2026, 10, 15);
    Note n(NoteKind k, String body, [List<NotePoint> points = const []]) =>
        Note(id: 'n', kind: k, body: body, points: points, createdAt: now);
    expect(
      reminderWords(n(NoteKind.text, 'Call Yousef\nabout the pump')),
      'Call Yousef',
    );
    expect(
      reminderWords(
        n(NoteKind.checklist, '', const [NotePoint('Print A-501')]),
      ),
      'Print A-501',
    );
    expect(reminderWords(n(NoteKind.text, 'x' * 200)).length, 120);
    expect(reminderId('note-sleeves'), reminderId('note-sleeves'));
  });
}
