import 'package:buildvibes/core/routing/app_router.dart';
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/activity/needs_you_screen.dart';
import 'package:buildvibes/features/home/home_screen.dart';
import 'package:buildvibes/features/spaces/spaces_tab.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

FakeSpaceRepository _spaces() =>
    FakeSpaceRepository(now: testNow)
      ..spaces.addAll(const [
        SpaceSummary(
          id: 'space-1',
          name: 'NBKCH Site team',
          pass: SpacePass.lead,
          isAdmin: true,
          needsYou: 2,
        ),
        SpaceSummary(
          id: 'space-2',
          name: 'Test site',
          pass: SpacePass.crew,
          isAdmin: false,
          needsYou: 1,
        ),
        SpaceSummary(
          id: 'space-3',
          name: 'Test site 2',
          pass: SpacePass.viewer,
          isAdmin: false,
        ),
      ]);

NeedsCard _need(String id, String space) => NeedsCard(
  kind: NeedsKind.forYou,
  spaceId: space,
  spaceName: space,
  at: testNow,
  workItemId: id,
  workItemRef: 'NB-001',
  workItemTitle: 'Rebar on grid C7',
  actorName: 'Sara Ali',
);

FakeActivityRepository _activity() => FakeActivityRepository(
  cards: [
    _need('i1', 'space-1'),
    _need('i2', 'space-1'),
    _need('i3', 'space-2'),
  ],
  today: [
    SpaceToday(
      spaceId: 'space-1',
      spaceName: 'NBKCH Site team',
      change: SpaceChange.chat,
      at: testNow,
    ),
  ],
);

void main() {
  test('a link to a feed post goes to Spaces while the feed is hidden', () {
    expect(redirectForFeed(false, '/posts/p1'), AppRoutes.home);
    expect(redirectForFeed(false, AppRoutes.posts), AppRoutes.home);
    expect(redirectForFeed(true, '/posts/p1'), isNull);
    expect(redirectForFeed(false, AppRoutes.spaces), isNull);
  });

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('(6) no Home in the bottom bar; the app opens on Spaces '
        '[$lang]', (tester) async {
      await pumpApp(tester, language: lang, spaces: _spaces());
      expect(find.byKey(const Key('nav-home')), findsNothing);
      expect(find.byKey(const Key('nav-spaces')), findsOneWidget);
      expect(find.text(l10n.navHome), findsNothing);
      expect(find.byType(SpacesTabScreen), findsOneWidget);
      // ST1 (4): Messages and My notebook on top, no Search; no feed tabs.
      expect(find.byKey(const Key('home-messages')), findsOneWidget);
      expect(find.byKey(const Key('home-notebook')), findsOneWidget);
      expect(find.byKey(const Key('home-search')), findsNothing);
      expect(find.byKey(const Key('home-tabs')), findsNothing);
    });

    testWidgets('(6) a link to a feed post opens Spaces [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, spaces: _spaces());
      await tester.tap(find.byKey(const Key('nav-profile')));
      await tester.pumpAndSettle();
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).go(AppRoutes.post('p1'));
      await tester.pumpAndSettle();
      expect(find.byType(SpacesTabScreen), findsOneWidget);
    });

    testWidgets('(6) Create goes straight to "Which Space?" [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, spaces: _spaces());
      await tester.tap(find.byKey(const Key('nav-create')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('create-choice')), findsNothing);
      expect(find.byKey(const Key('create-post')), findsNothing);
      expect(find.text(l10n.createPickSpace), findsOneWidget);
    });

    testWidgets('(6) the switch on brings Home and its feed back [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, spaces: _spaces(), feed: true);
      expect(find.byKey(const Key('nav-home')), findsOneWidget);
      expect(find.byKey(const Key('nav-spaces')), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SpacesTabScreen), findsNothing);
      expect(find.byKey(const Key('home-tabs')), findsOneWidget);
      expect(find.byKey(const Key('home-search')), findsOneWidget);
      await tester.tap(find.byKey(const Key('nav-create')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('create-post')), findsOneWidget);
    });

    testWidgets('ST1 (2): one "N need you" line, each Space with its own '
        'mark, no separate block; the line opens Needs you [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: _spaces(),
        activity: _activity(),
      );
      expect(find.byKey(const Key('spaces-needs-you')), findsOneWidget);
      expect(find.text(l10n.daybookNeedYou(3)), findsOneWidget);
      expect(find.text(l10n.spacesTabNeedsIn(2)), findsOneWidget);
      expect(find.byKey(const Key('space-needs-space-1')), findsOneWidget);
      expect(find.byKey(const Key('space-needs-space-2')), findsOneWidget);
      expect(find.byKey(const Key('space-needs-space-3')), findsNothing);
      // The highlighted "Space with activity" block is gone.
      expect(find.byKey(const Key('home-needs')), findsNothing);
      expect(find.byKey(const Key('home-day-header')), findsNothing);
      // Each Space: its pass and whether anything is new today.
      final line1 = tester.widget<Text>(
        find.byKey(const Key('space-line-space-1')),
      );
      expect(line1.data, contains(l10n.spacesTabNewToday));
      final line3 = tester.widget<Text>(
        find.byKey(const Key('space-line-space-3')),
      );
      expect(line3.data, contains(l10n.spacesTabQuiet));
      await tester.tap(find.byKey(const Key('spaces-needs-you')));
      await tester.pumpAndSettle();
      expect(find.byType(NeedsYouScreen), findsOneWidget);
    });

    testWidgets('ST1 (3): New Space · Join with a code are small word '
        'buttons at the end of the list [$lang]', (tester) async {
      await pumpApp(tester, language: lang, spaces: _spaces());
      final words = find.byKey(const Key('spaces-words'));
      expect(words, findsOneWidget);
      expect(
        tester.getTopLeft(words).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const Key('space-row-space-3'))).dy,
        ),
      );
      // Small: a line each, not cards.
      for (final k in ['spaces-new-space', 'spaces-enter-code']) {
        expect(tester.getSize(find.byKey(Key(k))).height, lessThan(64));
      }
      expect(find.text(l10n.spacesNewTitle), findsOneWidget);
      expect(find.text(l10n.homeJoinWithCode), findsOneWidget);
      await tester.tap(find.byKey(const Key('spaces-enter-code')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('code-sheet')), findsOneWidget);
    });

    testWidgets('ST1 (3): with no Space, the same word buttons [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang);
      expect(find.byKey(const Key('spaces-empty')), findsOneWidget);
      expect(find.byKey(const Key('spaces-words')), findsOneWidget);
      expect(find.byKey(const Key('spaces-needs-you')), findsNothing);
      await tester.tap(find.byKey(const Key('spaces-new-space')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.spacesNewTitle), findsWidgets);
    });
  }
}
