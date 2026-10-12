import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/library/add_file_screen.dart';
import 'package:buildvibes/features/library/file_preview_screen.dart';
import 'package:buildvibes/features/library/library_parts.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/chat_fakes.dart';
import '../../helpers/library_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';
import '../../helpers/work_fakes.dart';

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
const _everyone = 'thread-everyone';
const _mep = 'thread-mep';
const _me = 'user-1';

FakeSpaceRepository _spaces({bool addFiles = true}) =>
    FakeSpaceRepository(now: testNow)
      ..details[_space] = SpaceDetail(
        id: _space,
        name: 'Site team',
        myPass: addFiles ? SpacePass.lead : SpacePass.viewer,
        iAmAdmin: addFiles,
        myRights: MemberRights(
          createItems: addFiles,
          checkItems: addFiles,
          addFiles: addFiles,
        ),
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
        teams: const [
          SpaceTeam(id: 'team-mep', name: 'MEP Team', memberIds: {_me}),
          SpaceTeam(id: 'team-st', name: 'Structure', memberIds: {_me}),
        ],
      );

FakeChatRepository _chat() => FakeChatRepository(now: testNow)
  ..threadsBySpace[_space] = const [
    ChatThread(id: _everyone),
    ChatThread(id: _mep, teamId: 'team-mep', teamName: 'MEP Team'),
  ]
  ..messagesByThread[_everyone] = [];

LibraryFile _file(
  String id,
  String name, {
  String? team,
  String? teamName,
  String mime = 'application/pdf',
  String? rev,
  String? supersedes,
  LibrarySource source = LibrarySource.upload,
}) => LibraryFile(
  id: id,
  spaceId: _space,
  name: name,
  path: '$_space/library/$id/x.pdf',
  mime: mime,
  createdAt: testNow,
  teamId: team,
  teamName: teamName,
  bytes: 4800000,
  revLabel: rev,
  supersedesId: supersedes,
  source: source,
  uploadedById: 'p-sami',
  uploadedByName: 'Sami Al-Mansour',
);

FakeLibraryRepository _library() => FakeLibraryRepository(now: testNow)
  ..filesBySpace[_space] = [
    _file(
      'f-mep2',
      'MEP risers.pdf',
      team: 'team-mep',
      teamName: 'MEP Team',
      rev: 'Rev C',
      supersedes: 'f-mep',
    ),
    _file(
      'f-mep',
      'MEP risers.pdf',
      team: 'team-mep',
      teamName: 'MEP Team',
      rev: 'Rev B',
    ),
    _file('f-all', 'Level 3 plan.pdf', source: LibrarySource.chat),
    _file('f-photo', 'Gate 3.jpg', mime: 'image/jpeg'),
    _file('f-st', 'Beams.pdf', team: 'team-st', teamName: 'Structure'),
  ]
  ..usedIn['f-mep2'] = const [
    FileUse(itemId: 'item-17', ref: 'KCT-017', title: 'Sleeves at grid C7'),
  ];

FakeWorkRepository _work() => FakeWorkRepository()
  ..itemsBySpace[_space] = [
    WorkItem(
      id: 'item-17',
      spaceId: _space,
      ref: 'KCT-017',
      title: 'Sleeves at grid C7',
      status: WorkStatus.open,
      createdAt: testNow,
      ownerId: _me,
      ownerName: 'Omar Haddad',
      createdById: _me,
      createdByName: 'Omar Haddad',
      teamId: 'team-mep',
      teamName: 'MEP Team',
    ),
  ];

Future<TestApp> _open(
  WidgetTester tester,
  String lang,
  String path, {
  bool addFiles = true,
  FakeChatRepository? chat,
  FakeLibraryRepository? library,
  FakeWorkRepository? work,
}) async {
  final w = work ?? _work();
  w.details['item-17'] = WorkItemDetail(
    item: w.itemsBySpace[_space]!.first,
    events: const [],
  );
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: _spaces(addFiles: addFiles),
    chat: chat ?? _chat(),
    library: library ?? _library(),
    work: w,
  );
  _router(tester).push(path);
  await tester.pumpAndSettle();
  return app;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('chat: a photo goes up with its message [$lang]', (
      tester,
    ) async {
      final chat = _chat();
      await _open(tester, lang, '/spaces/$_space/chat/$_everyone', chat: chat);
      await _tap(tester, 'chat-attach');
      await _tap(tester, 'chat-attach-gallery');
      expect(find.byKey(const Key('chat-picked')), findsOneWidget);
      await _tap(tester, 'chat-send');
      expect(chat.uploads.single, startsWith('$_space/chat/'));
      expect(chat.calls, contains('post $_everyone  files image/png'));
      expect(find.byKey(const Key('chat-photo-0')), findsOneWidget);
    });

    testWidgets('chat: a PDF carries its name; one per message [$lang]', (
      tester,
    ) async {
      final chat = _chat();
      await _open(tester, lang, '/spaces/$_space/chat/$_everyone', chat: chat);
      await _tap(tester, 'chat-attach');
      await _tap(tester, 'chat-attach-pdf');
      await _tap(tester, 'chat-attach');
      await _tap(tester, 'chat-attach-pdf');
      expect(find.text(l10n.chatOneDocument), findsOneWidget);
      ScaffoldMessenger.of(
        tester.element(find.byKey(const Key('chat-composer'))),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat-input')), 'Rev C');
      await tester.pumpAndSettle();
      await _tap(tester, 'chat-send');
      expect(chat.uploads.single, endsWith('.pdf'));
      expect(
        chat.calls,
        contains('post $_everyone Rev C files application/pdf'),
      );
      expect(chat.posted.single.single.name, 'Level 3 plan.pdf');
    });

    testWidgets('chat: a Viewer chats in text only [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        '/spaces/$_space/chat/$_everyone',
        addFiles: false,
      );
      expect(find.byKey(const Key('chat-composer')), findsOneWidget);
      expect(find.byKey(const Key('chat-attach')), findsNothing);
    });

    testWidgets('chat: a file in a message opens its preview [$lang]', (
      tester,
    ) async {
      final chat = _chat()
        ..messagesByThread[_everyone] = [
          ChatMessage(
            id: 'm1',
            threadId: _everyone,
            kind: ChatKind.file,
            createdAt: testNow,
            authorId: 'p-sami',
            authorName: 'Sami Al-Mansour',
            file: _file('f-all', 'Level 3 plan.pdf'),
          ),
        ];
      await _open(tester, lang, '/spaces/$_space/chat/$_everyone', chat: chat);
      await _tap(tester, 'chat-file-f-all');
      expect(find.byType(FilePreviewScreen), findsOneWidget);
    });

    testWidgets('chat: a shared file removed since says so [$lang]', (
      tester,
    ) async {
      // The Library file is gone: the link came back empty (review 14).
      final chat = _chat()
        ..messagesByThread[_everyone] = [
          ChatMessage(
            id: 'm1',
            threadId: _everyone,
            kind: ChatKind.file,
            createdAt: testNow,
            authorId: 'p-sami',
            authorName: 'Sami Al-Mansour',
          ),
        ];
      await _open(tester, lang, '/spaces/$_space/chat/$_everyone', chat: chat);
      expect(find.byKey(const Key('chat-file-removed')), findsOneWidget);
      expect(find.text(l10n.chatFileRemoved), findsOneWidget);
    });

    testWidgets('toasts sit above the bottom actions [$lang]', (tester) async {
      await _open(tester, lang, '/spaces/$_space');
      await _tap(tester, 'space-tab-library');
      await _tap(tester, 'library-add');
      await _tap(tester, 'add-file-pick');
      await _tap(tester, 'add-file-upload');
      // Review 14: "Added to the Library." doesn't cover Add file.
      final toast = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      final add = tester.getRect(find.byKey(const Key('library-add')));
      expect(toast.bottom, lessThanOrEqualTo(add.top));
      expect(BvToastSpec.lift, greaterThan(0));
    });

    testWidgets('S13k: current files only, search and Files [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, '/spaces/$_space');
      await _tap(tester, 'space-tab-library');
      // The older MEP revision is in the record, not the list.
      expect(find.byKey(const Key('file-f-mep2')), findsOneWidget);
      expect(find.byKey(const Key('file-f-mep')), findsNothing);
      expect(find.textContaining(l10n.libraryFromChat), findsOneWidget);
      await _tap(tester, 'library-filter-files');
      expect(find.byKey(const Key('file-f-photo')), findsNothing);
      await _tap(tester, 'library-filter-all');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('library-search')),
          matching: find.byType(TextField),
        ),
        'beams',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('file-f-st')), findsOneWidget);
      expect(find.byKey(const Key('file-f-all')), findsNothing);
      expect(find.byKey(const Key('library-add')), findsOneWidget);
    });

    testWidgets('S13k: no Add file without the files right [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, '/spaces/$_space', addFiles: false);
      await _tap(tester, 'space-tab-library');
      expect(find.byKey(const Key('library-add')), findsNothing);
    });

    testWidgets('Add file: pick, title from the file, one Team [$lang]', (
      tester,
    ) async {
      final library = _library();
      await _open(
        tester,
        lang,
        '/spaces/$_space/library/new',
        library: library,
      );
      expect(find.byType(AddFileScreen), findsOneWidget);
      await _tap(tester, 'add-file-upload');
      expect(find.text(l10n.libraryPickFirst), findsOneWidget);
      await _tap(tester, 'add-file-pick');
      expect(find.text('Level 3 plan'), findsOneWidget);
      await _tap(tester, 'add-file-team-team-mep');
      expect(
        find.text(l10n.libraryTeamOnly(inOwnDirection('MEP Team'))),
        findsOneWidget,
      );
      await _tap(tester, 'add-file-upload');
      expect(library.uploads.single, startsWith('$_space/library/'));
      expect(
        library.calls.single,
        'add Level 3 plan.pdf team:team-mep rev:- supersedes:-',
      );
    });

    testWidgets('F1: current, used in, older revisions [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, '/spaces/$_space/library/f-mep2');
      expect(find.byKey(const Key('preview-current')), findsOneWidget);
      expect(find.byKey(const Key('preview-used-item-17')), findsOneWidget);
      expect(find.byKey(const Key('preview-older-f-mep')), findsOneWidget);
      // No network in tests: the sheet says so instead of failing.
      expect(find.text(l10n.previewCantShow), findsOneWidget);
      await _tap(tester, 'preview-older-f-mep');
      expect(find.byKey(const Key('preview-open-current')), findsOneWidget);
      expect(find.byKey(const Key('preview-new-revision')), findsNothing);
    });

    testWidgets('F1: a Team file is shared in its Team only [$lang]', (
      tester,
    ) async {
      final chat = _chat();
      await _open(tester, lang, '/spaces/$_space/library/f-mep2', chat: chat);
      await _tap(tester, 'preview-share');
      expect(find.text(l10n.previewShareTeamOnly), findsOneWidget);
      expect(find.byKey(const Key('share-to-$_everyone')), findsNothing);
      await _tap(tester, 'share-to-$_mep');
      expect(chat.calls.single, 'share $_mep f-mep2');
      expect(
        find.text(l10n.previewShared(inOwnDirection('MEP Team'))),
        findsOneWidget,
      );
    });

    testWidgets('F1: Download saves the file; share through the phone '
        '[$lang]', (tester) async {
      final app = await _open(tester, lang, '/spaces/$_space/library/f-all');
      await _tap(tester, 'preview-download');
      expect(app.saved.single, 'Level 3 plan.pdf');
      expect(find.text(l10n.previewSaved), findsOneWidget);
      await _tap(tester, 'preview-share-file');
      expect(app.sharedFiles.single, 'Level 3 plan.pdf');
    });

    testWidgets('F1: a new revision keeps the Team and replaces it [$lang]', (
      tester,
    ) async {
      final library = _library();
      await _open(
        tester,
        lang,
        '/spaces/$_space/library/f-mep2',
        library: library,
      );
      await _tap(tester, 'preview-new-revision');
      expect(
        find.text(l10n.libraryRevisionOf(inOwnDirection('MEP risers.pdf'))),
        findsOneWidget,
      );
      // Who sees it comes from the older file.
      expect(find.byKey(const Key('add-file-everyone')), findsNothing);
      await _tap(tester, 'add-file-pick');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('add-file-rev')),
          matching: find.byType(TextField),
        ),
        'Rev D',
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'add-file-upload');
      expect(
        library.calls.single,
        'add Level 3 plan.pdf team:team-mep rev:Rev D supersedes:f-mep2',
      );
    });

    testWidgets('W3: Attached; attach only files that fit; Team chat '
        '[$lang]', (tester) async {
      final library = _library()..attachedTo['item-17'] = ['f-all'];
      await _open(
        tester,
        lang,
        '/spaces/$_space/items/item-17',
        library: library,
      );
      expect(find.text(l10n.workAttached), findsOneWidget);
      expect(find.byKey(const Key('attached-f-all')), findsOneWidget);
      await _tap(tester, 'work-attach');
      await _tap(tester, 'attach-from-library');
      expect(
        find.text(l10n.libraryPickTeamNote(inOwnDirection('MEP Team'))),
        findsOneWidget,
      );
      // Structure's file doesn't fit a MEP item; f-all is attached already.
      Finder inPicker(String key) => find.descendant(
        of: find.byKey(const Key('library-picker')),
        matching: find.byKey(Key(key)),
      );
      expect(inPicker('file-f-st'), findsNothing);
      expect(inPicker('file-f-all'), findsNothing);
      expect(inPicker('file-f-mep2'), findsOneWidget);
      await _tap(tester, 'file-f-mep2');
      expect(library.calls.single, 'attach item-17 f-mep2');
      expect(find.text(l10n.workAttachedToast), findsOneWidget);
      ScaffoldMessenger.of(
        tester.element(find.byKey(const Key('work-attached'))),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      await _tap(tester, 'work-team-chat');
      expect(
        find.text(l10n.chatTeamPrivacy(inOwnDirection('MEP Team'))),
        findsOneWidget,
      );
    });

    testWidgets('W2-A: files picked before the item exists [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, '/spaces/$_space/items/new');
      await _tap(tester, 'work-new-attach');
      expect(find.text(l10n.workAttachTitle('KCT-006')), findsOneWidget);
      expect(find.byKey(const Key('attach-take-photo')), findsOneWidget);
      await _tap(tester, 'attach-from-library');
      await _tap(tester, 'file-f-all');
      expect(find.byKey(const Key('attached-f-all')), findsOneWidget);
      await _tap(tester, 'attached-remove-f-all');
      expect(find.byKey(const Key('attached-f-all')), findsNothing);
    });

    testWidgets('outbox: a new item gets its files once it exists [$lang]', (
      tester,
    ) async {
      final library = _library();
      final app = await _open(
        tester,
        lang,
        '/spaces/$_space',
        library: library,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      );
      library.refuseAttach = null;
      final sent = await container
          .read(workOutboxProvider.notifier)
          .send(
            const PendingItem(
              id: 'item-new',
              spaceId: _space,
              title: 'Seal the riser',
              ownerId: _me,
              ownerName: 'Omar Haddad',
              attachFileIds: ['f-all'],
            ),
          );
      expect(sent, isTrue);
      expect(app.work.created.single.id, 'item-new');
      expect(library.calls.single, 'attach item-new f-all');
    });
  }

  test('a title from a file name (review 14)', () {
    expect(titleFromFileName('C15B33V_site_report.pdf'), 'C15B33V site report');
    expect(
      titleFromFileName('Level-3 beam  schedule.pdf'),
      'Level 3 beam schedule',
    );
    expect(titleFromFileName('plan'), 'plan');
  });
}
