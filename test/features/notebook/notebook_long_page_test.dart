// Review 101 A: a notebook page with 300 entries builds only the entries on
// screen, plus a small margin; opened at entry 250 (from Filter or search),
// it is built and on screen. In English and Arabic.
import 'package:buildvibes/core/routing/app_routes.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/notebook_page.dart';
import 'package:buildvibes/features/notebook/notebook_page_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';

const _page = 'page-long';

/// What a screen and its margin hold: well under the 300.
const _bounded = 20;

/// 300 entries, the newest first, 2 hours 24 apart: 30 days.
FakeNotebookRepository _notebook() => FakeNotebookRepository(
  pages: [
    FakeNotebookRepository.myNotes(),
    NotebookPage(
      id: _page,
      title: 'Site log',
      createdAt: DateTime(2026, 9, 1),
      lastActivityAt: NotebookPageSamples.now,
    ),
  ],
  notes: [
    for (var i = 0; i < 300; i++)
      Note(
        id: 'entry-${i.toString().padLeft(3, '0')}',
        kind: NoteKind.text,
        title: 'Entry $i',
        body: 'Entry $i',
        createdAt: NotebookPageSamples.now.subtract(
          Duration(minutes: 144 * i + 1),
        ),
        pageId: _page,
      ),
  ],
);

Future<void> _open(WidgetTester tester, String lang, String path) async {
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: _notebook(),
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
}

Finder _entry(String id) => find.byKey(ValueKey(('swipe', id)));

int _built() => find.byType(NoteSlip, skipOffstage: false).evaluate().length;

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets('300 entries: only the entries on screen are built '
        '[$lang]', (tester) async {
      await _open(tester, lang, AppRoutes.notebookPage(_page));
      expect(_entry('entry-000'), findsOneWidget);
      expect(_built(), lessThanOrEqualTo(_bounded));
      // Each entry is made as it is built, not all 300 on every build.
      final list = tester.widget<ListView>(
        find.byKey(const Key('notebook-list')),
      );
      expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
    });

    testWidgets('opened at entry 250: it is built and on screen, and the '
        'page still builds only what shows [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        AppRoutes.notebookPage(_page, entry: 'entry-250'),
      );
      expect(_entry('entry-250'), findsOneWidget);
      final page = tester.getRect(find.byKey(const Key('notebook-list')));
      final entry = tester.getRect(_entry('entry-250'));
      expect(entry.top, greaterThanOrEqualTo(page.top - 1));
      expect(entry.bottom, lessThanOrEqualTo(page.bottom + 1));
      expect(_built(), lessThanOrEqualTo(_bounded));
    });
  }
}
