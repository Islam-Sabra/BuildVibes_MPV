// Review 110 A: the share card's Space list never shows as an empty card
// with no title. While the Spaces load it says so; if they can't be read it
// says so; a Space whose detail can't be read is left out and the others
// still show. In English and Arabic.
import 'dart:async';

import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_samples.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

const _other = 'space-other';

Future<void> _open(
  WidgetTester tester,
  String lang,
  FakeSpaceRepository spaces,
) async {
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: NotebookPageSamples(lang).repository(),
    spaces: spaces,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/notebook/pages/${NotebookPageSamples.siteA}');
  await tester.pumpAndSettle();
  await tester.longPress(_key('note-entry-pour'));
  await tester.pumpAndSettle();
  await tester.tap(_key('note-status-entry-pour-space'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    FakeSpaceRepository two() => FakeSpaceRepository()
      ..spaces.addAll([
        SpaceSummary(
          id: DaybookSamples.space,
          name: s.spaceName,
          pass: SpacePass.lead,
          isAdmin: true,
        ),
        const SpaceSummary(
          id: _other,
          name: 'Tower B',
          pass: SpacePass.lead,
          isAdmin: true,
        ),
      ])
      ..details[DaybookSamples.space] = s.detail()
      ..details[_other] = s.detail();

    testWidgets('while the Spaces load: a loading line [$lang]', (
      tester,
    ) async {
      final spaces = two()..spacesGate = Completer<void>().future;
      await _open(tester, lang, spaces);
      expect(find.text(l10n.notebookShareSpacesLoading), findsOneWidget);
      // Its 15 s limit runs out before the test ends.
      await tester.pump(const Duration(seconds: 16));
    });

    testWidgets('they can\'t be read: an error line, never an empty card '
        '[$lang]', (tester) async {
      final spaces = two()..spacesError = StateError('no');
      await _open(tester, lang, spaces);
      await tester.pumpAndSettle();
      expect(find.text(l10n.notebookShareSpacesError), findsOneWidget);
    });

    testWidgets('a Space\'s detail the app can\'t read: the error line, with '
        'its type and first line small under it [$lang]', (tester) async {
      final spaces = two()..detailErrors[_other] = TypeError();
      await _open(tester, lang, spaces);
      await tester.pumpAndSettle();
      expect(find.text(l10n.notebookShareSpacesError), findsOneWidget);
      expect(find.textContaining('TypeError'), findsOneWidget);
      expect(_key('share-space-${DaybookSamples.space}'), findsNothing);
    });

    testWidgets('a load that never ends: the error line after 15 s, with '
        'TimeoutException [$lang]', (tester) async {
      final spaces = two()..spacesGate = Completer<void>().future;
      await _open(tester, lang, spaces);
      expect(find.text(l10n.notebookShareSpacesLoading), findsOneWidget);
      await tester.pump(const Duration(seconds: 16));
      await tester.pump();
      expect(find.text(l10n.notebookShareSpacesError), findsOneWidget);
      expect(find.textContaining('TimeoutException'), findsOneWidget);
    });
  }
}
