// Review 113 bug 7: a file the bucket refuses is said in plain words, and
// "Couldn't send · Tap to fix" opens what is wrong, with Try again or
// Remove: never a dead end.
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
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

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _space = DaybookSamples.space;
const _mb = 1024 * 1024;

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// The refused Draft on Work: "Couldn't send. Tap to fix"; the card takes
/// the tap (its words don't).
Future<void> _openDraft(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.text(l10n.daybookCouldNotSend), warnIfMissed: false);
  await tester.pumpAndSettle();
}

typedef _App = ({TestApp app, FakeDaybookRepository daybook});

Future<_App> _open(
  WidgetTester tester,
  String lang, {
  PhoneFile? picked,
  bool Function(String path)? there,
}) async {
  final s = DaybookSamples(lang);
  final daybook = FakeDaybookRepository()..posts[_space] = const [];
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[_space] = s.detail(addFiles: true)
      ..spacePeople[_space] = s.people(),
    daybook: daybook,
    library: FakeLibraryRepository(now: DaybookSamples.thursday),
    now: DaybookSamples.thursday,
    pickDocument: picked == null ? null : () => picked,
    localFileThere: there,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/$_space');
  await tester.pumpAndSettle();
  return (app: app, daybook: daybook);
}

/// A file post from the Library's Add a file, the phone's file chosen.
Future<void> _filePost(WidgetTester tester) async {
  await _tap(tester, _key('space-library'));
  await _tap(tester, _key('library-add-file'));
  await _tap(tester, _key('file-from-phone'));
}

DaybookPostDraft? _draft(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Navigator).first),
).read(daybookDraftProvider(_space));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('a 38 MB drawing is refused before it goes, in plain words, '
        'with Link folder [$lang]', (tester) async {
      final (:app, daybook: _) = await _open(
        tester,
        lang,
        picked: PhoneFile(
          local: testPdfPath,
          name: 'A-501 full set.pdf',
          mime: 'application/octet-stream',
          bytes: 38 * _mb,
        ),
      );
      await _filePost(tester);
      expect(_key('file-refused'), findsOneWidget);
      expect(find.text(l10n.fileTooBigLine('38', '25')), findsOneWidget);
      expect(_draft(tester)?.files ?? const [], isEmpty);
      await _tap(tester, _key('file-refused-link-folder'));
      expect(_key('folder-sheet'), findsOneWidget);
      expect(_key('folder-url'), findsOneWidget);
      expect(app.library.uploads, isEmpty);
    });

    testWidgets('the Arabic line reads as the review wrote it [$lang]', (
      tester,
    ) async {
      expect(
        _l10n('ar').fileTooBigLine('38', '25'),
        'حجم الملف 38 ميجابايت. الحد الأقصى 25 ميجابايت.',
      );
      expect(
        _l10n('en').fileTooBigLine('38', '25'),
        'This file is 38 MB. The most is 25 MB.',
      );
    });

    testWidgets('a PDF the picker calls octet-stream goes as application/pdf '
        '[$lang]', (tester) async {
      final (:app, :daybook) = await _open(
        tester,
        lang,
        picked: PhoneFile(
          local: testPdfPath,
          name: 'A-501.pdf',
          mime: 'application/octet-stream',
          bytes: 2 * _mb,
        ),
      );
      await _filePost(tester);
      await _tap(tester, _key('writing-post'));
      expect(app.library.uploadTypes, ['application/pdf']);
      expect(daybook.createdPosts, hasLength(1));
    });

    testWidgets('storage answers 400 (inner 413): Tap to fix says the size; '
        'Remove takes the file off [$lang]', (tester) async {
      final (:app, :daybook) = await _open(tester, lang);
      app.library.storageRefuses = const StorageException(
        'The object exceeded the maximum allowed size',
        error: 'Payload too large',
        statusCode: '413',
      );
      await _filePost(tester);
      await _tap(tester, _key('writing-post'));
      // Back as the Draft, refused, saying so.
      expect(daybook.createdPosts, isEmpty);
      // The Draft on Work says so; a tap opens it, with the line.
      await _openDraft(tester, l10n);
      expect(_key('writing-could-not-send'), findsOneWidget);
      await _tap(tester, _key('writing-could-not-send'));
      expect(_key('could-not-send-fix'), findsOneWidget);
      // The phone's size (4.8 MB) is under the limit: no number claimed.
      expect(find.text(l10n.fileTooBigPlain('25')), findsOneWidget);
      expect(_key('could-not-send-link-folder'), findsOneWidget);
      await _tap(tester, _key('could-not-send-remove'));
      expect(_draft(tester)!.files, isEmpty);
      expect(_draft(tester)!.refusal, isNull);
    });

    testWidgets('a type storage refuses: Try again sends it again [$lang]', (
      tester,
    ) async {
      final (:app, :daybook) = await _open(tester, lang);
      app.library.storageRefuses = const StorageException(
        'mime type application/octet-stream is not supported',
        error: 'invalid_mime_type',
        statusCode: '415',
      );
      await _filePost(tester);
      await _tap(tester, _key('writing-post'));
      await _openDraft(tester, l10n);
      await _tap(tester, _key('writing-could-not-send'));
      expect(find.text(l10n.fileWrongTypeLine), findsOneWidget);
      expect(_key('could-not-send-link-folder'), findsNothing);
      await _tap(tester, _key('could-not-send-try-again'));
      expect(daybook.createdPosts, hasLength(1));
      expect(app.library.calls, hasLength(1));
    });

    testWidgets('any other refusal: the plain line, and Remove puts the post '
        'away [$lang]', (tester) async {
      final (app: _, :daybook) = await _open(tester, lang);
      daybook.refuse = true;
      await _filePost(tester);
      await _tap(tester, _key('writing-post'));
      await _openDraft(tester, l10n);
      await _tap(tester, _key('writing-could-not-send'));
      expect(find.text(l10n.couldNotSendGeneric), findsOneWidget);
      await _tap(tester, _key('could-not-send-remove'));
      expect(_draft(tester), isNull);
      expect(_key('composer'), findsNothing);
    });

    testWidgets('Z13: a file gone when the draft is sent: Tap to fix says '
        'so, Remove takes it off, and the line goes [$lang]', (tester) async {
      var there = true;
      final (:app, :daybook) = await _open(tester, lang, there: (_) => there);
      await _filePost(tester);
      there = false;
      await _tap(tester, _key('writing-post'));
      expect(daybook.createdPosts, isEmpty);
      expect(app.library.uploads, isEmpty);
      await _openDraft(tester, l10n);
      await _tap(tester, _key('writing-could-not-send'));
      expect(find.text(l10n.fileGoneLine), findsOneWidget);
      await _tap(tester, _key('could-not-send-remove'));
      expect(_draft(tester)?.files, isEmpty);
      expect(_draft(tester)?.couldNotSend, isFalse);
      expect(_key('writing-could-not-send'), findsNothing);
    });

    testWidgets('Z13: a file gone when the draft is opened: the same line '
        '[$lang]', (tester) async {
      var there = true;
      await _open(tester, lang, there: (_) => there);
      await _filePost(tester);
      expect(_key('writing-could-not-send'), findsNothing);
      await _tap(tester, _key('composer-close'));
      there = false;
      await tester.tap(_key('daybook-draft'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_key('writing-could-not-send'), findsOneWidget);
    });
  }
}
