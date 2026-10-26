// Review 100 B6 (D12): back by swipe, everywhere. Android's back gesture is
// the predictive one and does what ← does; on an iPhone a swipe from the
// leading edge goes back on every pushed screen, also while writing or
// selecting, in ←'s order: the open menu, then the selection, then the
// entry (saved in place, B2), then the screen. In English and Arabic.
import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/core/theme/bv_theme.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/notebook/note_page_editor.dart';
import 'package:buildvibes/features/notebook/notebook_page_screen.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(Key(k));

const _page = '/notebook/pages/${FakeNotebookRepository.myNotesId}';

Note _saved() => Note(
  id: 'entry-1',
  kind: NoteKind.text,
  title: 'Pour',
  blocks: [PageText('s-1', 'Clean the formwork')],
  body: 'Pour\nClean the formwork',
  createdAt: DateTime(2026, 10, 15, 9),
  pageId: FakeNotebookRepository.myNotesId,
);

NoteDraft _draft() => NoteDraft(
  id: 'draft-1',
  startedAt: NotebookSamples.now,
  title: 'Pour',
  blocks: [PageText('t-1', 'Rebar')],
  pageId: FakeNotebookRepository.myNotesId,
);

/// My notebook's list, then the page pushed over it.
Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<Note> notes = const [],
  NoteDraft? draft,
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(notes: notes),
    stored: {
      if (draft != null) 'notebook_draft:user-1': jsonEncode(draft.toJson()),
    },
  );
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  router.push('/notebook');
  await tester.pumpAndSettle();
  router.push(_page);
  await tester.pumpAndSettle();
  return app;
}

/// A swipe in from the leading edge (the right in Arabic), as an iPhone's.
Future<void> _swipeBack(WidgetTester tester, String lang) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final ar = lang == 'ar';
  await tester.dragFrom(
    Offset(ar ? size.width - 2 : 2, size.height / 2),
    Offset(ar ? -size.width * 0.7 : size.width * 0.7, 0),
  );
  await tester.pumpAndSettle();
}

NotePageEditorState _editor(WidgetTester tester) =>
    tester.state<NotePageEditorState>(find.byType(NotePageEditor));

NoteDraft? _drafted(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(noteDraftProvider);

void main() {
  test('Android: the back gesture is predictive (the manifest)', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
  });

  test('Android: pages move with the predictive back gesture; iPhone '
      'pages with the edge swipe', () {
    final theme = BvTheme.forLocale(const Locale('en'));
    final builders = theme.pageTransitionsTheme.builders;
    expect(
      builders[TargetPlatform.android],
      isA<PredictiveBackPageTransitionsBuilder>(),
    );
    expect(
      builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });

  testWidgets('every screen is a Material page, so it moves with the '
      "theme's transitions (go_router took the app for a WidgetsApp: its "
      'MaterialApp is another class, and every page had no transition)', (
    tester,
  ) async {
    await _open(tester, 'en');
    final page = ModalRoute.of(
      tester.element(find.byType(NotebookPageScreen)),
    )!;
    expect(page.settings, isA<MaterialPage<void>>());
  });

  for (final lang in ['en', 'ar']) {
    group('iPhone: a swipe from the leading edge does what ← does [$lang]', () {
      testWidgets('while writing: the line menu closes, then the entry is '
          'put down, then the screen goes', (tester) async {
        await _open(tester, lang, draft: _draft());
        await tester.tap(_key('note-draft'));
        await tester.pumpAndSettle();
        _editor(tester).focusBlock('t:t-1');
        await tester.pumpAndSettle();
        await tester.tap(_key('page-handle-t-1'));
        await tester.pumpAndSettle();
        expect(_key('page-block-menu'), findsOneWidget);
        // 1. The menu.
        await _swipeBack(tester, lang);
        expect(_key('page-block-menu'), findsNothing);
        expect(_key('note-tools'), findsOneWidget);
        // 2. The entry, kept as its Draft card; the page stays.
        await _swipeBack(tester, lang);
        expect(_key('note-tools'), findsNothing);
        expect(_key('note-draft'), findsOneWidget);
        expect(find.byType(NotebookPageScreen), findsOneWidget);
        // 3. The screen.
        await _swipeBack(tester, lang);
        expect(find.byType(NotebookPageScreen), findsNothing);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets(
        'a saved entry being edited is saved in place (B2)',
        (tester) async {
          final app = await _open(tester, lang, notes: [_saved()]);
          await tester.tap(_key('note-entry-1'));
          await tester.pumpAndSettle();
          await tester.enterText(_key('note-title'), 'Pour, level 3');
          await tester.pumpAndSettle();
          await _swipeBack(tester, lang);
          expect(_key('note-tools'), findsNothing);
          expect(_drafted(tester), isNull);
          expect(app.notebook.kept['entry-1']!.title, 'Pour, level 3');
          expect(find.byType(NotebookPageScreen), findsOneWidget);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets('while selecting: the selection goes first, then the '
          'screen', (tester) async {
        await _open(tester, lang, notes: [_saved()]);
        await tester.longPress(_key('note-head-entry-1'));
        await tester.pumpAndSettle();
        expect(_key('note-selected-entry-1'), findsOneWidget);
        await _swipeBack(tester, lang);
        expect(_key('note-selected-entry-1'), findsNothing);
        expect(find.byType(NotebookPageScreen), findsOneWidget);
        await _swipeBack(tester, lang);
        expect(find.byType(NotebookPageScreen), findsNothing);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    });

    group('Android: the system back does what ← does [$lang]', () {
      testWidgets('the selection goes first, then the screen', (tester) async {
        await _open(tester, lang, notes: [_saved()]);
        await tester.longPress(_key('note-head-entry-1'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_key('note-selected-entry-1'), findsNothing);
        expect(find.byType(NotebookPageScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(NotebookPageScreen), findsNothing);
      });

      testWidgets('while writing: the menu, then the entry, then the screen', (
        tester,
      ) async {
        await _open(tester, lang, draft: _draft());
        await tester.tap(_key('note-draft'));
        await tester.pumpAndSettle();
        _editor(tester).focusBlock('t:t-1');
        await tester.pumpAndSettle();
        await tester.tap(_key('page-handle-t-1'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_key('page-block-menu'), findsNothing);
        expect(_key('note-tools'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_key('note-tools'), findsNothing);
        expect(find.byType(NotebookPageScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(NotebookPageScreen), findsNothing);
      });
    });
  }
}
