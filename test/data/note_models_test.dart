// Slice 8 (review 83): notes and My calendar's rows as the server sends
// them, the week's first day, a to-do's due words, and what each kind of
// note fills when it is put in a Space.
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/notebook/calendar_screen.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/notebook/notebook_page_screen.dart';
import 'package:buildvibes/features/notebook/notebook_state.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/notebook_fakes.dart';

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

    test('F107: an older note opens as blocks (migrated on read)', () {
      final text = Note(
        id: 'n',
        kind: NoteKind.text,
        createdAt: start,
        body: 'Pump booking\nAl Bahar, 2 pm\n\nBring the hose',
      );
      final opened = NoteDraft.of(text);
      expect(opened.title, 'Pump booking');
      expect(
        [for (final b in opened.blocks) (b as PageText).text],
        ['Al Bahar, 2 pm', 'Bring the hose'],
      );
      final list = NoteDraft.of(
        Note(
          id: 'c',
          kind: NoteKind.checklist,
          createdAt: start,
          body: 'Before the walk',
          points: const [
            NotePoint('Print A-501', done: true),
            NotePoint('Meter'),
          ],
        ),
      );
      expect(list.title, 'Before the walk');
      expect(
        [for (final b in list.blocks) ((b as PageTodo).text, b.done)],
        [('Print A-501', true), ('Meter', false)],
      );
      final due = DateTime(2026, 10, 15, 16);
      final todo = NoteDraft.of(
        Note(
          id: 't',
          kind: NoteKind.todo,
          createdAt: start,
          body: 'Order sleeves',
          dueAt: due,
          doneAt: start,
        ),
      );
      expect(todo.title, isEmpty);
      expect((todo.blocks.single as PageTodo).done, isTrue);
      expect(todo.dueAt, due);
      final voice = NoteDraft.of(
        Note(
          id: 'v',
          kind: NoteKind.voice,
          createdAt: start,
          recording: const NoteRecording(path: 'u/v/a.m4a', durationMs: 8000),
        ),
      );
      expect((voice.blocks.single as PageVoice).path, 'u/v/a.m4a');
      // Saving writes a page.
      final saved = opened.toNote(start);
      expect(saved.isPage, isTrue);
      expect(saved.kind, NoteKind.text);
      expect(saved.body, 'Pump booking\nAl Bahar, 2 pm\nBring the hose');
    });

    test('F107: a page draft, what it saves, and when it is ready', () {
      final draft = NoteDraft(id: 'd', startedAt: start);
      expect(draft.isEmpty, isTrue);
      expect(draft.ready, isFalse);
      // Empty lines and a lone divider are nothing to keep.
      final empty = draft.copyWith(
        blocks: const [PageText('a', ''), PageDivider('b'), PageTodo('c', ' ')],
      );
      expect(empty.isEmpty, isTrue);
      final due = DateTime(2026, 10, 15, 16);
      const where = NoteLocation(
        text: 'Level 3, grid C7',
        lat: 29.37594,
        lng: 47.9774,
        accuracyM: 8,
      );
      final page = draft.copyWith(
        title: 'Before the pour, level 3',
        blocks: const [
          PageTodo('t1', 'Check the sleeves', done: true),
          PageText('x', ''),
          PageBullet('b1', 'Clean the formwork'),
        ],
        dueAt: () => due,
        location: () => where,
        files: const [NoteFile(local: '/a.pdf', name: 'A-501 Rev D.pdf')],
      );
      expect(page.ready, isTrue);
      final later = DateTime(2026, 10, 17, 8);
      final note = page.toNote(later);
      expect(note.kind, NoteKind.text);
      expect(note.title, 'Before the pour, level 3');
      expect([for (final b in note.blocks!) b.id], ['t1', 'b1']);
      expect(
        note.body,
        'Before the pour, level 3\nCheck the sleeves\nClean the formwork',
      );
      expect(note.dueAt, due);
      expect(note.location, where);
      expect(note.files.single.name, 'A-501 Rev D.pdf');
      // B6: a new note's time is when it is sent.
      expect(note.createdAt, later);
      // A voice block alone is something to keep.
      expect(
        draft.copyWith(blocks: const [PageVoice('v', local: '/v.m4a')]).ready,
        isTrue,
      );
      // So is a typed place; a GPS position alone isn't.
      expect(
        draft.copyWith(location: () => const NoteLocation(text: 'C7')).ready,
        isTrue,
      );
      expect(
        draft
            .copyWith(location: () => const NoteLocation(lat: 1, lng: 2))
            .ready,
        isFalse,
      );
    });

    test('F107: a page, its location and its PDFs from a row and on the '
        'phone', () {
      final row = Note.fromJson({
        'id': 'n1',
        'kind': 'text',
        'title': 'Pump',
        'body': 'Pump\nAl Bahar',
        'blocks': [
          {'id': 'b1', 'type': 'text', 'text': 'Al Bahar'},
          {
            'id': 'b2',
            'type': 'voice',
            'path': 'u/n1/v.m4a',
            'duration_ms': 8000,
          },
        ],
        'location_text': 'Grid C7',
        'location_lat': '29.375940',
        'location_lng': 47.9774,
        'location_accuracy_m': '8.0',
        'created_at': '2026-10-15T08:00:00Z',
        'note_files': [
          {
            'storage_path': 'u/n1/a.pdf',
            'kind': 'file',
            'mime': 'application/pdf',
            'bytes': 2400000,
            'name': 'A-501.pdf',
            'sort': 0,
          },
          {
            'storage_path': 'u/n1/v.m4a',
            'kind': 'voice',
            'mime': 'audio/mp4',
            'sort': 1,
          },
        ],
      });
      expect(row.isPage, isTrue);
      expect(row.recording, isNull);
      expect((row.blocks![1] as PageVoice).durationMs, 8000);
      expect(row.location!.lat, 29.37594);
      expect(row.location!.accuracyM, 8);
      expect(row.files.single.name, 'A-501.pdf');
      // Kept on the phone while it waits: the voice block's own copy too.
      final waiting = row.copyWith(
        blocks: [const PageVoice('b3', local: '/v.m4a', durationMs: 3000)],
      );
      final back = Note.fromJson(waiting.toJson());
      expect((back.blocks!.single as PageVoice).local, '/v.m4a');
      expect(back.location, row.location);
      expect(back.files.single.path, 'u/n1/a.pdf');
      // What save_note takes: no copy on the phone in a block.
      expect(
        (back.blocks!.single as PageVoice).toServer().containsKey('local'),
        isFalse,
      );
    });

    test('F107 B7: a saved note keeps its place; a new one goes by its '
        'time', () {
      Note at(String id, int hour) => Note(
        id: id,
        kind: NoteKind.text,
        body: id,
        createdAt: DateTime(2026, 10, 15, hour),
      );
      final notes = NotebookData(
        notes: [at('c', 10), at('b', 9), at('a', 8)],
        pages: [FakeNotebookRepository.myNotes()],
      );
      final edited = NoteChange.save(at('b', 9).copyWith(body: 'B'));
      expect([
        for (final n in edited.applyTo(notes).notes) n.id,
      ], ['c', 'b', 'a']);
      final early = NoteChange.save(at('x', 8).copyWith());
      expect(
        [for (final n in NoteChange.save(at('y', 9)).applyTo(notes).notes) n.id],
        ['c', 'y', 'b', 'a'],
      );
      expect(
        [for (final n in early.applyTo(notes).notes) n.id],
        ['c', 'b', 'x', 'a'],
      );
    });

    test('F107: Put in a Space\'s place: the typed words, the GPS only when '
        'the note carries it', () {
      expect(DaybookDraft.notePlace(null), isNull);
      expect(
        DaybookDraft.notePlace(const NoteLocation(text: 'Grid C7')),
        'Grid C7',
      );
      expect(
        DaybookDraft.notePlace(
          const NoteLocation(text: 'Grid C7', lat: 29.37594, lng: 47.9774),
        ),
        'Grid C7 · 29.37594, 47.97740',
      );
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
