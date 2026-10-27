// A heading picked with "/" inside a toggle is drawn, and can be written
// in (found with review 100's second check; English and Arabic).
import 'dart:convert';

import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/notebook/note_page_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(Key(k));

const _toggle = 'a0000000-0000-4000-8000-000000000001';
const _inside = 'a0000000-0000-4000-8000-000000000002';

TextEditingController _focused(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .firstWhere((t) => t.focusNode?.hasFocus ?? false)
    .controller!;

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets('"/" inside a toggle: the heading picked is drawn [$lang]', (
      tester,
    ) async {
      final draft = NoteDraft(
        id: 'd0000000-0000-4000-8000-000000000101',
        startedAt: NotebookSamples.now,
        title: 'Pour',
        blocks: [
          PageToggle(_toggle, 'Level 3', [PageText(_inside, '')]),
        ],
        pageId: FakeNotebookRepository.myNotesId,
      );
      await pumpApp(
        tester,
        language: lang,
        now: NotebookSamples.now,
        notebook: FakeNotebookRepository(),
        stored: {'notebook_draft:user-1': jsonEncode(draft.toJson())},
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/notebook/pages/${FakeNotebookRepository.myNotesId}');
      await tester.pumpAndSettle();
      await tester.tap(_key('note-draft').first);
      await tester.pumpAndSettle();
      tester
          .state<NotePageEditorState>(find.byType(NotePageEditor))
          .focusBlock('t:$_inside');
      await tester.pumpAndSettle();
      for (final ch in '/head'.characters) {
        tester.testTextInput.enterText(_focused(tester).text + ch);
        await tester.pumpAndSettle();
      }
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      final toggle =
          ProviderScope.containerOf(
                tester.element(find.byType(Scaffold).first),
              ).read(noteDraftProvider)!.blocks.single
              as PageToggle;
      expect(toggle.children.single, isA<PageHeading>());
      // It is drawn, as a field to write the heading in.
      expect(_key('page-field-t:$_inside'), findsOneWidget);
      await tester.enterText(_key('page-field-t:$_inside'), 'Pour day');
      await tester.pumpAndSettle();
      expect(find.text('Pour day'), findsOneWidget);
      final kept =
          ProviderScope.containerOf(
                tester.element(find.byType(Scaffold).first),
              ).read(noteDraftProvider)!.blocks.single
              as PageToggle;
      expect((kept.children.single as PageHeading).text, 'Pour day');
    });
  }
}
