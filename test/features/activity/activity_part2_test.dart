import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/l10n/bv_time.dart';
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
import 'package:buildvibes/features/spaces/space_sections.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/features/activity/needs_you_screen.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:buildvibes/shared/widgets/bv_daybook_masthead.dart';
import 'package:buildvibes/shared/widgets/bv_needs_row.dart';
import 'package:buildvibes/shared/widgets/bv_space_emblem.dart';
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

/// Where a row comes from: a Space, your record, your network, your posts.
enum _Src { space, record, network, posts }

ActivityRow _row(
  String id,
  ActivityKind kind,
  _Src src,
  int hour, {
  bool read = false,
  String? space = 'space-1',
  List<String> useful = const [],
  DateTime? at,
}) => ActivityRow(
  id: id,
  kind: kind,
  createdAt: at ?? testNow.subtract(Duration(hours: 10 - hour)),
  spaceId: src == _Src.space ? space : null,
  spaceName: src == _Src.space ? 'Tower B — Site team' : null,
  workItemId: src == _Src.space ? 'item-$id' : null,
  workItemRef: 'TB-021',
  workItemTitle: 'Rebar on grid C7',
  postId: src == _Src.posts ? 'post-1' : null,
  context: src == _Src.posts ? 'Slab poured.' : null,
  actorId: 'p-sara',
  actorName: 'Sara Ali',
  read: read,
  usefulNames: useful,
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    // When a row happened, in the app's one time format (review 54 A1).
    String moment(DateTime at) =>
        BvTime(l10n, lang, use24: false).moment(at, testNow);

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
      final texts = tester
          .widgetList<RichText>(
            find.descendant(
              of: find.byKey(const Key('home-day-header')),
              matching: find.byType(RichText),
            ),
          )
          .map((r) => r.text.toPlainText())
          .toList();
      final header = texts.join(' ');
      // Sunday 11 October 2026, Western digits in both languages, as Feed
      // and the daybook write it: no capitals (review 54 A6).
      expect(header, contains(lang == 'ar' ? 'الأحد' : 'Sunday'));
      expect(header, isNot(contains('SUNDAY')));
      expect(header, contains('11'));
      expect(header, contains(l10n.homeNothingNeedsYou));
      expect(
        tester.widget(find.byKey(const Key('home-day-header'))),
        isA<BvDaybookMasthead>(),
      );
      // Today starts at the phone's midnight.
      expect(activity.askedFrom, DateTime(2026, 10, 11));
      expect(find.byKey(const Key('tab-dot-1')), findsNothing);
      // It is one line, well under a tenth of the screen.
      expect(
        tester.getSize(find.byKey(const Key('home-day-header'))).height,
        lessThan(844 / 10),
      );
    });

    testWidgets('H1b (F3, F28): New Space and Join with a code above the '
        'list, the same width, one tap each [$lang]', (tester) async {
      await pumpApp(tester, language: lang, spaces: _twoSpaces());
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
      double top(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
      expect(
        tester.getSize(find.byKey(const Key('home-enter-code'))).width,
        tester.getSize(find.byKey(const Key('home-new-space'))).width,
      );
      // In the app's fonts it is never cut: test_screens/around_test.dart.
      expect(find.text(l10n.homeJoinWithCode), findsOneWidget);
      expect(find.text(l10n.spacesEnterCode), findsNothing);
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
      // In the action colour, after the bold day and the grey date (A6).
      Color? colorOf(String text) {
        Color? found;
        for (final r in tester.widgetList<RichText>(
          find.descendant(
            of: find.byKey(const Key('home-day-header')),
            matching: find.byType(RichText),
          ),
        )) {
          r.text.visitChildren((span) {
            if (span is TextSpan && span.text == text) {
              found = span.style?.color ?? found;
            }
            return true;
          });
        }
        return found;
      }

      expect(colorOf(l10n.homeDayNeedsYou(4)), BvColors.textAction);
      var shown = 0;
      for (final id in ['i1', 'i22', 'i333', 'r1']) {
        if (find.byKey(Key('needs-$id')).evaluate().isNotEmpty) shown++;
      }
      expect(shown, 3);
      // Names and titles keep their own direction (bidi marks), so match
      // the parts. One Space: its name once, over its three rows (F28).
      expect(find.textContaining('Rebar on grid C7'), findsNWidgets(3));
      expect(
        find.descendant(
          of: find.byKey(const Key('home-needs')),
          matching: find.textContaining('Tower B — Site team'),
        ),
        findsOneWidget,
      );
      await _reveal(tester, 'home-needs-all', 'spaces-day');
      await _tap(tester, 'home-needs-all');
      // Needs you, across Spaces (2544:35068).
      expect(find.byType(NeedsYouScreen), findsOneWidget);
      expect(find.byType(BvNeedsRow), findsNWidgets(4));
      expect(find.text(l10n.needsRowJoin), findsOneWidget);
      // Activity (A1 v3) has one slim line, which opens Home → Spaces.
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/activity');
      await tester.pumpAndSettle();
      expect(find.byType(ActivityScreen), findsOneWidget);
      expect(find.text(l10n.homeDayNeedsYou(4)), findsOneWidget);
      expect(find.byKey(const Key('needs-i1')), findsNothing);
      await _tap(tester, 'activity-needs-you');
      expect(find.byKey(const Key('spaces-day')), findsOneWidget);
      expect(find.byKey(const Key('needs-i1')), findsOneWidget);
    });

    testWidgets('F28: Needs you grouped by Space, its emblem and name once, '
        'rows with a quiet › on the end side; the whole row opens it '
        '[$lang]', (tester) async {
      final activity = FakeActivityRepository(
        cards: [
          _card(NeedsKind.forYou, 'i1'),
          _card(NeedsKind.youCheck, 'i22'),
          NeedsCard(
            kind: NeedsKind.forYou,
            spaceId: 'space-2',
            spaceName: 'Khiran villas — Finishing',
            at: testNow,
            workItemId: 'k1',
            workItemTitle: 'Tiles for villa 3',
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
      final one = find.byKey(const Key('home-needs-space-space-1'));
      final two = find.byKey(const Key('home-needs-space-space-2'));
      Finder inOne(Finder f) => find.descendant(of: one, matching: f);
      expect(inOne(find.textContaining('Tower B — Site team')), findsOneWidget);
      expect(inOne(find.byType(BvSpaceEmblem)), findsOneWidget);
      expect(
        find.descendant(of: two, matching: find.byType(BvSpaceEmblem)),
        findsOneWidget,
      );
      // No orange Open button: a quiet › on the end side of each row.
      expect(find.byType(BvButton).evaluate().length, 2);
      final row = find.byKey(const Key('needs-i1'));
      expect(
        tester.getSize(row).height,
        greaterThanOrEqualTo(BvActivitySpec.cardMinHeight),
      );
      final caret = find.descendant(
        of: row,
        matching: find.byIcon(BvIcons.caretForward),
      );
      final what = find.descendant(
        of: row,
        matching: find.textContaining('Rebar on grid C7'),
      );
      final caretX = tester.getCenter(caret).dx;
      final whatX = tester.getCenter(what).dx;
      expect(lang == 'ar' ? caretX < whatX : caretX > whatX, isTrue);
      // What happened, then the ref and time.
      final meta = find.descendant(
        of: row,
        matching: find.textContaining('TB-002'),
      );
      expect(tester.getTopLeft(what).dy, lessThan(tester.getTopLeft(meta).dy));
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
      // Space 2 has nothing new today: it still says when (F28), from
      // my_spaces().last_activity_at.
      final spaces = _oneSpace()
        ..spaces.add(
          SpaceSummary(
            id: 'space-2',
            name: 'Khiran villas — Finishing',
            pass: SpacePass.lead,
            isAdmin: true,
            lastActivityAt: testNow.subtract(const Duration(days: 3)),
          ),
        );
      await pumpApp(tester, language: lang, spaces: spaces, activity: activity);
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
        find.descendant(
          of: one,
          matching: find.text(
            moment(testNow.subtract(const Duration(hours: 2))),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: two,
          matching: find.text(
            moment(testNow.subtract(const Duration(days: 3))),
          ),
        ),
        findsOneWidget,
      );
      // Each Space's tile is its emblem, not a letter.
      expect(
        find.descendant(of: list, matching: find.byType(BvSpaceEmblem)),
        findsNWidgets(2),
      );
      // No counts on a Space: the only digits are the times.
      final digits = tester
          .widgetList<Text>(
            find.descendant(of: list, matching: find.byType(Text)),
          )
          .map((t) => t.data ?? '')
          .where((t) => t.contains(RegExp('[0-9]')));
      expect(
        digits.where(
          (t) =>
              t != moment(testNow.subtract(const Duration(hours: 2))) &&
              t != moment(testNow.subtract(const Duration(days: 3))),
        ),
        isEmpty,
      );
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
      // The row's time in the app's one format.
      expect(
        find.text(moment(testNow.subtract(const Duration(hours: 3)))),
        findsOneWidget,
      );
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
      expect(
        find.text(moment(testNow.subtract(const Duration(days: 1)))),
        findsOneWidget,
      );
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

    testWidgets('A1 v3 (F32): one list, newest first, by day, every source '
        'mixed; no groups, no REV letters, no counts; unread dots, then '
        'read [$lang]', (tester) async {
      final activity = FakeActivityRepository(
        cards: [_card(NeedsKind.youCheck, 'item-a')],
        rows: [
          _row('a', ActivityKind.itemDone, _Src.space, 9),
          _row('c', ActivityKind.follow, _Src.network, 7),
          _row(
            'd',
            ActivityKind.postUseful,
            _Src.posts,
            8,
            useful: const ['Sara Ali'],
          ),
          _row('e', ActivityKind.roleConfirmed, _Src.record, 1, read: true),
          _row(
            'b',
            ActivityKind.itemSentBack,
            _Src.space,
            0,
            read: true,
            at: DateTime(2026, 10, 7, 9),
          ),
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
      // The slim line, never a Needs you block.
      expect(find.text(l10n.homeDayNeedsYou(1)), findsOneWidget);
      expect(find.byKey(const Key('needs-item-a')), findsNothing);
      // No revision letters and no REV stamp.
      expect(find.textContaining('REV'), findsNothing);
      for (final letter in ['A', 'B']) {
        expect(find.text(letter), findsNothing);
      }
      // Newest first, whatever the source: a, d, c (yesterday), e, then b
      // on Wednesday 7 October.
      double top(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
      expect(top('activity-row-a'), lessThan(top('activity-row-d')));
      expect(top('activity-row-d'), lessThan(top('activity-row-c')));
      expect(top('activity-row-c'), lessThan(top('activity-row-e')));
      expect(find.text(l10n.chatYesterday), findsOneWidget);
      expect(find.text(l10n.chatToday), findsNothing);
      await _reveal(tester, 'activity-row-b', 'activity');
      final words = DaybookWords(l10n, lang, use24: false);
      final day = find.text(words.compactDate(DateTime(2026, 10, 7)));
      expect(day, findsOneWidget);
      expect(tester.getTopLeft(day).dy, lessThan(top('activity-row-b')));
      expect(top('activity-row-e'), lessThan(tester.getTopLeft(day).dy));
      // Where it happened, small and grey, under what happened.
      final where = tester.widget<Text>(
        find.byKey(const Key('activity-where-b')),
      );
      expect(where.data, contains('Tower B — Site team'));
      // Unread dots as they were; then marked read, and the dot goes.
      expect(find.byKey(const Key('activity-unread')), findsWidgets);
      expect(app.activity.calls, contains('mark-read'));
      expect(find.byKey(const Key('nav-activity-dot')), findsNothing);
      // A row that still needs you carries the paper clip; no other does.
      expect(
        find.descendant(
          of: find.byKey(const Key('activity-row-a')),
          matching: find.byKey(const Key('activity-needs-clip')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('activity-needs-clip')), findsOneWidget);
    });

    testWidgets('A1 v3: the name is bold while unread; a read row is quiet '
        '[$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: _oneSpace(),
        activity: FakeActivityRepository(
          rows: [
            _row('u', ActivityKind.itemDone, _Src.space, 9),
            _row('r', ActivityKind.itemDone, _Src.space, 8, read: true),
          ],
        ),
      );
      await _tap(tester, 'nav-activity');
      final type = lang == 'ar' ? BvType.arabic : BvType.latin;
      TextSpan nameOf(String id) {
        final rich = tester.widget<RichText>(
          find.descendant(
            of: find.byKey(Key('activity-text-$id')),
            matching: find.byType(RichText),
          ),
        );
        final spans = <TextSpan>[];
        rich.text.visitChildren((s) {
          if (s is TextSpan && (s.text ?? '').contains('Sara Ali')) {
            spans.add(s);
          }
          return true;
        });
        return spans.single;
      }

      expect(nameOf('u').style!.fontWeight, type.headingMd.fontWeight);
      // F34: a read row's name still stands out (Almarai Bold in Arabic).
      expect(nameOf('r').style!.fontWeight, type.emphasis.fontWeight);
    });

    // F13: every row opens what it is about; the whole row is the tap.
    for (final (kind, src, target) in [
      (ActivityKind.itemChecked, _Src.space, SpaceScreen),
      (ActivityKind.itemAssigned, _Src.space, SpaceScreen),
      // Review 105 Part 1: the Space's People, a screen over the Space.
      (ActivityKind.joinRequest, _Src.space, SpacePeopleScreen),
      (ActivityKind.joinConfirmed, _Src.space, SpaceScreen),
      (ActivityKind.follow, _Src.network, PersonProfileScreen),
      (ActivityKind.postReply, _Src.posts, PostScreen),
      (ActivityKind.roleConfirmed, _Src.record, ProfileScreen),
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
            rows: [_row('x', kind, src, 1, read: true)],
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
          _row('u1', ActivityKind.postUseful, _Src.posts, 1, read: true),
          _row(
            'u2',
            ActivityKind.postUseful,
            _Src.posts,
            2,
            read: true,
            useful: const ['Sara Ali', 'Omar Haddad'],
          ),
        ],
      );
      await pumpApp(tester, language: lang, activity: activity);
      await _tap(tester, 'nav-activity');
      expect(
        find.text(l10n.activityUseful0, findRichText: true),
        findsOneWidget,
      );
      final two = tester
          .widget<RichText>(
            find.descendant(
              of: find.byKey(const Key('activity-text-u2')),
              matching: find.byType(RichText),
            ),
          )
          .text
          .toPlainText();
      expect(two, contains('Sara Ali'));
      expect(two, contains('Omar Haddad'));
      expect(two, isNot(contains(RegExp('[0-9]'))));
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
