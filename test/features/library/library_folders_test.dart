// Review 113 (8, 9): LB1 the Library's folders, and LB2 Link folder.
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/library_folder.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
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

LibraryFile _pdf(String id, String name, {String? folder, int? versionNo}) =>
    LibraryFile(
      id: id,
      spaceId: _space,
      name: name,
      path: '$_space/library/$id/x.pdf',
      mime: 'application/pdf',
      createdAt: DaybookSamples.thursday,
      bytes: 2400000,
      folderId: folder,
      versionNo: versionNo,
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

    testWidgets('Z10: a link that no longer passes is refused, not opened '
        '[$lang]', (tester) async {
      final app = await openLibrary(
        tester,
        lang,
        folders: const [
          LibraryFolder(
            id: 'f-old',
            name: 'Old link',
            share: FolderShare.space,
            url: 'https://docs.google.com/document/d/1',
            service: LinkService.googleDrive,
          ),
        ],
      );
      await _tap(tester, _key('folder-f-old'));
      expect(app.opened, isEmpty);
      expect(find.text(l10n.libraryLinkWrong), findsOneWidget);
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

    // libfix (Z14, privacy): the Library adds a file into its folder,
    // with the folder's sharing, and writes no post: a post would open it
    // for everyone who sees the post.
    for (final folder in ['f-mine', 'f-omar', 'f-mep', 'f-drawings', null]) {
      testWidgets(
        'libfix: Add a file ${folder == null ? 'at the top' : 'in $folder'} '
        'goes straight into the Library, with no post [$lang]',
        (tester) async {
          final app = await openLibrary(tester, lang, files: []);
          if (folder != null) await _tap(tester, _key('folder-$folder'));
          await _tap(tester, _key('library-add-file'));
          // Review 103: File from the phone, or Scan.
          await _tap(tester, _key('file-from-phone'));
          // Review 115 (2): at the top level, who sees it; the whole Space.
          if (folder == null) await _tap(tester, _key('library-who-add'));
          expect(_key('composer'), findsNothing);
          expect(
            app.library.calls.single,
            'add Level 3 plan.pdf team:- rev:- supersedes:-'
            '${folder == null ? '' : ' folder:$folder'}',
          );
          expect(app.library.uploadTypes, ['application/pdf']);
          expect(app.daybook.createdPosts, isEmpty);
          // In the list at once.
          expect(
            _key('file-${app.library.filesBySpace[_space]!.single.id}'),
            findsOneWidget,
          );
        },
      );
    }

    for (final (folder, team) in [
      (null, null),
      ('f-drawings', null),
      ('f-mep', 't-mep'),
    ]) {
      testWidgets(
        'libfix: a new version ${folder == null ? 'at the top' : 'in $folder'} '
        'tells that same audience with a small post [$lang]',
        (tester) async {
          final app = await openLibrary(
            tester,
            lang,
            files: [_pdf('old', 'A-501.pdf', folder: folder, versionNo: 1)],
          );
          if (folder != null) await _tap(tester, _key('folder-$folder'));
          await _tap(tester, _key('library-add-file'));
          // Review 103: File from the phone, or Scan.
          await _tap(tester, _key('file-from-phone'));
          await _tap(tester, _key('replaces-version'));
          await _tap(tester, _key('version-old'));
          await _tap(tester, _key('replaces-done'));
          expect(
            app.library.calls.single,
            'add Level 3 plan.pdf team:- rev:- supersedes:old'
            '${folder == null ? '' : ' folder:$folder'}',
          );
          final post = app.daybook.createdPosts.single;
          expect(post.kind, 'file');
          expect(post.teamId, team, reason: "the folder's own audience");
          expect(
            post.title,
            l10n.libraryNewVersionPost(
              'Level 3 plan.pdf',
              l10n.libraryVersionNo(2),
            ),
          );
          expect(
            post.libraryFileId,
            app.library.filesBySpace[_space]!.first.id,
            reason: 'the new version',
          );
          expect(_key('composer'), findsNothing);
        },
      );
    }

    for (final folder in ['f-mine', 'f-omar']) {
      testWidgets('libfix: a new version in $folder tells nobody [$lang]', (
        tester,
      ) async {
        final app = await openLibrary(
          tester,
          lang,
          files: [_pdf('old', 'A-501.pdf', folder: folder, versionNo: 1)],
        );
        await _tap(tester, _key('folder-$folder'));
        await _tap(tester, _key('library-add-file'));
        // Review 103: File from the phone, or Scan.
        await _tap(tester, _key('file-from-phone'));
        await _tap(tester, _key('replaces-version'));
        await _tap(tester, _key('version-old'));
        await _tap(tester, _key('replaces-done'));
        expect(
          app.library.calls.single,
          contains('supersedes:old folder:$folder'),
        );
        expect(app.daybook.createdPosts, isEmpty);
      });
    }

    testWidgets("libfix: Add a new version from a file's screen goes into its "
        'folder too, with no composer [$lang]', (tester) async {
      final app = await openLibrary(
        tester,
        lang,
        files: [_pdf('old', 'A-501.pdf', folder: 'f-mine', versionNo: 1)],
      );
      await _tap(tester, _key('folder-f-mine'));
      await _tap(tester, _key('file-old'));
      await _tap(tester, _key('file-add-version'));
      expect(_key('composer'), findsNothing);
      expect(
        app.library.calls.single,
        'add Level 3 plan.pdf team:- rev:- supersedes:old folder:f-mine',
      );
      expect(app.daybook.createdPosts, isEmpty);
    });

    testWidgets("libfix: the version question offers only this folder's "
        'files [$lang]', (tester) async {
      await openLibrary(
        tester,
        lang,
        files: [
          _pdf('here', 'A-501.pdf', folder: 'f-drawings'),
          _pdf('there', 'M-201.pdf', folder: 'f-mine'),
          _pdf('top', 'Gate pass list.pdf'),
        ],
      );
      await _tap(tester, _key('folder-f-drawings'));
      await _tap(tester, _key('library-add-file'));
      // Review 103: File from the phone, or Scan.
      await _tap(tester, _key('file-from-phone'));
      await _tap(tester, _key('replaces-version'));
      expect(_key('version-here'), findsOneWidget);
      expect(_key('version-there'), findsNothing);
      expect(_key('version-top'), findsNothing);
    });

    testWidgets('Z14: the line reads as the review wrote it [$lang]', (
      tester,
    ) async {
      expect(
        lookupAppLocalizations(const Locale('en')).postFileAudienceLine,
        'People who see this post can open this file.',
      );
      expect(
        lookupAppLocalizations(const Locale('ar')).postFileAudienceLine,
        'كل من يرى هذا المنشور يمكنه فتح هذا الملف.',
      );
    });
  }
}
