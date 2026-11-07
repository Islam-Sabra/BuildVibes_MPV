// Review 122e, in English and Arabic: no example or sample text inside a
// field, and no help line that gives one (the rule from review 122d).
// Labels stay; a search keeps a plain hint with no example in it.
import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/pump_app.dart';

Map<String, String> _texts(String lang) {
  final json =
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final e in json.entries)
      if (!e.key.startsWith('@') && e.value is String)
        e.key: e.value as String,
  };
}

/// "e.g.", "for example", "such as"; «مثال», «مثلًا», «مثل».
final _example = {
  'en': RegExp(r'e\.g\.|for example|such as', caseSensitive: false),
  'ar': RegExp('مثال|مثل'),
};

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    String t(String en, String ar) => lang == 'ar' ? ar : en;

    group('122e no examples [$lang]', () {
      test('no text in the app gives an example', () {
        final found = [
          for (final e in _texts(lang).entries)
            if (_example[lang]!.hasMatch(e.value)) e.key,
        ];
        expect(found, isEmpty);
      });

      test('the Space search keeps a plain hint; the KP4 note field says '
          'Note; a wrong number says to check it, with no sample', () {
        expect(
          l10n.searchHint,
          t('Search words or a number', 'ابحث بكلمة أو رقم'),
        );
        expect(l10n.keyRoleNoteHint, t('Note', 'ملاحظة'));
        expect(l10n.phoneCheck, t('Check the number.', 'تحقّق من الرقم.'));
      });

      Future<BvTextField> field(
        WidgetTester tester,
        String path,
        String key,
      ) async {
        await pumpApp(tester, language: lang);
        GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
        await tester.pumpAndSettle();
        return tester.widget<BvTextField>(find.byKey(Key(key)));
      }

      testWidgets('New Space: the name field has its label, nothing inside', (
        tester,
      ) async {
        final f = await field(tester, '/spaces/new', 'space-name');
        expect(f.label, isNotNull);
        expect(f.placeholder, isNull);
      });

      testWidgets('the basics: the headline has nothing inside', (
        tester,
      ) async {
        final f = await field(
          tester,
          '/profile/edit/basics',
          'basics-headline',
        );
        expect(f.placeholder, isNull);
      });

      testWidgets('my phone number: no sample number inside', (tester) async {
        final f = await field(tester, '/profile/edit/phone', 'phone-field');
        expect(f.placeholder, isNull);
      });
    });
  }
}
