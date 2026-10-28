// Review 99B B3 (PG8) with review 100: Deleted items. One choice keeps them
// 7 · 30 · 90 days; each item says what it is, where it came from and
// when it was deleted; Restore puts it back; swiped toward the start,
// Delete forever after one confirm; Empty now after one confirm. In
// English and Arabic.
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/notebook_page.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

List<DeletedItem> _items(NotebookPageSamples s) => [
  DeletedItem(
    kind: DeletedKind.entry,
    id: 'gone-pump',
    title: s.pumpTitle,
    pageId: NotebookPageSamples.siteA,
    pageTitle: s.siteATitle,
    deletedAt: DateTime(2026, 10, 15, 9),
    purgeAt: DateTime(2026, 11, 14, 9),
  ),
  DeletedItem(
    kind: DeletedKind.page,
    id: 'gone-snags',
    title: s.t('Old snags', 'ملاحظات قديمة'),
    pageTitle: s.t('My notes', 'ملاحظاتي'),
    deletedAt: DateTime(2026, 10, 12, 9),
    purgeAt: DateTime(2026, 11, 11, 9),
  ),
  DeletedItem(
    kind: DeletedKind.part,
    id: 'gone-voice',
    title: s.t('Voice note, 0:42', 'تسجيل صوتي، 0:42'),
    pageId: NotebookPageSamples.siteB,
    pageTitle: s.siteBTitle,
    deletedAt: DateTime(2026, 10, 12, 8),
    purgeAt: DateTime(2026, 11, 11, 8),
  ),
];

Future<FakeNotebookRepository> _open(WidgetTester tester, String lang) async {
  final s = NotebookPageSamples(lang);
  final repo = s.repository()..deletedList = _items(s);
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: repo,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push('/notebook');
  await tester.pumpAndSettle();
  await _tap(tester, _key('notebook-deleted'));
  return repo;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = NotebookPageSamples(lang);

    group('PG8 Deleted items [$lang]', () {
      testWidgets('from the pages list\'s end: Keep for 7 · 30 · 90 days (30 '
          'chosen), then each item by day with what it was and its page', (
        tester,
      ) async {
        await _open(tester, lang);
        expect(find.text(l10n.notebookDeletedItems), findsWidgets);
        expect(find.text(l10n.notebookKeepFor), findsOneWidget);
        for (final d in [7, 30, 90]) {
          expect(_key('keep-$d'), findsOneWidget);
        }
        Color? ink(int d) => tester
            .widget<Text>(
              find.descendant(of: _key('keep-$d'), matching: find.byType(Text)),
            )
            .style
            ?.color;
        expect(ink(30), BvColors.textPrimary);
        expect(ink(7), BvColors.textSecondary);
        expect(find.text(l10n.notebookKeepNote(30)), findsOneWidget);
        expect(find.text(l10n.notebookToday), findsOneWidget);
        expect(find.text(l10n.notebookDaysAgo(3)), findsOneWidget);
        expect(
          find.text(l10n.notebookDeletedEntry(s.siteATitle)),
          findsOneWidget,
        );
        expect(
          find.text(l10n.notebookDeletedPage(s.t('My notes', 'ملاحظاتي'))),
          findsOneWidget,
        );
        expect(
          find.text(l10n.notebookDeletedPart(s.siteBTitle)),
          findsOneWidget,
        );
        expect(_key('deleted-empty-now'), findsOneWidget);
      });

      testWidgets('a choice of days goes to the server and the line follows', (
        tester,
      ) async {
        final repo = await _open(tester, lang);
        await _tap(tester, _key('keep-7'));
        expect(repo.calls, contains('keep:7'));
        expect(find.text(l10n.notebookKeepNote(7)), findsOneWidget);
      });

      testWidgets('J4: Restore is words with an icon, no box (PG8)', (
        tester,
      ) async {
        await _open(tester, lang);
        final restore = tester.widget<BvButton>(
          _key('deleted-restore-gone-pump'),
        );
        expect(restore.style, BvButtonStyle.quiet);
        expect(restore.icon, BvIcons.sendBack);
      });

      testWidgets('Restore puts it back in its page', (tester) async {
        final repo = await _open(tester, lang);
        await _tap(tester, _key('deleted-restore-gone-pump'));
        expect(repo.calls, contains('restore:gone-pump'));
        expect(_key('deleted-gone-pump'), findsNothing);
        expect(
          find.text(l10n.notebookRestoredTo(s.siteATitle)),
          findsOneWidget,
        );
      });

      testWidgets('swiped toward the start: Delete forever, after one '
          'confirm', (tester) async {
        final repo = await _open(tester, lang);
        await tester.timedDrag(
          _key('deleted-gone-snags'),
          Offset(lang == 'ar' ? 140 : -140, 0),
          const Duration(milliseconds: 300),
        );
        await tester.pumpAndSettle();
        await _tap(tester, _key('swipe-archive-gone-snags'));
        expect(find.text(l10n.notebookDeleteForeverTitle), findsOneWidget);
        expect(repo.calls.where((c) => c.startsWith('forever')), isEmpty);
        await _tap(tester, find.text(l10n.notebookDeleteForever).last);
        expect(repo.calls, contains('forever:gone-snags'));
        expect(_key('deleted-gone-snags'), findsNothing);
      });

      testWidgets('Empty now: after one confirm, everything goes for good', (
        tester,
      ) async {
        final repo = await _open(tester, lang);
        await _tap(tester, _key('deleted-empty-now'));
        expect(find.text(l10n.notebookEmptyNowTitle), findsOneWidget);
        await _tap(tester, find.text(l10n.notebookEmptyNow).last);
        expect(repo.calls, contains('empty'));
        expect(find.text(l10n.notebookDeletedNone), findsOneWidget);
        expect(_key('deleted-empty-now'), findsNothing);
      });
    });
  }
}
