// Review 122c, in English and Arabic: one short line, no explanations.
// KP0 is one row, TM0 one short line, KP3 has no intro or footnote, and
// KP4's first field has no label (its hint says it).
import 'package:buildvibes/data/models/company_teams.dart';
import 'package:buildvibes/data/models/key_people.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/key_people_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

const _space = 'space-1';

const _khalid = SpacePerson(
  id: 'p-khalid',
  firstName: 'Khalid',
  lastName: 'Al-Mansour',
);

FakeSpaceRepository _spaces({CompanyTeamPreview? preview}) {
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
  spaces.spacePeople[_space] = SpacePeople(
    members: [
      SpaceMember(
        person: const SpacePerson(id: 'user-1', firstName: 'Me', lastName: 'T'),
        pass: SpacePass.lead,
        isAdmin: true,
        confirmedAt: testNow,
      ),
    ],
  );
  if (preview != null) spaces.previews[_space] = preview;
  return spaces;
}

Future<void> _go(
  WidgetTester tester,
  String lang,
  String path, {
  CompanyTeamPreview? preview,
  KeyPeople who = const KeyPeople(),
}) async {
  await pumpApp(
    tester,
    language: lang,
    spaces: _spaces(preview: preview),
    keyPeople: FakeKeyPeopleRepository()..spaces[_space] = who,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    String t(String en, String ar) => lang == 'ar' ? ar : en;

    group('122c short text [$lang]', () {
      testWidgets('KP0 is one line: the title and the caret, no description', (
        tester,
      ) async {
        await _go(tester, lang, '/spaces/$_space/people');
        final card = _key('kp0-set-who-to-call');
        final texts = tester
            .widgetList<Text>(
              find.descendant(of: card, matching: find.byType(Text)),
            )
            .map((w) => w.data)
            .toList();
        expect(texts, [t('Set who to call', 'حدّد بمن يتصل الناس')]);
        expect(
          find.textContaining(
            t('they show on top of People', 'يظهرون أعلى الأشخاص'),
          ),
          findsNothing,
        );
      });

      testWidgets('TM0 is one short line', (tester) async {
        await _go(
          tester,
          lang,
          '/spaces/$_space/people',
          preview: const CompanyTeamPreview(),
        );
        await tester.tap(_key('people-view-teams'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: _key('teams-company-hint'),
            matching: find.text(
              t(
                'Teams from companies need 2 people with the same company.',
                'فرق الشركات تحتاج شخصين من نفس الشركة.',
              ),
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('KP3: no intro on top, no note at the bottom; the '
          'no-number line stays', (tester) async {
        await _go(
          tester,
          lang,
          '/spaces/$_space/key-people',
          who: const KeyPeople(
            roles: [
              KeyRole(
                id: 'r-safety',
                name: 'Safety officer',
                holders: [KeyHolder(person: _khalid)],
              ),
            ],
          ),
        );
        expect(
          find.textContaining(
            t('People everyone here should know', 'أشخاص يجب أن يعرفهم'),
          ),
          findsNothing,
        );
        expect(
          find.textContaining(
            t('Only the Space admin changes key people', 'مدير المساحة وحده'),
          ),
          findsNothing,
        );
        expect(
          find.text(
            t('No number shared · Message only', 'لم يشارك رقمه · رسالة فقط'),
          ),
          findsOneWidget,
        );
        expect(_key('key-people-add'), findsOneWidget);
      });

      testWidgets('KP4: no "Role name" label; "Call them for" stays', (
        tester,
      ) async {
        await _go(tester, lang, '/spaces/$_space/key-people');
        await tester.tap(_key('key-people-add'));
        await tester.pumpAndSettle();
        expect(find.text(t('Role name', 'اسم الدور')), findsNothing);
        expect(
          find.text(t('Call them for', 'اتصل بهم من أجل')),
          findsOneWidget,
        );
      });
    });
  }
}
