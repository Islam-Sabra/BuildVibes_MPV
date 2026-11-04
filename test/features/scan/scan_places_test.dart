// Review 103: Scan a document also stays in the Library's "Add a file", the
// chat and direct-message attach sheets, and Sign as done (Photo | Scan).
// In the Library a scan is a file marked "Scanned · 3 pages". In English
// and Arabic.
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

Future<TestApp> _library(
  WidgetTester tester,
  String lang, {
  List<LibraryFile> files = const [],
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[_space] = s.detail(addFiles: true)
      ..spacePeople[_space] = s.people(),
    daybook: FakeDaybookRepository()..posts[_space] = const [],
    library: FakeLibraryRepository(now: DaybookSamples.thursday)
      ..filesBySpace[_space] = List.of(files),
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
    final l10n = lookupAppLocalizations(Locale(lang));

    group('the Library [$lang]', () {
      testWidgets('Add a file offers Scan a document; the scan goes in, '
          'marked scanned', (tester) async {
        final app = await _library(tester, lang);
        await _tap(tester, _key('library-add-file'));
        expect(_key('file-from-phone'), findsOneWidget);
        expect(find.text(l10n.scanADocument), findsOneWidget);
        await _tap(tester, _key('file-scan'));
        await tester.enterText(_key('scan-name'), 'Permit 22');
        await _tap(tester, _key('scan-add'));
        // Top level: Whole Space, then it goes.
        await _tap(tester, _key('library-who-add'));
        expect(
          app.library.calls.where((c) => c.startsWith('add Permit 22.pdf')),
          hasLength(1),
        );
        expect(app.library.scannedMarks.single, endsWith(' 3'));
      });

      testWidgets('a scanned file\'s row says "Scanned · 3 pages"', (
        tester,
      ) async {
        await _library(
          tester,
          lang,
          files: [
            LibraryFile(
              id: 'f-scan',
              spaceId: _space,
              name: 'Delivery note.pdf',
              path: '$_space/library/f-scan/a.pdf',
              mime: 'application/pdf',
              bytes: 600000,
              createdAt: DaybookSamples.thursday,
              scanned: true,
              pageCount: 3,
            ),
          ],
        );
        expect(
          find.textContaining(l10n.scannedPages(l10n.scanPages(3))),
          findsOneWidget,
        );
      });
    });
  }
}
