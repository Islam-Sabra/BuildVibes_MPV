// F107 (review 92): a note writes like Notion. The + opens the categories
// grid in place of the keyboard; "/" lists the same kinds; the additions
// bar attaches a location (typed, GPS or both), photos, PDFs, a date, a
// reminder and voice blocks; the Draft keeps all of it; an older note opens
// as blocks. With the F106 bugs fixed here (docs/reviews/f106-bugs.md). In
// English and Arabic.
import 'dart:async';

import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/network/signal_state.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/notebook/note_location.dart';
import 'package:buildvibes/features/notebook/note_page_editor.dart';
import 'package:buildvibes/features/notebook/notebook_state.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
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

/// Four o'clock today, from the daybook's day-and-time picker; a reminder
/// at 3:45 pm.
Override _picks({DateTime? remind}) => pickDueProvider.overrideWithValue(
  (context, {required now, day, at}) async =>
      (day: DateTime(2026, 10, 15), at: remind ?? DateTime(2026, 10, 15, 16)),
);

/// The phone's GPS: Level 3's spot, ±8 m; or [failure].
Override _gps({GpsFailure? failure, List<int>? asks}) =>
    findPositionProvider.overrideWithValue(() async {
      asks?.add(1);
      return (lat: 29.37594, lng: 47.9774, accuracyM: 8.0, failure: failure);
    });

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<Note> notes = const [],
  List<Override> overrides = const [],
  Override? picks,
  Override? gps,
  FakeNotebookRepository? notebook,
  FakeSpaceRepository? spaces,
  FakeDaybookRepository? daybook,
  Map<String, Object> stored = const {},
  Future<void>? cameraOpen,
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: notebook ?? FakeNotebookRepository(notes: notes),
    spaces: spaces,
    daybook: daybook,
    stored: stored,
    cameraOpen: cameraOpen,
    overrides: [picks ?? _picks(), gps ?? _gps(), ...overrides],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/notebook/pages/page-my-notes');
  await tester.pumpAndSettle();
  return app;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

NoteDraft? _draft(WidgetTester tester) =>
    _container(tester).read(noteDraftProvider);

Future<void> _note(WidgetTester tester) => _tap(tester, _key('page-write'));

/// The page's text fields, in order.
Finder _lines() =>
    find.descendant(of: _key('note-page'), matching: find.byType(TextField));

bool _sendOn(WidgetTester tester) =>
    tester.widget<GestureDetector>(_key('writing-post')).onTap != null;

/// An addition's icon colour: the action colour while it is in use.
Color? _toolColour(WidgetTester tester, String tool) => tester
    .widget<Icon>(find.descendant(of: _key(tool), matching: find.byType(Icon)))
    .color;

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

FakeSpaceRepository _spaces(DaybookSamples s) => FakeSpaceRepository()
  ..spaces.add(
    SpaceSummary(
      id: DaybookSamples.space,
      name: s.spaceName,
      pass: SpacePass.lead,
      isAdmin: true,
    ),
  )
  ..details[DaybookSamples.space] = s.detail()
  ..spacePeople[DaybookSamples.space] = s.people();

/// A page note saved before, with its location and a photo.
Note _page({NoteLocation? location}) => Note(
  id: 'note-page',
  kind: NoteKind.text,
  title: 'Before the pour, level 3',
  body: 'Before the pour, level 3\nCheck the sleeves',
  blocks: const [
    PageTodo('a0000000-0000-4000-8000-000000000001', 'Check the sleeves'),
  ],
  location: location,
  photos: [NotePhoto(local: testPhotoPath)],
  createdAt: DateTime(2026, 10, 15, 9),
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final n = NotebookSamples(lang);

    testWidgets('NBX1: the + and the additions bar, no kind chip [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);
      await _note(tester);
      expect(_key('note-tool-categories'), findsOneWidget);
      for (final t in [
        'location',
        'image',
        'file',
        'date',
        'remind',
        'voice',
      ]) {
        expect(_key('note-tool-$t'), findsOneWidget);
      }
      expect(_key('writing-kind-chip'), findsNothing);
      expect(find.text(l10n.notebookNow), findsOneWidget);
      // The title has the keyboard.
      final title = tester.widget<TextField>(_key('note-title'));
      expect(title.focusNode!.hasFocus, isTrue);
      expect(_sendOn(tester), isFalse);
      // In Arabic the + is at the right, Send at the left.
      final plus = tester.getCenter(_key('note-tool-categories')).dx;
      final send = tester.getCenter(_key('writing-post')).dx;
      expect(lang == 'ar' ? plus > send : plus < send, isTrue);
    });

    testWidgets('NBX2: + opens the grid, the keyboard kept (D8); each tile '
        'inserts its block, and the keyboard comes back [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);
      await _note(tester);
      await tester.enterText(_key('note-title'), 'Pump booking');
      await tester.pumpAndSettle();
      final kinds = {
        NoteBlockKind.heading: PageHeading,
        NoteBlockKind.subheading: PageHeading,
        NoteBlockKind.todo: PageTodo,
        NoteBlockKind.bullets: PageBullet,
        NoteBlockKind.numbers: PageNumbered,
        NoteBlockKind.toggle: PageToggle,
        NoteBlockKind.table: PageTable,
        NoteBlockKind.callout: PageCallout,
        NoteBlockKind.quote: PageQuote,
        NoteBlockKind.divider: PageDivider,
        NoteBlockKind.text: PageText,
      };
      for (final MapEntry(key: kind, value: type) in kinds.entries) {
        await _tap(tester, _key('note-tool-categories'));
        expect(_key('note-categories'), findsOneWidget);
        // Review 100 D8: the keyboard stays up under the grid.
        expect(tester.testTextInput.isVisible, isTrue);
        expect(find.text(l10n.notebookCategories), findsOneWidget);
        expect(find.text(l10n.notebookOrTypeSlash), findsOneWidget);
        await _tap(tester, _key('note-category-${kind.name}'));
        expect(_key('note-categories'), findsNothing);
        // Each one lands on the page, and is typed into (a word, so the
        // next tile goes after it).
        final blocks = _draft(tester)!.blocks;
        expect(
          blocks.any((b) => b.runtimeType == type),
          isTrue,
          reason: kind.name,
        );
        if (kind == NoteBlockKind.subheading) {
          expect(
            blocks.whereType<PageHeading>().any((h) => h.level == 2),
            isTrue,
          );
        }
        if (kind != NoteBlockKind.table && kind != NoteBlockKind.divider) {
          expect(tester.testTextInput.isVisible, isTrue, reason: kind.name);
          tester.testTextInput.enterText(kind.name);
          await tester.pumpAndSettle();
        }
      }
      expect(_sendOn(tester), isTrue);
      await _tap(tester, _key('writing-post'));
    });

    testWidgets('NBX2: the line\'s own kind is outlined; an empty line turns '
        'into the tile [$lang]', (tester) async {
      await _open(tester, lang);
      await _note(tester);
      await tester.enterText(_key('note-title'), 'Walk');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      bool outlined(String kind) {
        final m = tester.widget<Material>(_key('note-category-$kind'));
        final side = (m.shape! as RoundedRectangleBorder).side;
        return side.color == BvColors.borderSelected &&
            m.color == BvColors.surfaceBrandSoft;
      }

      await _tap(tester, _key('note-tool-categories'));
      expect(outlined('text'), isTrue);
      expect(outlined('todo'), isFalse);
      await _tap(tester, _key('note-category-todo'));
      // The empty line turned: one block, a to-do.
      expect(_draft(tester)!.blocks.single, isA<PageTodo>());
      // Review 98: + on any other line is for a new text line below it.
      await _tap(tester, _key('note-tool-categories'));
      expect(outlined('text'), isTrue);
      expect(outlined('todo'), isFalse);
      expect(_draft(tester)!.blocks, [isA<PageTodo>(), isA<PageText>()]);
      // + again: the keyboard back.
      await _tap(tester, _key('note-tool-categories'));
      expect(_key('note-categories'), findsNothing);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('"/" still opens the list; Enter goes on a to-do list and '
        'an empty to-do leaves it; Backspace on an empty line takes it out '
        '(B1, B2) [$lang]', (tester) async {
      await _open(tester, lang);
      await _note(tester);
      await tester.enterText(_key('note-title'), n.walkTitle);
      // B1: Enter in the title goes on to the first line.
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_lines().first).focusNode!.hasFocus,
        isTrue,
      );
      tester.testTextInput.enterText('/');
      await tester.pumpAndSettle();
      expect(_key('page-add-menu'), findsOneWidget);
      await _tap(tester, _key('page-add-todo'));
      expect(_draft(tester)!.blocks.single, isA<PageTodo>());
      tester.testTextInput.enterText(n.walkPoints[0]);
      await tester.pumpAndSettle();
      // ignore: avoid_print
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      tester.testTextInput.enterText(n.walkPoints[1]);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_draft(tester)!.blocks.whereType<PageTodo>(), hasLength(3));
      // An empty to-do and Enter: back to text.
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_draft(tester)!.blocks.last, isA<PageText>());
      // Backspace on the empty text line: it goes.
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect([
        for (final b in _draft(tester)!.blocks) (b as PageTodo).text,
      ], n.walkPoints.take(2));
    });

    testWidgets('NBX3: each addition attaches to the note, shows at the '
        'slip\'s end, is tinted, and × takes it off [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        picks: _picks(remind: DateTime(2026, 10, 15, 15, 45)),
      );
      await _note(tester);
      await tester.enterText(_key('note-title'), n.walkTitle);
      await tester.pumpAndSettle();

      // Location: typed.
      await _tap(tester, _key('note-tool-location'));
      expect(_key('note-location-panel'), findsOneWidget);
      await tester.enterText(_key('note-location-typed'), 'Level 3, grid C7');
      await _tap(tester, _key('note-location-done'));
      expect(find.text('Level 3, grid C7'), findsOneWidget);
      expect(_toolColour(tester, 'note-tool-location'), BvColors.iconAction);

      // Image: the camera or the gallery.
      await _tap(tester, _key('note-tool-image'));
      await _tap(tester, _key('note-image-camera'));
      await _tap(tester, _key('note-tool-image'));
      await _tap(tester, _key('note-image-gallery'));
      expect(app.cameraAsks, [true, false]);
      expect(_key('note-photo-0'), findsOneWidget);
      expect(_key('note-photo-1'), findsOneWidget);
      expect(_toolColour(tester, 'note-tool-image'), BvColors.iconAction);

      // File: a PDF, its name and size.
      await _tap(tester, _key('note-tool-file'));
      expect(_key('note-file-0'), findsOneWidget);
      expect(find.text('Level 3 plan.pdf'), findsOneWidget);
      expect(_toolColour(tester, 'note-tool-file'), BvColors.iconAction);

      // Date and Remind me.
      await _tap(tester, _key('note-tool-date'));
      await _tap(tester, _key('note-tool-remind'));
      expect(_key('note-date-chip'), findsOneWidget);
      expect(_key('note-remind-chip'), findsOneWidget);
      expect(_toolColour(tester, 'note-tool-date'), BvColors.iconAction);
      expect(_toolColour(tester, 'note-tool-remind'), BvColors.iconAction);

      final d = _draft(tester)!;
      expect(d.location!.text, 'Level 3, grid C7');
      expect(d.photos, hasLength(2));
      expect(d.files.single.name, 'Level 3 plan.pdf');
      expect(d.dueAt, DateTime(2026, 10, 15, 15, 45));
      expect(d.remindAt, DateTime(2026, 10, 15, 15, 45));

      // × takes each off.
      await _tap(
        tester,
        find.descendant(
          of: _key('note-location-chip'),
          matching: _key('note-chip-remove'),
        ),
      );
      await _tap(tester, _key('note-photo-remove-0'));
      await _tap(tester, _key('note-file-remove'));
      await _tap(
        tester,
        find.descendant(
          of: _key('note-date-chip'),
          matching: _key('note-chip-remove'),
        ),
      );
      await _tap(
        tester,
        find.descendant(
          of: _key('note-remind-chip'),
          matching: _key('note-chip-remove'),
        ),
      );
      final gone = _draft(tester)!;
      expect(gone.location, isNull);
      expect(gone.photos, hasLength(1));
      expect(gone.files, isEmpty);
      expect((gone.dueAt, gone.remindAt), (null, null));
      expect(_toolColour(tester, 'note-tool-file'), BvColors.iconPrimary);

      // Sent: the note has what was left.
      await _tap(tester, _key('writing-post'));
      final note = app.notebook.kept.values.single;
      expect(note.photos.single.path, startsWith('user-1/'));
      expect(app.notebook.calls, contains('photo:${note.id}'));
    });

    testWidgets('NBX4: a typed location only, GPS only, and both; GPS asks '
        'the phone, and its × takes it off [$lang]', (tester) async {
      final asks = <int>[];
      final app = await _open(tester, lang, gps: _gps(asks: asks));
      Future<NoteLocation?> locate({String? typed, bool gps = false}) async {
        await _note(tester);
        await tester.enterText(_key('note-title'), 'Lift $typed $gps');
        await _tap(tester, _key('note-tool-location'));
        if (typed != null) {
          await tester.enterText(_key('note-location-typed'), typed);
          await tester.pumpAndSettle();
        }
        if (gps) {
          await _tap(tester, _key('note-gps-add'));
          expect(find.text(l10n.notebookGpsAdded), findsOneWidget);
          expect(find.textContaining('29.37594'), findsOneWidget);
        }
        await _tap(tester, _key('note-location-done'));
        await _tap(tester, _key('writing-post'));
        return app.notebook.kept.values.last.location;
      }

      final typed = await locate(typed: 'Grid C7');
      expect((typed!.text, typed.hasGps), ('Grid C7', false));
      final gps = await locate(gps: true);
      expect((gps!.text, gps.lat, gps.accuracyM), (null, 29.37594, 8));
      final both = await locate(typed: 'Level 3, grid C7', gps: true);
      expect((both!.text, both.lng), ('Level 3, grid C7', 47.9774));
      expect(asks, hasLength(2));
      expect(
        find.textContaining(l10n.notebookGpsChip('8')),
        findsWidgets,
        reason: 'the saved slip\'s chip says GPS ±8 m',
      );

      // × on the GPS row takes the position off, keeping the words.
      await _note(tester);
      await tester.enterText(_key('note-title'), 'Again');
      await _tap(tester, _key('note-tool-location'));
      await tester.enterText(_key('note-location-typed'), 'Core B');
      await _tap(tester, _key('note-gps-add'));
      await _tap(tester, _key('note-gps-remove'));
      expect(_draft(tester)!.location, const NoteLocation(text: 'Core B'));
    });

    testWidgets('NBX4: GPS refused says how to allow it [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, gps: _gps(failure: GpsFailure.denied));
      await _note(tester);
      await _tap(tester, _key('note-tool-location'));
      await _tap(tester, _key('note-gps-add'));
      expect(find.text(l10n.notebookGpsDenied), findsOneWidget);
      expect(_draft(tester)!.location, isNull);
    });

    testWidgets('Voice: hold for a voice block inside the note (B4) '
        '[$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _note(tester);
      await tester.enterText(_key('note-title'), 'Site walk');
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(_key('note-tool-voice')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 3));
      await gesture.up();
      await tester.pumpAndSettle();
      final voice = _draft(tester)!.blocks.whereType<PageVoice>().single;
      expect(voice.local, isNotNull);
      expect(_key('note-voice-${voice.id}'), findsOneWidget);
      // No voice note of its own.
      expect(app.notebook.kept, isEmpty);
      await _tap(tester, _key('writing-post'));
      final note = app.notebook.kept.values.single;
      final sent = note.blocks!.whereType<PageVoice>().single;
      expect(sent.path, 'user-1/${note.id}/voice.m4a');
      expect(app.notebook.calls, contains('upload:${note.id}'));
    });

    testWidgets('the Draft keeps the blocks and the additions, on the phone '
        'too [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _note(tester);
      await tester.enterText(_key('note-title'), n.walkTitle);
      await _tap(tester, _key('note-tool-categories'));
      await _tap(tester, _key('note-category-todo'));
      tester.testTextInput.enterText(n.walkPoints[0]);
      await tester.pumpAndSettle();
      await _tap(tester, _key('note-tool-location'));
      await tester.enterText(_key('note-location-typed'), 'Grid C7');
      await _tap(tester, _key('note-location-done'));
      await _tap(tester, _key('note-tool-file'));
      await _tap(tester, _key('note-tool-date'));
      await _back(tester);
      expect(_key('note-draft'), findsOneWidget);
      final raw = app.prefs.getString('notebook_draft:user-1')!;
      expect(raw, contains(n.walkPoints[0]));
      expect(raw, contains('Grid C7'));
      // Read again from the phone, as after the app closing.
      final container = _container(tester);
      container.invalidate(noteDraftProvider);
      final kept = container.read(noteDraftProvider)!;
      expect((kept.blocks.single as PageTodo).text, n.walkPoints[0]);
      expect(kept.location!.text, 'Grid C7');
      expect(kept.files.single.name, 'Level 3 plan.pdf');
      expect(kept.dueAt, DateTime(2026, 10, 15, 16));
      // A tap goes on writing, all of it there.
      await tester.pumpAndSettle();
      await _tap(tester, _key('note-draft'));
      expect(find.text(n.walkPoints[0]), findsOneWidget);
      expect(_key('note-file-0'), findsOneWidget);
    });

    testWidgets('an older note opens as blocks: a checklist\'s points are '
        'to-dos, ticks kept; saving writes a page [$lang]', (tester) async {
      final app = await _open(tester, lang, notes: [n.checklist()]);
      await _tap(tester, find.text(n.walkTitle));
      expect(_key('note-writing-card'), findsOneWidget);
      expect(
        tester.widget<TextField>(_key('note-title')).controller!.text,
        n.walkTitle,
      );
      final todos = _draft(tester)!.blocks.whereType<PageTodo>().toList();
      expect([for (final t in todos) t.text], n.walkPoints);
      expect([for (final t in todos) t.done], [true, true, false]);
      expect(find.text(n.walkPoints[2]), findsOneWidget);
      await tester.enterText(_key('note-title'), '${n.walkTitle}!');
      await _tap(tester, _key('writing-post'));
      final saved = app.notebook.kept['note-walk']!;
      expect(saved.isPage, isTrue);
      expect(saved.kind, NoteKind.text);
      expect(saved.blocks!.whereType<PageTodo>(), hasLength(3));
    });

    testWidgets('the saved slip: the title, the first 3 lines, the chips; '
        'a to-do ticks there; a tap edits in place [$lang]', (tester) async {
      final note = Note(
        id: 'note-slip',
        kind: NoteKind.text,
        title: 'Before the pour, level 3',
        body: 'x',
        blocks: const [
          PageTodo('a0000000-0000-4000-8000-000000000001', 'Check the sleeves'),
          PageTodo(
            'a0000000-0000-4000-8000-000000000002',
            'Clean the formwork',
          ),
          PageTodo('a0000000-0000-4000-8000-000000000003', 'Confirm the pump'),
          PageText('a0000000-0000-4000-8000-000000000004', 'Fourth line'),
        ],
        location: const NoteLocation(
          text: 'Grid C7',
          lat: 1,
          lng: 2,
          accuracyM: 8,
        ),
        dueAt: DateTime(2026, 10, 15, 14),
        photos: [
          NotePhoto(local: testPhotoPath),
          NotePhoto(local: testPhotoPath),
        ],
        files: const [NoteFile(path: 'user-1/note-slip/a.pdf', name: 'A.pdf')],
        createdAt: DateTime(2026, 10, 15, 9),
      );
      final app = await _open(tester, lang, notes: [note]);
      expect(find.text('Before the pour, level 3'), findsOneWidget);
      expect(find.text('Confirm the pump'), findsOneWidget);
      expect(find.text('Fourth line'), findsNothing);
      expect(find.text(l10n.notebookPhotoCount(2)), findsOneWidget);
      expect(find.text(l10n.notebookFileCount(1)), findsOneWidget);
      expect(find.textContaining('Grid C7'), findsOneWidget);
      await _tap(
        tester,
        _key('note-summary-tick-a0000000-0000-4000-8000-000000000001'),
      );
      final ticked = app.notebook.kept['note-slip']!.blocks!.first as PageTodo;
      expect(ticked.done, isTrue);
      await _tap(tester, find.text('Before the pour, level 3'));
      expect(_key('note-writing-card'), findsOneWidget);
      expect(find.text('Fourth line'), findsOneWidget);
    });

    // The F106 bugs fixed here --------------------------------------------

    testWidgets('B3: back from the camera the slip is still being written '
        '[$lang]', (tester) async {
      final shot = Completer<void>();
      await _open(tester, lang, cameraOpen: shot.future);
      await _note(tester);
      await tester.enterText(_key('note-title'), 'Sleeves');
      await _tap(tester, _key('note-tool-image'));
      await tester.tap(_key('note-image-camera'));
      await tester.pump();
      // The camera in front: the app goes behind.
      for (final s in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      shot.complete();
      await tester.pumpAndSettle();
      expect(_key('note-draft'), findsNothing);
      expect(_key('note-tools'), findsOneWidget);
      expect(_draft(tester)!.photos, hasLength(1));
    });

    testWidgets('B5: Remind me asks in its own words [$lang]', (tester) async {
      // The real pickers: no stand-in for the day and time here.
      final app = await pumpApp(
        tester,
        language: lang,
        now: NotebookSamples.now,
        notebook: FakeNotebookRepository(),
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/notebook/pages/page-my-notes');
      await tester.pumpAndSettle();
      await _note(tester);
      await _tap(tester, _key('note-tool-remind'));
      // The day: today, OK.
      await tester.tap(
        find.text(
          MaterialLocalizations.of(
            tester.element(find.byType(Dialog)),
          ).okButtonLabel,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.notebookRemindTime), findsOneWidget);
      expect(find.text(l10n.daybookDueTimeHelp), findsNothing);
      expect(find.text(l10n.notebookRemindMorning), findsOneWidget);
      expect(app.notebook.calls, isEmpty);
    });

    testWidgets('B8: what waits goes when the signal is back, and when the '
        'notebook opens [$lang]', (tester) async {
      final app = await _open(tester, lang);
      app.notebook.offline = true;
      await _note(tester);
      await tester.enterText(_key('note-title'), 'Rebar delivery 3 pm');
      await _tap(tester, _key('writing-post'));
      expect(find.text(l10n.daybookWaitingToSend), findsOneWidget);
      app.notebook.offline = false;
      // Something else got through.
      final signal = _container(tester).read(signalProvider.notifier);
      signal.lost();
      signal.back();
      await tester.pumpAndSettle();
      expect(app.notebook.kept, hasLength(1));
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);

      // Waiting from before: the notebook opening sends it.
      app.notebook.offline = true;
      await _note(tester);
      await tester.enterText(_key('note-title'), 'Crane at 6');
      await _tap(tester, _key('writing-post'));
      app.notebook.offline = false;
      GoRouter.of(tester.element(find.byType(Navigator).first)).pop();
      await tester.pumpAndSettle();
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/notebook/pages/page-my-notes');
      await tester.pumpAndSettle();
      expect(app.notebook.kept, hasLength(2));
    });

    testWidgets('B9: the notebook opens at the end of today; a sent note is '
        'in view [$lang]', (tester) async {
      final notes = [
        for (var i = 0; i < 12; i++)
          Note(
            id: 'n$i',
            kind: NoteKind.text,
            body: 'Note number $i',
            createdAt: DateTime(2026, 10, 15, 8, i),
          ),
      ];
      await _open(tester, lang, notes: notes);
      expect(find.text('Note number 11').hitTestable(), findsOneWidget);
      await _note(tester);
      await tester.enterText(_key('note-title'), 'The newest');
      await _tap(tester, _key('writing-post'));
      expect(find.text('The newest').hitTestable(), findsOneWidget);
    });

    testWidgets('B11: Put in a Space carries the photos and the typed place, '
        'and the GPS only when ticked [$lang]', (tester) async {
      final s = DaybookSamples(lang);
      final daybook = FakeDaybookRepository()
        ..posts[DaybookSamples.space] = const [];
      final app = await _open(
        tester,
        lang,
        notes: [
          _page(
            location: const NoteLocation(
              text: 'Level 3, grid C7',
              lat: 29.37594,
              lng: 47.9774,
              accuracyM: 8,
            ),
          ),
        ],
        spaces: _spaces(s),
        daybook: daybook,
      );
      DaybookPostDraft card() =>
          _container(tester).read(daybookDraftProvider(DaybookSamples.space))!;

      await tester.tap(_key('note-menu-note-page'));
      await tester.pumpAndSettle();
      expect(_key('note-include-gps'), findsOneWidget);
      await _tap(tester, _key('note-space-${DaybookSamples.space}'));
      expect(app.notebook.calls, contains('for-space:note-page:false'));
      expect(card().place, 'Level 3, grid C7');
      expect(card().photos, hasLength(1));
      expect(card().kind, DaybookKind.checklist);
      expect(card().points.single.text, 'Check the sleeves');

      // Again, with "Include my GPS position" ticked.
      await _container(
        tester,
      ).read(daybookDraftProvider(DaybookSamples.space).notifier).discard();
      GoRouter.of(tester.element(find.byType(Navigator).first)).pop();
      await tester.pumpAndSettle();
      await tester.tap(_key('note-menu-note-page'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('note-include-gps'));
      await _tap(tester, _key('note-space-${DaybookSamples.space}'));
      expect(app.notebook.calls, contains('for-space:note-page:true'));
      expect(card().place, 'Level 3, grid C7 · 29.37594, 47.97740');
    });

    testWidgets('B13: Send keeps the note on the phone before the draft '
        'goes [$lang]', (tester) async {
      final app = await _open(tester, lang);
      app.notebook.offline = true;
      await _note(tester);
      await tester.enterText(_key('note-title'), 'Keep me');
      await _tap(tester, _key('writing-post'));
      expect(
        app.prefs.getString('notebook_waiting:user-1'),
        contains('Keep me'),
      );
      expect(app.prefs.getString('notebook_draft:user-1'), isNull);
    });

    testWidgets('B14: an edit keeps a pin made since it began [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang, notes: [n.yesterday()]);
      await _tap(tester, _key('note-note-yesterday'));
      await tester.enterText(_key('note-title'), 'Door schedule');
      await tester.pumpAndSettle();
      // Pinned (another phone) while the edit is open; Back saves it in
      // place (review 100 B2).
      final notebook = _container(tester).read(notebookProvider.notifier);
      await notebook.pin(n.yesterday(), on: true);
      await tester.pumpAndSettle();
      await _back(tester);
      expect(app.notebook.kept['note-yesterday']!.pinned, isTrue);
      expect(app.notebook.kept['note-yesterday']!.title, 'Door schedule');
    });

    testWidgets('B15: a refused note says so and comes back as the Draft '
        '[$lang]', (tester) async {
      final app = await _open(tester, lang, notebook: _RefusingNotebook());
      await _note(tester);
      await tester.enterText(_key('note-title'), 'Refused words');
      await _tap(tester, _key('writing-post'));
      expect(find.text(l10n.notebookCouldntKeep), findsOneWidget);
      expect(_key('note-draft'), findsOneWidget);
      expect(_draft(tester)!.title, 'Refused words');
      expect(app.notebook.kept, isEmpty);
    });

    testWidgets('B16: a reminder whose time went by in the Draft is taken '
        'off at Send, and said [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        stored: {
          'notebook_draft:user-1':
              '{"id":"d1","started_at":"2026-10-15T08:00:00Z","title":"Old",'
              '"blocks":[],"remind_at":"2026-10-15T07:00:00Z"}',
        },
      );
      await _tap(tester, _key('note-draft'));
      await _tap(tester, _key('writing-post'));
      expect(find.text(l10n.notebookReminderGone), findsOneWidget);
      expect(app.notebook.kept['d1']!.remindAt, isNull);
    });

    testWidgets('B17: the bar\'s mic is read out [$lang]', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, lang);
      await _note(tester);
      expect(find.bySemanticsLabel(l10n.notebookVoiceTool), findsOneWidget);
      handle.dispose();
    });
  }
}

/// save_note refuses every note (not for want of a signal).
class _RefusingNotebook extends FakeNotebookRepository {
  @override
  Future<bool> save(Note note, {String? newPageTitle}) async {
    calls.add('save:${note.id}');
    throw const SpaceException(SpaceFailure.badInput);
  }
}
