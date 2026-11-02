// Review 113 (8, 9): LB1 the Library's folders, and LB2 Link folder.
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/library_folder.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/library_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _space = DaybookSamples.space;

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// LB1's folders: Whole Space, a Team, a person, only me, a OneDrive link.
List<LibraryFolder> sampleFolders(DaybookSamples s) => [
  LibraryFolder(
    id: 'f-drawings',
    name: s.t('Drawings', 'المخططات'),
    share: FolderShare.space,
    mine: true,
  ),
  LibraryFolder(
    id: 'f-mep',
    name: s.t('MEP submittals', 'اعتمادات الميكانيكا والكهرباء'),
    share: FolderShare.team,
    shareTeamId: 't-mep',
    shareTeamName: 'Gulf MEP',
  ),
  LibraryFolder(
    id: 'f-omar',
    name: s.t('For Omar', 'لعمر'),
    share: FolderShare.person,
    sharePersonId: DaybookSamples.omar,
    sharePersonName: s.omarName,
    mine: true,
  ),
  LibraryFolder(
    id: 'f-mine',
    name: s.t('My site notes', 'ملاحظاتي'),
    share: FolderShare.onlyMe,
    mine: true,
  ),
  LibraryFolder(
    id: 'f-link',
    name: s.t('Shop drawings, Block B', 'مخططات تنفيذية، المبنى B'),
    share: FolderShare.space,
    url: 'https://1drv.ms/f/s!Ab3xYz',
    service: LinkService.oneDrive,
  ),
];

LibraryFile _pdf(String id, String name, {String? folder}) => LibraryFile(
  id: id,
  spaceId: _space,
  name: name,
  path: '$_space/library/$id/x.pdf',
  mime: 'application/pdf',
  createdAt: DaybookSamples.thursday,
  bytes: 2400000,
  folderId: folder,
);

Future<TestApp> openLibrary(
  WidgetTester tester,
  String lang, {
  bool addFiles = true,
  bool admin = true,
  List<LibraryFolder>? folders,
  List<LibraryFile>? files,
}) async {
  final s = DaybookSamples(lang);
  final library = FakeLibraryRepository(now: DaybookSamples.thursday)
    ..foldersBySpace[_space] = List.of(folders ?? sampleFolders(s))
    ..filesBySpace[_space] =
        files ??
        [
          _pdf('loose', 'Gate pass list.pdf'),
          _pdf('in-folder', 'A-501 Rev D.pdf', folder: 'f-drawings'),
        ];
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[_space] = s.detail(addFiles: addFiles, admin: admin)
      ..spacePeople[_space] = s.people(),
    daybook: FakeDaybookRepository()..posts[_space] = const [],
    library: library,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/$_space');
  await tester.pumpAndSettle();
  await _tap(tester, _key('space-library'));
  return app;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('LB1: each folder with who sees it; today\'s files stay '
        'where they are; a folder\'s files only inside it [$lang]', (
      tester,
    ) async {
      await openLibrary(tester, lang);
      expect(find.text(s.spaceName), findsOneWidget, reason: 'the Space');
      for (final f in sampleFolders(s)) {
        expect(_key('folder-${f.id}'), findsOneWidget);
      }
      String line(String id) =>
          tester.widget<Text>(_key('folder-line-$id')).data!;
      expect(line('f-drawings'), l10n.libraryShareSpace);
      expect(line('f-mep'), contains('Gulf MEP'));
      expect(line('f-omar'), contains(s.omarName));
      expect(line('f-mine'), l10n.libraryShareOnlyMe);
      expect(line('f-link'), contains(l10n.libraryLinkLine('OneDrive')));
      expect(line('f-link'), contains(l10n.libraryShareSpace));
      expect(_key('file-loose'), findsOneWidget);
      expect(_key('file-in-folder'), findsNothing);

      await _tap(tester, _key('folder-f-drawings'));
      expect(_key('file-in-folder'), findsOneWidget);
      expect(_key('file-loose'), findsNothing);
      expect(find.text(l10n.libraryAddToFolder), findsOneWidget);
    });

    testWidgets('LB1: a search looks through every file, folders too '
        '[$lang]', (tester) async {
      await openLibrary(tester, lang);
      await tester.enterText(
        find.descendant(
          of: _key('library-search'),
          matching: find.byType(TextField),
        ),
        'a-501',
      );
      await tester.pumpAndSettle();
      expect(_key('file-in-folder'), findsOneWidget);
      expect(_key('folder-f-drawings'), findsNothing);
    });

    testWidgets('LB1: + New folder for a Team: one choice, then the Team '
        '[$lang]', (tester) async {
      final app = await openLibrary(tester, lang, folders: const []);
      await _tap(tester, _key('library-add'));
      await _tap(tester, _key('library-new-folder'));
      expect(_key('folder-sheet'), findsOneWidget);
      expect(_key('folder-url'), findsNothing);
      expect(_key('folder-warning'), findsNothing);
      await tester.enterText(
        find.descendant(
          of: _key('folder-name'),
          matching: find.byType(TextField),
        ),
        'MEP submittals',
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('folder-share-team'));
      expect(_key('folder-team-picker'), findsOneWidget);
      await _tap(tester, _key('folder-team-t-mep'));
      await _tap(tester, _key('folder-save'));
      expect(app.library.folderCalls, [
        'create MEP submittals team team:t-mep',
      ]);
      expect(_key('folder-sheet'), findsNothing);
    });

    testWidgets('LB1: a person folder waits for its person [$lang]', (
      tester,
    ) async {
      final app = await openLibrary(tester, lang, folders: const []);
      await _tap(tester, _key('library-add'));
      await _tap(tester, _key('library-new-folder'));
      await tester.enterText(
        find.descendant(
          of: _key('folder-name'),
          matching: find.byType(TextField),
        ),
        'For Omar',
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('folder-share-person'));
      // Closed without a pick: Add stays off.
      expect(_key('folder-person-picker'), findsOneWidget);
      expect(
        _key('folder-person-${DaybookSamples.islam}'),
        findsNothing,
        reason: 'never myself',
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await _tap(tester, _key('folder-save'));
      expect(app.library.folderCalls, isEmpty);
      await _tap(tester, _key('folder-pick-person'));
      await _tap(tester, _key('folder-person-${DaybookSamples.omar}'));
      await _tap(tester, _key('folder-save'));
      expect(app.library.folderCalls, [
        'create For Omar person person:${DaybookSamples.omar}',
      ]);
    });

    testWidgets('LB2: + Link folder: the service found, the warning, Add '
        'folder [$lang]', (tester) async {
      final app = await openLibrary(tester, lang, folders: const []);
      await _tap(tester, _key('library-add'));
      await _tap(tester, _key('library-link-folder'));
      expect(_key('folder-warning'), findsOneWidget);
      expect(find.text(l10n.libraryLinkWarning), findsOneWidget);
      Finder field(String k) =>
          find.descendant(of: _key(k), matching: find.byType(TextField));
      await tester.enterText(field('folder-url'), 'https://example.com/x');
      await tester.enterText(field('folder-name'), 'Shop drawings, Block B');
      await tester.pumpAndSettle();
      expect(find.text(l10n.libraryLinkWrong), findsOneWidget);
      expect(_key('folder-service'), findsNothing);
      await _tap(tester, _key('folder-save'));
      expect(app.library.folderCalls, isEmpty, reason: 'Add stays off');

      await tester.enterText(field('folder-url'), 'https://1drv.ms/f/s!Ab3');
      await tester.pumpAndSettle();
      expect(find.text(l10n.libraryLinkFound('OneDrive')), findsOneWidget);
      // Whole Space is chosen at first (LB2).
      await _tap(tester, _key('folder-save'));
      expect(app.library.folderCalls, [
        'create Shop drawings, Block B space url:https://1drv.ms/f/s!Ab3',
      ]);
    });

    testWidgets('LB1: a linked folder opens in the browser [$lang]', (
      tester,
    ) async {
      final app = await openLibrary(tester, lang);
      await _tap(tester, _key('folder-f-link'));
      expect(app.opened, [Uri.parse('https://1drv.ms/f/s!Ab3xYz')]);
    });

    testWidgets('LB1: no + for who may not add files [$lang]', (tester) async {
      await openLibrary(tester, lang, addFiles: false);
      expect(_key('library-add'), findsNothing);
    });

    testWidgets('LB1: its creator edits and deletes it; a folder with files '
        'is refused in plain words [$lang]', (tester) async {
      final app = await openLibrary(tester, lang);
      await tester.longPress(_key('folder-f-mine'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('folder-edit'));
      await _tap(tester, _key('folder-share-space'));
      await _tap(tester, _key('folder-save'));
      expect(app.library.folderCalls.last, startsWith('update f-mine'));
      expect(app.library.folderCalls.last, endsWith(' space'));

      app.library.folderRefuses = const SpaceException(
        SpaceFailure.badInput,
        'empty it first',
      );
      await tester.longPress(_key('folder-f-drawings'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('folder-delete'));
      await _tap(tester, find.text(l10n.libraryDeleteFolder).last);
      expect(find.text(l10n.libraryFolderNotEmpty), findsOneWidget);
    });

    testWidgets('LB1: someone else\'s folder has nothing to hold [$lang]', (
      tester,
    ) async {
      // Not the admin, and not mine.
      await openLibrary(tester, lang, admin: false);
      await tester.longPress(_key('folder-f-mep'));
      await tester.pumpAndSettle();
      expect(_key('folder-menu'), findsNothing);
    });

    testWidgets('Add a file here: the post\'s file goes into the folder '
        '(p_folder) [$lang]', (tester) async {
      final app = await openLibrary(tester, lang);
      await _tap(tester, _key('folder-f-drawings'));
      await _tap(tester, _key('library-add-file'));
      expect(_key('composer'), findsOneWidget);
      await _tap(tester, _key('file-from-phone'));
      await _tap(tester, _key('replaces-none'));
      await _tap(tester, _key('replaces-done'));
      final draft = ProviderScope.containerOf(
        tester.element(_key('composer')),
      ).read(daybookDraftProvider(_space));
      expect(draft!.files.single.folderId, 'f-drawings');
      await _tap(tester, _key('writing-post'));
      expect(app.library.calls.single, endsWith('folder:f-drawings'));
      expect(app.library.uploadTypes, ['application/pdf']);
    });
  }
}
