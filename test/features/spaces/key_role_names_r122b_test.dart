// Review 122b, in English and Arabic: a key role's name is free. KP4's
// name field is a search ("Search for a role... for quick contact") that
// narrows the market pack's examples as you type, in either language and
// ignoring Arabic letter forms, and keeps whatever is typed.
import 'package:buildvibes/data/models/key_people.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/shared/widgets/bv_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/key_people_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

const _space = 'space-1';

FakeSpaceRepository _spaces() {
  final spaces = FakeSpaceRepository(now: testNow);
  spaces.details[_space] = const SpaceDetail(
    id: _space,
    name: 'NBKCH Site',
    myPass: SpacePass.lead,
    iAmAdmin: true,
    myRights: MemberRights(invite: true, createItems: true),
    marketId: 'kw',
  );
  spaces.spaces.add(
    const SpaceSummary(
      id: _space,
      name: 'NBKCH Site',
      pass: SpacePass.lead,
      isAdmin: true,
    ),
  );
  return spaces;
}

/// KP4 for a new role, from KP3.
Future<FakeKeyPeopleRepository> _newRole(
  WidgetTester tester,
  String lang,
) async {
  final keys = FakeKeyPeopleRepository()..spaces[_space] = const KeyPeople();
  await pumpApp(tester, language: lang, spaces: _spaces(), keyPeople: keys);
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/$_space/key-people');
  await tester.pumpAndSettle();
  await tester.tap(_key('key-people-add'));
  await tester.pumpAndSettle();
  return keys;
}

/// The suggestion chips on screen, by their label.
List<String> _chips(WidgetTester tester) => [
  for (final c in tester.widgetList<BvChip>(find.byType(BvChip))) c.label,
];

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_key('key-role-name'), text);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(_key('key-role-save'));
  await tester.pumpAndSettle();
  await tester.tap(_key('key-role-save'));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    String t(String en, String ar) => lang == 'ar' ? ar : en;
    final safety = t('Safety officer', 'ضابط السلامة');

    group('122b role names are free [$lang]', () {
      testWidgets('the empty name field shows the search hint', (tester) async {
        await _newRole(tester, lang);
        expect(
          find.descendant(
            of: _key('key-role-name'),
            matching: find.text(
              t(
                'Search for a role... for quick contact',
                'ابحث عن دور... للتواصل السريع',
              ),
            ),
          ),
          findsOneWidget,
        );
        // Every example still shows while nothing is typed.
        expect(_chips(tester), hasLength(5));
      });

      testWidgets('a new role opens with the keyboard on the name', (
        tester,
      ) async {
        await _newRole(tester, lang);
        final field = tester.widget<EditableText>(
          find.descendant(
            of: _key('key-role-name'),
            matching: find.byType(EditableText),
          ),
        );
        expect(field.focusNode.hasFocus, isTrue);
      });

      testWidgets('«سلا» narrows the examples to the Safety officer', (
        tester,
      ) async {
        await _newRole(tester, lang);
        await _type(tester, 'سلا');
        expect(_chips(tester), [safety]);
      });

      testWidgets('matches in the other language too', (tester) async {
        await _newRole(tester, lang);
        await _type(tester, 'SAFE');
        expect(_chips(tester), [safety]);
      });

      testWidgets('ignores the forms of alef: «امين» finds «أمين المخزن»', (
        tester,
      ) async {
        await _newRole(tester, lang);
        await _type(tester, 'امين');
        expect(_chips(tester), [t('Storekeeper', 'أمين المخزن')]);
      });

      testWidgets('a role that isn\'t an example: no chips, saved as typed, '
          'shown as typed', (tester) async {
        final keys = await _newRole(tester, lang);
        await _type(tester, 'مشغّل رافعة');
        expect(_chips(tester), isEmpty);
        keys.spaces[_space] = const KeyPeople(
          roles: [KeyRole(id: 'r-crane', name: 'مشغّل رافعة')],
        );
        await _save(tester);
        expect(keys.saved.single.name, 'مشغّل رافعة');
        expect(find.textContaining('مشغّل رافعة'), findsOneWidget);
      });

      testWidgets('an English role that isn\'t an example saves as typed', (
        tester,
      ) async {
        final keys = await _newRole(tester, lang);
        await _type(tester, 'Crane operator');
        expect(_chips(tester), isEmpty);
        await _save(tester);
        expect(keys.saved.single.name, 'Crane operator');
      });

      testWidgets('a chip fills the field; an edit after it is what saves', (
        tester,
      ) async {
        final keys = await _newRole(tester, lang);
        await tester.tap(find.widgetWithText(BvChip, safety));
        await tester.pumpAndSettle();
        expect(
          tester.widget<BvChip>(find.widgetWithText(BvChip, safety)).selected,
          isTrue,
        );
        final edited = '$safety ${t('(night)', '(ليلي)')}';
        await _type(tester, edited);
        // Something else typed: the chip is off.
        expect(
          tester
              .widgetList<BvChip>(find.byType(BvChip))
              .where((c) => c.selected),
          isEmpty,
        );
        await _save(tester);
        expect(keys.saved.single.name, edited);
      });
    });
  }
}
