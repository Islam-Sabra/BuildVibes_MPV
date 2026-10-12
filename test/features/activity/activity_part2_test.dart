import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/activity/activity_screen.dart';
import 'package:buildvibes/features/chat/thread_screen.dart';
import 'package:buildvibes/features/profile/person_profile_screen.dart';
import 'package:buildvibes/features/projects/add_project_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

/// Scrolls [list] until [key] shows, clear of the bottom bar.
Future<void> _reveal(WidgetTester tester, String key, String list) async {
  final scrollable = find
      .descendant(of: find.byKey(Key(list)), matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    200,
    scrollable: scrollable,
  );
  await tester.drag(find.byKey(Key(list)), const Offset(0, -150));
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

FakeSpaceRepository _oneSpace() =>
    FakeSpaceRepository(now: testNow)
      ..spaces.add(
        const SpaceSummary(
          id: 'space-1',
          name: 'Tower B — Site team',
          pass: SpacePass.crew,
          isAdmin: false,
          projectId: 'proj-1',
          projectName: 'Harbour Tower',
        ),
      );

NeedsCard _card(NeedsKind kind, String id, {String? actor = 'Sara Ali'}) =>
    NeedsCard(
      kind: kind,
      spaceId: 'space-1',
      spaceName: 'Tower B — Site team',
      at: testNow.subtract(Duration(minutes: id.hashCode % 50)),
      workItemId: kind == NeedsKind.joinRequest ? null : id,
      workItemRef: kind == NeedsKind.joinRequest ? null : 'TB-00${id.length}',
      workItemTitle: 'Rebar on grid C7',
      requestId: kind == NeedsKind.joinRequest ? id : null,
      actorName: actor,
    );

ActivityRow _row(
  String id,
  ActivityKind kind,
  ActivityGroupKind group,
  int seq, {
  bool read = false,
  String? space = 'space-1',
  List<String> useful = const [],
}) => ActivityRow(
  id: id,
  kind: kind,
  group: group,
  createdAt: testNow.subtract(Duration(hours: 10 - seq)),
  seq: seq,
  spaceId: group == ActivityGroupKind.space ? space : null,
  spaceName: group == ActivityGroupKind.space ? 'Tower B — Site team' : null,
  myPass: group == ActivityGroupKind.space ? 'crew' : null,
  workItemId: group == ActivityGroupKind.space ? 'item-$id' : null,
  workItemRef: 'TB-021',
  workItemTitle: 'Rebar on grid C7',
  postId: group == ActivityGroupKind.posts ? 'post-1' : null,
  context: group == ActivityGroupKind.posts ? 'Slab poured.' : null,
  actorId: 'p-sara',
  actorName: 'Sara Ali',
  read: read,
  usefulNames: useful,
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('H1b: the date, Your day on site, and only parts above 0 '
        '[$lang]', (tester) async {
      final activity = FakeActivityRepository(
        day: const HomeDay(activeSpaces: 2, replies: 3),
      );
      await pumpApp(
        tester,
        language: lang,
        spaces: _oneSpace(),
        activity: activity,
      );
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeDayTitle), findsOneWidget);
      // Sunday 11 October 2026, Western digits in both languages.
      expect(find.textContaining('11'), findsWidgets);
      expect(
        find.textContaining(lang == 'ar' ? 'الأحد' : 'SUNDAY'),
        findsOneWidget,
      );
      // Today starts at the phone's midnight.
      expect(activity.askedFrom, DateTime(2026, 10, 11));
      final summary = tester.widget<RichText>(
        find
            .descendant(
              of: find.byKey(const Key('home-day-summary')),
              matching: find.byType(RichText),
            )
            .first,
      );
      final text = summary.text.toPlainText();
      expect(text, contains(l10n.homeDaySpacesActive(2)));
      expect(text, contains(l10n.homeDayReplies(3)));
      // Nothing needs you: that part hides, and the day ends here.
      expect(text, isNot(contains(l10n.homeDayNeedsYou(1))));
      expect(find.byKey(const Key('home-thats-your-day')), findsOneWidget);
      expect(find.byKey(const Key('tab-dot-1')), findsNothing);
    });

    testWidgets('H1b: at most 3 Needs you, See all opens Activity, and the '
        'Spaces dot [$lang]', (tester) async {
      final activity = FakeActivityRepository(
        day: const HomeDay(needsYou: 4),
        cards: [
          _card(NeedsKind.forYou, 'i1'),
          _card(NeedsKind.youCheck, 'i22'),
          _card(NeedsKind.sentBack, 'i333'),
          _card(NeedsKind.joinRequest, 'r1', actor: 'Nina Saad'),
        ],
      );
      await pumpApp(
        tester,
        language: lang,
        spaces: _oneSpace(),
        activity: activity,
      );
      // Something needs you: a dot on the Spaces label, never a number.
      expect(find.byKey(const Key('tab-dot-1')), findsOneWidget);
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tab-dot-1')), findsNothing);
      expect(find.byKey(const Key('home-thats-your-day')), findsNothing);
      var shown = 0;
      for (final id in ['i1', 'i22', 'i333', 'r1']) {
        if (find.byKey(Key('needs-$id')).evaluate().isNotEmpty) shown++;
      }
      expect(shown, 3);
      // Names and titles keep their own direction (bidi marks), so match
      // the parts.
      expect(find.textContaining('Rebar on grid C7'), findsNWidgets(3));
      await _reveal(tester, 'home-needs-all', 'spaces-day');
      await _tap(tester, 'home-needs-all');
      expect(find.byType(ActivityScreen), findsOneWidget);
      expect(find.text(l10n.activityNeedsHeader(4)), findsOneWidget);
      // A1: the button that fits each card.
      expect(find.text(l10n.needsCheck), findsOneWidget);
      await _reveal(tester, 'needs-open-r1', 'activity');
      expect(find.text(l10n.needsReview), findsOneWidget);
      expect(find.text(l10n.needsOverJoin), findsOneWidget);
      await _tap(tester, 'needs-open-r1');
      expect(find.byType(SpaceScreen), findsOneWidget);
    });

    testWidgets('H1b: Today in your Spaces opens the tab where the change '
        'is [$lang]', (tester) async {
      final activity = FakeActivityRepository(
        today: [
          SpaceToday(
            spaceId: 'space-1',
            spaceName: 'Tower B — Site team',
            projectName: 'Harbour Tower',
            change: SpaceChange.chat,
            at: testNow.subtract(const Duration(hours: 3)),
            threadId: 'thread-1',
            messageKind: 'text',
            messageBody: 'Podium slab poured last night.',
            actorName: 'Omar Haddad',
          ),
        ],
      );
      await pumpApp(
        tester,
        language: lang,
        spaces: _oneSpace(),
        activity: activity,
      );
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeTodayInSpaces), findsOneWidget);
      expect(
        find.textContaining('Podium slab poured last night.'),
        findsOneWidget,
      );
      expect(find.textContaining(l10n.homeProject), findsOneWidget);
      await _tap(tester, 'today-space-1');
      expect(find.byType(ThreadScreen), findsOneWidget);
    });

    testWidgets('A1: groups with REV letters, unread markers, then read; '
        'the Activity dot [$lang]', (tester) async {
      final activity = FakeActivityRepository(
        rows: [
          _row('a', ActivityKind.itemDone, ActivityGroupKind.space, 1),
          _row('b', ActivityKind.itemSentBack, ActivityGroupKind.space, 2),
          _row('c', ActivityKind.follow, ActivityGroupKind.network, 1),
          _row(
            'd',
            ActivityKind.postUseful,
            ActivityGroupKind.posts,
            1,
            useful: const ['Sara Ali'],
          ),
          _row('e', ActivityKind.roleConfirmed, ActivityGroupKind.record, 1),
        ],
      );
      final app = await pumpApp(
        tester,
        language: lang,
        spaces: _oneSpace(),
        activity: activity,
      );
      expect(find.byKey(const Key('nav-activity-dot')), findsOneWidget);
      await _tap(tester, 'nav-activity');
      // Nothing needs you: the line, then the changes.
      expect(find.text(l10n.activityEmptyTitle), findsOneWidget);
      expect(find.textContaining(l10n.activityChanges), findsOneWidget);
      // The Space group's stamp shows its latest letter.
      expect(find.text(l10n.activityRev('B')), findsOneWidget);
      expect(
        find.text(l10n.activitySpaceLine(l10n.spacesPassCrew)),
        findsOneWidget,
      );
      // Groups in order: the Space, record, network, posts.
      double top(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
      expect(
        top('activity-group-space:space-1'),
        lessThan(top('activity-group-record')),
      );
      expect(
        top('activity-group-record'),
        lessThan(top('activity-group-network')),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('activity-group-posts')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('activity-row-d')),
          matching: find.textContaining('Sara Ali'),
        ),
        findsOneWidget,
      );
      // Unread markers as they were; then marked read, and the dot goes.
      expect(find.byKey(const Key('letter-unread')), findsWidgets);
      expect(app.activity.calls, contains('mark-read'));
      expect(find.byKey(const Key('nav-activity-dot')), findsNothing);
      // A row opens its target.
      await tester.scrollUntilVisible(
        find.byKey(const Key('activity-row-c')),
        -200,
        scrollable: find.byType(Scrollable).last,
      );
      await _tap(tester, 'activity-row-c');
      expect(find.byType(PersonProfileScreen), findsOneWidget);
    });

    testWidgets('Useful never shows a count: names you follow, or none '
        '[$lang]', (tester) async {
      final activity = FakeActivityRepository(
        rows: [
          _row(
            'u1',
            ActivityKind.postUseful,
            ActivityGroupKind.posts,
            1,
            read: true,
          ),
          _row(
            'u2',
            ActivityKind.postUseful,
            ActivityGroupKind.posts,
            2,
            read: true,
            useful: const ['Sara Ali', 'Omar Haddad'],
          ),
        ],
      );
      await pumpApp(tester, language: lang, activity: activity);
      await _tap(tester, 'nav-activity');
      expect(find.text(l10n.activityUseful0), findsOneWidget);
      final two = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('activity-row-u2')),
          matching: find.textContaining('Omar Haddad'),
        ),
      );
      expect(two.data, contains('Sara Ali'));
      expect(two.data, isNot(contains(RegExp('[0-9]'))));
      expect(find.byKey(const Key('letter-read')), findsNWidgets(2));
    });

    testWidgets('A2: nothing yet, the ledger and Add a project [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-activity');
      expect(find.byKey(const Key('activity-empty')), findsOneWidget);
      for (final t in [
        l10n.ledgerWorkLine,
        l10n.ledgerRequestsLine,
        l10n.ledgerPostsLine,
        l10n.ledgerNetworkLine,
      ]) {
        expect(find.text(t), findsOneWidget);
      }
      expect(app.activity.calls, isNot(contains('mark-read')));
      await _tap(tester, 'activity-add-project');
      expect(find.byType(AddProjectScreen), findsOneWidget);
    });

    testWidgets('opening a Space marks it seen [$lang]', (tester) async {
      final spaces = _oneSpace()
        ..details['space-1'] = const SpaceDetail(
          id: 'space-1',
          name: 'Tower B — Site team',
          myPass: SpacePass.crew,
          iAmAdmin: false,
          myRights: MemberRights(),
        );
      final app = await pumpApp(tester, language: lang, spaces: spaces);
      _router(tester).push('/spaces/space-1');
      await tester.pumpAndSettle();
      expect(app.activity.calls, contains('seen space-1'));
    });
  }
}
