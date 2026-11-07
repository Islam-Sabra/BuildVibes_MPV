// Review 126 P1, in English and Arabic: where someone works now comes from
// their current Experience entry only (no end month; the latest start if
// several). The profile header and a Space member row read it; with none,
// the headline or the trade shows, as before, with no company.
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/current_work.dart';
import 'package:buildvibes/data/models/people.dart';
import 'package:buildvibes/data/models/profile.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/spaces/people_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

const _space = 'space-1';

/// A text that holds both parts of a meta line ("title · company"); each
/// part keeps its own direction marks, so the parts are matched one by one.
Finder _line(String a, String b) => find.byWidgetPredicate((w) {
  final text = w is Text ? (w.data ?? w.textSpan?.toPlainText() ?? '') : '';
  return text.contains(a) && text.contains(b);
});

/// A Space member as the server sends them: the profile with its
/// current_work embed (a list of at most one row).
Map<String, dynamic> _row(String id, String first, {Object? work}) => {
  'id': id,
  'first_name': first,
  'last_name': 'Haddad',
  'headline': 'Project manager',
  'trade_id': 'site_engineer',
  'current_work': ?work,
};

void main() {
  group('CurrentWork from the server', () {
    test('the embed: a list of one row', () {
      final w = CurrentWork.fromJson([
        {'title': 'BIM Manager', 'company_id': null, 'company_name': 'IMAR'},
      ]);
      expect(w?.title, 'BIM Manager');
      expect(w?.companyName, 'IMAR');
      expect(w?.registered, isFalse);
    });

    test('space_key_people: one object; a registered company', () {
      final w = CurrentWork.fromJson({
        'title': 'QS',
        'company_id': 'c-1',
        'company_name': 'Harbour Contracting',
      });
      expect(w?.registered, isTrue);
    });

    test('none: an empty list or null', () {
      expect(CurrentWork.fromJson(const []), isNull);
      expect(CurrentWork.fromJson(null), isNull);
    });

    test('a Space person: the current title and company', () {
      final p = SpacePerson.fromJson(
        _row(
          'p-1',
          'Islam',
          work: [
            {
              'title': 'BIM Manager',
              'company_id': null,
              'company_name': 'IMAR Group',
            },
          ],
        ),
      );
      expect(p.roleLabel('en'), 'BIM Manager');
      expect(p.companyLabel, 'IMAR Group');
      expect(p.companyRegistered, isFalse);
    });

    test('a Space person with no current entry: the headline, no company', () {
      final p = SpacePerson.fromJson(_row('p-2', 'Omar', work: const []));
      expect(p.roleLabel('en'), 'Project manager');
      expect(p.companyLabel, isNull);
    });

    test('onboarding and the basics no longer write a company to profiles', () {
      final about = AboutYouInput(
        firstName: 'Omar',
        lastName: 'Haddad',
        homeMarketId: 'kw',
        role: RoleChoice.trade(testRolePicker.byId('site_engineer')!),
        locale: 'en',
        companyNameText: 'GCG',
      );
      expect(about.toProfileUpdate().keys, isNot(contains('company_id')));
      expect(
        about.toProfileUpdate().keys,
        isNot(contains('company_name_text')),
      );
      const basics = BasicsInput(
        firstName: 'Omar',
        lastName: 'Haddad',
        companyNameText: 'GCG',
      );
      expect(basics.toJson().keys, isNot(contains('company_id')));
      expect(basics.toJson().keys, isNot(contains('company_name_text')));
    });
  });

  for (final lang in ['en', 'ar']) {
    group('126 P1 [$lang]', () {
      testWidgets('the profile header: the current Experience entry, not '
          'the headline; an ended entry doesn\'t count', (tester) async {
        final app = await pumpApp(tester, language: lang);
        app.profiles.profiles['p-islam'] = const MyProfile(
          id: 'p-islam',
          firstName: 'Islam',
          lastName: 'Sabra',
          locale: 'en',
          tradeId: 'site_engineer',
          headline: 'Project manager',
          homeMarketId: 'kw',
        );
        app.pages.experience['p-islam'] = [
          ExperienceEntry(
            id: 'e-old',
            title: 'Site engineer',
            start: DateTime(2018),
            end: DateTime(2021),
            companyLabel: 'Past Co',
          ),
          ExperienceEntry(
            id: 'e-now',
            title: 'BIM Manager',
            start: DateTime(2022, 3),
            companyLabel: 'IMAR Group',
          ),
        ];
        GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        ).push('/people/p-islam');
        await tester.pumpAndSettle();
        expect(_line('BIM Manager', 'IMAR Group'), findsWidgets);
        expect(find.textContaining('Project manager'), findsNothing);
      });

      testWidgets('the basics: the headline field shows the current title; '
          'editing it renames the current entry (lead\'s check)', (
        tester,
      ) async {
        final app = await pumpApp(tester, language: lang);
        app.pages.headline['user-1'] = 'Project manager';
        app.pages.experience['user-1'] = [
          ExperienceEntry(
            id: 'e-now',
            title: 'BIM Manager',
            start: DateTime(2022, 3),
            companyLabel: 'IMAR Group',
          ),
        ];
        GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        ).push('/profile/edit/basics');
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: find.byKey(const Key('basics-headline')),
          matching: find.byType(TextField),
        );
        expect(tester.widget<TextField>(field).controller?.text, 'BIM Manager');
        await tester.enterText(field, 'BIM Lead');
        await tester.ensureVisible(find.byKey(const Key('basics-save')));
        await tester.tap(find.byKey(const Key('basics-save')));
        await tester.pumpAndSettle();
        final now = app.pages.experience['user-1']!.single;
        expect(now.title, 'BIM Lead');
        expect(now.companyLabel, 'IMAR Group');
      });

      testWidgets('the profile header with no Experience: the headline, no '
          'company', (tester) async {
        final app = await pumpApp(tester, language: lang);
        app.profiles.profiles['p-omar'] = const MyProfile(
          id: 'p-omar',
          firstName: 'Omar',
          lastName: 'Haddad',
          locale: 'en',
          tradeId: 'site_engineer',
          headline: 'Project manager',
          homeMarketId: 'kw',
        );
        GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        ).push('/people/p-omar');
        await tester.pumpAndSettle();
        expect(find.textContaining('Project manager'), findsWidgets);
        expect(_line('Project manager', '·'), findsNothing);
      });

      testWidgets('a Space member row: title · company from the current '
          'entry', (tester) async {
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
              person: SpacePerson.fromJson(
                _row(
                  'p-islam',
                  'Islam',
                  work: [
                    {
                      'title': 'BIM Manager',
                      'company_id': null,
                      'company_name': 'IMAR Group',
                    },
                  ],
                ),
              ),
              pass: SpacePass.crew,
              isAdmin: false,
              confirmedAt: testNow,
            ),
            SpaceMember(
              person: SpacePerson.fromJson(_row('p-omar', 'Omar')),
              pass: SpacePass.crew,
              isAdmin: false,
              confirmedAt: testNow,
            ),
          ],
        );
        await pumpApp(tester, language: lang, spaces: spaces);
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).push('/spaces/$_space/people');
        await tester.pumpAndSettle();
        // The row's "title · company" line (SP8): separate texts.
        Finder roleLine(String id) => find.descendant(
          of: find.byKey(Key('member-$id')),
          matching: find.byType(RoleCompanyLine),
        );
        Finder inLine(String id, String text) =>
            find.descendant(of: roleLine(id), matching: find.text(text));
        expect(inLine('p-islam', 'BIM Manager'), findsOneWidget);
        expect(inLine('p-islam', 'IMAR Group'), findsOneWidget);
        expect(inLine('p-islam', 'Project manager'), findsNothing);
        expect(inLine('p-omar', 'Project manager'), findsOneWidget);
        expect(inLine('p-omar', metaDot), findsNothing);
      });
    });
  }
}
