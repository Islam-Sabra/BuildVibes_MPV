import 'dart:async';

import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/library/library_parts.dart'
    show libraryDocumentLine;
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_faces.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_popover_menu.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:buildvibes/shared/widgets/bv_writing_rows.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/library_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

/// Friday 16 October, 7:00 to 8:00: K2's site walk.
final _walkStart = DateTime(2026, 10, 16, 7);
final _walkEnd = DateTime(2026, 10, 16, 8);

/// The Library's M-201 Rev C (seed and K2).
final _revC = LibraryFile(
  id: 'lib-m201-c',
  spaceId: DaybookSamples.space,
  name: 'M-201.pdf',
  path: '${DaybookSamples.space}/library/lib-m201-c/M-201.pdf',
  mime: 'application/pdf',
  createdAt: DateTime(2026, 10, 10),
  bytes: 2400000,
  revLabel: 'Rev C',
);

typedef _App = ({TestApp app, FakeDaybookRepository daybook});

Future<_App> _open(
  WidgetTester tester,
  String lang, {
  int galleryPhotos = 2,
  int galleryRefused = 0,
  Future<void>? galleryPreparing,
  DateTime? pinTo,
  TimeOfDay pinTime = const TimeOfDay(hour: 14, minute: 0),
  LibraryFile? file,
}) async {
  final s = DaybookSamples(lang);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail(addFiles: true)
    ..spacePeople[DaybookSamples.space] = s.people();
  final daybook = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = [s.rebar()];
  final library = FakeLibraryRepository(now: DaybookSamples.thursday)
    ..filesBySpace[DaybookSamples.space] = [file ?? _revC];
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: spaces,
    daybook: daybook,
    library: library,
    now: DaybookSamples.thursday,
    galleryPhotos: galleryPhotos,
    galleryRefused: galleryRefused,
    galleryPreparing: galleryPreparing,
    overrides: [
      pickStartProvider.overrideWithValue(
        (context, {required now, start, end}) async =>
            start == null ? (start: _walkStart, end: _walkEnd) : null,
      ),
      pickPinProvider.overrideWithValue(
        (context, {required now, until}) async =>
            (until: pinTo ?? DateTime(2026, 10, 17)),
      ),
      pickPinTimeProvider.overrideWithValue(
        (context, {required initial}) async => pinTime,
      ),
    ],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return (app: app, daybook: daybook);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  // Review 105 SP2: the card is taller (kinds and rows): scroll to it.
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Opens a card, picks [kind] from the kind chips (review 105 SP2) and
/// types [title]. A file post starts from the Library's Add a file, its
/// file chooser open.
Future<void> _write(
  WidgetTester tester,
  AppLocalizations l10n,
  DaybookKind kind,
  String title,
) async {
  if (kind == DaybookKind.file) {
    await _tap(tester, find.byKey(const Key('space-library')));
    await _tap(tester, find.byKey(const Key('library-add-file')));
  } else {
    await _tap(tester, find.byKey(const Key('post-bar-notepad')));
    final chip = find.byKey(Key('kind-chip-$kind'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await _tap(tester, chip);
  }
  if (title.isNotEmpty) {
    await tester.enterText(find.byKey(const Key('writing-title')), title);
    await tester.pumpAndSettle();
  }
}

T _read<T>(WidgetTester tester, ProviderListenable<T> provider) =>
    ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    ).read(provider);

BvWritingToolbar _toolbar(WidgetTester tester) =>
    tester.widget<BvWritingToolbar>(find.byType(BvWritingToolbar));

Future<void> _post(WidgetTester tester) =>
    _tap(tester, find.byKey(const Key('writing-post')));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('review 105 SP2: the kinds are one choice of five chips, '
        'the one being written chosen [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, find.byKey(const Key('post-bar-notepad')));
      BvKindChips<DaybookKind> chips() =>
          tester.widget<BvKindChips<DaybookKind>>(
            find.byKey(const Key('writing-kinds')),
          );
      expect(chips().selected, DaybookKind.workItem);
      expect([for (final c in chips().choices) c.value], rowKinds);
      final chip = find.byKey(Key('kind-chip-${DaybookKind.announcement}'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await _tap(tester, chip);
      expect(chips().selected, DaybookKind.announcement);
    });

    testWidgets('F40: a point typed letter by letter keeps its field, its '
        'focus and every letter [$lang]', (tester) async {
      await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.checklist, s.handoverTitle);
      await _tap(tester, _emptyPoint());
      const words = 'Ceiling paint';
      Element? field;
      for (var i = 1; i <= words.length; i++) {
        // As the phone's keyboard does: into the field that has the focus.
        tester.testTextInput.enterText(words.substring(0, i));
        await tester.pump();
        final first = find
            .descendant(
              of: find.byKey(const Key('writing-points')),
              matching: find.byType(TextField),
            )
            .first;
        final now = tester.element(first);
        field ??= now;
        // The same field all along, never built again.
        expect(identical(now, field), isTrue, reason: 'letter $i');
        final text = tester.widget<TextField>(first);
        expect(text.focusNode!.hasFocus, isTrue, reason: 'letter $i');
        expect(text.controller!.text, words.substring(0, i));
      }
      // The point is kept, with an empty line under it.
      final draft = _read(tester, daybookDraftProvider(DaybookSamples.space));
      expect(draft!.writtenPoints.single.text, words);
    });

    testWidgets('F40: Enter goes to the next point; Backspace on an empty '
        'point takes it out and goes back [$lang]', (tester) async {
      await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.checklist, s.handoverTitle);
      await _tap(tester, _emptyPoint());
      tester.testTextInput.enterText('Doors');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      // On the empty line under it.
      TextField fieldAt(int i) => tester.widget<TextField>(
        find
            .descendant(
              of: find.byKey(const Key('writing-points')),
              matching: find.byType(TextField),
            )
            .at(i),
      );
      expect(fieldAt(1).focusNode!.hasFocus, isTrue);
      tester.testTextInput.enterText('Windows');
      await tester.pump();
      // Wipe it, then Backspace: it goes, back to "Doors".
      tester.testTextInput.enterText('');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      final draft = _read(tester, daybookDraftProvider(DaybookSamples.space));
      expect([for (final p in draft!.points) p.text], ['Doors']);
      expect(fieldAt(0).focusNode!.hasFocus, isTrue);
    });

    testWidgets('F41: points come back in the order they were typed [$lang]', (
      tester,
    ) async {
      final (app: _, :daybook) = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.checklist, s.handoverTitle);
      for (final p in ['Duct supports', 'Fire dampers', 'Diffusers']) {
        await tester.enterText(_emptyPoint(), p);
        await tester.pumpAndSettle();
      }
      // F56: Post asks on the who row, and the row opens the people.
      await _post(tester);
      expect(daybook.createdPosts, isEmpty);
      await _who(tester);
      await _pickPerson(tester, s.saraName);
      await _tap(tester, find.byKey(const Key('people-done')));
      await _post(tester);
      expect(
        [for (final p in daybook.createdPosts.single.points) p.text],
        ['Duct supports', 'Fire dampers', 'Diffusers'],
      );
    });

    testWidgets('a checklist: points typed in place; Post asks who it is '
        'for on a sheet, and posts once they are chosen [$lang]', (
      tester,
    ) async {
      final (:app, :daybook) = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.checklist, s.handoverTitle);
      // No point yet: Post is off.
      expect(_toolbar(tester).onPost, isNull);
      final points = s.handoverPoints();
      await tester.enterText(_emptyPoint(), points[0].text);
      await tester.pumpAndSettle();
      await tester.enterText(_emptyPoint(), points[1].text);
      await tester.pumpAndSettle();
      expect(_toolbar(tester).onPost, isNotNull);
      expect(_toolbar(tester).postReady, isFalse);
      // F56: Post asks on the who row; only the row opens the sheet.
      await _post(tester);
      expect(find.byKey(const Key('writing-people')), findsNothing);
      expect(find.text(l10n.daybookChooseWho), findsOneWidget);
      await _who(tester);
      expect(find.byKey(const Key('writing-people')), findsOneWidget);
      await _pickPerson(tester, s.saraName);
      // F45: a pick never closes the sheet, and never posts.
      expect(find.byKey(const Key('writing-people')), findsOneWidget);
      expect(daybook.createdPosts, isEmpty);
      await _tap(tester, find.byKey(const Key('people-done')));
      expect(daybook.createdPosts, isEmpty);
      await _post(tester);
      final sent = daybook.createdPosts.single;
      expect(sent.kind, DaybookPost.checklistKind);
      expect(sent.title, s.handoverTitle);
      expect(sent.people, [DaybookSamples.sara]);
      expect(
        [for (final p in sent.points) p.text],
        [points[0].text, points[1].text],
      );
      // App-chosen ids: one per point, kept as the post's.
      expect(sent.points.map((p) => p.id).toSet(), hasLength(2));
      expect(_read(tester, workOutboxProvider), isEmpty);
      expect(app.chimes, isNotEmpty);
    });

    testWidgets('an announcement pinned until a day [$lang]', (tester) async {
      final (app: _, :daybook) = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.announcement, s.halfDay);
      await _tap(tester, find.byKey(const Key('writing-add')));
      await _tap(tester, find.text(l10n.daybookPinUntil));
      expect(
        find.textContaining(
          l10n.daybookPinnedProperty(lang == 'ar' ? 'الجمعة' : 'Fri'),
        ),
        findsOneWidget,
      );
      await _post(tester);
      final sent = daybook.createdPosts.single;
      expect(sent.kind, DaybookPost.announcementKind);
      expect(sent.pinnedUntil, DateTime(2026, 10, 17));
      expect(sent.toParams()['p_people'], isEmpty);
    });

    testWidgets('F82: + Time pins until a time; ✕ takes the time away, and '
        'the pin ends with its day again [$lang]', (tester) async {
      final (app: _, :daybook) = await _open(tester, lang);
      final words = DaybookWords(l10n, lang, use24: false);
      final now = DaybookSamples.thursday;
      await _write(tester, l10n, DaybookKind.announcement, s.halfDay);
      await _tap(tester, find.byKey(const Key('writing-add')));
      await _tap(tester, find.text(l10n.daybookPinUntil));
      final pin = find.byKey(const Key('writing-pin'));
      final noTime = l10n.daybookPinnedProperty(
        words.pinnedShort(DateTime(2026, 10, 17), now),
      );
      expect(
        find.descendant(of: pin, matching: find.text(noTime)),
        findsOneWidget,
      );
      // No time yet: no ✕, and + Time.
      expect(find.byKey(const Key('writing-property-remove')), findsNothing);
      // Its start: the title's selection handle can sit over its middle.
      final addTime = find.text(l10n.daybookPinAddTime);
      await tester.ensureVisible(addTime);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getTopLeft(addTime) + const Offset(4, 4));
      await tester.pumpAndSettle();
      final at = DateTime(2026, 10, 16, 14);
      final withTime = l10n.daybookPinnedProperty(words.pinnedShort(at, now));
      expect(
        find.descendant(of: pin, matching: find.text(withTime)),
        findsOneWidget,
      );
      if (lang == 'en') expect(withTime, 'Pinned until Fri 2:00\u00A0pm');
      expect(find.text(l10n.daybookPinAddTime), findsNothing);
      await _tap(tester, find.bySemanticsLabel(l10n.daybookPinRemoveTime));
      expect(
        find.descendant(of: pin, matching: find.text(noTime)),
        findsOneWidget,
      );
      await tester.tapAt(tester.getTopLeft(addTime) + const Offset(4, 4));
      await tester.pumpAndSettle();
      await _post(tester);
      expect(daybook.createdPosts.single.pinnedUntil, at);
    });

    testWidgets('F82: a time today that has passed is refused before '
        'sending [$lang]', (tester) async {
      final (app: _, :daybook) = await _open(
        tester,
        lang,
        // Today (Thursday 10:30): until its end, then 9:00\u00A0am.
        pinTo: DateTime(2026, 10, 16),
        pinTime: const TimeOfDay(hour: 9, minute: 0),
      );
      final words = DaybookWords(l10n, lang, use24: false);
      await _write(tester, l10n, DaybookKind.announcement, s.halfDay);
      await _tap(tester, find.byKey(const Key('writing-add')));
      await _tap(tester, find.text(l10n.daybookPinUntil));
      final today = l10n.daybookPinnedProperty(
        words.pinnedShort(DateTime(2026, 10, 16), DaybookSamples.thursday),
      );
      if (lang == 'en') expect(today, 'Pinned until today');
      await tester.tap(find.text(l10n.daybookPinAddTime));
      await tester.pump();
      expect(find.text(l10n.daybookPinLater), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text(today), findsOneWidget);
      await _post(tester);
      expect(daybook.createdPosts.single.pinnedUntil, DateTime(2026, 10, 16));
    });

    testWidgets('F56: an announcement goes To: Everyone, or one Team chosen '
        'from a single choice [$lang]', (tester) async {
      final (app: _, :daybook) = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.announcement, s.halfDay);
      // Review 105 SP2: the Team row, the whole Space first.
      final to = find.byKey(const Key('writing-to'));
      expect(
        find.descendant(of: to, matching: find.text(l10n.daybookWholeSpace)),
        findsOneWidget,
      );
      // Review 79 A2: the caret is the mirrored icon, never a character.
      expect(
        find.descendant(of: to, matching: find.byIcon(BvIcons.caretForward)),
        findsOneWidget,
      );
      await _tap(tester, to);
      final menu = tester.widget<BvPopoverMenu<String>>(
        find.byKey(const Key('writing-to-menu')),
      );
      expect(menu.picker, isTrue);
      // A Space admin may post to any Team.
      expect(
        [for (final i in menu.items) i.label],
        [l10n.daybookEveryone, for (final t in s.people().teams) t.name],
      );
      final mep = s.people().teams.first;
      await _tap(
        tester,
        find.descendant(
          of: find.byKey(const Key('writing-to-menu')),
          matching: find.text(mep.name),
        ),
      );
      expect(
        find.descendant(of: to, matching: find.text(mep.name)),
        findsOneWidget,
      );
      await _post(tester);
      final sent = daybook.createdPosts.single;
      expect(sent.teamId, mep.id);
      expect(sent.toParams()['p_team'], mep.id);
    });

    testWidgets('a scheduled activity: who\'s coming first; then Post with '
        'no start opens the time pickers, and only Post posts [$lang]', (
      tester,
    ) async {
      final (app: _, :daybook) = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.activity, s.siteWalk);
      expect(
        find.descendant(
          of: find.byKey(const Key('writing-who')),
          matching: find.text(l10n.daybookRowChoose),
        ),
        findsOneWidget,
      );
      await _who(tester);
      await _pickPerson(tester, s.saraName);
      await _tap(tester, find.byKey(const Key('people-done')));
      await _post(tester);
      // The pickers only fill the card (F56).
      expect(daybook.createdPosts, isEmpty);
      await _post(tester);
      final sent = daybook.createdPosts.single;
      expect(sent.kind, DaybookPost.activityKind);
      expect(sent.startsAt, _walkStart);
      expect(sent.endsAt, _walkEnd);
    });

    testWidgets('a file post from the Library: picking File goes straight to '
        'the file; the title may stay empty [$lang]', (tester) async {
      final (app: _, :daybook) = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.file, '');
      expect(find.byKey(const Key('file-chooser')), findsOneWidget);
      await _tap(tester, find.byKey(Key('file-${_revC.id}')));
      expect(_toolbar(tester).onPost, isNotNull);
      await _post(tester);
      final sent = daybook.createdPosts.single;
      expect(sent.kind, DaybookPost.fileKind);
      expect(sent.libraryFileId, _revC.id);
      expect(sent.toParams()['p_title'], isNull);
    });

    testWidgets('a file post from the phone, a new version of Rev C: into '
        'the Library first, then the post [$lang]', (tester) async {
      final (:app, :daybook) = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.file, 'M-201 Rev D');
      await _tap(tester, find.byKey(const Key('file-from-phone')));
      expect(find.byKey(const Key('replaces-choice')), findsOneWidget);
      // F71: New file chosen first; New version opens the files, searchable.
      await _tap(tester, find.byKey(const Key('replaces-version')));
      expect(find.byKey(const Key('version-picker')), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('version-search')),
          matching: find.byType(TextField),
        ),
        'm-2',
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(Key('version-${_revC.id}')));
      expect(find.byKey(const Key('replaces-picked')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('replaces-done')));
      // The card: "Replaces M-201.pdf · Rev C", with ✕.
      expect(
        find.byWidgetPredicate((w) => '${w.key}'.contains('writing-replaces-')),
        findsOneWidget,
      );
      await _post(tester);
      expect(app.library.calls.single, contains('supersedes:${_revC.id}'));
      final added = app.library.filesBySpace[DaybookSamples.space]!.first;
      expect(daybook.createdPosts.single.libraryFileId, added.id);
    });

    testWidgets('Review 81 R2: a new version from the paper clip on a note '
        'turns the card into a File post, keeping what was typed; it goes '
        'as the post\'s file, V4 replacing V3 [$lang]', (tester) async {
      final v3 = LibraryFile(
        id: 'lib-m201-v3',
        spaceId: DaybookSamples.space,
        name: 'M-201.pdf',
        path: '${DaybookSamples.space}/library/lib-m201-v3/M-201.pdf',
        mime: 'application/pdf',
        createdAt: DateTime(2026, 10, 10),
        bytes: 4600000,
        versionNo: 3,
      );
      final (:app, :daybook) = await _open(tester, lang, file: v3);
      await _write(tester, l10n, DaybookKind.note, s.handoverTitle);
      await tester.enterText(find.byKey(const Key('writing-body')), 'Rev D');
      await tester.pumpAndSettle();
      await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
      await _tap(tester, find.byKey(const Key('attach-file')));
      await _tap(tester, find.byKey(const Key('replaces-version')));
      await _tap(tester, find.byKey(Key('version-${v3.id}')));
      await _tap(tester, find.byKey(const Key('replaces-done')));
      final card = tester.widget<BvWritingCard>(find.byType(BvWritingCard));
      expect(card.kindLabel, l10n.daybookKindDocument);
      expect(find.text(s.handoverTitle), findsOneWidget);
      expect(find.text('Rev D'), findsOneWidget);
      await _post(tester);
      final added = app.library.filesBySpace[DaybookSamples.space]!.first;
      expect(added.supersedesId, v3.id);
      expect(added.versionNo, 4);
      final sent = daybook.createdPosts.single;
      expect(sent.kind, DaybookPost.fileKind);
      expect(sent.libraryFileId, added.id);
      expect(sent.attachedFileIds, isEmpty);
      expect(sent.title, s.handoverTitle);
      // V3's file now says it was replaced by V4.
      final older = await app.library.detail(v3.id);
      expect(older!.supersededById, added.id);
    });

    testWidgets('a plain new PDF on a note stays the note\'s file [$lang]', (
      tester,
    ) async {
      final (app: _, :daybook) = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.note, s.handoverTitle);
      await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
      await _tap(tester, find.byKey(const Key('attach-file')));
      await _tap(tester, find.byKey(const Key('replaces-done')));
      expect(
        tester
            .widget<BvKindChips<DaybookKind>>(
              find.byKey(const Key('writing-kinds')),
            )
            .selected,
        DaybookKind.note,
      );
      await _post(tester);
      final sent = daybook.createdPosts.single;
      expect(sent.kind, DaybookPost.noteKind);
      expect(sent.libraryFileId, isNull);
      expect(sent.attachedFileIds, hasLength(1));
    });

    testWidgets('a lost answer from the Library: the next try finds its own '
        'id there and goes on to the post, once [$lang]', (tester) async {
      final (:app, :daybook) = await _open(tester, lang);
      app.library.loseAnswer = true;
      await _write(tester, l10n, DaybookKind.file, 'M-201 Rev D');
      await _tap(tester, find.byKey(const Key('file-from-phone')));
      await _tap(tester, find.byKey(const Key('replaces-none')));
      await _tap(tester, find.byKey(const Key('replaces-done')));
      await _post(tester);
      expect(app.library.calls, hasLength(1));
      final added = app.library.filesBySpace[DaybookSamples.space]!.first;
      expect(daybook.createdPosts.single.libraryFileId, added.id);
      expect(_read(tester, workOutboxProvider), isEmpty);
    });

    testWidgets('F73: a large file says how much has gone while it '
        'uploads, with a line; no signal says Waiting to send [$lang]', (
      tester,
    ) async {
      final (:app, :daybook) = await _open(tester, lang);
      final hold = Completer<void>();
      app.library.holdUpload = hold;
      await _write(tester, l10n, DaybookKind.file, 'M-201 Rev D');
      await _tap(tester, find.byKey(const Key('file-from-phone')));
      await _tap(tester, find.byKey(const Key('replaces-none')));
      await _tap(tester, find.byKey(const Key('replaces-done')));
      await _post(tester);
      // 4.8 MB (the test PDF): a third has gone.
      expect(find.byKey(const Key('card-sending')), findsOneWidget);
      expect(find.text(l10n.daybookSendingBytes('1.5', '4.6')), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      // The signal drops: the try ends, and it waits.
      daybook.offline = true;
      hold.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('card-sending')), findsNothing);
      expect(find.text(l10n.daybookWaitingToSend), findsOneWidget);
    });

    testWidgets('Review 74 H2: photos still being prepared show as '
        '"Preparing…" slots on the card, which stays usable [$lang]', (
      tester,
    ) async {
      final ready = Completer<void>();
      await _open(tester, lang, galleryPreparing: ready.future);
      await _tap(tester, find.byKey(const Key('post-bar-notepad')));
      await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
      await tester.tap(find.byKey(const Key('attach-photos')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 2; i++) {
        expect(find.byKey(Key('writing-photo-preparing-$i')), findsOneWidget);
      }
      expect(find.text(l10n.photoPreparing), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      // Still writing meanwhile.
      await tester.enterText(
        find.byKey(const Key('writing-title')),
        s.cableTraysTitle,
      );
      await tester.pump();
      expect(find.text(s.cableTraysTitle), findsOneWidget);
      ready.complete();
      await tester.pumpAndSettle();
      expect(find.text(l10n.photoPreparing), findsNothing);
      expect(
        tester.widget<BvWritingCard>(find.byType(BvWritingCard)).photos,
        hasLength(2),
      );
    });

    testWidgets("Review 74 H1: a picked photo nobody could open isn't sent: "
        'one line, and the others still go [$lang]', (tester) async {
      await _open(tester, lang, galleryRefused: 1);
      await _tap(tester, find.byKey(const Key('post-bar-notepad')));
      await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
      await _tap(tester, find.byKey(const Key('attach-photos')));
      expect(find.text(l10n.photoCannotOpen), findsOneWidget);
      expect(
        tester.widget<BvWritingCard>(find.byType(BvWritingCard)).photos,
        hasLength(2),
      );
    });

    testWidgets('K4: 📎 on a work item: photos from the gallery and a file, '
        'which goes to the Library and onto the item [$lang]', (tester) async {
      final (:app, :daybook) = await _open(tester, lang);
      await _tap(tester, find.byKey(const Key('post-bar-notepad')));
      await tester.enterText(
        find.byKey(const Key('writing-title')),
        s.cableTraysTitle,
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
      expect(find.byKey(const Key('attach-sheet')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('attach-photos')));
      // From the gallery, not the camera (proof photos stay camera only).
      expect(app.cameraAsks, [false]);
      expect(
        tester.widget<BvWritingCard>(find.byType(BvWritingCard)).photos,
        hasLength(2),
      );
      await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
      // F72: the phone's files straight away.
      await _tap(tester, find.byKey(const Key('attach-file')));
      await _tap(tester, find.byKey(const Key('replaces-none')));
      await _tap(tester, find.byKey(const Key('replaces-done')));
      // Someone to do it, then Post.
      await _who(tester);
      await _tap(
        tester,
        find.descendant(
          of: find.byType(BvGiveToPicker),
          matching: find.text(s.omarName),
        ),
      );
      await _post(tester);
      final item = daybook.created.single;
      expect(item.photoPaths, hasLength(2));
      final added = app.library.filesBySpace[DaybookSamples.space]!.first;
      expect(app.library.calls.single, contains('supersedes:-'));
      expect(daybook.marks, ['attach ${item.id} ${added.id}']);
    });

    testWidgets('a refused checklist comes back as its Draft, still a '
        'checklist [$lang]', (tester) async {
      final (app: _, :daybook) = await _open(tester, lang);
      daybook.refuse = true;
      await _write(tester, l10n, DaybookKind.checklist, s.handoverTitle);
      await tester.enterText(_emptyPoint(), 'Doors');
      await tester.pumpAndSettle();
      // F56: Post asks on the who row, and the row opens the people.
      await _post(tester);
      expect(daybook.createdPosts, isEmpty);
      await _who(tester);
      await _pickPerson(tester, s.saraName);
      await _tap(tester, find.byKey(const Key('people-done')));
      await _post(tester);
      final draft = _read(tester, daybookDraftProvider(DaybookSamples.space));
      expect(draft?.kind, DaybookKind.checklist);
      expect(draft?.couldNotSend, isTrue);
      expect(draft?.writtenPoints.single.text, 'Doors');
      expect(find.text(l10n.daybookCouldNotSend), findsOneWidget);
    });
  }

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('F45: pick one, then Done: back on the card with the face, '
        'nothing posted [$lang]', (tester) async {
      final (app: _, :daybook) = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.activity, s.siteWalk);
      // Review 105 SP2: the For row.
      await _who(tester);
      await _pickPerson(tester, s.omarName);
      // The chosen faces sit by Done, never a number.
      expect(
        find.descendant(
          of: find.byType(DaybookPeopleDone),
          matching: find.byType(BvFaces),
        ),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('people-done')));
      expect(find.byKey(const Key('writing-people')), findsNothing);
      final draft = _read(tester, daybookDraftProvider(DaybookSamples.space));
      expect(draft!.people.single.id, DaybookSamples.omar);
      expect(daybook.createdPosts, isEmpty);
    });

    testWidgets('F45: pick two, then drag the sheet down: both kept, '
        'nothing posted [$lang]', (tester) async {
      final (app: _, :daybook) = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.activity, s.siteWalk);
      await _who(tester);
      await _pickPerson(tester, s.omarName);
      await _pickPerson(tester, s.saraName);
      await tester.drag(
        find.byKey(const Key('bv-sheet-handle')),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('writing-people')), findsNothing);
      final draft = _read(tester, daybookDraftProvider(DaybookSamples.space));
      expect(
        {for (final p in draft!.people) p.id},
        {DaybookSamples.omar, DaybookSamples.sara},
      );
      expect(daybook.createdPosts, isEmpty);
    });
  }

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    // A daily report starts from Space info, with its own tests.
    for (final kind in [...rowKinds, DaybookKind.file]) {
      testWidgets('F39, F72: 📎 is the one way to add: Camera, Photos, a '
          'file from the phone and From the Library on a ${kind.json} '
          '[$lang]', (tester) async {
        await _open(tester, lang);
        await _write(
          tester,
          l10n,
          kind,
          kind == DaybookKind.file ? '' : s.handoverTitle,
        );
        // A file post goes to its file first.
        if (kind == DaybookKind.file) {
          await _tap(tester, find.byKey(const Key('file-lib-m201-c')));
        }
        await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
        expect(find.byKey(const Key('attach-sheet')), findsOneWidget);
        // A file post is its file: no photos there.
        final photos = kind == DaybookKind.file ? findsNothing : findsOneWidget;
        expect(find.byKey(const Key('attach-camera')), photos);
        expect(find.byKey(const Key('attach-photos')), photos);
        expect(find.byKey(const Key('attach-file')), findsOneWidget);
        expect(find.byKey(const Key('attach-library')), findsOneWidget);
        // F49: the phone's row says only what the server takes.
        expect(
          find.descendant(
            of: find.byKey(const Key('attach-file')),
            matching: find.text(libraryDocumentLine()),
          ),
          findsOneWidget,
        );
        expect(libraryDocumentLine(), 'PDF');
      });
    }

    testWidgets('F74, review 105 SP2: File isn\'t a kind chip; a file post '
        'starts from the Library [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, find.byKey(const Key('post-bar-notepad')));
      expect(find.byKey(Key('kind-chip-${DaybookKind.file}')), findsNothing);
      expect(l10n.daybookKindDocument, lang == 'en' ? 'File' : 'ملف');
    });

    for (final count in [2, DaybookPostDraft.filesMax]) {
      testWidgets('F51: $count gallery photos on a work item: all posted, in '
          'order [$lang]', (tester) async {
        final (app: _, :daybook) = await _open(
          tester,
          lang,
          galleryPhotos: count,
        );
        await _tap(tester, find.byKey(const Key('post-bar-notepad')));
        await tester.enterText(
          find.byKey(const Key('writing-title')),
          s.cableTraysTitle,
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
        await _tap(tester, find.byKey(const Key('attach-photos')));
        await _who(tester);
        await _tap(
          tester,
          find.descendant(
            of: find.byType(BvGiveToPicker),
            matching: find.text(s.omarName),
          ),
        );
        await _post(tester);
        final item = daybook.created.single;
        expect(item.photoPaths, hasLength(count));
        // In the order they were picked, which is the order sent.
        expect(item.photoPaths, daybook.uploads);
      });

      testWidgets('F51: $count gallery photos on a checklist: all posted, in '
          'order [$lang]', (tester) async {
        final (app: _, :daybook) = await _open(
          tester,
          lang,
          galleryPhotos: count,
        );
        await _write(tester, l10n, DaybookKind.checklist, s.handoverTitle);
        await tester.enterText(_emptyPoint(), 'Doors');
        await tester.pumpAndSettle();
        await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
        await _tap(tester, find.byKey(const Key('attach-photos')));
        await _who(tester);
        await _pickPerson(tester, s.saraName);
        await _tap(tester, find.byKey(const Key('people-done')));
        await _post(tester);
        final post = daybook.createdPosts.single;
        expect(post.photoPaths, hasLength(count));
        expect(post.photoPaths, daybook.uploads);
      });
    }
  }

  test('the pin picker pins to the end of the day it picks', () {
    expect(pinDaysMax, 90);
    expect(
      pinnedLastDay(DateTime(2026, 10, 17)),
      DateTime(2026, 10, 16, 23, 59),
    );
  });

  test('F82: a pin has a time unless it ends at midnight', () {
    expect(pinHasTime(DateTime(2026, 10, 17)), isFalse);
    expect(pinHasTime(DateTime(2026, 10, 16, 14)), isTrue);
    expect(pinToEndOf(DateTime(2026, 10, 16)), DateTime(2026, 10, 17));
    expect(pinnedLastDay(DateTime(2026, 10, 16, 14)).day, 16);
  });

  test('F56: who may post to which Team: an admin to any, a member to their '
      'own, and someone in none to Everyone only', () {
    final people = const DaybookSamples('en').people();
    expect(
      audienceTeams(people, me: DaybookSamples.islam, admin: true),
      people.teams,
    );
    expect(
      [
        for (final t in audienceTeams(
          people,
          me: DaybookSamples.omar,
          admin: false,
        ))
          t.name,
      ],
      ['MEP'],
    );
    expect(
      audienceTeams(people, me: DaybookSamples.islam, admin: false),
      isEmpty,
    );
    expect(audienceTeams(null, me: DaybookSamples.omar, admin: true), isEmpty);
  });

  test('assignable people are Lead and Crew; an activity is for anyone', () {
    final people = const DaybookSamples('en').people();
    expect(
      assignablePeople(people).map((p) => p.id),
      isNot(contains(DaybookSamples.mona)),
    );
    expect(attendees(people).map((p) => p.id), contains(DaybookSamples.mona));
    expect(
      assignablePeople(people, me: DaybookSamples.islam).last.id,
      DaybookSamples.islam,
    );
    expect(SpacePass.viewer, isNotNull);
  });
}

/// Picks [name] on the people sheet.
/// Taps the card's "who" row (F56), scrolled into view first.
Future<void> _who(WidgetTester tester) async {
  final row = find.byKey(const Key('writing-who'));
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  // Its icon: the title's selection handle can sit over the middle.
  await tester.tap(find.descendant(of: row, matching: find.byType(Icon)).first);
  await tester.pumpAndSettle();
}

Future<void> _pickPerson(WidgetTester tester, String name) async {
  final row = find.descendant(
    of: find.byKey(const Key('writing-people')),
    matching: find.text(name),
  );
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

/// The checklist's empty last line ("Add a point").
Finder _emptyPoint() => find
    .descendant(
      of: find.byKey(const Key('writing-points')),
      matching: find.byType(TextField),
    )
    .last;
