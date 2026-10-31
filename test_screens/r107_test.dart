// Review 107: onboarding v2, the shots in English and Arabic at 390 × 844 in
// the app's fonts. OB1 the welcome; OB2 the email; OB3 the code while it
// is checked; OB4 your name (and OB4b with a kept invite: "Joining …");
// OB5 your work, one picked, from the market pack's nine; OB6 join your
// Space, a code typed; OB7 the first-run tips, one shot per tip. Run:
//   flutter test test_screens/r107_test.dart --update-goldens
import 'dart:async';

import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/first_run_tip.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/reference_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r107/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r107/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key).first);
  await tester.pumpAndSettle();
  await tester.tap(_key(key).first);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.descendant(of: _key(key), matching: find.byType(TextField));
  await tester.enterText(field.first, text);
  await tester.pumpAndSettle();
}

Map<String, String> _label(String en, String ar) => {'en': en, 'ar': ar};

/// The market pack's trades as migration 20261116120000 leaves them: nine
/// popular in Kuwait, in their order.
final _pack = buildRolePicker(
  families: [
    {'id': 'engineering', 'name': _label('Engineering', 'الهندسة')},
    {'id': 'management', 'name': _label('Management', 'الإدارة')},
    {'id': 'trades', 'name': _label('Trades', 'الحِرف')},
    {'id': 'other', 'name': _label('Other', 'أخرى')},
  ],
  trades: [
    for (final (id, family, en, ar) in [
      ('site_engineer', 'engineering', 'Site engineer', 'مهندس موقع'),
      ('bim_specialist', 'engineering', 'BIM specialist', 'أخصائي BIM'),
      ('site_manager', 'management', 'Site manager', 'مدير موقع'),
      ('foreman', 'management', 'Foreman', 'رئيس عمال'),
      ('electrician', 'trades', 'Electrician', 'كهربائي'),
      ('plumber', 'trades', 'Plumber', 'سبّاك'),
      ('steel_fixer', 'trades', 'Steel fixer', 'حدّاد تسليح'),
      ('carpenter', 'trades', 'Carpenter', 'نجّار'),
      ('mason', 'trades', 'Mason', 'بنّاء'),
      ('painter', 'trades', 'Painter', 'دهّان'),
      ('other', 'other', 'Other', 'أخرى'),
    ])
      {'id': id, 'family_id': family, 'name': _label(en, ar)},
  ],
  marketTrades: [
    for (final (i, id) in [
      'bim_specialist',
      'site_engineer',
      'electrician',
      'steel_fixer',
      'foreman',
      'site_manager',
      'plumber',
      'carpenter',
      'mason',
    ].indexed)
      {'trade_id': id, 'popular_sort': i + 1},
    {'trade_id': 'painter'},
    {'trade_id': 'other'},
  ],
);

const _tower = 'Kuwait City Tower — Site team';

FakeSpaceRepository _spaces() => FakeSpaceRepository()
  ..invites['K7Q4MD'] = const FakeInvite(
    spaceId: 'space-kct',
    spaceName: _tower,
    invitedBy: 'Islam Sabra',
    marketId: 'kw',
  );

Future<TestApp> _signedOut(
  WidgetTester tester,
  String lang, {
  FakeAuthRepository? auth,
}) => pumpApp(
  tester,
  language: lang,
  signedIn: false,
  auth: auth,
  spaces: _spaces(),
  overrides: [rolePickerProvider.overrideWith((ref, market) async => _pack)],
);

/// OB1 → OB2 → OB3: the code goes in and is checked.
Future<void> _signIn(WidgetTester tester) async {
  await _tap(tester, 'welcome-email');
  await _type(tester, 'email-field', 'sami@gulfbuild.co');
  await _tap(tester, 'email-send');
  await tester.enterText(_key('code-input'), '123456');
  await tester.pumpAndSettle();
}

Future<void> _name(WidgetTester tester, DaybookSamples s) async {
  await _type(tester, 'name-first', s.t('Sami', 'سامي'));
  await _type(tester, 'name-last', s.t('Al-Mansour', 'المنصور'));
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    testWidgets('OB1 the welcome [$lang]', (tester) async {
      await _signedOut(tester, lang);
      await _snap(tester, 'OB1-welcome', lang);
    });

    testWidgets('OB2 the email [$lang]', (tester) async {
      await _signedOut(tester, lang);
      await _tap(tester, 'welcome-email');
      await _type(tester, 'email-field', 'sami@gulfbuild.co');
      await _snap(tester, 'OB2-email', lang);
    });

    testWidgets('OB3 the code, Checking… [$lang]', (tester) async {
      final auth = FakeAuthRepository()..verifyGate = Completer<void>().future;
      await _signedOut(tester, lang, auth: auth);
      await _tap(tester, 'welcome-email');
      await _type(tester, 'email-field', 'sami@gulfbuild.co');
      await _tap(tester, 'email-send');
      await tester.enterText(_key('code-input'), '472915');
      await tester.pump();
      await _snap(tester, 'OB3-code-checking', lang);
    });

    testWidgets('OB4 your name [$lang]', (tester) async {
      await _signedOut(tester, lang);
      await _signIn(tester);
      await _name(tester, s);
      await _snap(tester, 'OB4-name', lang);
    });

    testWidgets('OB4b with an invite kept: Joining … [$lang]', (tester) async {
      await _signedOut(tester, lang);
      await _tap(tester, 'welcome-invite');
      await tester.enterText(_key('code-input'), 'K7Q4MD');
      await tester.pumpAndSettle();
      await _tap(tester, 'invite-continue');
      await _type(tester, 'email-field', 'sami@gulfbuild.co');
      await _tap(tester, 'email-send');
      await tester.enterText(_key('code-input'), '123456');
      await tester.pumpAndSettle();
      await _snap(tester, 'OB4b-name-joining', lang);
    });

    testWidgets('OB5 your work, Steel fixer picked [$lang]', (tester) async {
      await _signedOut(tester, lang);
      await _signIn(tester);
      await _name(tester, s);
      await _tap(tester, 'name-continue');
      await _tap(tester, 'work-tile-steel_fixer');
      await _snap(tester, 'OB5-work', lang);
    });

    testWidgets('OB6 join your Space, a code typed [$lang]', (tester) async {
      await _signedOut(tester, lang);
      await _signIn(tester);
      await _name(tester, s);
      await _tap(tester, 'name-continue');
      await _tap(tester, 'work-tile-foreman');
      await _tap(tester, 'work-continue');
      await tester.enterText(_key('code-input'), 'K7Q4MD');
      await tester.pumpAndSettle();
      await _snap(tester, 'OB6-join-space', lang);
    });

    /// Work as Omar (Crew), with someone else's item and one given to him.
    Future<void> work(WidgetTester tester, Set<FirstRunTip> seen) async {
      await pumpApp(
        tester,
        language: lang,
        auth: FakeAuthRepository(
          userId: DaybookSamples.omar,
          phone: '+96550000001',
        ),
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail(
            pass: SpacePass.crew,
            admin: false,
          )
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: FakeDaybookRepository()
          ..posts[DaybookSamples.space] = [
            s.card(
              s.item(
                id: 'post-theirs',
                at: DateTime(2026, 10, 15, 8),
                title: s.t('Formwork check, level 3', 'فحص القوالب، الطابق 3'),
                authorId: DaybookSamples.islam,
                ownerId: DaybookSamples.sara,
              ),
            ),
            s.card(
              s.item(
                id: 'post-mine',
                at: DateTime(2026, 10, 15, 9),
                title: s.t('Sleeves at grid C7', 'جلبات عند المحور C7'),
                authorId: DaybookSamples.islam,
                ownerId: DaybookSamples.omar,
              ),
              need: DaybookNeed.toSign,
            ),
          ],
        tips: FakeTipsRepository(seen: Set.of(seen)),
        now: DaybookSamples.thursday,
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
    }

    testWidgets('OB7 tip 1 of 3: the camera [$lang]', (tester) async {
      await work(tester, {});
      await _snap(tester, 'OB7-tip1-camera', lang);
    });

    testWidgets('OB7 tip 2 of 3: hold a card [$lang]', (tester) async {
      await work(tester, {FirstRunTip.camera});
      await _snap(tester, 'OB7-tip2-hold', lang);
    });

    testWidgets('OB7 tip 3 of 3: Sign as done [$lang]', (tester) async {
      await work(tester, {FirstRunTip.camera, FirstRunTip.hold});
      await _snap(tester, 'OB7-tip3-sign-done', lang);
    });
  }
}
