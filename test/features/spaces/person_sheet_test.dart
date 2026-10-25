// F79 (review 80): a person on the People tab opens a short sheet: View
// profile and Message for everyone; Pass and Remove for the Space admin
// only; for yourself, View profile only.
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/messages/dm_thread_screen.dart';
import 'package:buildvibes/features/spaces/member_pass_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart' show SpaceOpen;
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/hold.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<FakeSpaceRepository> _open(
  WidgetTester tester,
  String lang, {
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  bool admin = true,
}) async {
  final s = DaybookSamples(lang);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail(pass: pass, admin: admin)
    ..spacePeople[DaybookSamples.space] = s.people();
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: spaces,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}', extra: SpaceOpen.people);
  await tester.pumpAndSettle();
  return spaces;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(Key(k));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('the Space admin: View profile, Message, Pass and Remove; '
        'Pass opens the pass [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, _key('member-${DaybookSamples.omar}'));
      expect(_key('person-sheet-${DaybookSamples.omar}'), findsOneWidget);
      for (final k in [
        'person-profile',
        'person-message',
        'person-pass',
        'person-remove',
      ]) {
        expect(_key(k), findsOneWidget, reason: k);
      }
      await _tap(tester, _key('person-pass'));
      expect(find.byType(MemberPassScreen), findsOneWidget);
    });

    testWidgets('a Crew member: View profile and Message only, never the '
        'pass [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
        admin: false,
      );
      await _tap(tester, _key('member-${DaybookSamples.sara}'));
      expect(_key('person-profile'), findsOneWidget);
      expect(_key('person-message'), findsOneWidget);
      expect(_key('person-pass'), findsNothing);
      expect(_key('person-remove'), findsNothing);
      await _tap(tester, _key('person-message'));
      expect(find.byType(DmThreadScreen), findsOneWidget);
    });

    testWidgets('yourself: View profile only [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, _key('member-${DaybookSamples.islam}'));
      expect(_key('person-profile'), findsOneWidget);
      expect(_key('person-message'), findsNothing);
      expect(_key('person-pass'), findsNothing);
    });

    testWidgets('Remove asks first and is held; the person leaves the list '
        'at once, and goes when the undo bar has (review 94) [$lang]', (
      tester,
    ) async {
      final spaces = await _open(tester, lang);
      await _tap(tester, _key('member-${DaybookSamples.omar}'));
      await _tap(tester, _key('person-remove'));
      expect(find.text(l10n.spacesRemoveBody), findsOneWidget);
      expect(find.text(l10n.holdToRemove), findsOneWidget);
      await hold(tester, holdOnSheet);
      expect(_key('member-${DaybookSamples.omar}'), findsNothing);
      expect(find.text(l10n.spacesRemovedUndo), findsOneWidget);
      expect(spaces.calls, isNot(contains('remove ${DaybookSamples.omar}')));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(spaces.calls.last, 'remove ${DaybookSamples.omar}');
    });

    testWidgets('Undo puts the person back, and nothing is removed '
        '(review 94) [$lang]', (tester) async {
      final spaces = await _open(tester, lang);
      await _tap(tester, _key('member-${DaybookSamples.omar}'));
      await _tap(tester, _key('person-remove'));
      await hold(tester, holdOnSheet);
      expect(_key('member-${DaybookSamples.omar}'), findsNothing);
      await tester.tap(find.byKey(const Key('undo-bar-action')));
      await tester.pumpAndSettle();
      expect(_key('member-${DaybookSamples.omar}'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(spaces.calls, isNot(contains('remove ${DaybookSamples.omar}')));
    });
  }
}
