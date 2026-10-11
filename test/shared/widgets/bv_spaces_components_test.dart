import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_badge.dart';
import 'package:buildvibes/shared/widgets/bv_bottom_bar.dart';
import 'package:buildvibes/shared/widgets/bv_code_tag.dart';
import 'package:buildvibes/shared/widgets/bv_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvCodeTag', () {
    testBoth('the code stays left to right in both languages', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvCodeTag(
          label: 'INVITE CODE',
          code: 'K7Q 4MD',
          note: 'Works until 18 Oct',
        ),
        lang: lang,
      );
      expect(find.text('INVITE CODE'), findsOneWidget);
      expect(find.text('Works until 18 Oct'), findsOneWidget);
      final code = tester.widget<Text>(find.byKey(const Key('code-tag-code')));
      expect(code.textDirection, TextDirection.ltr);
      expect(code.data, 'K7Q 4MD');
    });
  });

  group('BvBadge action tone', () {
    testBoth('solid fill with the light text', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvBadge(label: '1 needs you', tone: BvBadgeTone.action),
        lang: lang,
      );
      expect(textStyle(tester, '1 needs you').color, BvColors.textInverse);
      final box = tester.widget<Container>(
        find.ancestor(
          of: find.text('1 needs you'),
          matching: find.byType(Container),
        ),
      );
      expect((box.decoration! as BoxDecoration).color, BvColors.actionPrimary);
    });
  });

  group('BvListRow badge trailing', () {
    testBoth('a badge in place of the chevron', (tester, lang) async {
      await pumpComponent(
        tester,
        BvListRow(
          title: 'Tower B',
          trailing: const BvRowTrailing.badge(
            BvBadge(label: '2 needs you', tone: BvBadgeTone.action),
          ),
          onTap: () {},
        ),
        lang: lang,
      );
      expect(find.text('2 needs you'), findsOneWidget);
      expect(find.byIcon(BvIcons.caretForward), findsNothing);
    });
  });

  group('BvBottomBar without Create', () {
    testBoth('four tabs and no Create slot (Space tabs)', (tester, lang) async {
      var selected = 0;
      await pumpComponent(
        tester,
        StatefulBuilder(
          builder: (context, setState) => BvBottomBar(
            selectedIndex: selected,
            onSelect: (i) => setState(() => selected = i),
            items: const [
              BvBottomBarItem(
                key: Key('t-work'),
                icon: BvIcons.workItems,
                label: 'Work',
              ),
              BvBottomBarItem(
                key: Key('t-chat'),
                icon: BvIcons.chat,
                label: 'Chat',
              ),
              BvBottomBarItem(
                key: Key('t-people'),
                icon: BvIcons.people,
                label: 'People',
              ),
              BvBottomBarItem(
                key: Key('t-library'),
                icon: BvIcons.library,
                label: 'Library',
              ),
            ],
          ),
        ),
        lang: lang,
      );
      expect(find.byKey(const Key('nav-create-button')), findsNothing);
      await tester.tap(find.byKey(const Key('t-people')));
      await tester.pump();
      expect(selected, 2);
    });
  });
}
