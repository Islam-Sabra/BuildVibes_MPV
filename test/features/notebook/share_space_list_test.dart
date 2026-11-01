// Review 110 A, and the lead's check W1–W2: the share card's Space list
// never shows as an empty card with no title. While the Spaces load it
// says so; after 15 s from when the list opened, or on an error, it says it
// couldn't load them, with a short code (the error's type, never its raw
// words) and Try again. A Space's detail changing never restarts the list.
// Review 112: the list is one call, my_postable_spaces, not one read per
// Space. In English and Arabic.
import 'dart:async';

import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/features/create/create_sheet.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

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

    testWidgets('they can\'t be read: the error line, a short code, never '
        'the raw message; Try again [$lang]', (tester) async {
      final spaces = two()..spacesError = StateError('raw server words');
      await _open(tester, lang, spaces);
      await tester.pumpAndSettle();
      expect(find.text(l10n.notebookShareSpacesError), findsOneWidget);
      expect(
        find.text(l10n.notebookShareSpacesCode('StateError')),
        findsOneWidget,
      );
      expect(find.textContaining('raw server words'), findsNothing);
      // Try again reads them again.
      spaces.spacesError = null;
      await tester.tap(_key('share-spaces-retry'));
      await tester.pumpAndSettle();
      expect(_key('share-space-${DaybookSamples.space}'), findsOneWidget);
      expect(find.text(l10n.notebookShareSpacesError), findsNothing);
    });

    testWidgets('review 112: one call, my_postable_spaces; no Space\'s '
        'detail is read for the list [$lang]', (tester) async {
      final spaces = two();
      await _open(tester, lang, spaces);
      await tester.pumpAndSettle();
      expect(_key('share-space-${DaybookSamples.space}'), findsOneWidget);
      expect(_key('share-space-$_other'), findsOneWidget);
      expect(spaces.postableCalls, 1);
      expect(spaces.fetchSpaceCalls, 0);
    });

    testWidgets('review 112: only the Spaces where I may give work [$lang]', (
      tester,
    ) async {
      final spaces = two()..details[_other] = s.detail(pass: SpacePass.viewer);
      await _open(tester, lang, spaces);
      await tester.pumpAndSettle();
      expect(_key('share-space-${DaybookSamples.space}'), findsOneWidget);
      expect(_key('share-space-$_other'), findsNothing);
    });

    testWidgets('15 s from when the list opened: the error line, code '
        'TimeoutException [$lang]', (tester) async {
      final spaces = two()..spacesGate = Completer<void>().future;
      await _open(tester, lang, spaces);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text(l10n.notebookShareSpacesLoading), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(find.text(l10n.notebookShareSpacesError), findsOneWidget);
      expect(
        find.text(l10n.notebookShareSpacesCode('TimeoutException')),
        findsOneWidget,
      );
    });

    testWidgets('W1: a Space\'s detail read again never restarts the list '
        '[$lang]', (tester) async {
      await _open(tester, lang, two());
      await tester.pumpAndSettle();
      expect(_key('share-space-${DaybookSamples.space}'), findsOneWidget);
      final runs = workItemSpacesRuns;
      _container(tester).invalidate(spaceDetailProvider(DaybookSamples.space));
      _container(tester).invalidate(spaceDetailProvider(_other));
      await tester.pumpAndSettle();
      expect(workItemSpacesRuns, runs);
      expect(_key('share-space-${DaybookSamples.space}'), findsOneWidget);
    });
  }
}
