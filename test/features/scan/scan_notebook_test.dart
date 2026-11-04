// Review 103 SC7 in the notebook: Scan sits on the writing bar right after
// the photo button. A scan becomes the entry's PDF block, marked
// "Scanned · 3 pages" (SC4), and goes to the server with its mark.
import 'dart:convert';

import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

const _siteA = '/notebook/pages/${NotebookPageSamples.siteA}';

Future<void> _write(WidgetTester tester, String lang) async {
  final repo = NotebookPageSamples(lang).repository();
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: repo,
    stored: {
      'notebook_draft:user-1': jsonEncode(
        NoteDraft(
          id: 'draft-1',
          startedAt: NotebookPageSamples.now,
          title: 'Delivery',
          blocks: [PageText('l-1', 'Rebar arrived')],
          pageId: NotebookPageSamples.siteA,
        ).toJson(),
      ),
    },
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(_siteA);
  await tester.pumpAndSettle();
  await _tap(tester, _key('note-draft-card-draft-1'));
  await tester.tap(find.text('Rebar arrived'));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    testWidgets('SC7: Scan right after the photo button; a scan is the '
        'entry\'s PDF, Scanned · 3 pages [$lang]', (tester) async {
      await _write(tester, lang);
      final photo = tester.getCenter(_key('note-tool-image')).dx;
      final scan = tester.getCenter(_key('note-tool-scan')).dx;
      final add = tester.getCenter(_key('note-tool-add')).dx;
      if (lang == 'ar') {
        expect(scan, lessThan(photo));
        expect(add, lessThan(scan));
      } else {
        expect(scan, greaterThan(photo));
        expect(add, greaterThan(scan));
      }
      await _tap(tester, _key('note-tool-scan'));
      await tester.enterText(_key('scan-name'), 'Cube test 7 days');
      await _tap(tester, _key('scan-add'));
      final draft = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      ).read(noteDraftProvider)!;
      final file = draft.files.single;
      expect(file.name, 'Cube test 7 days.pdf');
      expect(file.scanned, isTrue);
      expect(file.pages, 3);
      expect(file.toServer()['scanned'], isTrue);
      expect(file.toServer()['page_count'], 3);
      expect(
        find.textContaining(l10n.scannedPages(l10n.scanPages(3))),
        findsOneWidget,
      );
    });
  }
}
