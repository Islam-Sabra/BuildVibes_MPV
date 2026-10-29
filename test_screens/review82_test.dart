// Review 82 S1 and S2, and the Arabic version picker (review 50, after
// review 81): the screens they touch, English and Arabic, at 390 × 844 on
// a 12-hour phone, in the app's fonts.
// Run:
//   flutter test test_screens/review82_test.dart --update-goldens
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/library_fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Saves the app as it is now, at 390 × 844 and twice the pixels, to
/// `docs/screens/review82/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  debugDisableShadows = false;
  ContextMenuController.removeAny();
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/review82/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

final _m201 = LibraryFile(
  id: 'lib-m201-c',
  spaceId: DaybookSamples.space,
  name: 'M-201.pdf',
  path: '${DaybookSamples.space}/library/lib-m201-c/M-201.pdf',
  mime: 'application/pdf',
  createdAt: DateTime(2026, 10, 10),
  bytes: 4800000,
  versionNo: 3,
  revLabel: 'Rev C',
);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<DaybookCard> posts = const [],
  String path = '/spaces/${DaybookSamples.space}',
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(admin: true)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()
      ..posts[DaybookSamples.space] = posts
      ..pointsByPost[DaybookSamples.handoverId] = s.handoverPoints(),
    library: FakeLibraryRepository(now: DaybookSamples.thursday)
      ..filesBySpace[DaybookSamples.space] = [_m201],
    now: DaybookSamples.thursday,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return app;
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('S1 history lines: each time on one line [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, posts: [s.gate(), s.rebar()]);
      await _snap(tester, 'S1-history-lines', lang);
    });

    testWidgets('S1 a checklist\'s ticks: each time on one line [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, posts: [s.handover()]);
      await _snap(tester, 'S1-checklist-ticks', lang);
    });

    testWidgets('S2 Space info: Hand over Space admin [$lang]', (tester) async {
      await _open(tester, lang, path: '/spaces/${DaybookSamples.space}/info');
      await tester.scrollUntilVisible(_key('info-transfer'), 200);
      await tester.pumpAndSettle();
      await _snap(tester, 'S2-space-info', lang);
      await _tap(tester, _key('info-transfer'));
      await _snap(tester, 'S2-hand-over', lang);
    });

    testWidgets('the version picker: «يحل محل M-201.pdf · V3» [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);
      await _tap(tester, _key('post-bar-notepad'));
      // Review 105 SP2: the kind menu became one row of kind chips.
      await _tap(tester, _key('kind-chip-${DaybookKind.note}'));
      await tester.enterText(_key('writing-title'), s.handoverTitle);
      await tester.pumpAndSettle();
      await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
      await _tap(tester, _key('attach-file'));
      await _tap(tester, _key('replaces-version'));
      await _tap(tester, _key('version-${_m201.id}'));
      await _snap(tester, 'F71-replaces-picked', lang);
    });
  }
}
