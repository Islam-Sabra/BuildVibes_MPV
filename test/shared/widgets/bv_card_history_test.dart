import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_paper_specs.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
import 'package:buildvibes/shared/widgets/bv_card_history.dart';
import 'package:buildvibes/shared/widgets/bv_trace_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  const lines = [
    BvHistoryLine(
      id: 'a',
      name: 'Omar Haddad',
      lead: 'Omar Haddad:',
      detail: 'Sleeves arrived.',
      time: (time: '09:05', period: null),
      tint: BvAvatarTints.green,
    ),
    BvHistoryLine(
      id: 'b',
      name: 'Islam Ahmed',
      lead: 'You checked it',
      time: (time: '10:58', period: null),
    ),
  ];

  group('BvCardHistory', () {
    testBoth('a thin line on the leading side, one line per event with its '
        'face and time, oldest first', (tester, lang) async {
      await pumpComponent(
        tester,
        BvCardHistory(lines: lines, lineKey: (id) => Key('line-$id')),
        lang: lang,
      );
      final box = tester.widget<DecoratedBox>(
        find.byKey(const Key('card-history')),
      );
      final border =
          (box.decoration as BoxDecoration).border! as BorderDirectional;
      expect(border.start.width, BvCardHistorySpec.rule);
      expect(border.end, BorderSide.none);
      expect(find.byType(BvAvatar), findsNWidgets(2));
      expect(
        tester.getSize(find.byType(BvAvatar).first),
        const Size.square(BvAvatarSpec.note),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('line-a'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('line-b'))).dy),
      );
      // The time is at the end of its line.
      final line = tester.getRect(find.byKey(const Key('line-a')));
      final time = tester.getRect(find.text('09:05'));
      expect(
        isRtl(lang) ? time.left - line.left : line.right - time.right,
        moreOrLessEquals(0, epsilon: 0.5),
      );
      expect(textStyle(tester, '09:05').color, BvColors.textSecondary);
      expect(find.byKey(const Key('card-history-earlier')), findsNothing);
    });

    testBoth('Show earlier sits above the lines and calls back', (
      tester,
      lang,
    ) async {
      var taps = 0;
      await pumpComponent(
        tester,
        BvCardHistory(
          lines: lines,
          earlierLabel: 'Show earlier',
          onEarlier: () => taps++,
        ),
        lang: lang,
      );
      expect(
        tester.getTopLeft(find.text('Show earlier')).dy,
        lessThan(tester.getTopLeft(find.text('09:05')).dy),
      );
      expect(textStyle(tester, 'Show earlier').color, BvColors.textAction);
      await tester.tap(find.text('Show earlier'));
      expect(taps, 1);
    });
  });

  group('BvTraceRow', () {
    testBoth('one quiet line on the subtle surface: face, words, time, '
        'and the caret at the end', (tester, lang) async {
      var taps = 0;
      await pumpComponent(
        tester,
        BvTraceRow(
          key: const Key('trace'),
          name: 'Omar Haddad',
          text: 'Omar Haddad added an update · Sleeves at grid C7',
          time: '16:07',
          onTap: () => taps++,
        ),
        lang: lang,
      );
      final row = tester.getRect(find.byKey(const Key('trace')));
      expect(row.height, greaterThanOrEqualTo(BvTraceSpec.minHeight));
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('trace')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((box.decoration! as BoxDecoration).color, BvColors.surfaceSubtle);
      final text = tester.widget<Text>(
        find.text('Omar Haddad added an update · Sleeves at grid C7'),
      );
      expect(text.maxLines, 1);
      final caret = tester.getCenter(find.byType(Icon)).dx;
      final time = tester.getCenter(find.text('16:07')).dx;
      expect(isRtl(lang) ? caret < time : caret > time, isTrue);
      await tester.tap(find.byKey(const Key('trace')));
      expect(taps, 1);
    });
  });
}
