// Review 115 (3), in English and Arabic at 390 × 844 in the app's fonts:
// a swipe on the Spaces tab shows Explore, and in a Space a swipe on Work
// shows Chat with the switch on Chat. Mirrored in Arabic. Run:
//   flutter test test_screens/r115_test.dart --update-goldens
import 'dart:async';

import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/chat/chat_tab.dart';
import 'package:buildvibes/features/explore/explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/chat_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r115/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r115/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

/// Toward the end of reading: left in English, right in Arabic.
Offset _toNext(String lang) => Offset(lang == 'ar' ? 220 : -220, 0);

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    testWidgets('SW1 a swipe on Spaces shows Explore [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        now: DaybookSamples.thursday,
        spaces: FakeSpaceRepository(now: testNow)
          ..spaces.add(
            SpaceSummary(
              id: 'space-1',
              name: s.t('NBKCH Site team', 'فريق موقع NBKCH'),
              pass: SpacePass.lead,
              isAdmin: true,
            ),
          ),
      );
      await tester.dragFrom(const Offset(195, 420), _toNext(lang));
      await tester.pumpAndSettle();
      expect(find.byType(ExploreScreen), findsOneWidget);
      await _snap(tester, 'SW1_explore', lang);
    });

    testWidgets('SW2 in a Space, a swipe on Work shows Chat [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        auth: FakeAuthRepository(
          userId: DaybookSamples.islam,
          phone: '+96550000001',
        ),
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail(pass: SpacePass.lead)
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: FakeDaybookRepository()
          ..posts[DaybookSamples.space] = s.d1(),
        chat: FakeChatRepository(now: testNow)
          ..threadsBySpace[DaybookSamples.space] = [
            const ChatThread(id: 'all'),
          ],
        now: DaybookSamples.thursday,
      );
      unawaited(_router(tester).push('/spaces/${DaybookSamples.space}'));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(195, 320), _toNext(lang));
      await tester.pumpAndSettle();
      expect(find.byType(ChatTab), findsOneWidget);
      await _snap(tester, 'SW2_chat', lang);
    });
  }
}
