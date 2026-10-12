import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/features/home/home_screen.dart';
import 'package:buildvibes/shared/widgets/bv_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const _tabKeys = [
  'nav-home',
  'nav-explore',
  'nav-create',
  'nav-activity',
  'nav-profile',
];

double _centreX(WidgetTester tester, String key) =>
    tester.getCenter(find.byKey(Key(key))).dx;

void main() {
  testWidgets('English: five slots in order, left to right, Home first', (
    tester,
  ) async {
    await pumpApp(tester);

    for (final label in ['Home', 'Explore', 'Create', 'Activity', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
    final xs = [for (final k in _tabKeys) _centreX(tester, k)];
    expect(xs, orderedEquals([...xs]..sort()));
    // Home opens first, on its Feed.
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Arabic: labels in Arabic and the bar reads right to left', (
    tester,
  ) async {
    await pumpApp(tester, language: 'ar');

    for (final label in ['الرئيسية', 'استكشف', 'إنشاء', 'النشاط', 'ملفي']) {
      expect(find.text(label), findsWidgets);
    }
    final xs = [for (final k in _tabKeys) _centreX(tester, k)];
    expect(xs, orderedEquals([...xs]..sort((a, b) => b.compareTo(a))));
  });

  testWidgets('tapping a tab shows that tab', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('nav-explore')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Explore'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-activity')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Activity'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Profile'), findsOneWidget);
  });

  testWidgets('Create opens the composer and keeps the current tab', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('nav-create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composer-text')), findsOneWidget);

    // Nothing written: closing asks nothing and comes back to Home.
    await tester.tap(find.byKey(const Key('composer-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composer-text')), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('every slot is at least the minimum touch size', (tester) async {
    await pumpApp(tester);
    for (final k in _tabKeys) {
      final size = tester.getSize(find.byKey(Key(k)));
      expect(size.height, greaterThanOrEqualTo(BvSize.touchMin));
    }
  });

  testWidgets('the bar matches the Figma sizes', (tester) async {
    await pumpApp(tester);
    final bar = tester.getSize(find.byType(BvBottomBar));
    // 64 high, top border included (no safe area in tests).
    expect(bar.height, BvBottomBarSize.height);
    expect(find.byType(HomeScreen), findsOneWidget);
    for (final k in _tabKeys) {
      expect(
        tester.getSize(find.byKey(Key(k))),
        const Size(BvBottomBarSize.slotWidth, BvBottomBarSize.slotHeight),
      );
    }
    expect(
      tester.getSize(find.byKey(const Key('nav-create-button'))),
      const Size(BvBottomBarSize.createWidth, BvBottomBarSize.createHeight),
    );
    final create = tester.widget<Container>(
      find.byKey(const Key('nav-create-button')),
    );
    expect((create.decoration! as BoxDecoration).color, BvColors.actionPrimary);
  });

  testWidgets('active tab: indicator above an ink icon, same label weight', (
    tester,
  ) async {
    await pumpApp(tester);

    // Only one indicator, and it sits in the Home slot above the icon.
    final indicator = find.byKey(const Key('nav-indicator'));
    expect(indicator, findsOneWidget);
    final home = find.byKey(const Key('nav-home'));
    expect(find.descendant(of: home, matching: indicator), findsOneWidget);
    final homeIcon = find.descendant(of: home, matching: find.byType(Icon));
    expect(
      tester.getBottomLeft(indicator).dy,
      lessThan(tester.getTopLeft(homeIcon).dy),
    );
    expect(tester.widget<Icon>(homeIcon).color, BvColors.iconPrimary);

    final explore = find.byKey(const Key('nav-explore'));
    final exploreIcon = find.descendant(
      of: explore,
      matching: find.byType(Icon),
    );
    expect(tester.widget<Icon>(exploreIcon).color, BvColors.iconSecondary);

    TextStyle label(Finder slot) => tester
        .widget<Text>(find.descendant(of: slot, matching: find.byType(Text)))
        .style!;
    final homeLabel = label(home);
    final exploreLabel = label(explore);
    expect(homeLabel.color, BvColors.textPrimary);
    expect(exploreLabel.color, BvColors.textSecondary);
    expect(homeLabel.fontWeight, exploreLabel.fontWeight);

    // Same glyph when active.
    await tester.tap(explore);
    await tester.pumpAndSettle();
    expect(tester.widget<Icon>(exploreIcon).icon, BvIcons.explore);
    expect(find.descendant(of: explore, matching: indicator), findsOneWidget);
  });
}
