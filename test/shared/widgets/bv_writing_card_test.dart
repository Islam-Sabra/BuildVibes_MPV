import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_writing_specs.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
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
}
