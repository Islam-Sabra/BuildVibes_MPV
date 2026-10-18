import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/activity/activity_screen.dart';
import 'package:buildvibes/features/chat/thread_screen.dart';
import 'package:buildvibes/features/feed/post_screen.dart';
import 'package:buildvibes/features/profile/profile_screen.dart';
import 'package:buildvibes/features/spaces/new_space_screen.dart';
import 'package:buildvibes/features/profile/person_profile_screen.dart';
import 'package:buildvibes/features/projects/add_project_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/features/activity/needs_you_screen.dart';
import 'package:buildvibes/shared/widgets/bv_needs_row.dart';
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

FakeSpaceRepository _twoSpaces() => _oneSpace()
  ..spaces.add(
    const SpaceSummary(
      id: 'space-2',
      name: 'Khiran villas — Finishing',
      pass: SpacePass.lead,
      isAdmin: true,
    ),
  );

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
  int hour, {
  bool read = false,
  String? space = 'space-1',
  List<String> useful = const [],
}) => ActivityRow(
  id: id,
  kind: kind,
  group: group,
  createdAt: testNow.subtract(Duration(hours: 10 - hour)),
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

    testWidgets('H1b (F10): one line, the date and what needs you; no '
        'title and no other counts [$lang]', (tester) async {
      final activity = FakeActivityRepository();
      await pumpApp(
        tester,
        language: lang,
        spaces: _twoSpaces(),
        activity: activity,
      );
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
      final header = tester
          .widget<RichText>(
            find
                .descendant(
                  of: find.byKey(const Key('home-day-header')),
                  matching: find.byType(RichText),
                )
                .first,
          )
          .text
          .toPlainText();
      // Sunday 11 October 2026, Western digits in both languages.
      expect(header, contains(lang == 'ar' ? 'الأحد' : 'SUNDAY'));
      expect(header, contains('11'));
      expect(header, contains(l10n.homeNothingNeedsYou));
      // Today starts at the phone's midnight.
      expect(activity.askedFrom, DateTime(2026, 10, 11));
      expect(find.byKey(const Key('tab-dot-1')), findsNothing);
      // It is one line, well under a tenth of the screen.
      expect(
        tester.getSize(find.byKey(const Key('home-day-header'))).height,
        lessThan(844 / 10),
      );
    });

    testWidgets('H1b (F3): New Space and Enter an invite code above the '
        'list, one tap each [$lang]', (tester) async {
      await pumpApp(tester, language: lang, spaces: _twoSpaces());
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
      double top(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
      expect(top('home-enter-code'), lessThan(top('home-your-spaces')));
      expect(top('home-new-space'), lessThan(top('home-your-spaces')));
      await _tap(tester, 'home-enter-code');
      expect(find.byKey(const Key('invite-code-field')), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const Key('code-sheet')))).pop();
      await tester.pumpAndSettle();
      await _tap(tester, 'home-new-space');
      expect(find.byType(NewSpaceScreen), findsOneWidget);
    });

    testWidgets('H1b (F3): with no Space, the empty state has both, '
        'large [$lang]', (tester) async {
      await pumpApp(tester, language: lang);
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('spaces-empty')), findsOneWidget);
      for (final key in ['spaces-enter-code', 'spaces-new-space']) {
        expect(
          tester.getSize(find.byKey(Key(key))).width,
          greaterThan(390 / 2),
        );
      }
      await _tap(tester, 'spaces-new-space');
      expect(find.byType(NewSpaceScreen), findsOneWidget);
    });

    testWidgets('H1b: at most 3 Needs you, See all opens Needs you, and the '
        'Spaces dot [$lang]', (tester) async {
      final activity = FakeActivityRepository(
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
      expect(
        find.descendant(
          of: find.byKey(const Key('home-day-header')),
          matching: find.textContaining(
            l10n.homeDayNeedsYou(4),
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
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
      // Needs you, across Spaces (2544:35068).
      expect(find.byType(NeedsYouScreen), findsOneWidget);
      expect(find.byType(BvNeedsRow), findsNWidgets(4));
      expect(find.text(l10n.needsRowJoin), findsOneWidget);
      // Activity (A1) lists them too, each with the button that fits.
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/activity');
      await tester.pumpAndSettle();
      expect(find.byType(ActivityScreen), findsOneWidget);
      expect(find.text(l10n.activityNeedsHeader(4)), findsOneWidget);
      expect(find.text(l10n.needsCheck), findsOneWidget);
      await _reveal(tester, 'needs-open-r1', 'activity');
      expect(find.text(l10n.needsReview), findsOneWidget);
      await _tap(tester, 'needs-open-r1');
      expect(find.byType(SpaceScreen), findsOneWidget);
    });

    testWidgets('F10: a Needs you card, the Space first, Open on the end '
        'side level with the text, and the whole card opens it [$lang]', (
      tester,
    ) async {
      final activity = FakeActivityRepository(
        cards: [_card(NeedsKind.forYou, 'i1')],
      );
      await pumpApp(
        tester,
        language: lang,
        spaces: _oneSpace(),
        activity: activity,
      );
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('needs-i1'));
      expect(
        tester.getSize(card).height,
        greaterThanOrEqualTo(BvActivitySpec.cardMinHeight),
      );
      Finder inCard(Finder f) => find.descendant(of: card, matching: f);
      final space = inCard(find.textContaining('Tower B — Site team'));
      final what = inCard(find.textContaining('Rebar on grid C7'));
      final meta = inCard(find.textContaining('TB-002'));
      // The Space name, then what happened, then the ref and time.
      expect(tester.getTopLeft(space).dy, lessThan(tester.getTopLeft(what).dy));
      expect(tester.getTopLeft(what).dy, lessThan(tester.getTopLeft(meta).dy));
      expect(tester.widget<Text>(space).style!.fontWeight, FontWeight.w600);
      // Open on the end side, level with the text.
      final open = find.byKey(const Key('needs-open-i1'));
      final openX = tester.getCenter(open).dx;
      final whatX = tester.getCenter(what).dx;
      expect(lang == 'ar' ? openX < whatX : openX > whatX, isTrue);
      final openY = tester.getCenter(open).dy;
      expect(openY, greaterThan(tester.getTopLeft(space).dy));
      expect(openY, lessThan(tester.getBottomLeft(meta).dy));
      // A tap anywhere on the card opens it.
      await tester.tap(meta);
      await tester.pumpAndSettle();
      expect(find.byType(SpaceScreen), findsOneWidget);
    });

    testWidgets('F3 + F10: Your Spaces, every Space once, news first, '
        'never a Needs you item again [$lang]', (tester) async {
      final activity = FakeActivityRepository(
        cards: [_card(NeedsKind.forYou, 'item-7')],
        today: [
          // Space 1's news is the work item Needs you shows already.
          SpaceToday(
            spaceId: 'space-1',
            spaceName: 'Tower B — Site team',
            change: SpaceChange.workItem,
            at: testNow.subtract(const Duration(hours: 2)),
            workItemId: 'item-7',
            workItemRef: 'TB-007',
            workItemTitle: 'Rebar on grid C7',
            eventKind: 'raised',
            actorName: 'Sara Ali',
          ),
        ],
      );
      await pumpApp(
        tester,
        language: lang,
        spaces: _twoSpaces(),
        activity: activity,
      );
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
      final list = find.byKey(const Key('home-your-spaces'));
      // Each Space once; the one with news today first.
      final one = find.byKey(const Key('home-space-space-1'));
      final two = find.byKey(const Key('home-space-space-2'));
      expect(one, findsOneWidget);
      expect(two, findsOneWidget);
      expect(tester.getTopLeft(one).dy, lessThan(tester.getTopLeft(two).dy));
      // The work item shows once, in Needs you; its Space only says when.
      expect(
        find.descendant(of: list, matching: find.textContaining('TB-007')),
        findsNothing,
      );
      expect(
        find.descendant(of: one, matching: find.text(l10n.rowHoursAgo(2))),
        findsOneWidget,
      );
      // No counts on a Space: the only digits are that time.
      final digits = tester
          .widgetList<Text>(
            find.descendant(of: list, matching: find.byType(Text)),
          )
          .map((t) => t.data ?? '')
          .where((t) => t.contains(RegExp('[0-9]')));
      expect(digits.where((t) => t != l10n.rowHoursAgo(2)), isEmpty);
      expect(
        tester.getSize(two).height,
        greaterThanOrEqualTo(BvActivitySpec.cardMinHeight),
      );
      await _tap(tester, 'home-space-space-2');
      expect(find.byType(SpaceScreen), findsOneWidget);
    });

    testWidgets('H1b: a Space\'s news opens the tab where the change is '
        '[$lang]', (tester) async {
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
      expect(find.text(l10n.homeYourSpaces), findsOneWidget);
      expect(
        find.textContaining('Podium slab poured last night.'),
        findsOneWidget,
      );
      // The row's time in the frame's form: "3h ago" / "قبل 3 ساعات".
      expect(find.text(l10n.rowHoursAgo(3)), findsOneWidget);
      await _tap(tester, 'home-space-space-1');
      expect(find.byType(ThreadScreen), findsOneWidget);
    });

    testWidgets('H1b: a line mixing English values reads in order [$lang]', (
      tester,
    ) async {
      final activity = FakeActivityRepository(
        today: [
          SpaceToday(
            spaceId: 'space-1',
            spaceName: 'Tower B — Site team',
            change: SpaceChange.workItem,
            at: testNow.subtract(const Duration(days: 1)),
            workItemId: 'item-5',
            workItemRef: 'KCT-005',
            workItemTitle: 'Gate 3',
            eventKind: 'raised',
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
      expect(find.text(l10n.rowYesterday), findsOneWidget);
      final line = find.descendant(
        of: find.byKey(const Key('home-space-space-1')),
        matching: find.textContaining('Gate 3'),
      );
      final text = tester.widget<Text>(line).data!;
      // Each value sits in its own isolate, so it keeps its place in the
      // sentence (the layout itself: test/core/l10n/bidi_test.dart).
      for (final value in ['Omar Haddad', 'KCT-005', 'Gate 3']) {
        expect(text, contains('\u2066$value\u2069'));
      }
    });

    testWidgets('A1 (F13): groups, no REV letters, unread dots, then read; '
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
      // No revision letters and no REV stamp: they read like a drawing's
      // revision table.
      expect(find.textContaining('REV'), findsNothing);
      for (final letter in ['A', 'B']) {
        expect(find.text(letter), findsNothing);
      }
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
      // Unread dots as they were; then marked read, and the dot goes.
      expect(find.byKey(const Key('activity-unread')), findsWidgets);
      expect(app.activity.calls, contains('mark-read'));
      expect(find.byKey(const Key('nav-activity-dot')), findsNothing);
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
    });

    // F13: every row opens what it is about; the whole row is the tap.
    for (final (kind, group, target) in [
      (ActivityKind.itemChecked, ActivityGroupKind.space, SpaceScreen),
      (ActivityKind.itemAssigned, ActivityGroupKind.space, SpaceScreen),
      (ActivityKind.joinRequest, ActivityGroupKind.space, SpaceScreen),
      (ActivityKind.joinConfirmed, ActivityGroupKind.space, SpaceScreen),
      (ActivityKind.follow, ActivityGroupKind.network, PersonProfileScreen),
      (ActivityKind.postReply, ActivityGroupKind.posts, PostScreen),
      (ActivityKind.roleConfirmed, ActivityGroupKind.record, ProfileScreen),
    ]) {
      testWidgets('A1 (F13): ${kind.json} opens $target [$lang]', (
        tester,
      ) async {
        final spaces = _oneSpace()
          ..details['space-1'] = const SpaceDetail(
            id: 'space-1',
            name: 'Tower B — Site team',
            myPass: SpacePass.crew,
            iAmAdmin: true,
            myRights: MemberRights(),
          );
        await pumpApp(
          tester,
          language: lang,
          spaces: spaces,
          activity: FakeActivityRepository(
            rows: [_row('x', kind, group, 1, read: true)],
          ),
        );
        await _tap(tester, 'nav-activity');
        final row = find.byKey(const Key('activity-row-x'));
        // The far end of the row, away from its words, opens it too.
        await tester.tapAt(tester.getTopRight(row) + const Offset(-4, 4));
        await tester.pumpAndSettle();
        expect(find.byType(target), findsOneWidget);
      });
    }

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
      expect(find.byKey(const Key('activity-unread')), findsNothing);
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
