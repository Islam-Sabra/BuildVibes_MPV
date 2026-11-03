// Review 115: (1) a Library file goes through the outbox, as posts do: it
// shows in its folder at once with "Uploading 40%", waits for signal, and
// "Couldn't upload · Tap to fix" opens the composer's line; (2) at the
// Library's top level, "Who sees it: Whole Space · Change" before it goes,
// a choice that puts it in a matching folder, made once. In English and
// Arabic.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/core/file_cache.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/library_folder.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/library_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

const _space = DaybookSamples.space;

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<LibraryFolder> folders = const [],
  List<LibraryFile>? files,
}) async {
  final s = DaybookSamples(lang);
  final library = FakeLibraryRepository(now: DaybookSamples.thursday)
    ..foldersBySpace[_space] = List.of(folders)
    ..filesBySpace[_space] = files ?? [];
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[_space] = s.detail(addFiles: true)
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

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

List<PendingItem> _waiting(WidgetTester tester) => [
  for (final i in _container(tester).read(workOutboxProvider))
    if (i.kind == PendingKind.libraryFile) i,
];

/// The new file's row in the list, while it waits or goes.
Finder _pending(WidgetTester tester) =>
    _key('library-pending-${_waiting(tester).single.id}');

const _onlyMe = LibraryFolder(
  id: 'f-mine',
  name: 'My site notes',
  share: FolderShare.onlyMe,
  mine: true,
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('1. Library uploads like posts [$lang]', () {
      testWidgets('it shows in its folder at once, "Uploading 33%", then '
          'is there', (tester) async {
        final app = await _open(tester, lang, folders: const [_onlyMe]);
        app.library.holdUpload = Completer<void>();
        await _tap(tester, _key('folder-f-mine'));
        await _tap(tester, _key('library-add-file'));
        await tester.pump();
        expect(_pending(tester), findsOneWidget);
        expect(
          find.descendant(
            of: _pending(tester),
            matching: find.text(l10n.libraryUploading(33)),
          ),
          findsOneWidget,
        );
        // Leaving the screen doesn't stop it.
        await _tap(
          tester,
          find.byTooltip(
            MaterialLocalizations.of(
              tester.element(find.byType(Navigator).first),
            ).backButtonTooltip,
          ),
        );
        app.library.holdUpload!.complete();
        await tester.pumpAndSettle();
        expect(app.library.calls.single, endsWith('folder:f-mine'));
        expect(_waiting(tester), isEmpty);
        expect(app.daybook.createdPosts, isEmpty);
      });

      testWidgets('no signal: "Waiting for signal", kept, and sent when the '
          'signal is back', (tester) async {
        final app = await _open(tester, lang);
        app.library.uploadsOffline = true;
        await _tap(tester, _key('library-add-file'));
        await _tap(tester, _key('library-who-add'));
        expect(
          find.descendant(
            of: _pending(tester),
            matching: find.text(l10n.libraryWaitingForSignal),
          ),
          findsOneWidget,
        );
        expect(app.library.calls, isEmpty);
        // Kept on the phone, as posts are.
        expect(_waiting(tester).single.files.single.local, isNotNull);
        app.library.uploadsOffline = false;
        await _container(tester).read(workOutboxProvider.notifier).flushAll();
        await tester.pumpAndSettle();
        expect(app.library.calls.single, startsWith('add Level 3 plan.pdf'));
        expect(_waiting(tester), isEmpty);
        expect(
          _key(
            'library-pending-${app.library.filesBySpace[_space]!.single.id}',
          ),
          findsNothing,
        );
        expect(
          _key('file-${app.library.filesBySpace[_space]!.single.id}'),
          findsOneWidget,
        );
      });

      testWidgets('removed while it waits: never sent, and its copy goes', (
        tester,
      ) async {
        final app = await _open(tester, lang);
        app.library.uploadsOffline = true;
        await _tap(tester, _key('library-add-file'));
        await _tap(tester, _key('library-who-add'));
        final kept = _waiting(tester).single.files.single.local!;
        expect(File(kept).existsSync(), isTrue);
        await _tap(
          tester,
          _key('library-pending-remove-${_waiting(tester).single.id}'),
        );
        expect(_waiting(tester), isEmpty);
        app.library.uploadsOffline = false;
        await _container(tester).read(workOutboxProvider.notifier).flushAll();
        await tester.pumpAndSettle();
        expect(app.library.calls, isEmpty);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        expect(File(kept).existsSync(), isFalse);
      });

      testWidgets('refused: "Couldn\'t upload · Tap to fix" opens the '
          'composer\'s line, with the size; Remove takes it off', (
        tester,
      ) async {
        final app = await _open(tester, lang);
        app.library.storageRefuses = const StorageException(
          'The object exceeded the maximum allowed size',
          error: 'Payload too large',
          statusCode: '413',
        );
        await _tap(tester, _key('library-add-file'));
        await _tap(tester, _key('library-who-add'));
        expect(
          find.descendant(
            of: _pending(tester),
            matching: find.text(l10n.libraryCouldNotUpload),
          ),
          findsOneWidget,
        );
        await _tap(tester, _pending(tester));
        expect(_key('could-not-send-fix'), findsOneWidget);
        expect(_key('could-not-send-try-again'), findsOneWidget);
        await _tap(tester, _key('could-not-send-remove'));
        expect(_waiting(tester), isEmpty);
        expect(app.library.calls, isEmpty);
      });

      testWidgets('refused, then Try again sends it', (tester) async {
        final app = await _open(tester, lang);
        app.library.storageRefuses = const StorageException(
          'mime type application/pdf is not supported',
          statusCode: '415',
        );
        await _tap(tester, _key('library-add-file'));
        await _tap(tester, _key('library-who-add'));
        await _tap(tester, _pending(tester));
        await _tap(tester, _key('could-not-send-try-again'));
        expect(app.library.calls.single, startsWith('add Level 3 plan.pdf'));
        expect(_waiting(tester), isEmpty);
      });
    });

    group('2. Who sees it, at the top level [$lang]', () {
      testWidgets('one line before it goes: Whole Space by default, '
          'the file at the top', (tester) async {
        final app = await _open(tester, lang);
        await _tap(tester, _key('library-add-file'));
        expect(
          find.descendant(
            of: _key('library-who-line'),
            matching: find.text(
              l10n.libraryWhoSeesLine(l10n.libraryShareSpace),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('library-who-line'),
            matching: find.text(l10n.libraryWhoChange),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('library-who-add'));
        expect(
          app.library.calls.single,
          'add Level 3 plan.pdf team:- rev:- supersedes:-',
        );
        expect(app.library.folderCalls, isEmpty);
      });

      for (final (share, pick, name, line) in [
        (FolderShare.onlyMe, null, l10n.libraryMyFiles, 'only_me'),
        (
          FolderShare.team,
          'folder-team-t-mep',
          s.t('MEP', 'الكهروميكانيك'),
          'team team:t-mep',
        ),
        (
          FolderShare.person,
          'folder-person-${DaybookSamples.omar}',
          s.omarName,
          'person person:${DaybookSamples.omar}',
        ),
      ]) {
        testWidgets('Change → ${share.json}: a folder named "$name", made '
            'once, holds it', (tester) async {
          final app = await _open(tester, lang);
          Future<void> addOne() async {
            await _tap(tester, _key('library-add-file'));
            await _tap(tester, _key('library-who-change'));
            await _tap(tester, _key('library-who-${share.json}'));
            if (pick != null) await _tap(tester, _key(pick));
            await _tap(tester, _key('library-who-add'));
          }

          await addOne();
          expect(app.library.folderCalls, ['create $name $line']);
          final folder = app.library.foldersBySpace[_space]!.single;
          expect(app.library.calls.single, endsWith('folder:${folder.id}'));
          // The second goes into the same folder: no new one.
          await addOne();
          expect(app.library.folderCalls, hasLength(1));
          expect(app.library.calls.last, endsWith('folder:${folder.id}'));
          expect(app.daybook.createdPosts, isEmpty);
        });
      }

      testWidgets('an only-me folder already there takes it', (tester) async {
        final app = await _open(tester, lang, folders: const [_onlyMe]);
        await _tap(tester, _key('library-add-file'));
        await _tap(tester, _key('library-who-change'));
        await _tap(tester, _key('library-who-only_me'));
        await _tap(tester, _key('library-who-add'));
        expect(app.library.folderCalls, isEmpty);
        expect(app.library.calls.single, endsWith('folder:f-mine'));
      });

      testWidgets('inside a folder: no line, the folder\'s sharing', (
        tester,
      ) async {
        final app = await _open(tester, lang, folders: const [_onlyMe]);
        await _tap(tester, _key('folder-f-mine'));
        await _tap(tester, _key('library-add-file'));
        expect(_key('library-who-line'), findsNothing);
        expect(app.library.calls.single, endsWith('folder:f-mine'));
      });
    });
  }

  test('B2: the start-up clean-up never deletes a Library file waiting in '
      'the outbox', () async {
    final cache = Directory.systemTemp.createTempSync('bv_cache_115');
    addTearDown(() => cache.deleteSync(recursive: true));
    final waiting = File('${cache.path}/file_picker/9/plan.pdf')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3])
      ..setLastModifiedSync(DateTime(2026, 11, 1));
    final item = PendingItem(
      id: 'lib-1',
      spaceId: _space,
      title: '',
      ownerId: '',
      ownerName: '',
      kind: PendingKind.libraryFile,
      files: [
        DraftFile(
          libraryId: 'lib-1',
          name: 'plan.pdf',
          mime: 'application/pdf',
          local: waiting.path,
        ),
      ],
    );
    await cleanUpCache(
      cache,
      now: DateTime(2026, 11, 3),
      pending: [
        jsonEncode([item.toJson()]),
      ],
    );
    expect(waiting.existsSync(), isTrue);
  });
}
