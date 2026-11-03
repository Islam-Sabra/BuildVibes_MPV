// Review 115 (3): a sideways swipe on a tab's main screen moves to the next
// or the previous bottom tab, mirrored in Arabic. Not on a screen opened
// inside a tab, and never from the screen's edges, where Android's back
// gesture starts.
import 'dart:async';

import 'package:buildvibes/features/explore/explore_screen.dart';
import 'package:buildvibes/shared/widgets/bv_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_app.dart';

int _tab(WidgetTester tester) =>
    tester.widget<BvBottomBar>(find.byType(BvBottomBar)).selectedIndex;

/// The middle of the screen, away from the edges.
const _middle = Offset(195, 420);
const _far = 220.0;

/// A swipe toward the end of reading: to the left in English, to the right
/// in Arabic. It shows the next tab.
Future<void> _swipeToNext(WidgetTester tester, String lang) async {
  await tester.dragFrom(_middle, Offset(lang == 'ar' ? _far : -_far, 0));
  await tester.pumpAndSettle();
}

Future<void> _swipeToPrevious(WidgetTester tester, String lang) async {
  await tester.dragFrom(_middle, Offset(lang == 'ar' ? -_far : _far, 0));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets('a swipe moves to the next and the previous tab, mirrored in '
        'Arabic [$lang]', (tester) async {
      await pumpApp(tester, language: lang);
      expect(_tab(tester), 0);

      // The first tab has nothing before it.
      await _swipeToPrevious(tester, lang);
      expect(_tab(tester), 0);

      for (final next in [1, 2, 3]) {
        await _swipeToNext(tester, lang);
        expect(_tab(tester), next);
      }
      // Profile is the last.
      await _swipeToNext(tester, lang);
      expect(_tab(tester), 3);

      await _swipeToPrevious(tester, lang);
      expect(_tab(tester), 2);
    });

    testWidgets('a swipe from the screen\'s edges is left to the phone\'s '
        'back gesture [$lang]', (tester) async {
      await pumpApp(tester, language: lang);
      await tester.tap(find.byKey(const Key('nav-explore')));
      await tester.pumpAndSettle();
      expect(_tab(tester), 1);

      final width = tester.view.physicalSize.width;
      await tester.dragFrom(const Offset(4, 420), const Offset(_far, 0));
      await tester.pumpAndSettle();
      expect(_tab(tester), 1);
      await tester.dragFrom(Offset(width - 4, 420), const Offset(-_far, 0));
      await tester.pumpAndSettle();
      expect(_tab(tester), 1);
    });

    testWidgets('a screen opened inside a tab doesn\'t swipe [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang);
      await tester.tap(find.byKey(const Key('nav-profile')));
      await tester.pumpAndSettle();
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/profile/settings');
      await tester.pumpAndSettle();

      await _swipeToPrevious(tester, lang);
      expect(_tab(tester), 3);
      expect(
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).state.uri.path,
        '/profile/settings',
      );
    });

    testWidgets('a sheet open on a tab doesn\'t swipe [$lang]', (tester) async {
      await pumpApp(tester, language: lang);
      await tester.tap(find.byKey(const Key('nav-explore')));
      await tester.pumpAndSettle();
      // A sheet opened from the tab, on the tab's own navigator.
      unawaited(
        showModalBottomSheet<void>(
          context: tester.element(find.byType(ExploreScreen)),
          builder: (_) => const SizedBox(height: 600),
        ),
      );
      await tester.pumpAndSettle();
      await _swipeToNext(tester, lang);
      expect(_tab(tester), 1);
    });
  }
}
