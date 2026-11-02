// Review 113 Part B: Need you now, the Library's folders, bug 7 and the
// check-in nudge, in English and Arabic at 390 × 844 in the app's fonts.
// Run:
//   flutter test test_screens/r113b_test.dart --update-goldens
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/library_folder.dart';
import 'package:buildvibes/data/models/need_you.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

import '../test/helpers/check_in_samples.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/library_fakes.dart';
import '../test/helpers/need_you_fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/push_fakes.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r113b/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r113b/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

const _space = DaybookSamples.space;
Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Finder _field(String k) =>
    find.descendant(of: _key(k), matching: find.byType(TextField));

List<LibraryFolder> _folders(DaybookSamples s) => [
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
    shareTeamName: 'Gulf MEP',
  ),
  LibraryFolder(
    id: 'f-omar',
    name: s.t('For Omar', 'لعمر'),
    share: FolderShare.person,
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

Future<TestApp> _app(
  WidgetTester tester,
  String lang, {
  FakeNeedYouRepository? needYou,
  FakeDaybookRepository? daybook,
  FakeLibraryRepository? library,
  FakePushMessaging? push,
  PhoneFile? picked,
  String path = '/spaces/$_space',
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[_space] = s.detail(addFiles: true)
      ..spacePeople[_space] = s.people(),
    daybook: daybook ?? (FakeDaybookRepository()..posts[_space] = s.d1()),
    library:
        library ??
        (FakeLibraryRepository(now: DaybookSamples.thursday)
          ..foldersBySpace[_space] = _folders(s)),
    needYou: needYou,
    push: push,
    pickDocument: picked == null ? null : () => picked,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return app;
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    Future<void> sheet(WidgetTester tester, FakeNeedYouRepository n) async {
      await _app(tester, lang, needYou: n, path: '/spaces/$_space/people');
      await _tap(tester, _key('member-${DaybookSamples.omar}'));
    }

    testWidgets('NN0 the person sheet with Need you now [$lang]', (t) async {
      await sheet(t, FakeNeedYouRepository());
      await _snap(t, 'NN0-person-sheet', lang);
    });

    testWidgets('NN1 the sheet [$lang]', (t) async {
      await sheet(t, FakeNeedYouRepository());
      await _tap(t, _key('person-need-you'));
      await _snap(t, 'NN1-sheet', lang);
      await t.enterText(
        _field('need-you-reason'),
        s.t('Concrete truck waiting', 'شاحنة الخرسانة تنتظر'),
      );
      await _tap(t, _key('need-you-add-place'));
      await t.enterText(_field('need-you-place'), s.t('Gate 2', 'البوابة 2'));
      await t.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await _snap(t, 'NN1-sheet-filled', lang);
    });

    testWidgets('NN1 the refusal [$lang]', (t) async {
      await sheet(
        t,
        FakeNeedYouRepository()
          ..refuseSend = const SpaceException(
            SpaceFailure.badInput,
            'at most 3 an hour',
          ),
      );
      await _tap(t, _key('person-need-you'));
      await _tap(t, _key('need-you-send'));
      await _snap(t, 'NN1-refusal', lang);
    });

    NeedYouCall call(String id, {NeedYouAnswer? answer, bool got = false}) =>
        NeedYouCall(
          id: id,
          spaceId: _space,
          fromId: got ? DaybookSamples.omar : DaybookSamples.islam,
          toId: got ? DaybookSamples.islam : DaybookSamples.rakesh,
          fromName: got ? s.omarName : s.islamName,
          toName: got ? s.islamName : s.rakeshName,
          reason: s.t('Concrete truck waiting', 'شاحنة الخرسانة تنتظر'),
          place: s.t('Gate 2', 'البوابة 2'),
          createdAt: DaybookSamples.thursday.subtract(
            const Duration(minutes: 5),
          ),
          answer: answer,
        );

    testWidgets('NN3 the sender sees the answer [$lang]', (t) async {
      await _app(
        t,
        lang,
        needYou: FakeNeedYouRepository()
          ..callsList.add(call('c1', answer: NeedYouAnswer.coming)),
      );
      await _snap(t, 'NN3-sender-answered', lang);
    });

    testWidgets('NN3 the sender waiting [$lang]', (t) async {
      await _app(
        t,
        lang,
        needYou: FakeNeedYouRepository()..callsList.add(call('c1')),
      );
      await _snap(t, 'NN3-sender-waiting', lang);
    });

    testWidgets('NN4 a call I got, in the Space [$lang]', (t) async {
      await _app(
        t,
        lang,
        needYou: FakeNeedYouRepository()..callsList.add(call('c1', got: true)),
      );
      await _snap(t, 'NN4-call-in-space', lang);
    });

    testWidgets('LB1 folders [$lang]', (t) async {
      await _app(t, lang);
      await _tap(t, _key('space-library'));
      await _snap(t, 'LB1-folders', lang);
      await _tap(t, _key('library-add'));
      await _snap(t, 'LB1-add-menu', lang);
    });

    testWidgets('LB1 inside a folder [$lang]', (t) async {
      await _app(
        t,
        lang,
        library: FakeLibraryRepository(now: DaybookSamples.thursday)
          ..foldersBySpace[_space] = _folders(s)
          ..filesBySpace[_space] = [
            LibraryFile(
              id: 'in',
              spaceId: _space,
              name: 'A-501 Rev D.pdf',
              path: '$_space/library/in/x.pdf',
              mime: 'application/pdf',
              createdAt: DaybookSamples.thursday,
              bytes: 2400000,
              folderId: 'f-drawings',
            ),
          ],
      );
      await _tap(t, _key('space-library'));
      await _tap(t, _key('folder-f-drawings'));
      await _snap(t, 'LB1-inside-folder', lang);
    });

    testWidgets('LB1 the sharing choice [$lang]', (t) async {
      await _app(t, lang);
      await _tap(t, _key('space-library'));
      await _tap(t, _key('library-add'));
      await _tap(t, _key('library-new-folder'));
      await t.enterText(
        _field('folder-name'),
        s.t('MEP submittals', 'اعتمادات الميكانيكا'),
      );
      await _tap(t, _key('folder-share-team'));
      await _snap(t, 'LB1-share-team-picker', lang);
      await _tap(t, _key('folder-team-t-mep'));
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await _snap(t, 'LB1-share-team-picked', lang);
    });

    testWidgets('LB2 Link folder [$lang]', (t) async {
      await _app(t, lang);
      await _tap(t, _key('space-library'));
      await _tap(t, _key('library-add'));
      await _tap(t, _key('library-link-folder'));
      await t.enterText(_field('folder-url'), 'https://1drv.ms/f/s!Ab3xYz');
      await t.enterText(
        _field('folder-name'),
        s.t('Shop drawings, Block B', 'مخططات تنفيذية، المبنى B'),
      );
      await t.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await _snap(t, 'LB2-link-folder', lang);
      await t.enterText(_field('folder-url'), 'https://example.com/x');
      await t.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await _snap(t, 'LB2-wrong-link', lang);
    });

    testWidgets('B7 too big [$lang]', (t) async {
      await _app(
        t,
        lang,
        picked: PhoneFile(
          local: testPdfPath,
          name: 'A-501 full set.pdf',
          mime: 'application/pdf',
          bytes: 38 * 1024 * 1024,
        ),
      );
      await _tap(t, _key('space-library'));
      await _tap(t, _key('library-add-file'));
      await _tap(t, _key('file-from-phone'));
      await _snap(t, 'B7-too-big', lang);
    });

    testWidgets('B7 Tap to fix [$lang]', (t) async {
      final app = await _app(t, lang);
      app.library.storageRefuses = const StorageException(
        'The object exceeded the maximum allowed size',
        error: 'Payload too large',
        statusCode: '413',
      );
      await _tap(t, _key('space-library'));
      await _tap(t, _key('library-add-file'));
      await _tap(t, _key('file-from-phone'));
      await _tap(t, _key('writing-post'));
      await _snap(t, 'B7-draft-could-not-send', lang);
      await t.tap(_key('writing-card-error'), warnIfMissed: false);
      await t.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await _snap(t, 'B7-composer-line', lang);
      await _tap(t, _key('writing-could-not-send'));
      await _snap(t, 'B7-tap-to-fix', lang);
    });

    testWidgets('B7 a generic refusal, Try again or Remove [$lang]', (t) async {
      final daybook = FakeDaybookRepository()..posts[_space] = s.d1();
      await _app(t, lang, daybook: daybook);
      daybook.refuse = true;
      await _tap(t, _key('space-library'));
      await _tap(t, _key('library-add-file'));
      await _tap(t, _key('file-from-phone'));
      await _tap(t, _key('writing-post'));
      await t.tap(_key('writing-card-error'), warnIfMissed: false);
      await t.pumpAndSettle();
      await _tap(t, _key('writing-could-not-send'));
      await _snap(t, 'B7-tap-to-fix-generic', lang);
    });

    testWidgets('NUDGE the composer filled [$lang]', (t) async {
      final push = FakePushMessaging();
      await _app(
        t,
        lang,
        push: push,
        daybook: FakeDaybookRepository()
          ..posts[_space] = [CheckInSamples.card(lang)],
        path: '/explore',
      );
      push.tap({
        'open': 'check_in_nudge',
        'space_id': _space,
        'from_post_id': CheckInSamples.id,
      });
      await t.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await _snap(t, 'NUDGE-composer', lang);
    });
  }
}
