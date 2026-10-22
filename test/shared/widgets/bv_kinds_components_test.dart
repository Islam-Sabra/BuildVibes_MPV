import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_kinds_specs.dart';
import 'package:buildvibes/shared/widgets/bv_ack_pill.dart';
import 'package:buildvibes/shared/widgets/bv_attach_row.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
import 'package:buildvibes/shared/widgets/bv_calendar_leaf.dart';
import 'package:buildvibes/shared/widgets/bv_checklist_point.dart';
import 'package:buildvibes/shared/widgets/bv_faces.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_pinned_note.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvChecklistPoint (K1 v13 2594:36130)', () {
    testBoth('unticked: an empty box and the words; a whole 48 row ticks', (
      tester,
      lang,
    ) async {
      var taps = 0;
      await pumpComponent(
        tester,
        BvChecklistPoint(text: 'Floor tiles', onTap: () => taps++),
        lang: lang,
      );
      final row = find.byType(BvChecklistPoint);
      expect(
        tester.getSize(row).height,
        greaterThanOrEqualTo(BvChecklistSpec.rowMinHeight),
      );
      expect(find.byIcon(BvIcons.check), findsNothing);
      // The far end of the row is part of the target, not only the box.
      await tester.tapAt(tester.getTopRight(row) + const Offset(-4, 20));
      expect(taps, 1);
      final box = tester.getCenter(find.byKey(const Key('checklist-box')));
      final words = tester.getCenter(find.text('Floor tiles'));
      // The box leads: at the start in either direction.
      expect(isRtl(lang) ? box.dx > words.dx : box.dx < words.dx, isTrue);
    });

    testBoth('ticked: green box, struck-through grey words, who and when', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvChecklistPoint(
          text: 'Ceiling paint touch-up',
          tick: (
            name: 'Sara Al-Mutairi',
            tint: null,
            time: (time: '10:12', period: null),
          ),
        ),
        lang: lang,
      );
      final text = tester.widget<Text>(find.text('Ceiling paint touch-up'));
      expect(text.style!.decoration, TextDecoration.lineThrough);
      expect(text.style!.color, BvColors.textSecondary);
      expect(find.byIcon(BvIcons.check), findsOneWidget);
      final box = tester.widget<AnimatedContainer>(
        find.byKey(const Key('checklist-box')),
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        BvColors.feedbackSuccess,
      );
      expect(find.byType(BvAvatar), findsOneWidget);
      expect(find.text('10:12'), findsOneWidget);
      // Read only without onTap.
      final semantics = tester.getSemantics(find.byType(BvChecklistPoint));
      expect(semantics.flagsCollection.isChecked, isNotNull);
    });

    testBoth(
      'F54, F67: my tick: one tick haptic, the check fills in about 300 ms, '
      'and nothing glows',
      (tester, lang) async {
        // F67: the tick goes through bvHaptic; this phone has no effect
        // of its own, so Flutter's medium impact plays.
        final haptics = <String>[];
        const settings = MethodChannel('buildvibes/settings');
        tester.binding.defaultBinaryMessenger
          ..setMockMethodCallHandler(settings, (call) async {
            haptics.add('${call.method} ${call.arguments}');
            return null;
          })
          ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              haptics.add(call.arguments as String);
            }
            return null;
          });
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            settings,
            null,
          ),
        );
        var ticked = false;
        await pumpComponent(
          tester,
          StatefulBuilder(
            builder: (context, setState) => BvChecklistPoint(
              text: 'Floor tiles',
              tick: ticked
                  ? (
                      name: 'Islam Ahmed',
                      tint: null,
                      time: (time: '09:00', period: null),
                    )
                  : null,
              onTap: () => setState(() => ticked = true),
            ),
          ),
          lang: lang,
        );
        await tester.tap(find.byType(BvChecklistPoint));
        await tester.pump();
        expect(haptics, ['haptic tick', 'HapticFeedbackType.mediumImpact']);
        await tester.pump(BvChecklistSpec.tick ~/ 2);
        final half = tester.widget<ScaleTransition>(
          find.ancestor(
            of: find.byKey(const Key('checklist-check')),
            matching: find.byType(ScaleTransition),
          ),
        );
        expect(half.scale.value, inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('checklist-check')), findsOneWidget);
        expect(_glow(tester), isNull);
      },
    );

    testBoth('F54: someone else\'s tick arriving live glows, then fades', (
      tester,
      lang,
    ) async {
      final ticked = ValueNotifier(false);
      addTearDown(ticked.dispose);
      await pumpComponent(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: ticked,
          builder: (context, on, _) => BvChecklistPoint(
            text: 'Floor tiles',
            tick: on
                ? (
                    name: 'Omar Haddad',
                    tint: null,
                    time: (time: '09:00', period: null),
                  )
                : null,
            onTap: () {},
          ),
        ),
        lang: lang,
      );
      expect(_glow(tester), isNull);
      ticked.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_glow(tester), isNotNull);
      await tester.pump(BvChecklistSpec.glowHold + BvChecklistSpec.glowFade);
      await tester.pumpAndSettle();
      expect(_glow(tester), isNull);
    });

    testBoth('F54: with the phone\'s animations off, nothing glows', (
      tester,
      lang,
    ) async {
      final ticked = ValueNotifier(false);
      addTearDown(ticked.dispose);
      await pumpComponent(
        tester,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ValueListenableBuilder<bool>(
            valueListenable: ticked,
            builder: (context, on, _) => BvChecklistPoint(
              text: 'Floor tiles',
              tick: on
                  ? (
                      name: 'Omar Haddad',
                      tint: null,
                      time: (time: '09:00', period: null),
                    )
                  : null,
            ),
          ),
        ),
        lang: lang,
      );
      ticked.value = true;
      await tester.pump();
      expect(_glow(tester), isNull);
      expect(find.byKey(const Key('checklist-check')), findsOneWidget);
    });

    testBoth('progress: the share of the points, and its words', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvChecklistProgress(ticked: 2, total: 5, label: '2 of 5 ticked'),
        lang: lang,
      );
      expect(find.text('2 of 5 ticked'), findsOneWidget);
      final bar = tester.widget<FractionallySizedBox>(
        find.byKey(const Key('checklist-progress')),
      );
      expect(bar.widthFactor, closeTo(0.4, 0.001));
    });
  });

  testBoth('BvCalendarLeaf: weekday band, day, month (2594:36288)', (
    tester,
    lang,
  ) async {
    await pumpComponent(
      tester,
      const BvCalendarLeaf(weekday: 'FRI', day: '16', month: 'Oct'),
      lang: lang,
    );
    // 56 wide, at least 66 high: Arabic's taller lines make it taller.
    final leaf = tester.getSize(find.byKey(const Key('calendar-leaf')));
    expect(leaf.width, BvCalendarLeafSpec.width);
    expect(leaf.height, greaterThanOrEqualTo(BvCalendarLeafSpec.height));
    for (final t in ['FRI', '16', 'Oct']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(
      tester.widget<Text>(find.text('16')).style!.fontSize,
      BvCalendarLeafSpec.daySize,
    );
  });

  group('BvAckPill', () {
    testBoth('soft, main and done; done shows a check', (tester, lang) async {
      var taps = 0;
      await pumpComponent(
        tester,
        Column(
          children: [
            BvAckPill(
              key: const Key('soft'),
              label: 'Got it',
              icon: BvIcons.check,
              onTap: () => taps++,
            ),
            BvAckPill(
              key: const Key('main'),
              label: 'On my way',
              tone: BvAckPillTone.primary,
              onTap: () => taps++,
            ),
            BvAckPill(
              key: const Key('done'),
              label: 'In my calendar',
              icon: BvIcons.due,
              tone: BvAckPillTone.done,
              onTap: () => taps++,
            ),
          ],
        ),
        lang: lang,
      );
      Color? fill(String key) {
        final pill = find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(Container),
        );
        return (tester.widget<Container>(pill.first).decoration!
                as BoxDecoration)
            .color;
      }

      expect(fill('soft'), BvColors.surfaceBrandSoft);
      expect(fill('main'), BvColors.actionPrimary);
      expect(fill('done'), BvColors.surfaceSubtle);
      // Done trades its own icon for the check.
      expect(
        find.descendant(
          of: find.byKey(const Key('done')),
          matching: find.byIcon(BvIcons.check),
        ),
        findsOneWidget,
      );
      for (final k in ['soft', 'main', 'done']) {
        await tester.tap(find.byKey(Key(k)));
      }
      expect(taps, 3);
    });
  });

  testBoth('BvPinnedNote: pin, author, audience, until, words, faces and '
      'the action (K1 v13 2594:36070)', (tester, lang) async {
    await pumpComponent(
      tester,
      BvPinnedNote(
        author: 'Sara Al-Mutairi',
        audience: '· to everyone',
        time: '8:38',
        until: 'Until Friday 23 Oct · 2:00 pm',
        title: 'Friday is a half day.',
        leading: const BvFaces([
          (name: 'Omar Haddad', tint: BvAvatarTints.plain),
        ], large: true),
        action: BvAckPill(label: 'Got it', icon: BvIcons.check, onTap: () {}),
      ),
      lang: lang,
    );
    // F85: the pin's mark, and the pin on the facts line.
    expect(find.byIcon(BvIcons.pin), findsNWidgets(2));
    for (final t in [
      'Sara Al-Mutairi',
      '· to everyone',
      '8:38',
      'Until Friday 23 Oct · 2:00 pm',
      'Friday is a half day.',
      'Got it',
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    final note = tester.widget<Container>(find.byKey(const Key('pinned-note')));
    expect(
      (note.decoration! as BoxDecoration).color,
      BvColors.surfaceBrandSoft,
    );
    // The action sits at the end, the faces at the start.
    final faces = tester.getCenter(find.byType(BvFaces)).dx;
    final action = tester.getCenter(find.byType(BvAckPill)).dx;
    expect(isRtl(lang) ? faces > action : faces < action, isTrue);
  });

  testBoth('BvAttachRow: the icon, two lines and a › that mirrors (K4 v13)', (
    tester,
    lang,
  ) async {
    var taps = 0;
    await pumpComponent(
      tester,
      BvAttachRow(
        icon: BvIcons.image,
        title: 'Photo from the gallery',
        subtitle: 'Up to 10 photos',
        onTap: () => taps++,
      ),
      lang: lang,
    );
    expect(find.text('Up to 10 photos'), findsOneWidget);
    expect(
      tester.getSize(find.byType(BvAttachRow)).height,
      greaterThanOrEqualTo(BvAttachSpec.rowMinHeight),
    );
    final caret = tester.widget<Icon>(find.byIcon(BvIcons.caretForward));
    expect(caret.icon!.matchTextDirection, isTrue);
    await tester.tap(find.byType(BvAttachRow));
    expect(taps, 1);
  });

  testBoth('BvFaces large: the slip header\'s 24, overlapping', (
    tester,
    lang,
  ) async {
    await pumpComponent(
      tester,
      const BvFaces([
        (name: 'Omar Haddad', tint: BvAvatarTints.plain),
        (name: 'Sara Al-Mutairi', tint: BvAvatarTints.plain),
      ], large: true),
      lang: lang,
    );
    expect(tester.getSize(find.byType(BvFaces)).height, 24);
  });

  testBoth('BvGiveToPicker with chosenIds: several are checked, a pick '
      'toggles', (tester, lang) async {
    final picks = <String>[];
    await pumpComponent(
      tester,
      BvGiveToPicker(
        people: const [
          BvGiveToPerson(id: 'a', name: 'Sara Al-Mutairi', team: 'Site'),
          BvGiveToPerson(id: 'b', name: 'Omar Haddad', team: 'MEP'),
          BvGiveToPerson(id: 'c', name: 'Rakesh Nair'),
        ],
        currentOwnerId: null,
        currentLabel: 'now',
        chosenIds: const {'a', 'b'},
        searchPlaceholder: 'Who is it for…',
        onPick: (p) => picks.add(p.id),
      ),
      lang: lang,
    );
    expect(find.byIcon(BvIcons.check), findsNWidgets(2));
    // The Team stays under a chosen name; "now" is for one owner only.
    expect(find.text('now'), findsNothing);
    expect(find.text('Site'), findsOneWidget);
    await tester.tap(find.text('Rakesh Nair'));
    expect(picks, ['c']);
  });

  testBoth('BvWritingCard: a kind\'s extra under the text; a property with '
      'its own ×', (tester, lang) async {
    var removed = 0;
    final title = TextEditingController();
    final body = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(body.dispose);
    await pumpComponent(
      tester,
      BvWritingCard(
        titleController: title,
        bodyController: body,
        bodyPlaceholder: 'Add a note',
        kindLabel: 'Checklist',
        onKindTap: () {},
        properties: [
          BvWritingProperty.icon(
            icon: BvIcons.document,
            label: 'M-201.pdf',
            onRemove: () => removed++,
            removeLabel: 'Remove file',
          ),
        ],
        extra: const Text('points', key: Key('extra')),
      ),
      lang: lang,
    );
    final extra = tester.getTopLeft(find.byKey(const Key('extra'))).dy;
    final text = tester.getTopLeft(find.byKey(const Key('writing-body'))).dy;
    expect(extra, greaterThan(text));
    // The chip has its caret: there is a kind menu to open.
    expect(find.byIcon(BvIcons.caretDown), findsOneWidget);
    await tester.tap(find.byKey(const Key('writing-property-remove')));
    expect(removed, 1);
  });

  testBoth('BvWritingCard: more than four photos scroll as squares', (
    tester,
    lang,
  ) async {
    final body = TextEditingController();
    addTearDown(body.dispose);
    await pumpComponent(
      tester,
      BvWritingCard(
        bodyController: body,
        bodyPlaceholder: 'x',
        photoHeight: 110,
        photos: [
          for (var i = 0; i < 6; i++) ColoredBox(color: Color(0xFF000000 + i)),
        ],
      ),
      lang: lang,
    );
    expect(find.byKey(const Key('writing-photos-scroll')), findsOneWidget);
  });
}

/// The glow behind a checklist point, while it shows.
Color? _glow(WidgetTester tester) =>
    (tester
                .widget<DecoratedBox>(find.byKey(const Key('checklist-glow')))
                .decoration
            as BoxDecoration)
        .color;
