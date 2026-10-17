import 'package:flutter/gestures.dart' show kLongPressTimeout, kPressTimeout;
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_writing_specs.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:buildvibes/shared/widgets/bv_controls.dart';
import 'package:buildvibes/shared/widgets/bv_send_back_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

enum _Reason { photoMissing, notAsAsked, somethingElse }

const _reasons = [
  (value: _Reason.photoMissing, label: 'Photo missing'),
  (value: _Reason.notAsAsked, label: 'Not as asked'),
  (value: _Reason.somethingElse, label: 'Something else'),
];

/// Enabled with a reason; "Something else" also needs a note.
class _Host extends StatefulWidget {
  const _Host({required this.onSend});

  final ValueChanged<(_Reason, String)> onSend;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final _note = TextEditingController();
  _Reason? _reason;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _ready =>
      _reason != null &&
      (_reason != _Reason.somethingElse || _note.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) => BvSendBackCard<_Reason>(
    title: 'Send back to Omar',
    reasons: _reasons,
    selected: _reason,
    onSelected: (r) => setState(() => _reason = r),
    noteController: _note,
    notePlaceholder: 'Add a note',
    onNoteChanged: (_) => setState(() {}),
    sendLabel: 'Send back',
    onSend: _ready ? () => widget.onSend((_reason!, _note.text)) : null,
  );
}

bool _enabled(WidgetTester tester) =>
    tester.widget<BvButton>(find.byType(BvButton)).onPressed != null;

Color _ring(WidgetTester tester, int i) {
  final box = decorationOf(
    tester,
    find
        .descendant(
          of: find.byType(BvRadio).at(i),
          matching: find.byType(Container),
        )
        .first,
  );
  return (box.border! as Border).top.color;
}

void main() {
  testBoth('one reason at a time, with the small radio', (tester, lang) async {
    await pumpComponent(tester, _Host(onSend: (_) {}), lang: lang);
    expect(
      tester.getSize(find.byType(BvSendBackCard<_Reason>)).width,
      BvSendBackSpec.width,
    );
    expect(tester.getSize(find.byType(BvRadio).first), const Size.square(20));
    expect(_ring(tester, 0), BvColors.borderDefault);
    expect(_enabled(tester), isFalse);

    await tester.tap(find.text('Not as asked'));
    await tester.pump();
    expect(_ring(tester, 1), BvColors.actionPrimary);
    await tester.tap(find.text('Photo missing'));
    await tester.pump();
    expect(_ring(tester, 0), BvColors.actionPrimary);
    expect(_ring(tester, 1), BvColors.borderDefault);
    expect(_enabled(tester), isTrue);

    // The radio is at the start.
    final radio = tester.getCenter(find.byType(BvRadio).first).dx;
    final label = tester.getCenter(find.text('Photo missing')).dx;
    expect(isRtl(lang) ? radio > label : radio < label, isTrue);
    // No voice note to hold: no microphone (send_back takes none).
    expect(find.byIcon(BvIcons.microphone), findsNothing);
  });

  testBoth('"Something else" needs a note before sending', (
    tester,
    lang,
  ) async {
    (_Reason, String)? sent;
    await pumpComponent(tester, _Host(onSend: (v) => sent = v), lang: lang);
    await tester.tap(find.text('Something else'));
    await tester.pump();
    expect(_enabled(tester), isFalse);

    await tester.enterText(find.byType(TextField), 'One sleeve is short');
    await tester.pump();
    expect(_enabled(tester), isTrue);
    await tester.tap(find.byType(BvButton));
    expect(sent, (_Reason.somethingElse, 'One sleeve is short'));
  });

  testBoth('holding the microphone starts and ends a voice note', (
    tester,
    lang,
  ) async {
    final note = TextEditingController();
    addTearDown(note.dispose);
    final events = <String>[];
    await pumpComponent(
      tester,
      BvSendBackCard<_Reason>(
        title: 'Send back to Omar',
        reasons: _reasons,
        selected: null,
        onSelected: (_) {},
        noteController: note,
        notePlaceholder: 'Add a note',
        onMicrophoneHoldStart: () => events.add('start'),
        onMicrophoneHoldEnd: () => events.add('end'),
        sendLabel: 'Send back',
        onSend: null,
      ),
      lang: lang,
    );
    // The microphone sits at the note's end.
    final mic = tester.getCenter(find.byIcon(BvIcons.microphone)).dx;
    final field = tester.getCenter(find.byType(TextField)).dx;
    expect(isRtl(lang) ? mic < field : mic > field, isTrue);
    await tester.longPress(find.byKey(const Key('send-back-microphone')));
    expect(events, ['start', 'end']);
  });

  testWidgets('the standard radio keeps its 48 tap area', (tester) async {
    await pumpComponent(
      tester,
      const Column(
        children: [
          BvRadio(selected: true),
          BvRadio(selected: true, small: true),
        ],
      ),
      lang: 'en',
    );
    expect(tester.getSize(find.byType(BvRadio).first), const Size.square(48));
    expect(tester.getSize(find.byType(BvRadio).last), const Size.square(20));
  });

  testBoth('the microphone looks 18 and has a 48 × 48 touch area', (
    tester,
    lang,
  ) async {
    final note = TextEditingController();
    addTearDown(note.dispose);
    var holds = 0;
    await pumpComponent(
      tester,
      BvSendBackCard<_Reason>(
        title: 'Send back to Omar',
        reasons: _reasons,
        selected: null,
        onSelected: (_) {},
        noteController: note,
        notePlaceholder: 'Add a note',
        onMicrophoneHoldStart: () => holds++,
        onMicrophoneHoldEnd: () {},
        sendLabel: 'Send back',
        onSend: null,
      ),
      lang: lang,
    );
    final icon = find.byIcon(BvIcons.microphone);
    expect(tester.getSize(icon), const Size.square(BvSendBackSpec.microphone));
    final target = find.byKey(const Key('send-back-microphone'));
    expect(tester.getSize(target).width, BvSendBackSpec.microphoneTouch);
    final centre = tester.getCenter(target);
    const reach = BvSize.touchMin / 2 - 1;
    for (final p in [
      centre.translate(-reach, 0),
      centre.translate(reach, 0),
      centre.translate(0, -reach),
      centre.translate(0, reach),
    ]) {
      final gesture = await tester.startGesture(p);
      await tester.pump(kLongPressTimeout + kPressTimeout);
      await gesture.up();
      await tester.pump();
    }
    expect(holds, 4);
  });

  testBoth('reasons are full-width rows at least 42 high', (
    tester,
    lang,
  ) async {
    await pumpComponent(tester, _Host(onSend: (_) {}), lang: lang);
    final row = find.ancestor(
      of: find.text('Photo missing'),
      matching: find.byType(GestureDetector),
    );
    expect(tester.getSize(row.first).height, greaterThanOrEqualTo(42));
  });
}
