// Slice 8 (review 83): notes and My calendar's rows as the server sends
// them, the week's first day, a to-do's due words, and what each kind of
// note fills when it is put in a Space.
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/notebook/calendar_screen.dart';
import 'package:buildvibes/features/notebook/notebook_screen.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authUserIdProvider.overrideWithValue(const AsyncData('user-1')),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('a note from the server: its points, its to-do time, its one '
      'recording from note_files', () {
    final note = Note.fromJson({
      'id': 'n1',
      'kind': 'voice',
      'body': null,
      'points': null,
      'due_at': null,
      'done_at': null,
      'pinned': true,
      'put_in_post_id': 'post-1',
      'created_at': '2026-10-15T08:40:00Z',
      'note_files': [
        {
          'storage_path': 'user-1/n1/a.m4a',
          'kind': 'voice',
          'mime': 'audio/mp4',
          'bytes': 52000,
          'duration_ms': 24000,
          'sort': 0,
        },
      ],
    });
    expect(note.kind, NoteKind.voice);
    expect(note.pinned, isTrue);
    expect(note.putInPostId, 'post-1');
    expect(note.recording?.path, 'user-1/n1/a.m4a');
    expect(note.recording?.duration, const Duration(seconds: 24));
    expect(note.canPut, isFalse, reason: 'a voice note has no words');

    final list = Note.fromJson({
      'id': 'n2',
      'kind': 'checklist',
      'body': 'Before the site walk',
      'points': [
        {'text': 'Print A-501', 'done': true},
        {'text': 'Charge the meter', 'done': false},
      ],
      'pinned': false,
      'created_at': '2026-10-15T06:15:00Z',
    });
    expect([for (final p in list.points) p.done], [true, false]);
    // Kept on the phone and read back the same.
    final again = Note.fromJson(list.toJson());
    expect(again.points.first.text, 'Print A-501');
    expect(again.createdAt, list.createdAt);
  });

  test('a calendar row: a work item on its due date, a to-do and an '
      'activity on their own day; a kind this version does not know is '
      'left out', () {
    final item = CalendarRow.fromJson({
      'kind': 'work_item',
      'space_id': 's1',
      'space_name': 'Kuwait City Tower',
      'post_id': 'p1',
      'title': 'Rebar spacing',
      'day': '2026-10-15',
      'starts_at': null,
      'status': 'open',
      'needs_me': true,
    })!;
    expect(item.day, DateTime(2026, 10, 15));
    expect(item.startsAt, isNull);
    expect(item.needsMe, isTrue);
    final todo = CalendarRow.fromJson({
      'kind': 'todo',
      'note_id': 'n1',
      'title': 'Order sleeves',
      'day': null,
      'starts_at': DateTime(2026, 10, 16, 9).toUtc().toIso8601String(),
      'status': 'done',
    })!;
    expect(todo.day, DateTime(2026, 10, 16));
    expect(todo.done, isTrue);
    expect(
      CalendarRow.fromJson({'kind': 'meeting', 'day': '2026-10-15'}),
      isNull,
    );
  });

  test('the week starts on the market\'s day: Sunday for Kuwait, Saturday '
      'for a Saturday market', () {
    final thursday = DateTime(2026, 10, 15, 12);
    expect(weekOf(thursday, 0), DateTime(2026, 10, 11));
    expect(weekOf(thursday, 6), DateTime(2026, 10, 10));
    expect(weekOf(thursday, 1), DateTime(2026, 10, 12));
    expect(weekOf(DateTime(2026, 10, 11), 0), DateTime(2026, 10, 11));
  });

  test('a to-do\'s due: its time today, or its day when it has no time', () {
    final words = DaybookWords(
      lookupAppLocalizations(const Locale('en')),
      'en',
      use24: false,
    );
    final now = DateTime(2026, 10, 15, 12);
    expect(
      todoDue(words, DateTime(2026, 10, 15, 16), now),
      words.due(
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 15, 16),
        now: now,
        late: false,
      ),
    );
    expect(
      todoDue(words, DateTime(2026, 10, 18), now),
      words.due(DateTime(2026, 10, 18), null, now: now, late: false),
    );
    expect(
      todoDue(words, DateTime(2026, 10, 15, 9), now),
      words.due(
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 15, 9),
        now: now,
        late: true,
      ),
    );
  });

  group('Put in a Space fills the writing card', () {
    final created = DateTime(2026, 10, 15, 8);

    test('a note: a work item, its first line the title, the rest its '
        'words', () async {
      final c = await _container();
      await c
          .read(daybookDraftProvider('s1').notifier)
          .fromNote(
            'post-1',
            Note(
              id: 'n1',
              kind: NoteKind.text,
              body: 'Call the pump supplier\nAsk for the 2 pm slot',
              createdAt: created,
            ),
          );
      final d = c.read(daybookDraftProvider('s1'))!;
      expect(d.id, 'post-1');
      expect(d.kind, DaybookKind.workItem);
      expect(d.title, 'Call the pump supplier');
      expect(d.body, 'Ask for the 2 pm slot');
      expect(d.noteId, 'n1');
    });

    test('a long first line is cut at a word; the whole note stays in the '
        'words', () async {
      final c = await _container();
      final long = List.filled(40, 'concrete').join(' ');
      await c
          .read(daybookDraftProvider('s1').notifier)
          .fromNote(
            'post-1',
            Note(id: 'n1', kind: NoteKind.text, body: long, createdAt: created),
          );
      final d = c.read(daybookDraftProvider('s1'))!;
      expect(d.title.length, lessThanOrEqualTo(DaybookPostDraft.titleMax));
      expect(d.title.endsWith('concrete'), isTrue);
      expect(d.body, long);
    });

    test('a to-do: its time is the due', () async {
      final c = await _container();
      final at = DateTime(2026, 10, 15, 16);
      await c
          .read(daybookDraftProvider('s1').notifier)
          .fromNote(
            'post-1',
            Note(
              id: 'n1',
              kind: NoteKind.todo,
              body: 'Order 40 more sleeves',
              dueAt: at,
              createdAt: created,
            ),
          );
      final d = c.read(daybookDraftProvider('s1'))!;
      expect(d.kind, DaybookKind.workItem);
      expect(d.dueDate, DateTime(2026, 10, 15));
      expect(d.dueAt, at);
    });

    test('a checklist: a checklist with its title and points', () async {
      final c = await _container();
      await c
          .read(daybookDraftProvider('s1').notifier)
          .fromNote(
            'post-1',
            Note(
              id: 'n1',
              kind: NoteKind.checklist,
              body: 'Before the site walk',
              points: const [
                NotePoint('Print A-501', done: true),
                NotePoint('Charge the meter'),
              ],
              createdAt: created,
            ),
          );
      final d = c.read(daybookDraftProvider('s1'))!;
      expect(d.kind, DaybookKind.checklist);
      expect(d.title, 'Before the site walk');
      expect(
        [for (final p in d.points) p.text],
        ['Print A-501', 'Charge the meter'],
      );
    });

    test('a card already half-written keeps its words; the note\'s go '
        'under them', () async {
      final c = await _container();
      final draft = c.read(daybookDraftProvider('s1').notifier);
      await draft.put(
        const DaybookPostDraft(id: 'post-0', title: 'Gate', body: 'Fix it'),
      );
      await draft.fromNote(
        'post-1',
        Note(
          id: 'n1',
          kind: NoteKind.text,
          body: 'Hinge is loose',
          createdAt: created,
        ),
      );
      final d = c.read(daybookDraftProvider('s1'))!;
      expect(d.id, 'post-0');
      expect(d.title, 'Gate');
      expect(d.body, 'Fix it\n\nHinge is loose');
      expect(d.noteId, 'n1');
    });
  });
}
