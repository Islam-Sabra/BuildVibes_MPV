import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_writing_specs.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
import 'package:buildvibes/shared/widgets/bv_torn_edge.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  testBoth('empty card: placeholders, orange cursor, no extra rows', (
    tester,
    lang,
  ) async {
    final title = TextEditingController();
    final body = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(body.dispose);
    await pumpComponent(
      tester,
      BvWritingCard(
        titleController: title,
        titlePlaceholder: 'Title',
        bodyController: body,
        bodyPlaceholder: 'Write what needs doing',
      ),
      lang: lang,
    );
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Write what needs doing'), findsOneWidget);
    expect(find.byType(BvAvatar), findsNothing);
    expect(find.byIcon(BvIcons.caretDown), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.cursorColor, BvColors.actionPrimary);
    expect(field.cursorWidth, BvWritingCardSpec.cursorWidth);

    await tester.enterText(find.byType(TextField).first, 'Cable tray');
    expect(title.text, 'Cable tray');
  });

  testBoth('filled card: draft, kind chip, properties and cover', (
    tester,
    lang,
  ) async {
    final title = TextEditingController(text: 'Cable tray hangers');
    final body = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(body.dispose);
    var kindTaps = 0;
    var removed = 0;
    await pumpComponent(
      tester,
      BvWritingCard(
        titleController: title,
        titlePlaceholder: 'Title',
        bodyController: body,
        bodyPlaceholder: 'Write what needs doing',
        draftLabel: 'Draft',
        kindLabel: 'Work item',
        onKindTap: () => kindTaps++,
        properties: const [
          BvWritingProperty.person(label: 'Omar Haddad'),
          BvWritingProperty.icon(icon: BvIcons.due, label: 'Sun 18 Oct'),
          BvWritingProperty.icon(icon: BvIcons.place, label: 'Level 4'),
        ],
        cover: const ColoredBox(color: BvColors.surfaceSubtle),
        onRemoveCover: () => removed++,
      ),
      lang: lang,
    );
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Omar Haddad'), findsOneWidget);
    expect(
      tester.widget<BvAvatar>(find.byType(BvAvatar)).size,
      BvAvatarSize.xxs,
    );
    await tester.tap(find.text('Work item'));
    expect(kindTaps, 1);

    final remove = find.byKey(const Key('writing-cover-remove'));
    expect(tester.getSize(remove), const Size.square(26));
    // The remove button sits at the cover's top end corner.
    final cover = tester.getRect(find.byType(ColoredBox).last);
    final button = tester.getRect(remove);
    expect(button.top - cover.top, BvWritingCardSpec.removeTop);
    expect(
      isRtl(lang) ? button.left - cover.left : cover.right - button.right,
      BvWritingCardSpec.removeEnd,
    );
    await tester.tap(remove);
    expect(removed, 1);
  });

  testBoth('a straight dashed rectangle with the small radius, no tear', (
    tester,
    lang,
  ) async {
    final title = TextEditingController();
    final body = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(body.dispose);
    await pumpComponent(
      tester,
      BvWritingCard(
        titleController: title,
        titlePlaceholder: 'Title',
        bodyController: body,
        bodyPlaceholder: 'Write what needs doing',
      ),
      lang: lang,
    );
    final paper = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(const Key('writing-card-outline')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(paper.decoration, isA<BoxDecoration>());
    final box = paper.decoration as BoxDecoration;
    expect(box.color, BvColors.surfaceElevated);
    expect(box.borderRadius, BvWritingCardSpec.radius);
    expect(BvWritingCardSpec.radius, BvRadius.controlAll);
    expect(
      tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(BvWritingCard),
              matching: find.byType(DecoratedBox),
            ),
          )
          .any(
            (d) =>
                d.decoration is ShapeDecoration &&
                (d.decoration as ShapeDecoration).shape is BvSlipBorder,
          ),
      isFalse,
    );
    expect((BvWritingCardSpec.dashOn, BvWritingCardSpec.dashOff), (4.0, 3.0));
    expect(BvWritingCardSpec.border, BvStroke.dash);
    // The title starts 18 below the card's top: no torn edge above it.
    final card = tester.getRect(find.byType(BvWritingCard));
    final field = tester.getRect(find.byType(TextField).first);
    expect(field.top - card.top, BvWritingCardSpec.paddingTop);
  });

  testBoth('one kind to post: the chip shows no drop-down caret', (
    tester,
    lang,
  ) async {
    final title = TextEditingController();
    final body = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(body.dispose);
    await pumpComponent(
      tester,
      BvWritingCard(
        titleController: title,
        titlePlaceholder: 'Title',
        bodyController: body,
        bodyPlaceholder: 'Write what needs doing',
        kindLabel: 'Work item',
      ),
      lang: lang,
    );
    expect(find.text('Work item'), findsOneWidget);
    expect(find.byIcon(BvIcons.caretDown), findsNothing);
    expect(
      find.ancestor(
        of: find.byKey(const Key('writing-kind-chip')),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
  });

  testBoth('kind chip, properties and the cover remove: 48 touch areas', (
    tester,
    lang,
  ) async {
    final title = TextEditingController(text: 'Cable tray hangers, level 4');
    final body = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(body.dispose);
    final taps = <String>[];
    await pumpComponent(
      tester,
      BvWritingCard(
        titleController: title,
        titlePlaceholder: 'Title',
        bodyController: body,
        bodyPlaceholder: 'Write what needs doing',
        draftLabel: 'Draft',
        kindLabel: 'Work item',
        onKindTap: () => taps.add('kind'),
        properties: [
          BvWritingProperty.person(
            label: 'Omar Haddad',
            onTap: () => taps.add('owner'),
          ),
        ],
        cover: const ColoredBox(color: BvColors.surfaceSubtle),
        onRemoveCover: () => taps.add('remove'),
      ),
      lang: lang,
    );
    expect(find.byIcon(BvIcons.caretDown), findsOneWidget);

    // The kind chip: 26 high, touched 12 above and 10 below.
    final chip = tester.getRect(find.byKey(const Key('writing-kind-chip')));
    expect(chip.height, BvWritingCardSpec.chipHeight);
    const chipOutset = BvWritingCardSpec.chipTouchOutset;
    expect(chipOutset.top + chip.height + chipOutset.bottom, BvSize.touchMin);
    await tapEach(tester, [
      chip.topCenter.translate(0, 1 - chipOutset.top),
      chip.bottomCenter.translate(0, chipOutset.bottom - 1),
    ]);
    expect(taps, ['kind', 'kind']);

    // The owner: an 18 line, touched 20 above and 10 below.
    taps.clear();
    final owner = tester.getRect(find.text('Omar Haddad'));
    const lineOutset = BvWritingCardSpec.propertyTouchOutset;
    expect(
      lineOutset.top + BvWritingCardSpec.propertyHeight + lineOutset.bottom,
      BvSize.touchMin,
    );
    final line = tester.getRect(
      find
          .ancestor(of: find.text('Omar Haddad'), matching: find.byType(Wrap))
          .first,
    );
    expect(line.height, BvWritingCardSpec.propertyHeight);
    await tapEach(tester, [
      Offset(owner.center.dx, line.top + 1 - lineOutset.top),
      Offset(owner.center.dx, line.bottom + lineOutset.bottom - 1),
    ]);
    expect(taps, ['owner', 'owner']);

    // The remove button: 26 to see, a 48 square to touch, partly outside
    // the cover.
    taps.clear();
    final remove = find.byKey(const Key('writing-cover-remove'));
    expect(tester.getSize(remove), const Size.square(26));
    expect(
      tester.getSize(find.byKey(const Key('writing-cover-remove-target'))),
      const Size.square(BvSize.touchMin),
    );
    await tapEach(tester, touchSquareEdges(tester, remove));
    expect(taps, ['remove', 'remove', 'remove', 'remove']);
  });
}
