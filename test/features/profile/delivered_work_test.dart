// RE1 and RE2: Checked work on the profile (kept from the retired 0.9.0
// Work tests; the work item page itself is gone, slice 1).
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/profile/delivered_work.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/work_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('RE2: everything hidden until switched on [$lang]', (
      tester,
    ) async {
      final work = FakeWorkRepository()
        ..delivered.add(
          DeliveredWork(
            id: 'w1',
            title: 'Clash report, level 2',
            projectName: 'Kuwait City Tower',
            checkedByName: 'Omar Haddad',
            checkedAt: testNow,
            shown: false,
          ),
        );
      await pumpApp(tester, language: lang, work: work);
      _router(tester).push('/profile/delivered');
      await tester.pumpAndSettle();
      expect(find.byType(DeliveredScreen), findsOneWidget);
      expect(find.byKey(const Key('delivered-hidden-w1')), findsOneWidget);
      await _tap(tester, 'delivered-w1');
      expect(work.calls.single, 'shown w1 true');
      expect(find.byKey(const Key('delivered-shown-w1')), findsOneWidget);
    });

    testWidgets('across a block: Checked, without the name [$lang]', (
      tester,
    ) async {
      // The server leaves the name out (review 11 A5).
      final hidden = DeliveredWork(
        id: 'w1',
        title: 'Sleeves at grid C7',
        projectName: 'Kuwait City Tower',
        checkedAt: testNow,
      );
      final work = FakeWorkRepository()
        ..delivered.add(hidden)
        ..shownBy['p-omar'] = [hidden];
      await pumpApp(tester, language: lang, work: work);
      _router(tester).push('/profile/delivered');
      await tester.pumpAndSettle();
      expect(find.textContaining(l10n.deliveredCheckedOn('')), findsOneWidget);

      _router(tester).push('/people/p-omar/work/w1');
      await tester.pumpAndSettle();
      // In Arabic the stamp's word is the same text; count the row only.
      final onStamp = find.descendant(
        of: find.byKey(const Key('delivered-stamp')),
        matching: find.text(l10n.deliveredCheckedRowNoName),
      );
      expect(
        find.text(l10n.deliveredCheckedRowNoName).evaluate().length -
            onStamp.evaluate().length,
        1,
      );
      expect(find.text(l10n.deliveredCheckedRow), findsNothing);
    });

    testWidgets('RE1: only the allowed facts, and why [$lang]', (tester) async {
      final work = FakeWorkRepository()
        ..shownBy['p-omar'] = [
          DeliveredWork(
            id: 'w1',
            title: 'Sleeves at grid C7',
            place: 'Level 2 · Grid C7',
            projectName: 'Kuwait City Tower',
            checkedByName: 'Sara Ali',
            checkedAt: testNow,
          ),
        ];
      await pumpApp(tester, language: lang, work: work);
      _router(tester).push('/people/p-omar/work/w1');
      await tester.pumpAndSettle();
      expect(find.byType(DeliveredPublicScreen), findsOneWidget);
      expect(find.text('Sleeves at grid C7'), findsOneWidget);
      expect(find.text('Kuwait City Tower'), findsOneWidget);
      expect(find.byKey(const Key('delivered-stamp')), findsOneWidget);
      // The stamp hugs its label, never the full width.
      expect(
        tester.getSize(find.byKey(const Key('delivered-stamp'))).width,
        lessThan(
          tester.getSize(find.byKey(const Key('delivered-photo'))).width,
        ),
      );
      // No reference and no record: the Space stays private.
      expect(find.textContaining('KCT-'), findsNothing);
      expect(find.byKey(const Key('work-sign-off')), findsNothing);
    });
  }
}
