import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/library/file_preview_screen.dart';
import 'package:buildvibes/features/library/library_file_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/work_outbox.dart'
    show refusalsProvider;
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/chat_fakes.dart';
import '../../helpers/library_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

const _space = 'space-1';
const _me = 'user-1';

FakeSpaceRepository _spaces({bool addFiles = true}) =>
    FakeSpaceRepository(now: testNow)
      ..details[_space] = SpaceDetail(
        id: _space,
        name: 'Site team',
        myPass: addFiles ? SpacePass.lead : SpacePass.viewer,
        iAmAdmin: addFiles,
        myRights: MemberRights(createItems: addFiles, addFiles: addFiles),
      )
      ..spacePeople[_space] = SpacePeople(
        members: [
          SpaceMember(
            person: const SpacePerson(
              id: _me,
              firstName: 'Omar',
              lastName: 'Haddad',
            ),
            pass: SpacePass.lead,
            isAdmin: true,
            confirmedAt: testNow,
          ),
        ],
      );

LibraryFile _file(
  String id,
  String name, {
  String? rev,
  String? supersedes,
  String? team,
  String by = 'p-lina',
  DateTime? at,
  LibrarySource source = LibrarySource.upload,
  int? no,
  String? chain,
}) => LibraryFile(
  id: id,
  spaceId: _space,
  name: name,
  path: '$_space/library/$id/x.pdf',
  mime: 'application/pdf',
  createdAt: at ?? testNow,
  teamId: team,
  teamName: team == null ? null : 'MEP Team',
  bytes: 4800000,
  revLabel: rev,
  supersedesId: supersedes,
  source: source,
  uploadedById: by,
  uploadedByName: by == _me ? 'Omar Haddad' : 'Lina Khalil',
  versionNo: no,
  chainId: chain,
);

/// A-501 is at Rev D with two older versions and new for me, received by
/// Islam and Omar (me); a delivery note came from chat, never posted.
FakeLibraryRepository _library() {
  final library = FakeLibraryRepository(now: testNow)
    ..filesBySpace[_space] = [
      _file('a501-d', 'A-501 Rev D.pdf', rev: 'Rev D', supersedes: 'a501-c'),
      _file(
        'a501-c',
        'A-501 Rev C.pdf',
        rev: 'Rev C',
        supersedes: 'a501-b',
        at: testNow.subtract(const Duration(days: 9)),
      ),
      _file(
        'a501-b',
        'A-501 Rev B.pdf',
        rev: 'Rev B',
        at: testNow.subtract(const Duration(days: 20)),
      ),
      _file(
        'note',
        'Pour 4 delivery note.pdf',
        source: LibrarySource.chat,
        at: testNow.subtract(const Duration(days: 3)),
      ),
    ]
    ..usedIn['a501-d'] = const [
      FileUse(itemId: 'item-17', ref: 'KCT-017', title: 'Sleeves at grid C7'),
    ]
    ..postByFile['a501-d'] = 'post-a501';
  final islam = LibraryReceipt(
    profileId: 'p-islam',
    name: 'Islam Ahmed',
    at: testNow.subtract(const Duration(hours: 2)),
  );
  library
    ..overviewBySpace[_space] = {
      'a501-d': LibraryOverview(
        fileId: 'a501-d',
        newForMe: true,
        received: [islam],
      ),
      'note': const LibraryOverview(fileId: 'note'),
    }
    ..receiptsByFile['a501-d'] = [islam];
  return library;
}

Future<TestApp> _open(
  WidgetTester tester,
  String lang,
  String path, {
  bool addFiles = true,
  FakeLibraryRepository? library,
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: _spaces(addFiles: addFiles),
    chat: FakeChatRepository(now: testNow)
      ..threadsBySpace[_space] = const []
      ..messagesByThread.clear(),
    library: library ?? _library(),
  );
  _router(tester).push(path);
  await tester.pumpAndSettle();
  return app;
}

DaybookPostDraft? _draft(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(SpaceScreen)),
).read(daybookDraftProvider(_space));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('LV1: versions in use only, their line, NEW VERSION, faces '
        '[$lang]', (tester) async {
      await _open(tester, lang, '/spaces/$_space');
      await _tap(tester, 'space-library');
      expect(find.byKey(const Key('file-a501-d')), findsOneWidget);
      expect(find.byKey(const Key('file-a501-c')), findsNothing);
      expect(find.byKey(const Key('file-a501-b')), findsNothing);
      expect(
        find.text(
          joinMeta(['Rev D', l10n.libraryOlderVersions(2), l10n.daybookToday]),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('file-new-version-a501-d')), findsOneWidget);
      expect(find.byKey(const Key('file-new-version-note')), findsNothing);
      // Faces, never "1 received" (rule 3); none for nobody.
      expect(find.byKey(const Key('file-faces-a501-d')), findsOneWidget);
      expect(find.byKey(const Key('file-faces-note')), findsNothing);
      // No chips, no Recent (review 67).
      expect(find.byKey(const Key('library-filter-all')), findsNothing);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('library-search')),
          matching: find.byType(TextField),
        ),
        'delivery',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('file-note')), findsOneWidget);
      expect(find.byKey(const Key('file-a501-d')), findsNothing);
    });

    testWidgets('LV1: no Add a file without the files right [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, '/spaces/$_space', addFiles: false);
      await _tap(tester, 'space-library');
      expect(find.byKey(const Key('library-add-file')), findsNothing);
    });

    testWidgets('LV1: Add a file opens the writing card as a Document, the '
        'chooser open [$lang]', (tester) async {
      await _open(tester, lang, '/spaces/$_space');
      await _tap(tester, 'space-library');
      await _tap(tester, 'library-add-file');
      // The Work tab, the card at Now, a file post, the chooser up.
      expect(find.byKey(const Key('daybook-writing-card')), findsOneWidget);
      expect(_draft(tester)?.kind, DaybookKind.file);
      expect(find.byKey(const Key('file-chooser')), findsOneWidget);
      await _tap(tester, 'file-from-phone');
      // A Library file is in use: is it a new version of one?
      expect(find.byKey(const Key('replaces-choice')), findsOneWidget);
      await _tap(tester, 'replaces-none');
      await _tap(tester, 'replaces-done');
      final files = _draft(tester)!.files;
      expect(files.single.name, 'Level 3 plan.pdf');
      expect(files.single.supersedesId, isNull);
      // Nothing went to the Library on its own: it goes with the post.
      expect(
        (tester.widget(find.byType(SpaceScreen)) as SpaceScreen).spaceId,
        _space,
      );
    });

    testWidgets('LV2: who received it, the Received pill, the versions '
        '[$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        '/spaces/$_space/library/a501-d/page',
      );
      expect(find.byType(LibraryFileScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('file-received-by')),
          matching: find.textContaining('Islam'),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('file-received')), findsOneWidget);
      expect(find.text(l10n.libraryInUse('Rev D')), findsOneWidget);
      expect(find.byKey(const Key('version-open-a501-c')), findsOneWidget);
      expect(find.byKey(const Key('version-open-a501-b')), findsOneWidget);
      expect(find.byKey(const Key('version-open-a501-d')), findsNothing);
      // Below the versions, each older one with when it was replaced.
      await tester.scrollUntilVisible(
        find.byKey(const Key('file-used-item-17')),
        100,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('library-file')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byKey(const Key('file-used-item-17')), findsOneWidget);

      // Received acts on the newest post carrying this version.
      await _tap(tester, 'file-received');
      expect(app.daybook.marks, ['ack post-a501 received true']);

      // An older version opens full screen.
      await _tap(tester, 'version-open-a501-c');
      expect(find.byType(FilePreviewScreen), findsOneWidget);
    });

    testWidgets('review 79: a refused Received says so on the file page, '
        'not on the Work tab under it [$lang]', (tester) async {
      final app = await _open(tester, lang, '/spaces/$_space');
      _router(tester).push('/spaces/$_space/library/a501-d/page');
      await tester.pumpAndSettle();
      app.daybook.refuse = true;
      await _tap(tester, 'file-received');
      final said = l10n.daybookRefusedPlain(l10n.daybookCouldNotAck);
      expect(
        find.descendant(
          of: find.byType(LibraryFileScreen),
          matching: find.text(said),
        ),
        findsOneWidget,
      );
      expect(find.text(said), findsOneWidget);
      // The Work tab isn't told: nothing waits for it there.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LibraryFileScreen)),
      );
      expect(container.read(refusalsProvider), isNull);
      expect(find.byType(LibraryFileScreen), findsOneWidget);
    });

    testWidgets('LV2: no post, no pill and no Received line [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, '/spaces/$_space/library/note/page');
      expect(find.byKey(const Key('file-received')), findsNothing);
      expect(find.byKey(const Key('file-received-by')), findsNothing);
      // From chat: no new version from here.
      expect(find.byKey(const Key('file-add-version')), findsNothing);
    });

    testWidgets('LV2: Add a new version opens the writing card with Replaces '
        'set [$lang]', (tester) async {
      final library = _library();
      await _open(tester, lang, '/spaces/$_space', library: library);
      await _tap(tester, 'space-library');
      await _tap(tester, 'file-a501-d');
      await _tap(tester, 'file-add-version');
      // Straight to the phone's files: no chooser, no question.
      expect(find.byKey(const Key('file-chooser')), findsNothing);
      expect(find.byKey(const Key('replaces-choice')), findsNothing);
      final file = _draft(tester)!.files.single;
      expect(file.supersedesId, 'a501-d');
      // "Replaces A-501 · Rev D" (F71; no number in this fake Library).
      expect(file.supersedesRev, endsWith('Rev D'));
      expect(
        find.descendant(
          of: find.byKey(Key('writing-replaces-${file.libraryId}')),
          matching: find.textContaining('Rev D'),
        ),
        findsOneWidget,
      );
      // Never added without its post (review 69 1b).
      expect(library.calls, isEmpty);
    });

    testWidgets('LV2: ⋯ has Share in chat and Download [$lang]', (
      tester,
    ) async {
      final app = await _open(
        tester,
        lang,
        '/spaces/$_space/library/a501-d/page',
      );
      await _tap(tester, 'file-more');
      expect(find.text(l10n.previewShare), findsOneWidget);
      await tester.tap(find.text(l10n.previewDownload));
      await tester.pumpAndSettle();
      expect(app.saved.single, 'A-501 Rev D.pdf');
    });

    testWidgets('LV2: my own version asks nothing of me [$lang]', (
      tester,
    ) async {
      final library = _library();
      library.filesBySpace[_space]![0] = _file(
        'a501-d',
        'A-501 Rev D.pdf',
        rev: 'Rev D',
        supersedes: 'a501-c',
        by: _me,
      );
      await _open(
        tester,
        lang,
        '/spaces/$_space/library/a501-d/page',
        library: library,
      );
      expect(find.byKey(const Key('file-received')), findsNothing);
      expect(find.byKey(const Key('file-received-by')), findsOneWidget);
    });

    testWidgets('F75, F80: versions by the app\'s number, exactly one in '
        'use; the older ones say when they were replaced [$lang]', (
      tester,
    ) async {
      final library = _library();
      library.filesBySpace[_space]!
        ..[0] = _file(
          'a501-d',
          'A-501 Rev D.pdf',
          rev: 'Rev D',
          supersedes: 'a501-c',
          no: 3,
          chain: 'a501-b',
        )
        ..[1] = _file(
          'a501-c',
          'A-501 Rev C.pdf',
          rev: 'Rev C',
          supersedes: 'a501-b',
          at: testNow.subtract(const Duration(days: 9)),
          no: 2,
          chain: 'a501-b',
        )
        ..[2] = _file(
          'a501-b',
          'A-501 Rev B.pdf',
          rev: 'Rev B',
          at: testNow.subtract(const Duration(days: 20)),
          no: 1,
          chain: 'a501-b',
        );
      await _open(
        tester,
        lang,
        '/spaces/$_space/library/a501-d/page',
        library: library,
      );
      final inUse = l10n.libraryInUseNo('').trim();
      expect(find.textContaining(inUse), findsOneWidget);
      for (final n in [1, 2, 3]) {
        expect(find.textContaining(l10n.libraryVersionNo(n)), findsWidgets);
      }
      expect(
        find.textContaining(l10n.libraryReplacedOn('').split(' ').first),
        findsNWidgets(2),
      );
    });

    testWidgets('F70: the empty Library line keeps the screen\'s margins '
        '[$lang]', (tester) async {
      await _open(
        tester,
        lang,
        '/spaces/$_space',
        library: FakeLibraryRepository(now: testNow)
          ..filesBySpace[_space] = const [],
      );
      await _tap(tester, 'space-library');
      final pad = tester.widget<Padding>(
        find.byKey(const Key('library-empty')),
      );
      expect((pad.padding as EdgeInsetsDirectional).start, BvSpace.gutter);
      expect((pad.padding as EdgeInsetsDirectional).end, BvSpace.gutter);
    });
  }
}
