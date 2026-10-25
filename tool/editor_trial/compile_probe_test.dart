// Review 97 trial: does appflowy_editor 6.2.0 (pub.dev, MPL 2.0) compile
// on this app's Flutter? Kept out of test/ on purpose: while it doesn't
// compile, every app test would fail with it. Run it alone:
//   flutter test tool/editor_trial/compile_probe_test.dart
// On Flutter 3.44 it fails to compile (docs/reviews/editor-trial-report.md):
// the package's DeltaTextInputService lacks TextInputClient.onFocusReceived,
// and file_picker 13 has no FilePicker.platform nor PlatformFile.bytes.
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the editor builds with one empty line', (tester) async {
    final state = EditorState(document: Document.blank(withInitialText: true));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppFlowyEditorLocalizations.delegate],
        home: Scaffold(body: AppFlowyEditor(editorState: state)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppFlowyEditor), findsOneWidget);
  });
}
