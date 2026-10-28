// Review 102 N4: the selection bar's Move, for entries and for lines, reads
// "Move to…" («نقل إلى…») with the same icon, and the page picker it opens
// is titled the same. In English and Arabic.
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';

const _words = {'en': 'Move to…', 'ar': 'نقل إلى…'};

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    test('the words: the bar\'s Move and the picker\'s title [$lang]', () {
      expect(l10n.notebookMove, _words[lang]);
      expect(l10n.notebookMoveToPage, _words[lang]);
    });

    testWidgets('an entry held: the bar says Move to…, with the page icon; '
        'its picker is titled Move to… [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        now: NotebookPageSamples.now,
        notebook: NotebookPageSamples(lang).repository(),
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/notebook/pages/${NotebookPageSamples.siteA}');
      await tester.pumpAndSettle();
      await tester.longPress(
        find.byKey(const ValueKey(('swipe', 'entry-pour'))),
      );
      await tester.pumpAndSettle();
      final move = find.byKey(const Key('select-move'));
      expect(
        find.descendant(of: move, matching: find.text(_words[lang]!)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: move, matching: find.byIcon(BvIcons.pageFolder)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('select-move')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(_words[lang]!),
        ),
        findsOneWidget,
      );
    });
  }
}
