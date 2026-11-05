// Review 121b: Call in a direct message's top bar (no frame; the lead's
// words: a phone icon before ⋯, the size of the bar's other icons), and
// review 121 F2's empty Call them for. English and Arabic at 390 × 844.
// Run:
//   flutter test test_screens/r121b_test.dart --update-goldens
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/key_people.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/dm_fakes.dart';
import '../test/helpers/key_people_fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r121b/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    String t(String en, String ar) => lang == 'ar' ? ar : en;

    Future<void> go(
      WidgetTester tester,
      String path, {
      FakeDmRepository? dm,
      FakeSpaceRepository? spaces,
      FakeKeyPeopleRepository? keys,
    }) async {
      tester.view.physicalSize = shotSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        language: lang,
        dm: dm,
        spaces: spaces,
        keyPeople: keys,
        now: DateTime(2026, 11, 5, 11),
      );
      GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
      await tester.pumpAndSettle();
    }

    testWidgets('DM2 with Call [$lang]', (tester) async {
      final dm = FakeDmRepository()
        ..pages['t-gus'] = DmThreadPage(
          threadId: 't-gus',
          person: DmPerson(
            id: 'p-gus',
            name: t('Gus Store', 'غس ستور'),
            headline: t('Storekeeper', 'أمين المخزن'),
            company: 'NBKCH',
          ),
          state: DmState.open,
          messages: [
            DmMessage(
              id: 'm2',
              fromMe: true,
              kind: ChatKind.text,
              createdAt: DateTime(2026, 11, 5, 10, 42),
              body: t('On my way to the store', 'في طريقي إلى المخزن'),
            ),
            DmMessage(
              id: 'm1',
              fromMe: false,
              kind: ChatKind.text,
              createdAt: DateTime(2026, 11, 5, 10, 40),
              body: t('The cement came in', 'وصل الإسمنت'),
            ),
          ],
        );
      await go(
        tester,
        '/messages/t-gus',
        dm: dm,
        keys: FakeKeyPeopleRepository()..callable.add('p-gus'),
      );
      await _snap(tester, 'dm2_call', lang);
    });

    testWidgets('KP4 empty: the Call them for hint [$lang]', (tester) async {
      final spaces = FakeSpaceRepository(now: testNow);
      spaces.details['space-1'] = const SpaceDetail(
        id: 'space-1',
        name: 'NBKCH Site',
        myPass: SpacePass.lead,
        iAmAdmin: true,
        myRights: MemberRights(invite: true, createItems: true),
        marketId: 'kw',
      );
      spaces.spaces.add(
        const SpaceSummary(
          id: 'space-1',
          name: 'NBKCH Site',
          pass: SpacePass.lead,
          isAdmin: true,
        ),
      );
      await go(
        tester,
        '/spaces/space-1/key-people',
        spaces: spaces,
        keys: FakeKeyPeopleRepository()..spaces['space-1'] = const KeyPeople(),
      );
      await tester.tap(find.byKey(const Key('key-people-add')));
      await tester.pumpAndSettle();
      await _snap(tester, 'kp4_empty', lang);
    });
  }
}
