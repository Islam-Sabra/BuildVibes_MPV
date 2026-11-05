// Review 121: KP1, OC1, KP2, KP3, KP4 and NUM1, in English and Arabic at
// 390 × 844 in the app's fonts, with the frames' people. Run:
//   flutter test test_screens/r121_test.dart --update-goldens
import 'package:buildvibes/data/models/key_people.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/key_people_fakes.dart';
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
      matchesGoldenFile('../docs/screens/r121/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String k) async {
  await tester.ensureVisible(_key(k).first);
  await tester.pumpAndSettle();
  await tester.tap(_key(k).first);
  await tester.pumpAndSettle();
}

const _space = 'space-1';

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    String t(String en, String ar) => lang == 'ar' ? ar : en;

    SpacePerson p(
      String id,
      String first,
      String last,
      String role,
      String co,
    ) => SpacePerson(
      id: id,
      firstName: first,
      lastName: last,
      headline: role,
      companyLabel: co,
    );

    final islam = p(
      'p-islam',
      t('Islam', 'إسلام'),
      t('Sabra', 'صبرة'),
      t('BIM manager', 'مدير BIM'),
      'AECOX',
    );
    final khalid = p(
      'p-khalid',
      t('Khalid', 'خالد'),
      t('Al-Mansour', 'المنصور'),
      t('Safety', 'السلامة'),
      'NBKCH',
    );
    final tariq = p(
      'p-tariq',
      t('Tariq', 'طارق'),
      t('Rahman', 'رحمن'),
      t('Safety', 'السلامة'),
      'NBKCH',
    );
    final omar = p(
      'p-omar',
      t('Omar', 'عمر'),
      t('Haddad', 'حداد'),
      t('Project engineer', 'مهندس المشروع'),
      'NBKCH',
    );
    final rakesh = p(
      'p-rakesh',
      t('Rakesh', 'راكيش'),
      t('Nair', 'ناير'),
      t('MEP engineer', 'مهندس MEP'),
      'Gulf MEP',
    );
    final ali = p(
      'p-ali',
      t('Ali', 'علي'),
      t('Saleh', 'صالح'),
      t('Electrician', 'كهربائي'),
      'Gulf MEP',
    );
    final hassan = p(
      'p-hassan',
      t('Hassan', 'حسن'),
      t('Karim', 'كريم'),
      t('Foreman', 'مراقب عمال'),
      'Gulf MEP',
    );
    final joseph = p(
      'p-joseph',
      t('Joseph', 'جوزيف'),
      t('Mathew', 'ماثيو'),
      t('Plumber', 'سبّاك'),
      'Gulf MEP',
    );
    final mona = p(
      'p-mona',
      t('Mona', 'منى'),
      t('Adel', 'عادل'),
      t('Surveyor', 'مسّاح'),
      'NBKCH',
    );
    final sami = p(
      'p-sami',
      t('Sami', 'سامي'),
      t('Youssef', 'يوسف'),
      t('Carpenter', 'نجّار'),
      'NBKCH',
    );

    SpaceMember m(SpacePerson person, {bool admin = false}) => SpaceMember(
      person: person,
      pass: admin ? SpacePass.lead : SpacePass.crew,
      isAdmin: admin,
      confirmedAt: testNow,
    );

    final teams = [
      SpaceTeam(
        id: 't-civil',
        name: t('Civil', 'المدني'),
        memberIds: {omar.id, hassan.id, mona.id, sami.id},
        adminId: omar.id,
        adminName: omar.fullName,
      ),
      SpaceTeam(
        id: 't-gulf',
        name: 'Gulf MEP',
        memberIds: {rakesh.id, ali.id, joseph.id, hassan.id},
        adminId: rakesh.id,
        adminName: rakesh.fullName,
      ),
      SpaceTeam(
        id: 't-night',
        name: t('Night shift', 'الوردية الليلية'),
        memberIds: {khalid.id, tariq.id, ali.id, hassan.id, mona.id},
        adminId: khalid.id,
        adminName: khalid.fullName,
      ),
    ];

    final callFor = t(
      'hazards, accidents, work permits',
      'المخاطر والحوادث وأذونات العمل',
    );
    final engineerFor = t(
      'drawings, method statements, site changes',
      'المخططات وطرق التنفيذ وتغييرات الموقع',
    );

    KeyPeople who({bool seen = true, bool both = false}) => KeyPeople(
      seen: seen,
      roles: [
        KeyRole(
          id: 'r-safety',
          name: t('Safety officer', 'ضابط السلامة'),
          callFor: callFor,
          holders: [
            KeyHolder(
              person: khalid,
              note: t('Day shift', 'الوردية الصباحية'),
              canCall: true,
            ),
            if (both)
              KeyHolder(
                person: tariq,
                note: t('Night shift', 'الوردية الليلية'),
              ),
          ],
        ),
        KeyRole(
          id: 'r-engineer',
          name: t('Project engineer', 'مهندس المشروع'),
          callFor: engineerFor,
          holders: [KeyHolder(person: omar)],
        ),
      ],
    );

    FakeSpaceRepository spaces({bool admin = false}) {
      final repo = FakeSpaceRepository(now: testNow);
      repo.details[_space] = SpaceDetail(
        id: _space,
        name: 'NBKCH Site',
        myPass: admin ? SpacePass.lead : SpacePass.crew,
        iAmAdmin: admin,
        myRights: MemberRights(invite: admin, createItems: admin),
        marketId: 'kw',
      );
      repo.spaces.add(
        SpaceSummary(
          id: _space,
          name: 'NBKCH Site',
          pass: admin ? SpacePass.lead : SpacePass.crew,
          isAdmin: admin,
        ),
      );
      repo.spacePeople[_space] = SpacePeople(
        members: [
          m(islam, admin: true),
          m(rakesh),
          m(ali),
          m(khalid),
          m(omar),
          m(tariq),
          m(hassan),
          m(joseph),
          m(mona),
          m(sami),
        ],
        teams: teams,
      );
      return repo;
    }

    Future<FakeKeyPeopleRepository> go(
      WidgetTester tester,
      String path, {
      bool admin = false,
      KeyPeople? people,
      MyPhone phone = const MyPhone(),
    }) async {
      tester.view.physicalSize = shotSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final keys = FakeKeyPeopleRepository()
        ..spaces[_space] = people ?? who()
        ..mine = phone;
      await pumpApp(
        tester,
        language: lang,
        spaces: spaces(admin: admin),
        keyPeople: keys,
      );
      GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
      await tester.pumpAndSettle();
      return keys;
    }

    testWidgets('KP1 [$lang]', (tester) async {
      await go(tester, '/spaces/$_space/people');
      await _snap(tester, 'kp1', lang);
    });

    testWidgets('OC1 [$lang]', (tester) async {
      await go(tester, '/spaces/$_space/people');
      await _tap(tester, 'people-view-teams');
      await _snap(tester, 'oc1', lang);
    });

    testWidgets('KP2 [$lang]', (tester) async {
      await go(tester, '/spaces/$_space', people: who(seen: false));
      await _snap(tester, 'kp2', lang);
    });

    testWidgets('KP3 [$lang]', (tester) async {
      await go(
        tester,
        '/spaces/$_space/key-people',
        admin: true,
        people: who(both: true),
      );
      await _snap(tester, 'kp3', lang);
    });

    testWidgets('KP4 [$lang]', (tester) async {
      await go(
        tester,
        '/spaces/$_space/key-people',
        admin: true,
        people: const KeyPeople(),
      );
      await _tap(tester, 'key-people-add');
      await tester.tap(find.text(t('Safety officer', 'ضابط السلامة')));
      await tester.pumpAndSettle();
      await tester.enterText(
        _key('key-role-call-for'),
        t('Hazards, accidents, work permits', 'المخاطر والحوادث وأذونات العمل'),
      );
      for (final (id, note) in [
        ('p-khalid', t('Day shift', 'الوردية الصباحية')),
        ('p-tariq', t('Night shift', 'الوردية الليلية')),
      ]) {
        await _tap(tester, 'key-role-add-person');
        await _tap(tester, 'key-pick-$id');
        await _tap(tester, 'key-holder-$id');
        await tester.enterText(_key('key-holder-note-field'), note);
        await _tap(tester, 'key-holder-note-save');
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'kp4', lang);
    });

    testWidgets('NUM1 [$lang]', (tester) async {
      await go(
        tester,
        '/profile/edit/phone',
        phone: const MyPhone(
          phone: '+96555123456',
          visibility: PhoneVisibility.spaces,
        ),
      );
      await _snap(tester, 'num1', lang);
    });

    testWidgets('P1, a person in two Teams [$lang]', (tester) async {
      await go(tester, '/spaces/$_space/people', people: const KeyPeople());
      await _snap(tester, 'p1_two_teams', lang);
    });
  }
}
