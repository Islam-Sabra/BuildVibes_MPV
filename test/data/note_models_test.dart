// Slice 8 (review 83): notes and My calendar's rows as the server sends
// them, the week's first day, a to-do's due words, and what each kind of
// note fills when it is put in a Space.
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/notebook/calendar_screen.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
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

  group('F106: a note written in place', () {
    final start = DateTime(2026, 10, 15, 12);

    test('photos come from note_files, in their order', () {
      final note = Note.fromJson({
        'id': 'n1',
        'kind': 'text',
        'body': 'Pump',
        'created_at': '2026-10-15T09:00:00Z',
        'note_files': [
          {'storage_path': 'u/n1/b.jpg', 'kind': 'photo', 'sort': 1},
          {'storage_path': 'u/n1/a.jpg', 'kind': 'photo', 'sort': 0},
        ],
      });
      expect(
        [for (final p in note.photos) p.path],
        ['u/n1/a.jpg', 'u/n1/b.jpg'],
      );
      // Kept on the phone while it waits, with its own copy.
      final back = Note.fromJson(
        note.copyWith(photos: [const NotePhoto(local: '/kept.jpg')]).toJson(),
      );
      expect(back.photos.single.local, '/kept.jpg');
    });

    test('the kind changes and keeps the words', () {
      final note = NoteDraft(
        id: 'd',
        startedAt: start,
        title: 'Before the walk',
        body: 'Print A-501\n\nCharge the meter',
      );
      final list = note.asKind(NoteKind.checklist);
      expect(list.title, 'Before the walk');
      expect(list.body, isEmpty);
      expect(
        [for (final p in list.points) p.text],
        ['Print A-501', 'Charge the meter'],
      );
      final back = list.asKind(NoteKind.text);
      expect(back.points, isEmpty);
      expect(back.body, 'Print A-501\nCharge the meter');
      // A to-do takes the first line; with no title, the first line of
      // the words (the rest waits for another kind).
      expect(note.asKind(NoteKind.todo).title, 'Before the walk');
      final untitled = NoteDraft(id: 'd', startedAt: start, body: 'A\nB');
      final todo = untitled.asKind(NoteKind.todo);
      expect((todo.title, todo.body), ('A', 'B'));
      expect(todo.toNote(start).body, 'A');
    });

    test('what each kind saves, and when it is ready', () {
      final draft = NoteDraft(id: 'd', startedAt: start);
      expect(draft.isEmpty, isTrue);
      expect(draft.ready, isFalse);
      final note = draft.copyWith(title: 'Pump', body: 'at 2 pm');
      expect(note.ready, isTrue);
      expect(note.toNote(start).body, 'Pump\nat 2 pm');
      final list = draft.copyWith(kind: NoteKind.checklist, title: 'Walk');
      expect(list.ready, isFalse);
      final pointed = list.copyWith(points: [(id: 'p', text: 'Doors')]);
      expect(pointed.ready, isTrue);
      expect(pointed.toNote(start).points.single.text, 'Doors');
      final due = DateTime(2026, 10, 15, 16);
      final todo = draft.copyWith(
        kind: NoteKind.todo,
        title: 'Sleeves',
        dueAt: () => due,
      );
      expect(todo.toNote(start).dueAt, due);
      // A note left from another day is kept on the day it is sent.
      final later = DateTime(2026, 10, 17, 8);
      expect(note.toNote(later).createdAt, later);
      expect(note.toNote(start).createdAt, start);
    });

    test('the Draft is kept on the phone, and an empty one is not', () async {
      final container = await _container();
      final drafts = container.read(noteDraftProvider.notifier);
      await drafts.put(NoteDraft(id: 'd', startedAt: start, title: 'Pump'));
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('notebook_draft:user-1'), contains('Pump'));
      container.invalidate(noteDraftProvider);
      expect(container.read(noteDraftProvider)!.title, 'Pump');
      await container
          .read(noteDraftProvider.notifier)
          .put(NoteDraft(id: 'd', startedAt: start));
      expect(prefs.getString('notebook_draft:user-1'), isNull);
      await container.read(noteDraftProvider.notifier).close();
      expect(container.read(noteDraftProvider), isNull);
    });
  });
}
