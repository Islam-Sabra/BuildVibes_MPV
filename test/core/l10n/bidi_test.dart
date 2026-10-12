import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

/// x of [part]'s first character when [text] is laid out right to left.
double _xOf(String text, String part) {
  final painter = TextPainter(
    text: TextSpan(text: text),
    textDirection: TextDirection.rtl,
  )..layout(maxWidth: 4000);
  return painter
      .getOffsetForCaret(TextPosition(offset: text.indexOf(part)), Rect.zero)
      .dx;
}

void main() {
  test('a phone number stays in order inside an Arabic sentence', () {
    final sentence = 'أرسلنا رمزاً إلى ${ltrRun('+965 5000 0001')} عبر واتساب';
    // Left to right on screen: "+965", then "0001".
    expect(_xOf(sentence, '+'), lessThan(_xOf(sentence, '0001')));
    final unmarked = 'أرسلنا رمزاً إلى +965 5000 0001 عبر واتساب';
    expect(_xOf(unmarked, '+'), greaterThan(_xOf(unmarked, '0001')));
  });

  test('a meta line keeps each part in its own direction', () {
    final line = joinMeta(['أخصائي BIM', 'Gulf Build Co.', '']);
    expect(line.contains('Gulf Build Co.'), isTrue);
    expect(' · '.allMatches(line).length, 1, reason: 'empty parts dropped');
    expect(line.codeUnitAt(0), 0x2067, reason: 'Arabic part: an RTL isolate');
  });

  test('review 20: English values in an Arabic sentence keep their places', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    // "بند جديد KCT-005 من Omar Haddad: Gate 3", read from the right.
    final line = ar.todayItem(
      'raised',
      inOwnDirection('Omar Haddad'),
      ltrRun('KCT-005'),
      inOwnDirection('Gate 3'),
    );
    expect(_xOf(line, 'KCT'), greaterThan(_xOf(line, 'Omar')));
    expect(_xOf(line, 'Omar'), greaterThan(_xOf(line, 'Gate')));
    // With the old embedding marks the name and the title ran together
    // as one English run: the title came first, at the right.
    String embed(String t) => '\u202A$t\u202C';
    final old = ar.todayItem(
      'raised',
      embed('Omar Haddad'),
      embed('KCT-005'),
      embed('Gate 3'),
    );
    expect(_xOf(old, 'Omar'), lessThan(_xOf(old, 'Gate')));
  });

  testBoth(
    'a Latin value in a field reads left to right, aligned to the form',
    (tester, lang) async {
      final controller = TextEditingController(text: 'Gulf Build Co.');
      addTearDown(controller.dispose);
      await pumpComponent(
        tester,
        BvTextField(controller: controller),
        lang: lang,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, TextDirection.ltr);
      expect(field.textAlign, isRtl(lang) ? TextAlign.right : TextAlign.left);
      controller.text = 'شركة النور';
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).textDirection,
        TextDirection.rtl,
      );
    },
  );
}
