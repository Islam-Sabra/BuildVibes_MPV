import 'package:buildvibes/shared/widgets/bv_name_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

const _latin =
    'Method statement, sleeves and openings at level 2, grid C7, rev D.pdf';

Text _shown(WidgetTester tester) => tester.widget<Text>(
  find.descendant(of: find.byType(BvNameText), matching: find.byType(Text)),
);

void main() {
  testBoth('review 79 A4: a Latin file name keeps its own direction, so a '
      'long one is cut at its own end, on the line start side', (
    tester,
    lang,
  ) async {
    await pumpComponent(
      tester,
      const SizedBox(width: 200, child: BvNameText(_latin)),
      lang: lang,
    );
    final text = _shown(tester);
    expect(text.textDirection, TextDirection.ltr);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    // In Arabic it still sits on the right, the line's start.
    expect(text.textAlign, lang == 'ar' ? TextAlign.end : TextAlign.start);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(BvNameText),
        matching: find.byType(RichText),
      ),
    );
    expect(paragraph.textDirection, TextDirection.ltr);
    expect(paragraph.didExceedMaxLines, isTrue);
  });

  testBoth('an Arabic name stays right to left, at the start', (
    tester,
    lang,
  ) async {
    await pumpComponent(tester, const BvNameText('مخطط الأعمدة'), lang: lang);
    final text = _shown(tester);
    expect(text.textDirection, TextDirection.rtl);
    expect(text.textAlign, lang == 'ar' ? TextAlign.start : TextAlign.end);
  });
}
