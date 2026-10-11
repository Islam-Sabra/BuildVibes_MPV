import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_bottom_bar.dart';
import 'package:buildvibes/shared/widgets/bv_placeholder_screen.dart';
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
    // Home opens first.
    expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);
  });

  testWidgets('Arabic: labels in Arabic and the bar reads right to left', (
    tester,
  ) async {
    await pumpApp(tester, language: 'ar');

    for (final label in ['الرئيسية', 'استكشاف', 'إنشاء', 'النشاط', 'الملف']) {
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

  testWidgets('Create opens a sheet and keeps the current tab', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('nav-create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-sheet')), findsOneWidget);

    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-sheet')), findsNothing);
    expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);
  });

  testWidgets('every slot is at least the minimum touch size', (tester) async {
    await pumpApp(tester);
    for (final k in _tabKeys) {
      final size = tester.getSize(find.byKey(Key(k)));
      expect(size.height, greaterThanOrEqualTo(BvSize.touchMin));
    }
  });

  testWidgets('the bar stays short and the tab fills the rest', (tester) async {
    await pumpApp(tester);
    final bar = tester.getSize(find.byType(BvBottomBar));
    expect(bar.height, lessThan(BvSize.touchMin * 2));
    expect(find.byType(BvPlaceholderScreen), findsOneWidget);
  });
}
