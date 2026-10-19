import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/library/library_parts.dart'
    show libraryDocumentLine;
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_faces.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_popover_menu.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
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
}) async {
  final s = DaybookSamples(lang);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail()
    ..spacePeople[DaybookSamples.space] = s.people();
  final daybook = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = [s.rebar()];
  final library = FakeLibraryRepository(now: DaybookSamples.thursday)
    ..filesBySpace[DaybookSamples.space] = [_revC];
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: spaces,
    daybook: daybook,
    library: library,
    now: DaybookSamples.thursday,
    galleryPhotos: galleryPhotos,
    overrides: [
      pickStartProvider.overrideWithValue(
        (context, {required now, start, end}) async =>
            start == null ? (start: _walkStart, end: _walkEnd) : null,
      ),
      pickPinProvider.overrideWithValue(
        (context, {required now, until}) async =>
            (until: DateTime(2026, 10, 17)),
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
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Opens a card, picks [kind] from the kind chip's menu (E6) and types
/// [title].
Future<void> _write(
  WidgetTester tester,
  AppLocalizations l10n,
  DaybookKind kind,
  String title,
) async {
  await _tap(tester, find.byKey(const Key('post-bar-notepad')));
  await _tap(tester, find.byKey(const Key('writing-kind-chip')));
  expect(find.byKey(const Key('writing-kind-menu')), findsOneWidget);
  await _tap(
    tester,
    find.descendant(
      of: find.byKey(const Key('writing-kind-menu')),
      matching: find.text(kindName(l10n, kind)),
    ),
  );
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

    testWidgets('E6: the kind chip opens one single choice of five, the '
        'one being written checked [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, find.byKey(const Key('post-bar-notepad')));
      await _tap(tester, find.byKey(const Key('writing-kind-chip')));
      final menu = tester.widget<BvPopoverMenu<DaybookKind>>(
        find.byKey(const Key('writing-kind-menu')),
      );
      expect(menu.picker, isTrue);
      expect(menu.selected, DaybookKind.workItem);
      expect([for (final i in menu.items) i.value], DaybookKind.values);
      await _tap(tester, find.text(l10n.daybookKindAnnouncement));
      expect(
        tester.widget<BvWritingCard>(find.byType(BvWritingCard)).kindLabel,
        l10n.daybookKindAnnouncement,
      );
    });

    testWidgets('F40: a point typed letter by letter keeps its field, its '
        'focus and every letter [$lang]', (tester) async {
      await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.checklist, s.handoverTitle);
      await tester.tap(_emptyPoint());
      await tester.pumpAndSettle();
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
      await tester.tap(_emptyPoint());
      await tester.pumpAndSettle();
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
      // Post asks who it is for first.
      await _post(tester);
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
      await _post(tester);
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
      await _tap(tester, find.bySemanticsLabel(l10n.daybookMore));
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

    testWidgets('a scheduled activity: Post with no start opens the time '
        'pickers, then posts [$lang]', (tester) async {
      final (app: _, :daybook) = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.activity, s.siteWalk);
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
      await _tap(tester, find.byKey(Key('replaces-${_revC.id}')));
      await _tap(tester, find.byKey(const Key('replaces-done')));
      await _post(tester);
      expect(app.library.calls.single, contains('supersedes:${_revC.id}'));
      final added = app.library.filesBySpace[DaybookSamples.space]!.first;
      expect(daybook.createdPosts.single.libraryFileId, added.id);
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
      await _tap(tester, find.byKey(const Key('attach-file')));
      await _tap(tester, find.byKey(const Key('file-from-phone')));
      await _tap(tester, find.byKey(const Key('replaces-none')));
      await _tap(tester, find.byKey(const Key('replaces-done')));
      // Someone to do it, then Post.
      await _post(tester);
      await _tap(
        tester,
        find.descendant(
          of: find.byType(BvGiveToPicker),
          matching: find.text(s.omarName),
        ),
      );
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
      // Post asks who it is for first.
      await _post(tester);
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
      await _tap(tester, find.bySemanticsLabel(l10n.daybookMore));
      await _tap(tester, find.text(l10n.daybookPeople));
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
      await _tap(tester, find.bySemanticsLabel(l10n.daybookMore));
      await _tap(tester, find.text(l10n.daybookPeople));
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

    for (final kind in DaybookKind.values) {
      testWidgets('F39: 📎 opens "Add to this post" on a ${kind.json} '
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
        expect(find.byKey(const Key('attach-photos')), findsOneWidget);
        expect(find.byKey(const Key('attach-file')), findsOneWidget);
        // F49: the File row says only what the server takes; F50: it keeps
        // its name "File".
        expect(
          find.descendant(
            of: find.byKey(const Key('attach-file')),
            matching: find.text(libraryDocumentLine()),
          ),
          findsOneWidget,
        );
        expect(libraryDocumentLine(), 'PDF');
        expect(
          find.descendant(
            of: find.byKey(const Key('attach-file')),
            matching: find.text(l10n.daybookKindFile),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('F50: the File kind reads "Document for receipt", with its '
        'small line [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, find.byKey(const Key('post-bar-notepad')));
      await _tap(tester, find.byKey(const Key('writing-kind-chip')));
      final menu = find.byKey(const Key('writing-kind-menu'));
      expect(
        find.descendant(
          of: menu,
          matching: find.text(l10n.daybookKindDocument),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: menu,
          matching: find.text(l10n.daybookKindDocumentNote),
        ),
        findsOneWidget,
      );
      // The old name is gone from the menu; 📎 → File keeps it.
      expect(
        find.descendant(of: menu, matching: find.text(l10n.daybookKindFile)),
        findsNothing,
      );
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
        await _post(tester);
        await _tap(
          tester,
          find.descendant(
            of: find.byType(BvGiveToPicker),
            matching: find.text(s.omarName),
          ),
        );
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
        await _post(tester);
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
