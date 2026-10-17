import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/home/home_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Islam's Spaces: Kuwait City Tower (Lead), Khiran villas (Crew) and
/// Salmiya (Viewer).
FakeSpaceRepository _spaces(DaybookSamples s) {
  SpaceDetail detail(String id, String name, SpacePass pass) => SpaceDetail(
    id: id,
    name: name,
    myPass: pass,
    iAmAdmin: false,
    myRights: MemberRights(
      createItems: pass != SpacePass.viewer,
      markDone: pass != SpacePass.viewer,
    ),
  );
  return FakeSpaceRepository()
    ..spaces.addAll([
      SpaceSummary(
        id: DaybookSamples.space,
        name: s.spaceName,
        pass: SpacePass.lead,
        isAdmin: true,
      ),
      const SpaceSummary(
        id: 'space-khiran',
        name: 'Khiran villas',
        pass: SpacePass.crew,
        isAdmin: false,
      ),
      const SpaceSummary(
        id: 'space-salmiya',
        name: 'Salmiya',
        pass: SpacePass.viewer,
        isAdmin: false,
      ),
    ])
    ..details[DaybookSamples.space] = s.detail()
    ..details['space-khiran'] = detail(
      'space-khiran',
      'Khiran villas',
      SpacePass.crew,
    )
    ..details['space-salmiya'] = detail(
      'space-salmiya',
      'Salmiya',
      SpacePass.viewer,
    )
    ..spacePeople[DaybookSamples.space] = s.people();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('F1: Create offers Post to everyone or Work item in a Space; '
        'a post is written on Home [$lang]', (tester) async {
      await pumpApp(tester, language: lang, spaces: _spaces(s));
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'nav-create');
      expect(find.byKey(const Key('create-choice')), findsOneWidget);
      expect(find.text(l10n.createPostToEveryone), findsOneWidget);
      expect(find.text(l10n.createWorkItem), findsOneWidget);
      await _tap(tester, 'create-post');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('post-writing-card')), findsOneWidget);
    });

    testWidgets('F1: Work item in a Space lists the Spaces where you can '
        'write work items, never a Viewer\'s; the last one first [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        language: lang,
        spaces: _spaces(s),
        daybook: FakeDaybookRepository(),
        now: DaybookSamples.thursday,
      );
      // Khiran villas was the Space opened last on this phone.
      await app.prefs.setString(
        'last_space:${app.auth.userId}',
        'space-khiran',
      );
      await _tap(tester, 'nav-create');
      await _tap(tester, 'create-work-item');
      expect(find.text(l10n.createPickSpace), findsOneWidget);
      expect(find.byKey(const Key('create-space-space-salmiya')), findsNothing);
      final khiran = find.byKey(const Key('create-space-space-khiran'));
      final kct = find.byKey(const Key('create-space-${DaybookSamples.space}'));
      expect(tester.getTopLeft(khiran).dy, lessThan(tester.getTopLeft(kct).dy));
      expect(
        find.descendant(of: khiran, matching: find.text(l10n.createLastSpace)),
        findsOneWidget,
      );
      // Picking a Space opens its daybook with the work item card open.
      await tester.tap(kct);
      await tester.pumpAndSettle();
      expect(find.byType(SpaceScreen), findsOneWidget);
      expect(find.byType(BvWritingCard), findsOneWidget);
      expect(find.byType(BvWritingToolbar), findsOneWidget);
      // That Space is now the last one.
      expect(
        app.prefs.getString('last_space:${app.auth.userId}'),
        DaybookSamples.space,
      );
    });

    testWidgets('F1: with no Space to write in, an invite code or a new '
        'Space, never a dead end [$lang]', (tester) async {
      await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-create');
      await _tap(tester, 'create-work-item');
      expect(find.byKey(const Key('create-no-spaces')), findsOneWidget);
      expect(find.text(l10n.createNoWorkSpaces), findsOneWidget);
      await _tap(tester, 'create-enter-code');
      expect(find.byKey(const Key('code-sheet')), findsOneWidget);
    });

    testWidgets('F1: inside a Space, the Work item bar stays and opens the '
        'card as before [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: _spaces(s),
        daybook: FakeDaybookRepository(),
        now: DaybookSamples.thursday,
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
      // Opened plainly, the card waits for the bar.
      expect(find.byType(BvWritingToolbar), findsNothing);
      await _tap(tester, 'post-bar-notepad');
      expect(find.byType(BvWritingToolbar), findsOneWidget);
    });
  }
}
