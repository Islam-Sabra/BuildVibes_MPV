import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/space_search.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/chat/thread_screen.dart';
import 'package:buildvibes/features/library/library_file_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/spaces/space_search_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/search_fakes.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

const _space = 'space-1';

FakeSpaceRepository _spaces({
  SpacePass pass = SpacePass.lead,
  bool createItems = true,
}) => FakeSpaceRepository(now: testNow)
  ..details[_space] = SpaceDetail(
    id: _space,
    name: 'Site team',
    myPass: pass,
    iAmAdmin: pass == SpacePass.lead,
    myRights: MemberRights(createItems: createItems),
  );

FakeSearchRepository _search() => FakeSearchRepository()
  ..hits.addAll([
    SpaceSearchHit(
      kind: SpaceSearchKind.post,
      id: 'post-c7',
      postId: 'post-c7',
      postKind: 'work_item',
      ref: 'KCT-021',
      title: 'Sleeves at grid C7 before the pour',
      authorName: 'Omar Haddad',
      createdAt: testNow,
      status: WorkStatus.done,
    ),
    SpaceSearchHit(
      kind: SpaceSearchKind.point,
      id: 'point-1',
      postId: 'post-walk',
      postKind: 'checklist',
      title: 'Walk, level 4',
      snippet: 'Sleeves not sealed at wall B',
      createdAt: testNow,
    ),
    SpaceSearchHit(
      kind: SpaceSearchKind.file,
      id: 'file-ms',
      title: 'Method statement, sleeves.pdf',
      createdAt: testNow,
    ),
    SpaceSearchHit(
      kind: SpaceSearchKind.message,
      id: 'msg-1',
      threadId: 'thread-1',
      snippet: 'Sleeves arrive tomorrow morning',
      authorName: 'Omar Haddad',
      createdAt: testNow,
    ),
  ]);

Future<TestApp> _openSearch(WidgetTester tester, String lang) async {
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: _spaces(),
    search: _search(),
  );
  _router(tester).push('/spaces/$_space');
  await tester.pumpAndSettle();
  await _tap(tester, 'space-more');
  await tester.tap(find.text(_l10n(lang).searchMenu));
  await tester.pumpAndSettle();
  return app;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('search-field')),
      matching: find.byType(TextField),
    ),
    text,
  );
  await tester.pump(SpaceSearchScreen.pause);
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('S: from the Space menu; after 2 characters, three groups '
        '[$lang]', (tester) async {
      final app = await _openSearch(tester, lang);
      expect(find.byType(SpaceSearchScreen), findsOneWidget);

      await _type(tester, 's');
      expect(app.search.queries, isEmpty);
      expect(find.byKey(const Key('search-results')), findsNothing);

      await _type(tester, 'sleeves');
      expect(app.search.queries, ['sleeves']);
      expect(find.text(l10n.searchWorkItems), findsOneWidget);
      expect(find.text(l10n.searchFiles), findsOneWidget);
      expect(find.text(l10n.searchChat), findsOneWidget);
      // A work item's stamp; a point under its post.
      expect(
        find.descendant(
          of: find.byKey(const Key('search-post-post-c7')),
          matching: find.text(l10n.daybookStampDone),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('search-point-point-1')),
          matching: find.textContaining('Walk, level 4'),
        ),
        findsOneWidget,
      );

      // ✕ clears; Cancel goes back.
      await _tap(tester, 'search-clear');
      expect(find.byKey(const Key('search-results')), findsNothing);
      await _tap(tester, 'search-cancel');
      expect(find.byType(SpaceSearchScreen), findsNothing);
      expect(find.byType(SpaceScreen), findsOneWidget);
    });

    testWidgets('S: nothing found, and no count [$lang]', (tester) async {
      await _openSearch(tester, lang);
      await _type(tester, 'scaffold');
      expect(
        find.text(l10n.searchNothing(inOwnDirection('scaffold'))),
        findsOneWidget,
      );
      expect(find.byKey(const Key('search-results')), findsNothing);
      // Groups and rows only: no "4 results" line (rule 3).
      await _type(tester, 'sleeves');
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      expect(texts.where((t) => RegExp(r'^\d+\b').hasMatch(t)), isEmpty);
    });

    testWidgets('S: rows open the file page and the thread at the message '
        '[$lang]', (tester) async {
      await _openSearch(tester, lang);
      await _type(tester, 'sleeves');
      await _tap(tester, 'search-file-file-ms');
      expect(find.byType(LibraryFileScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(LibraryFileScreen))).pop();
      await tester.pumpAndSettle();
      await _tap(tester, 'search-message-msg-1');
      final thread = tester.widget<ThreadScreen>(find.byType(ThreadScreen));
      expect(thread.threadId, 'thread-1');
      expect(thread.atMessage, 'msg-1');
    });

    testWidgets('V1: Read only is a Viewer\'s; a locked Crew pass is just the '
        'pass [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: _spaces(pass: SpacePass.viewer, createItems: false),
      );
      _router(tester).push('/spaces/$_space');
      await tester.pumpAndSettle();
      expect(find.text(l10n.daybookReadOnly), findsOneWidget);
      expect(find.text(l10n.spacesPassViewer), findsOneWidget);
    });

    testWidgets('V1: a Crew pass with posting locked [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: _spaces(pass: SpacePass.crew, createItems: false),
      );
      _router(tester).push('/spaces/$_space');
      await tester.pumpAndSettle();
      expect(find.text(l10n.daybookReadOnly), findsNothing);
      expect(find.text(l10n.spacesPassCrew), findsOneWidget);
    });
  }
}
