import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_writing_specs.dart';
import 'package:buildvibes/shared/widgets/bv_popover_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

enum _Kind { workItem, checklist, announcement }

const _kinds = [
  BvMenuItem(
    value: _Kind.workItem,
    label: 'Work item',
    icon: BvIcons.confirmed,
  ),
  BvMenuItem(
    value: _Kind.checklist,
    label: 'Checklist',
    icon: BvIcons.workItems,
  ),
  BvMenuItem(
    value: _Kind.announcement,
    label: 'Announcement',
    icon: BvIcons.info,
  ),
];

const _proof = [
  BvSlipMenuItem(
    value: 'check',
    label: 'Check',
    icon: BvIcons.check,
    tone: BvSlipMenuTone.positive,
  ),
  BvSlipMenuItem(
    value: 'back',
    label: 'Send back',
    icon: BvIcons.sendBack,
    tone: BvSlipMenuTone.destructive,
  ),
  BvSlipMenuItem(value: 'chat', label: 'Discuss in chat', icon: BvIcons.chat),
];

Size _row(WidgetTester tester, String text) => tester.getSize(
  find.ancestor(of: find.text(text), matching: find.byType(InkWell)),
);

void main() {
  testBoth('more menu: leading icons, 42 rows, picks a row', (
    tester,
    lang,
  ) async {
    String? picked;
    await pumpComponent(
      tester,
      BvPopoverMenu<String>.more(
        items: const [
          BvMenuItem(value: 'assign', label: 'Assign', icon: BvIcons.person),
          BvMenuItem(value: 'place', label: 'Location', icon: BvIcons.place),
        ],
        onSelected: (v) => picked = v,
      ),
      lang: lang,
    );
    expect(
      tester.getSize(find.byType(BvPopoverMenu<String>)).width,
      BvPopoverMenuSpec.widthMore,
    );
    expect(_row(tester, 'Assign').height, BvPopoverMenuSpec.rowHeight);
    final icon = tester.getCenter(find.byIcon(BvIcons.person)).dx;
    final label = tester.getCenter(find.text('Assign')).dx;
    expect(isRtl(lang) ? icon > label : icon < label, isTrue);
    await tester.tap(find.text('Location'));
    expect(picked, 'place');
    expect(find.byIcon(BvIcons.check), findsNothing);
  });

  testBoth('kind picker: one selected row, orange with a check', (
    tester,
    lang,
  ) async {
    var kind = _Kind.workItem;
    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (context, setState) => BvPopoverMenu<_Kind>.picker(
          items: _kinds,
          selected: kind,
          onSelected: (v) => setState(() => kind = v),
        ),
      ),
      lang: lang,
    );
    expect(
      tester.getSize(find.byType(BvPopoverMenu<_Kind>)).width,
      BvPopoverMenuSpec.widthPicker,
    );
    expect(textStyle(tester, 'Work item').color, BvColors.textAction);
    expect(textStyle(tester, 'Checklist').color, BvColors.textPrimary);
    expect(find.byIcon(BvIcons.check), findsOneWidget);
    // The check is at the end: on the left in Arabic.
    final check = tester.getCenter(find.byIcon(BvIcons.check)).dx;
    final label = tester.getCenter(find.text('Work item')).dx;
    expect(isRtl(lang) ? check < label : check > label, isTrue);

    await tester.tap(find.text('Checklist'));
    await tester.pump();
    expect(kind, _Kind.checklist);
    expect(textStyle(tester, 'Work item').color, BvColors.textPrimary);
    expect(textStyle(tester, 'Checklist').color, BvColors.textAction);
    expect(find.byIcon(BvIcons.check), findsOneWidget);
  });

  testBoth('slip menu: trailing icons, tones, dividers but the last', (
    tester,
    lang,
  ) async {
    String? picked;
    await pumpComponent(
      tester,
      BvSlipMenu<String>(items: _proof, onSelected: (v) => picked = v),
      lang: lang,
    );
    expect(textStyle(tester, 'Check').color, BvColors.textPositive);
    expect(textStyle(tester, 'Send back').color, BvColors.textDestructive);
    expect(textStyle(tester, 'Discuss in chat').color, BvColors.textPrimary);

    // The icon is at the end: on the left in Arabic.
    final icon = tester.getCenter(find.byIcon(BvIcons.check)).dx;
    final label = tester.getCenter(find.text('Check')).dx;
    expect(isRtl(lang) ? icon < label : icon > label, isTrue);

    BoxDecoration? line(String text) =>
        tester
                .widget<Container>(
                  find
                      .ancestor(
                        of: find.text(text),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration?;
    expect(
      (line('Check')!.border! as Border).bottom.color,
      BvColors.borderSubtle,
    );
    expect(line('Discuss in chat'), isNull);

    await tester.tap(find.text('Send back'));
    expect(picked, 'back');
  });

  Future<void> openLifted(
    WidgetTester tester,
    String lang,
    Rect anchor,
    ValueChanged<String?> onClosed,
  ) async {
    await pumpComponent(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => onClosed(
            await showBvLifted<String>(
              context,
              anchor: anchor,
              lifted: const ColoredBox(
                key: Key('lifted'),
                color: BvColors.surfaceElevated,
              ),
              popover: (context) => BvSlipMenu<String>(
                items: _proof,
                onSelected: (v) => Navigator.pop(context, v),
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
      lang: lang,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testBoth('lifted: the menu sits under the slip, at its end', (
    tester,
    lang,
  ) async {
    const anchor = Rect.fromLTWH(64, 200, 310, 180);
    String? result = 'unset';
    await openLifted(tester, lang, anchor, (v) => result = v);
    expect(tester.getRect(find.byKey(const Key('lifted'))), anchor);
    expect(find.byType(BvDim), findsOneWidget);
    final menu = tester.getRect(find.byType(BvSlipMenu<String>));
    expect(menu.top, anchor.bottom + BvSlipMenuSpec.anchorGap);
    if (isRtl(lang)) {
      expect(menu.left, anchor.left);
    } else {
      expect(menu.right, anchor.right);
    }

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(result, 'check');
  });

  testBoth('lifted: over the slip when there is no room; the dim closes', (
    tester,
    lang,
  ) async {
    const anchor = Rect.fromLTWH(64, 600, 310, 180);
    String? result = 'unset';
    await openLifted(tester, lang, anchor, (v) => result = v);
    final menu = tester.getRect(find.byType(BvSlipMenu<String>));
    expect(menu.bottom, anchor.top - BvSlipMenuSpec.anchorGap);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(BvDim), findsNothing);
  });
}
