// Review 111: TM1 to TM5, in English and Arabic at 390 × 844 in the app's
// fonts. TM1b is the one line for a single company. Run:
//   flutter test test_screens/r111_test.dart --update-goldens
import 'package:buildvibes/data/models/company_teams.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/spaces/who_sees_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r111/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String k) async {
  await tester.tap(_key(k));
  await tester.pumpAndSettle();
}

const _space = 'space-1';

SpaceMember _m(
  String id,
  String first,
  String last,
  String role, {
  SpacePass pass = SpacePass.crew,
  String company = 'Gulf MEP',
}) => SpaceMember(
  person: SpacePerson(
    id: id,
    firstName: first,
    lastName: last,
    headline: role,
    companyLabel: company,
  ),
  pass: pass,
  isAdmin: id == 'user-1',
  confirmedAt: testNow,
);

CompanyPerson _c(String id, String name, [SpacePass p = SpacePass.crew]) =>
    CompanyPerson(id: id, name: name, pass: p);

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    String t(String en, String ar) => lang == 'ar' ? ar : en;
    final omar = t('Omar Haddad', 'عمر حداد');
    final khalid = t('Khalid Al-Mansour', 'خالد المنصور');
    final rakesh = t('Rakesh Nair', 'راكيش ناير');

    final civil = SpaceTeam(
      id: 't-civil',
      name: 'Civil',
      memberIds: const {'p-omar'},
      adminId: 'p-omar',
      adminName: omar,
    );
    final night = SpaceTeam(
      id: 't-night',
      name: t('Night shift', 'الوردية الليلية'),
      memberIds: const {'p-khalid'},
      adminId: 'p-khalid',
      adminName: khalid,
    );
    final gulf = SpaceTeam(
      id: 't-gulf',
      name: 'Gulf MEP',
      memberIds: const {'p-rakesh', 'p-ali', 'p-joseph', 'p-hassan'},
      adminId: 'p-rakesh',
      adminName: rakesh,
    );

    final companies = CompanyTeamPreview(
      groups: [
        CompanyGroup(
          key: 'abc',
          name: 'ABC Contracting',
          adminId: 'a1',
          people: [
            _c('a1', omar, SpacePass.lead),
            for (var i = 2; i <= 6; i++) _c('a$i', 'Person $i'),
          ],
        ),
        CompanyGroup(
          key: 'a.b.c',
          name: 'A.B.C Contracting',
          people: [_c('b1', 'Person 7'), _c('b2', 'Person 8')],
        ),
        CompanyGroup(
          key: 'gulf',
          name: 'Gulf MEP',
          adminId: 'g1',
          people: [
            _c('g1', rakesh, SpacePass.lead),
            for (var i = 2; i <= 4; i++) _c('g$i', 'Person $i'),
          ],
        ),
        CompanyGroup(
          key: 'delta',
          name: 'Delta Steel',
          adminId: 'd1',
          people: [
            _c('d1', khalid, SpacePass.lead),
            for (var i = 2; i <= 5; i++) _c('d$i', 'Person $i'),
          ],
        ),
      ],
      similar: const [(a: 'abc', b: 'a.b.c')],
      noCompany: [for (var i = 1; i <= 3; i++) _c('n$i', 'Person $i')],
    );

    FakeSpaceRepository spaces({
      CompanyTeamPreview? preview,
      List<SpaceJoinRequest> requests = const [],
    }) {
      final repo = FakeSpaceRepository(now: testNow);
      repo.details[_space] = const SpaceDetail(
        id: _space,
        name: 'NBKCH Site',
        myPass: SpacePass.lead,
        iAmAdmin: true,
        myRights: MemberRights(invite: true, createItems: true),
      );
      repo.spacePeople[_space] = SpacePeople(
        requests: requests,
        members: [
          _m('user-1', 'Islam', 'Sabra', 'BIM Manager', pass: SpacePass.lead),
          _m(
            'p-omar',
            t('Omar', 'عمر'),
            t('Haddad', 'حداد'),
            t('Site engineer', 'مهندس موقع'),
            company: 'ABC Contracting',
          ),
          _m(
            'p-khalid',
            t('Khalid', 'خالد'),
            t('Al-Mansour', 'المنصور'),
            t('Foreman', 'مراقب عمال'),
            company: 'Delta Steel',
          ),
          _m(
            'p-rakesh',
            t('Rakesh', 'راكيش'),
            t('Nair', 'ناير'),
            t('MEP engineer', 'مهندس ميكانيكا وكهرباء'),
          ),
          _m(
            'p-ali',
            t('Ali', 'علي'),
            t('Saleh', 'صالح'),
            t('Electrician', 'كهربائي'),
          ),
          _m(
            'p-joseph',
            t('Joseph', 'جوزيف'),
            t('Mathew', 'ماثيو'),
            t('Plumber', 'سبّاك'),
          ),
          _m(
            'p-hassan',
            t('Hassan', 'حسن'),
            t('Kamal', 'كمال'),
            t('Foreman', 'مراقب عمال'),
          ),
        ],
        teams: [civil, night, gulf],
      );
      if (preview != null) repo.previews[_space] = preview;
      return repo;
    }

    Future<void> go(
      WidgetTester tester,
      FakeSpaceRepository repo,
      String path,
    ) async {
      tester.view.physicalSize = shotSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(tester, language: lang, spaces: repo);
      GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
      await tester.pumpAndSettle();
    }

    testWidgets('TM1 [$lang]', (tester) async {
      await go(tester, spaces(preview: companies), '/spaces/$_space/people');
      await _tap(tester, 'people-view-teams');
      await _snap(tester, 'tm1', lang);
    });

    testWidgets('TM1b, the one line [$lang]', (tester) async {
      await go(
        tester,
        spaces(
          preview: CompanyTeamPreview(
            groups: [
              CompanyGroup(
                key: 'delta',
                name: 'Delta Steel',
                people: [_c('1', 'A'), _c('2', 'B')],
              ),
            ],
          ),
        ),
        '/spaces/$_space/people',
      );
      await _tap(tester, 'people-view-teams');
      await _snap(tester, 'tm1b', lang);
    });

    testWidgets('TM2 [$lang]', (tester) async {
      await go(tester, spaces(preview: companies), '/spaces/$_space/people');
      await _tap(tester, 'people-view-teams');
      await _tap(tester, 'teams-make-card');
      await _snap(tester, 'tm2', lang);
    });

    testWidgets('TM3 [$lang]', (tester) async {
      await go(tester, spaces(), '/spaces/$_space/teams/t-gulf');
      await _snap(tester, 'tm3', lang);
    });

    testWidgets('TM4 [$lang]', (tester) async {
      final repo = spaces(
        requests: [
          SpaceJoinRequest(
            id: 'req-1',
            createdAt: testNow,
            person: SpacePerson(
              id: 'p-nabil',
              firstName: t('Nabil', 'نبيل'),
              lastName: t('Mansour', 'منصور'),
              headline: t('Electrician', 'كهربائي'),
              companyLabel: 'Gulf MEP',
            ),
          ),
        ],
      );
      repo.companyMatches['p-nabil'] = const CompanyTeamMatch(
        teamId: 't-gulf',
        teamName: 'Gulf MEP',
        company: 'Gulf MEP',
      );
      await go(tester, repo, '/spaces/$_space/people');
      await _tap(tester, 'request-let-in-req-1');
      await _snap(tester, 'tm4', lang);
    });

    testWidgets('TM5 [$lang]', (tester) async {
      final repo = spaces();
      await go(tester, repo, '/spaces/$_space/people');
      // ignore: unawaited_futures
      pickWhoSees(
        tester.element(find.byKey(const Key('space-people'))),
        people: repo.spacePeople[_space]!,
        me: 'p-rakesh',
        spaceAdmin: false,
        chosen: 't-gulf',
      );
      await tester.pumpAndSettle();
      await _snap(tester, 'tm5', lang);
    });
  }
}
