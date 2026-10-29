// Review 105 Part 6 (SP1 2666:38461, AR 2666:38593; ruling Q5): one line
// at the top of Work, "3 need you · 2 due today ›". A tap filters Work to
// the items waiting on me, and another shows everything again; it shows
// only while something waits (no charts, no percentages). The morning
// brief: an announcement starts pinned until the day ends, at the phone's
// midnight, and stays at the top until then; Got it as now. In English
// and Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));
Finder _entry(String id) => _key('daybook-card-$id');

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  required List<DaybookCard> posts,
  List<CalendarWorkItem> calendar = const [],
  String me = DaybookSamples.islam,
  DaybookExtras? extras,
}) async {
  final s = DaybookSamples(lang);
  final daybook = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = posts
    ..calendar.addAll(calendar);
  if (extras != null) daybook.extrasBySpace[DaybookSamples.space] = extras;
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: SpacePass.lead,
        admin: me == DaybookSamples.islam,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: daybook,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// The rebar, Islam's to sign, due today.
CalendarWorkItem _rebarDue(DaybookSamples s) => CalendarWorkItem(
  postId: 'post-rebar',
  spaceId: DaybookSamples.space,
  title: s.rebarTitle,
  day: DateTime(2026, 10, 15),
  status: WorkStatus.open,
  needsMe: true,
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('Part 6 the Needs you line [$lang]', () {
      testWidgets('"2 need you · 1 due today" at the top of Work, in place '
          'of the to-do strip', (tester) async {
        await _open(
          tester,
          lang,
          posts: [...s.v13(), s.gate()],
          calendar: [_rebarDue(s)],
        );
        expect(_key('needs-you'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('needs-you'),
            matching: find.text(l10n.daybookNeedYou(2)),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('needs-you'),
            matching: find.text(l10n.daybookNeedYouDue(1)),
          ),
          findsOneWidget,
        );
        expect(_key('to-do-strip'), findsNothing);
        // At the top: above the cards.
        await scrollToRow(tester, _entry('post-rebar'));
        expect(
          tester.getRect(_key('needs-you')).bottom,
          lessThanOrEqualTo(tester.getRect(_entry('post-rebar')).top),
        );
      });

      testWidgets('a tap shows only what waits on me; a tap again shows '
          'everything', (tester) async {
        await _open(
          tester,
          lang,
          posts: [...s.v13(), s.gate()],
          calendar: [_rebarDue(s)],
        );
        await scrollToRow(tester, _entry('post-gate'));
        expect(_entry('post-gate'), findsOneWidget);
        await _tap(tester, _key('needs-you'));
        expect(_key('needs-you-on'), findsOneWidget);
        expect(_entry('post-gate'), findsNothing);
        await scrollToRow(tester, _entry('post-rebar'));
        expect(_entry('post-rebar'), findsOneWidget);
        await scrollToRow(tester, _entry('post-sleeves'));
        expect(_entry('post-sleeves'), findsOneWidget);
        await _tap(tester, _key('needs-you'));
        expect(_key('needs-you-on'), findsNothing);
        await scrollToRow(tester, _entry('post-gate'));
        expect(_entry('post-gate'), findsOneWidget);
      });

      testWidgets('nothing due today: only "need you"', (tester) async {
        await _open(tester, lang, posts: s.v13());
        expect(find.text(l10n.daybookNeedYou(2)), findsOneWidget);
        expect(find.text(l10n.daybookNeedYouDue(1)), findsNothing);
      });

      testWidgets('nothing waits on me: no line', (tester) async {
        await _open(tester, lang, posts: [s.gate()]);
        expect(_key('needs-you'), findsNothing);
      });
    });

    group('Part 6 the morning brief [$lang]', () {
      testWidgets('an announcement starts pinned until today ends (the '
          'phone\'s midnight)', (tester) async {
        final app = await _open(tester, lang, posts: [s.gate()]);
        await _tap(tester, _key('post-bar-notepad'));
        await tester.enterText(_key('writing-title'), 'Pour at 10:00');
        await tester.pumpAndSettle();
        await _tap(tester, _key('kind-chip-${DaybookKind.announcement}'));
        final draft = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        ).read(daybookDraftProvider(DaybookSamples.space));
        expect(draft?.pinnedUntil, DateTime(2026, 10, 16));
        await _tap(tester, _key('writing-post'));
        expect(
          app.daybook.createdPosts.single.pinnedUntil,
          DateTime(2026, 10, 16),
        );
      });

      testWidgets('pinned, it stays at the top; Got it as now', (tester) async {
        final post = s.halfDayPost();
        final app = await _open(
          tester,
          lang,
          me: DaybookSamples.omar,
          posts: [
            DaybookCard(post: post, lastActivityAt: post.createdAt),
            s.rebar(),
          ],
          extras: DaybookExtras(pinned: [post]),
        );
        final brief = _key('pinned-${DaybookSamples.halfDayId}');
        expect(brief, findsOneWidget);
        expect(
          tester.getRect(brief).top,
          lessThan(tester.getRect(_entry('post-rebar')).top),
        );
        await _tap(
          tester,
          find.descendant(of: brief, matching: _key('ack-got_it')),
        );
        expect(app.daybook.marks, [
          'ack ${DaybookSamples.halfDayId} got_it true',
        ]);
      });
    });
  }
}
