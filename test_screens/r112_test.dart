// Review 112: a work item is always for someone else. In English and
// Arabic at 390 × 844 in the app's fonts. N1 alone in a Space: For says to
// invite someone, Post stays off; N2 the notebook share as a work item:
// For: Choose, Post off; N3 the server's refusal, in plain words. Run:
//   flutter test test_screens/r112_test.dart --update-goldens
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/notebook_page_samples.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r112/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r112/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    /// Islam (Lead) writing a work item in the Space, with [people].
    Future<FakeDaybookRepository> write(
      WidgetTester tester, {
      SpacePeople? people,
    }) async {
      final daybook = FakeDaybookRepository()
        ..posts[DaybookSamples.space] = s.d1();
      await pumpApp(
        tester,
        language: lang,
        auth: FakeAuthRepository(
          userId: DaybookSamples.islam,
          phone: '+96550000001',
        ),
        composerKind: 'work_item',
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail(pass: SpacePass.lead)
          ..spacePeople[DaybookSamples.space] = people ?? s.people(),
        daybook: daybook,
        now: DaybookSamples.thursday,
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
      await _tap(tester, _key('post-bar-notepad'));
      await tester.enterText(
        _key('writing-title'),
        s.t(
          'Fix the cracked tile at the stair',
          'إصلاح البلاطة المكسورة عند الدرج',
        ),
      );
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      return daybook;
    }

    testWidgets('N1 alone in a Space: invite someone; Post off [$lang]', (
      tester,
    ) async {
      SpaceMember member(String id, String name, SpacePass pass) => SpaceMember(
        person: SpacePerson(
          id: id,
          firstName: name.split(' ').first,
          lastName: name.split(' ').skip(1).join(' '),
        ),
        pass: pass,
        isAdmin: id == DaybookSamples.islam,
        confirmedAt: DateTime(2026, 9, 5),
      );
      await write(
        tester,
        people: SpacePeople(
          members: [
            member(DaybookSamples.islam, s.islamName, SpacePass.lead),
            member(DaybookSamples.mona, s.monaName, SpacePass.viewer),
          ],
          teams: const [],
        ),
      );
      await _tap(tester, _key('writing-who'));
      await _snap(tester, 'N1-alone-invite', lang);
    });

    testWidgets('N2 the notebook share as a work item: For: Choose, Post '
        'off [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        now: NotebookPageSamples.now,
        notebook: NotebookPageSamples(lang).repository(),
        spaces: FakeSpaceRepository()
          ..spaces.add(
            SpaceSummary(
              id: DaybookSamples.space,
              name: s.spaceName,
              pass: SpacePass.lead,
              isAdmin: true,
            ),
          )
          ..details[DaybookSamples.space] = s.detail()
          ..spacePeople[DaybookSamples.space] = s.people(),
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/notebook/pages/${NotebookPageSamples.siteA}');
      await tester.pumpAndSettle();
      await tester.longPress(_key('note-entry-pour'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('note-status-entry-pour-space'));
      await _tap(tester, _key('share-space-${DaybookSamples.space}'));
      await _tap(tester, _key('share-kind-work_item'));
      await _snap(tester, 'N2-share-for-choose', lang);
      await _tap(tester, _key('share-for'));
      await _snap(tester, 'N2b-share-for-picker', lang);
    });

    testWidgets('N3 the server says no: in plain words [$lang]', (
      tester,
    ) async {
      final daybook = await write(tester);
      daybook.refuseItemsWith = const SpaceException(
        SpaceFailure.badInput,
        'a work item is for someone else',
      );
      await _tap(tester, _key('writing-who'));
      await _tap(
        tester,
        find.descendant(
          of: find.byType(BvGiveToPicker),
          matching: find.text(s.omarName),
        ),
      );
      await _tap(tester, _key('writing-post'));
      await _tap(tester, _key('daybook-draft'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'N3-refused-for-yourself', lang);
    });
  }
}
