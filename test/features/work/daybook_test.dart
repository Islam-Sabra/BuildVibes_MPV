// The daybook in v13 (review 53 Part B): one full-width card per work
// item, its history inside, traces on earlier days, the reader's one
// action from needs_me.
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/spaces/invite_screen.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_card_history.dart';
import 'package:buildvibes/shared/widgets/bv_day_divider.dart';
import 'package:buildvibes/shared/widgets/bv_daybook_masthead.dart';
import 'package:buildvibes/shared/widgets/bv_due_today_strip.dart';
import 'package:buildvibes/shared/widgets/bv_first_page.dart';
import 'package:buildvibes/shared/widgets/bv_list_row.dart';
import 'package:buildvibes/shared/widgets/bv_month_dropdown.dart';
import 'package:buildvibes/shared/widgets/bv_paper_clip.dart';
import 'package:buildvibes/shared/widgets/bv_post_bar.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:buildvibes/shared/widgets/bv_trace_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

DaybookWords _words(String lang) =>
    DaybookWords(_l10n(lang), lang, use24: false);

/// Just after Omar's second sign-off.
final _now = DateTime(2026, 10, 15, 10, 57);

Future<FakeDaybookRepository> _open(
  WidgetTester tester,
  String lang, {
  required List<DaybookCard> posts,
  DateTime? now,
  String? me,
  SpacePass pass = SpacePass.lead,
  bool admin = true,
  List<CalendarWorkItem> calendar = const [],
  Map<String, DaybookMonth> months = const {},
  FakeDaybookRepository? daybook,
}) async {
  final s = DaybookSamples(lang);
  final fake = (daybook ?? FakeDaybookRepository())
    ..posts[DaybookSamples.space] = posts
    ..calendar.addAll(calendar)
    ..months.addAll(months);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail(pass: pass, admin: admin)
    ..spacePeople[DaybookSamples.space] = s.people();
  await pumpApp(
    tester,
    language: lang,
    spaces: spaces,
    daybook: fake,
    now: now ?? _now,
    auth: FakeAuthRepository(
      userId: me ?? DaybookSamples.islam,
      phone: '+96550000001',
    ),
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return fake;
}

BvDaybookMasthead _masthead(WidgetTester tester) =>
    tester.widget<BvDaybookMasthead>(find.byType(BvDaybookMasthead));

Finder _card(String id) => find.byKey(Key('daybook-card-$id'));

Finder _inCard(String id, Finder f) =>
    find.descendant(of: _card(id), matching: f);

/// The texts of a card's history lines, top to bottom.
List<String> _lines(WidgetTester tester, String id) {
  final rich = tester.widgetList<RichText>(
    find.descendant(
      of: _inCard(id, find.byType(BvCardHistory)),
      matching: find.byType(RichText),
    ),
  );
  return [
    for (final r in rich)
      if ((r.text as TextSpan).children != null) r.text.toPlainText(),
  ];
}

DaybookCard _numbered(DaybookSamples s, int i) => s.card(
  s.item(
    id: 'post-${i.toString().padLeft(3, '0')}',
    at: DateTime(2026, 9, 1).add(Duration(hours: 6 * i)),
    title: 'Item $i',
    authorId: DaybookSamples.sara,
    ownerId: DaybookSamples.omar,
  ),
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final words = _words(lang);
    final s = DaybookSamples(lang);

    testWidgets('the masthead is one line: Today and the date at Now, no '
        'count [$lang]', (tester) async {
      await _open(tester, lang, posts: s.v13());
      final masthead = _masthead(tester);
      // F59: at Now it always reads Today, then the date.
      expect(masthead.weekday, l10n.daybookTodayDivider);
      expect(masthead.date, l10n.daybookMastheadToday(words.compactDate(_now)));
      expect(find.textContaining('41'), findsNothing);
      // No hour spine: the cards take the width, 16 from each edge.
      final card = tester.getRect(_inCard('post-sleeves', find.byType(BvSlip)));
      expect(card.left, 16);
      expect(card.right, 390 - 16.0);
    });

    testWidgets('one card per work item: header, title, facts, the latest '
        'proof with its stamp, newest activity at the bottom [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, posts: s.v13());
      // The sleeves moved past the rebar: its last activity is later.
      expect(
        tester.getTopLeft(_card('post-sleeves')).dy,
        greaterThan(tester.getTopLeft(_card('post-rebar')).dy),
      );
      // Header: "You", the ref, the time of the latest activity.
      expect(_inCard('post-sleeves', find.text(l10n.daybookYou)), findsOne);
      expect(
        _inCard('post-sleeves', find.text(l10n.daybookCardRef('KCT-014'))),
        findsOne,
      );
      expect(
        _inCard(
          'post-sleeves',
          find.text(words.time.parts(DaybookSamples.sleevesDoneAt).time),
        ),
        findsWidgets,
      );
      expect(_inCard('post-sleeves', find.text(s.sleeves)), findsOne);
      expect(
        _inCard(
          'post-sleeves',
          find.text(
            words.meta(
              s.sleevesCard().post,
              me: DaybookSamples.islam,
              now: _now,
            ),
          ),
        ),
        findsOne,
      );
      expect(_inCard('post-sleeves', find.text(s.levelTwo)), findsOne);
      // The latest proof, with its DONE stamp; one photo, one stamp.
      expect(
        _inCard('post-sleeves', find.byKey(const Key('slip-photo'))),
        findsOne,
      );
      final stamp = tester.widget<BvInkStamp>(
        _inCard('post-sleeves', find.byType(BvInkStamp)),
      );
      expect(stamp.label, l10n.daybookStampDone);
      expect(
        stamp.subline,
        words.stampLine(s.omarName, DaybookSamples.sleevesDoneAt),
      );
      // No separate sign-off, update or send-back entries.
      expect(find.byType(BvSlip), findsNWidgets(2));
    });

    testWidgets('the history shows the latest three in order; Show earlier '
        'opens the rest in place [$lang]', (tester) async {
      await _open(tester, lang, posts: s.v13());
      String line(DaybookEvent e) {
        final phrase = words.eventPhrase(
          e,
          me: DaybookSamples.islam,
          now: _now,
        );
        final detail = words.eventDetail(e);
        return detail == null
            ? phrase
            : '${l10n.daybookHistoryLead(phrase)} $detail';
      }

      final history = s.sleevesCard().history.where((e) => e.shown).toList();
      // Oldest at the top: the last three of five.
      expect(_lines(tester, 'post-sleeves'), [
        for (final e in history.take(3).toList().reversed) line(e),
      ]);
      final earlier = _inCard(
        'post-sleeves',
        find.byKey(const Key('card-history-earlier')),
      );
      expect(earlier, findsOne);
      await tester.ensureVisible(earlier);
      await tester.tap(earlier);
      await tester.pumpAndSettle();
      expect(_lines(tester, 'post-sleeves'), [
        for (final e in history.reversed) line(e),
      ]);
      // Everything is loaded: no Show earlier left.
      expect(earlier, findsNothing);
      // The rebar has one line, nothing earlier.
      expect(_lines(tester, 'post-rebar'), hasLength(1));
      expect(
        _inCard('post-rebar', find.byKey(const Key('card-history-earlier'))),
        findsNothing,
      );
    });

    testWidgets('past the first 50, Show earlier reads post_history [$lang]', (
      tester,
    ) async {
      final card = s.sleevesCard().copyWith(historyMore: true);
      final fake = FakeDaybookRepository()
        ..earlier[card.id] = [
          s.event(
            'ev-old',
            DaybookEventKind.comment,
            DateTime(2026, 10, 14, 9),
            DaybookSamples.omar,
            note: 'The oldest line',
          ),
        ];
      await _open(tester, lang, posts: [card], daybook: fake);
      final earlier = _inCard(
        'post-sleeves',
        find.byKey(const Key('card-history-earlier')),
      );
      await tester.ensureVisible(earlier);
      await tester.tap(earlier);
      await tester.pumpAndSettle();
      expect(fake.historyCalls, isEmpty);
      // All five loaded lines show; more are on the server.
      expect(_lines(tester, 'post-sleeves'), hasLength(5));
      await tester.ensureVisible(earlier);
      await tester.tap(earlier);
      await tester.pumpAndSettle();
      expect(fake.historyCalls, [card.id]);
      expect(_lines(tester, 'post-sleeves'), hasLength(6));
      expect(_lines(tester, 'post-sleeves').first, contains('The oldest line'));
    });

    testWidgets('each earlier day a card had something happen keeps one '
        'trace, at that day\'s latest event; it opens the card [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, posts: s.v13());
      final wednesday = DateTime(2026, 10, 14);
      final traces = find.byType(BvTraceRow, skipOffstage: false);
      // Wednesday: raised at 15:50, an update at 16:07; one trace, 16:07.
      expect(traces, findsOneWidget);
      final trace = tester.widget<BvTraceRow>(traces);
      expect(trace.time, words.time.clock(DaybookSamples.sleevesWedUpdateAt));
      expect(
        trace.text,
        l10n.daybookTrace(
          words.eventPhrase(
            s.sleevesCard().history.firstWhere((e) => e.id == 'ev-sleeves-c1'),
            me: DaybookSamples.islam,
            now: _now,
            trace: true,
          ),
          s.sleeves,
        ),
      );
      // It sits under Wednesday's divider, above today's.
      final dividers = tester
          .widgetList<BvDayDivider>(
            find.byType(BvDayDivider, skipOffstage: false),
          )
          .map((d) => d.label)
          .toList();
      expect(dividers, [
        words.compactDate(wednesday),
        l10n.daybookTodayDivider,
      ]);

      await tester.drag(
        find.byKey(const Key('daybook')),
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      await tester.tap(traces);
      await tester.pumpAndSettle();
      // The card, with its history open at Wednesday's update.
      final update = find.textContaining(
        s.sleevesWedUpdate,
        findRichText: true,
      );
      expect(_inCard('post-sleeves', update), findsOne);
      final viewport = tester.getRect(find.byKey(const Key('daybook')));
      final at = tester.getRect(_inCard('post-sleeves', update));
      expect(viewport.overlaps(at), isTrue);
    });

    testWidgets('a trace on each earlier day, each at its own latest '
        'event; a trace opens the card at that day\'s line [$lang]', (
      tester,
    ) async {
      final monday = DateTime(2026, 10, 12);
      final tuesday = DateTime(2026, 10, 13);
      final card = s.card(
        s.item(
          id: 'post-trays',
          at: monday.add(const Duration(hours: 8)),
          title: s.cableTraysTitle,
          authorId: DaybookSamples.islam,
          ownerId: DaybookSamples.omar,
        ),
        events: [
          s.event(
            'ev-mon',
            DaybookEventKind.comment,
            monday.add(const Duration(hours: 9)),
            DaybookSamples.omar,
            note: 'Monday words',
          ),
          s.event(
            'ev-tue-1',
            DaybookEventKind.comment,
            tuesday.add(const Duration(hours: 7)),
            DaybookSamples.sara,
            note: 'Tuesday early',
          ),
          s.event(
            'ev-tue-2',
            DaybookEventKind.comment,
            tuesday.add(const Duration(hours: 15)),
            DaybookSamples.omar,
            note: 'Tuesday late',
          ),
          s.event(
            'ev-thu',
            DaybookEventKind.comment,
            DateTime(2026, 10, 15, 9),
            DaybookSamples.omar,
            note: 'Today',
          ),
        ],
      );
      await _open(tester, lang, posts: [card]);
      final traces = tester
          .widgetList<BvTraceRow>(find.byType(BvTraceRow, skipOffstage: false))
          .toList();
      // Monday (raised, then an update: the update) and Tuesday (its
      // latest), never today.
      expect(traces.map((t) => t.time), [
        words.time.clock(monday.add(const Duration(hours: 9))),
        words.time.clock(tuesday.add(const Duration(hours: 15))),
      ]);
      expect(find.byType(BvDayDivider, skipOffstage: false), findsNWidgets(3));
      // Monday's trace: the card opens with its whole history, at Monday.
      final monTrace = find.byKey(
        Key('daybook-trace-post-trays-${monday.toIso8601String()}'),
        skipOffstage: false,
      );
      await tester.ensureVisible(monTrace);
      await tester.pumpAndSettle();
      await tester.tap(monTrace);
      await tester.pumpAndSettle();
      final monday9 = _inCard(
        'post-trays',
        find.textContaining('Monday words', findRichText: true),
      );
      expect(monday9, findsOne);
      expect(
        tester
            .getRect(find.byKey(const Key('daybook')))
            .overlaps(tester.getRect(monday9)),
        isTrue,
      );
    });

    testWidgets('a card made on an earlier day and with nothing since is '
        'only on that day; no trace [$lang]', (tester) async {
      await _open(tester, lang, posts: [s.gate(), s.rebar()]);
      expect(find.byType(BvTraceRow, skipOffstage: false), findsNothing);
      expect(find.byType(BvDayDivider, skipOffstage: false), findsNWidgets(2));
    });

    testWidgets('needs_me gives the reader one action and the clip [$lang]', (
      tester,
    ) async {
      final mine = s.item(
        id: 'post-mine',
        at: DateTime(2026, 10, 15, 9),
        title: 'Mine to sign',
        authorId: DaybookSamples.sara,
        ownerId: DaybookSamples.islam,
      );
      DaybookPost other(String id, String title) => s.item(
        id: id,
        at: DateTime(2026, 10, 15, 9, 30),
        title: title,
        authorId: DaybookSamples.islam,
        ownerId: DaybookSamples.lina,
      );
      await _open(
        tester,
        lang,
        posts: [
          s.card(mine, need: DaybookNeed.toSign),
          s.sleevesCard(),
          s.card(other('post-give', 'Owner left'), need: DaybookNeed.giveTo),
          s.card(other('post-tick', 'To tick'), need: DaybookNeed.toTick),
          s.card(other('post-new', 'A new need'), need: DaybookNeed.unknown),
          s.card(other('post-none', 'Nothing for me')),
        ],
      );
      Finder clip(String id) => _inCard(id, find.byType(BvPaperClip));
      expect(_inCard('post-mine', find.text(l10n.daybookSignAsDone)), findsOne);
      expect(clip('post-mine'), findsOne);
      expect(
        _inCard('post-sleeves', find.text(l10n.daybookDoubleTapToCheck)),
        findsOne,
      );
      expect(clip('post-sleeves'), findsOne);
      expect(_inCard('post-give', find.text(l10n.daybookGiveTo)), findsOne);
      expect(clip('post-give'), findsOne);
      // A checklist point (slice 2), or a value this version doesn't know:
      // the clip, no action.
      for (final id in ['post-tick', 'post-new']) {
        expect(clip(id), findsOne);
        expect(
          _inCard(id, find.byKey(const Key('slip-pill-action'))),
          findsNothing,
        );
      }
      expect(clip('post-none'), findsNothing);
      expect(
        _inCard('post-none', find.byKey(const Key('slip-pill-action'))),
        findsNothing,
      );
    });

    testWidgets('a note-only proof to check: the note and its stamp, no '
        'frame and no hint; Check is in the menu [$lang]', (tester) async {
      await _open(tester, lang, posts: [s.sleevesCard(photos: const [])]);
      expect(
        _inCard('post-sleeves', find.byKey(const Key('slip-photo'))),
        findsNothing,
      );
      expect(_inCard('post-sleeves', find.byType(BvSlipNote)), findsOne);
      expect(_inCard('post-sleeves', find.byType(BvInkStamp)), findsOne);
      expect(find.text(l10n.daybookDoubleTapToCheck), findsNothing);
      expect(_inCard('post-sleeves', find.byType(BvPaperClip)), findsOne);
      await tester.longPress(_inCard('post-sleeves', find.byType(BvSlip)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.daybookCheck), findsOne);
    });

    testWidgets('checked: CHECKED on the photo, no action [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, posts: [s.gate()]);
      final stamp = tester.widget<BvInkStamp>(
        _inCard('post-gate', find.byType(BvInkStamp)),
      );
      expect(stamp.label, l10n.daybookStampChecked);
      expect(stamp.tone, BvInkStampTone.positive);
      expect(find.byType(BvPaperClip), findsNothing);
      expect(find.byKey(const Key('slip-pill-action')), findsNothing);
      expect(find.text(l10n.daybookDoubleTapToCheck), findsNothing);
    });

    testWidgets('sent back: SENT BACK on the photo; the owner signs again '
        '[$lang]', (tester) async {
      await _open(
        tester,
        lang,
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
        admin: false,
        posts: [
          s.sleevesCard(
            me: DaybookSamples.omar,
            upTo: DaybookSamples.sleevesSentBackAt,
          ),
        ],
      );
      final stamp = tester.widget<BvInkStamp>(find.byType(BvInkStamp));
      expect(stamp.label, l10n.daybookStampSentBack);
      expect(stamp.tone, BvInkStampTone.destructive);
      expect(find.text(l10n.daybookSignAsDone), findsOne);
      expect(
        _lines(tester, 'post-sleeves').last,
        '${l10n.daybookHistoryLead(l10n.daybookLineSentBack(s.islamName))} '
        '${words.reason(SendBackReason.photoMissing)}',
      );
    });

    testWidgets('cancelled: faded, struck through, CANCELLED, and the line '
        '[$lang]', (tester) async {
      await _open(tester, lang, posts: [s.doorHardware()]);
      expect(find.byKey(const Key('slip-cancelled')), findsOne);
      expect(
        tester.widget<BvInkStamp>(find.byType(BvInkStamp)).label,
        l10n.daybookStampCancelled,
      );
      expect(_lines(tester, 'post-door'), [l10n.daybookLineYouCancelled]);
    });

    testWidgets('given to someone else: a line in the history [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        posts: [s.traysForOmar(givenAt: DateTime(2026, 10, 15, 12, 30))],
        now: DateTime(2026, 10, 15, 12, 31),
      );
      expect(_lines(tester, 'post-trays'), [
        l10n.daybookLineYouGave(s.rakeshName, s.omarName),
      ]);
    });

    testWidgets('B1: a newest page with nothing to show loads the older one '
        '[$lang]', (tester) async {
      // 30 reports (slice 7, not drawn yet) fill the first page; the work
      // item before them still shows, with no scrolling.
      final announcements = [
        for (var i = 0; i < 30; i++)
          DaybookCard(
            post: DaybookPost(
              id: 'ann-${i.toString().padLeft(2, '0')}',
              kind: 'report',
              createdAt: DateTime(2026, 10, 15, 9, i),
              title: 'Notice $i',
            ),
            lastActivityAt: DateTime(2026, 10, 15, 9, i),
          ),
      ];
      final daybook = await _open(
        tester,
        lang,
        posts: [s.gate(), ...announcements],
      );
      expect(daybook.pageCalls, hasLength(2));
      expect(_card('post-gate'), findsOneWidget);
    });

    testWidgets('DY1: back to yesterday, the masthead follows [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, posts: s.d1());
      await tester.drag(
        find.byKey(const Key('daybook')),
        const Offset(0, 3000),
      );
      await tester.pumpAndSettle();
      final wednesday = DateTime(2026, 10, 14);
      expect(_masthead(tester).weekday, words.weekday(wednesday));
      expect(_masthead(tester).date, words.dayMonth(wednesday));
    });

    testWidgets('L1: Late by 1 day and the Due today strip [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        posts: s.l1(),
        me: DaybookSamples.omar,
        now: DaybookSamples.friday,
        calendar: [
          s.cableTraysDue(),
          // Another Space's, and one already done: not on this strip.
          CalendarWorkItem(
            postId: 'post-elsewhere',
            spaceId: 'other',
            title: 'Elsewhere',
            day: DateTime(2026, 10, 16),
            status: WorkStatus.open,
          ),
          CalendarWorkItem(
            postId: 'post-signed',
            spaceId: DaybookSamples.space,
            title: 'Signed',
            day: DateTime(2026, 10, 16),
            status: WorkStatus.done,
          ),
        ],
      );
      // F57: no "Late" line; a passed due is a reminder on the facts line.
      expect(find.textContaining('Late'), findsNothing);
      expect(
        find.text('${l10n.daybookToDo} ${s.cableTraysTitle}'),
        findsOneWidget,
      );
      expect(find.byType(BvDueTodayStrip), findsOneWidget);
      // The strip sits under the masthead, above the diary.
      expect(
        tester.getTopLeft(find.byType(BvDueTodayStrip)).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('daybook'))).dy + 1),
      );
    });

    testWidgets('F57: the strip keeps what is still to do from earlier days, '
        'oldest first, the day in grey and never "late" [$lang]', (
      tester,
    ) async {
      final wednesday = DateTime(2026, 10, 14);
      final rebar = s.t('Rebar spacers, level 2', 'فواصل الحديد، الطابق 2');
      await _open(
        tester,
        lang,
        posts: s.l1(),
        me: DaybookSamples.omar,
        now: DaybookSamples.friday,
        calendar: [
          s.cableTraysDue(),
          CalendarWorkItem(
            postId: 'post-rebar-spacers',
            spaceId: DaybookSamples.space,
            title: rebar,
            day: wednesday,
            status: WorkStatus.open,
          ),
          // Signed as done on an earlier day: gone from the strip.
          CalendarWorkItem(
            postId: 'post-signed-wed',
            spaceId: DaybookSamples.space,
            title: 'Signed on Wednesday',
            day: wednesday,
            status: WorkStatus.done,
          ),
        ],
      );
      final day = words.stripDay(wednesday, DaybookSamples.friday)!;
      final text = '${l10n.daybookToDo} $day $rebar · ${s.cableTraysTitle}';
      expect(find.text(text), findsOneWidget);
      final strip = tester.widget<BvDueTodayStrip>(
        find.byType(BvDueTodayStrip),
      );
      expect(strip.items, [
        (day: day, title: rebar),
        (day: null, title: s.cableTraysTitle),
      ]);
      expect(find.textContaining('Late'), findsNothing);
      expect(find.textContaining('Signed on Wednesday'), findsNothing);
    });

    testWidgets('Review 73 A1: a long strip, tapped anywhere, opens the To do '
        'sheet with every item oldest first, and a row opens its card '
        '[$lang]', (tester) async {
      final friday = DaybookSamples.friday;
      final earlier = [
        for (var d = 0; d < 5; d++)
          CalendarWorkItem(
            postId: 'post-early-$d',
            spaceId: DaybookSamples.space,
            title: s.t(
              'Firestopping around the riser sleeves, block $d',
              'سد الحريق حول جلب الصاعد، المبنى $d',
            ),
            day: DateTime(2026, 10, 10 + d),
            status: WorkStatus.open,
          ),
      ];
      await _open(
        tester,
        lang,
        posts: s.l1(),
        me: DaybookSamples.omar,
        now: friday,
        calendar: [
          s.cableTraysDue(),
          CalendarWorkItem(
            postId: 'post-sleeves',
            spaceId: DaybookSamples.space,
            title: s.sleeves,
            day: DateTime(2026, 10, 15),
            status: WorkStatus.open,
          ),
          ...earlier.reversed,
        ],
      );
      final inOrder = [
        for (final i in earlier) (id: i.postId, title: i.title, day: i.day),
        (id: 'post-sleeves', title: s.sleeves, day: DateTime(2026, 10, 15)),
        (id: 'post-trays', title: s.cableTraysTitle, day: null),
      ];
      // The strip stops at two lines: the last items can't be read there.
      final line = tester.widget<Text>(
        find.descendant(
          of: find.byType(BvDueTodayStrip),
          matching: find.byType(Text),
        ),
      );
      expect(line.maxLines, 2);
      expect(line.overflow, TextOverflow.ellipsis);

      // Tapped at its end, away from the words' start.
      await tester.tapAt(
        tester.getRect(find.byType(BvDueTodayStrip)).centerRight -
            const Offset(4, 0),
      );
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('to-do-sheet'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('bv-sheet')),
          matching: find.text(l10n.daybookToDoSheet),
        ),
        findsOneWidget,
      );
      // No count, no "+ more".
      expect(find.textContaining('+'), findsNothing);
      final rows = tester
          .widgetList<BvListRow>(
            find.descendant(of: sheet, matching: find.byType(BvListRow)),
          )
          .toList();
      expect(rows.map((r) => r.title), [for (final i in inOrder) i.title]);
      expect(rows.map((r) => r.subtitle), [
        for (final i in inOrder)
          i.day == null ? null : words.stripDay(i.day!, friday),
      ]);
      // An earlier day in grey, as on the strip.
      final day = words.stripDay(DateTime(2026, 10, 15), friday)!;
      final dayText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('to-do-row-5')),
          matching: find.text(day),
        ),
      );
      expect(dayText.style?.color, BvColors.textSecondary);

      // A row closes the sheet and opens its card, highlighted.
      final row = find.byKey(const Key('to-do-row-5'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      final ring = find.descendant(
        of: find.byKey(const Key('daybook-card-post-sleeves')),
        matching: find.byKey(const Key('bv-highlight-ring')),
      );
      for (var i = 0; i < 20 && ring.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(ring, findsOneWidget);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
    });

    testWidgets('V1: a Viewer reads only: no clips, no actions, the pass '
        'chip [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        me: DaybookSamples.mona,
        // Even if the server said so, a Viewer's card shows no clip.
        posts: [s.sleevesCard(), s.rebar()],
        pass: SpacePass.viewer,
        admin: false,
      );
      expect(find.byType(BvPaperClip), findsNothing);
      expect(find.text(l10n.daybookDoubleTapToCheck), findsNothing);
      expect(find.text(l10n.daybookSignAsDone), findsNothing);
      expect(find.byKey(const Key('slip-pill-action')), findsNothing);
      expect(find.byType(BvPassChip), findsOneWidget);
      expect(find.text(l10n.spacesPassViewer), findsOneWidget);
      expect(find.text(l10n.daybookReadOnly), findsOneWidget);
      expect(find.text(l10n.daybookWorkItem), findsNothing);
      // The history still reads.
      expect(_lines(tester, 'post-sleeves'), hasLength(3));
    });

    testWidgets('DY3: day one: post and invite, no announcement [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, posts: const []);
      expect(find.byType(BvFirstPage), findsOneWidget);
      final page = tester.widget<BvFirstPage>(find.byType(BvFirstPage));
      expect(page.actions.map((a) => a.label), [
        l10n.daybookFirstPost,
        l10n.daybookFirstInvite,
      ]);
      await tester.tap(find.text(l10n.daybookFirstInvite));
      await tester.pumpAndSettle();
      expect(find.byType(InviteScreen), findsOneWidget);
    });

    testWidgets('DY3: a Viewer\'s empty daybook offers nothing to do [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        posts: const [],
        pass: SpacePass.viewer,
        admin: false,
      );
      expect(
        tester.widget<BvFirstPage>(find.byType(BvFirstPage)).actions,
        isEmpty,
      );
    });

    testWidgets('slice 2: an announcement off its pin is a card; a report '
        '(slice 7) waits [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [
          s.rebar(),
          DaybookCard(
            post: DaybookPost(
              id: 'post-ann',
              kind: 'announcement',
              createdAt: DateTime(2026, 10, 15, 9),
              title: 'Crane closed today',
            ),
            lastActivityAt: DateTime(2026, 10, 15, 9),
          ),
          DaybookCard(
            post: DaybookPost(
              id: 'post-report',
              kind: 'report',
              createdAt: DateTime(2026, 10, 15, 9, 5),
              title: 'Daily report',
            ),
            lastActivityAt: DateTime(2026, 10, 15, 9, 5),
          ),
        ],
      );
      expect(find.text('Crane closed today'), findsOneWidget);
      expect(find.text('Daily report'), findsNothing);
      expect(find.byType(BvSlip), findsNWidgets(2));
      expect(find.byType(BvFirstPage), findsNothing);
      expect(find.byType(BvPostBar), findsOneWidget);
    });

    testWidgets(
      'DY2: the month: week start, dots, rings; a day jumps [$lang]',
      (tester) async {
        final older = [for (var i = 0; i < 40; i++) _numbered(s, i)];
        final daybook = await _open(
          tester,
          lang,
          posts: [...older, ...s.d1()],
          months: {
            '${DaybookSamples.space} 2026-10': DaybookMonth(
              postDays: {DateTime(2026, 10, 14), DateTime(2026, 10, 15)},
              dueDays: {DateTime(2026, 10, 16)},
            ),
          },
        );
        await tester.tap(find.byType(BvDaybookMasthead));
        await tester.pumpAndSettle();
        final month = tester.widget<BvMonthDropdown>(
          find.byType(BvMonthDropdown),
        );
        expect(month.firstWeekday, 0); // the Kuwait pack starts on Sunday
        expect(month.selected, DateTime(2026, 10, 15));
        expect(month.postDays, {14, 15});
        expect(month.dueDays, {16});
        expect(daybook.monthCalls, ['${DaybookSamples.space} 2026-10']);

        // The month before; then a September day, which is in an older page.
        await tester.tap(find.byKey(const Key('month-previous')));
        await tester.pumpAndSettle();
        expect(daybook.monthCalls.last, '${DaybookSamples.space} 2026-9');
        final pagesBefore = daybook.pageCalls.length;
        await tester.tap(find.byKey(const Key('month-day-2')));
        await tester.pumpAndSettle();
        expect(find.byType(BvMonthDropdown), findsNothing);
        expect(daybook.pageCalls.length, greaterThan(pagesBefore));
        expect(_masthead(tester).weekday, words.weekday(DateTime(2026, 9, 2)));
        expect(find.text('Item 4'), findsOneWidget);
      },
    );

    testWidgets('scrolling back loads older pages [$lang]', (tester) async {
      final older = [for (var i = 0; i < 45; i++) _numbered(s, i)];
      final daybook = await _open(tester, lang, posts: older);
      expect(daybook.pageCalls, hasLength(1));
      for (var i = 0; i < 30 && daybook.pageCalls.length < 2; i++) {
        await tester.drag(
          find.byKey(const Key('daybook')),
          const Offset(0, 900),
        );
        await tester.pumpAndSettle();
      }
      expect(daybook.pageCalls, hasLength(2));
      expect(find.text('Item 0', skipOffstage: false), findsOneWidget);
    });

    testWidgets('a page that fails to load says so [$lang]', (tester) async {
      final daybook = FakeDaybookRepository()..failPages = true;
      final spaces = FakeSpaceRepository()
        ..details[DaybookSamples.space] = s.detail();
      await pumpApp(tester, language: lang, spaces: spaces, daybook: daybook);
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
      expect(find.text(l10n.errorGeneric), findsOneWidget);
    });
  }
}
