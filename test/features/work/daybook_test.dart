import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/spaces/invite_screen.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_day_divider.dart';
import 'package:buildvibes/shared/widgets/bv_daybook_masthead.dart';
import 'package:buildvibes/shared/widgets/bv_daybook_spine.dart';
import 'package:buildvibes/shared/widgets/bv_due_today_strip.dart';
import 'package:buildvibes/shared/widgets/bv_first_page.dart';
import 'package:buildvibes/shared/widgets/bv_month_dropdown.dart';
import 'package:buildvibes/shared/widgets/bv_paper_clip.dart';
import 'package:buildvibes/shared/widgets/bv_post_bar.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:buildvibes/shared/widgets/bv_update_note.dart';
import 'package:buildvibes/core/design/daybook_paper_specs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

DaybookWords _words(String lang) =>
    DaybookWords(_l10n(lang), lang, use24: false);

Future<FakeDaybookRepository> _open(
  WidgetTester tester,
  String lang, {
  required List<DaybookRecord> posts,
  DateTime? now,
  SpacePass pass = SpacePass.lead,
  bool admin = true,
  List<CalendarWorkItem> calendar = const [],
  Map<String, DaybookMonth> months = const {},
}) async {
  final s = DaybookSamples(lang);
  final daybook = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = posts
    ..calendar.addAll(calendar)
    ..months.addAll(months);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail(pass: pass, admin: admin);
  await pumpApp(
    tester,
    language: lang,
    spaces: spaces,
    daybook: daybook,
    now: now ?? DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return daybook;
}

BvDaybookMasthead _masthead(WidgetTester tester) =>
    tester.widget<BvDaybookMasthead>(find.byType(BvDaybookMasthead));

DaybookPost _numbered(DaybookSamples s, int i) => s.item(
  id: 'post-${i.toString().padLeft(3, '0')}',
  at: DateTime(2026, 9, 1).add(Duration(hours: 6 * i)),
  title: 'Item $i',
  authorId: DaybookSamples.sara,
  authorName: s.saraName,
  ownerId: DaybookSamples.omar,
  ownerName: s.omarName,
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final words = _words(lang);
    final s = DaybookSamples(lang);

    testWidgets('D1: today\'s masthead, day 41, slips on the spine [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, posts: s.d1());
      expect(_masthead(tester).weekday, words.weekday(DaybookSamples.thursday));
      expect(
        find.text(
          l10n.daybookDateLine(words.dayMonth(DateTime(2026, 10, 15)), 41),
        ),
        findsOneWidget,
      );
      // Newest at the bottom.
      final sleeves = tester.getTopLeft(find.text(s.sleeves).first).dy;
      final rebar = tester
          .getTopLeft(find.byKey(const Key('daybook-entry-post-rebar')))
          .dy;
      expect(rebar, greaterThan(sleeves));
      // On the spine, the part of the day on its own line (F15).
      final at = words.spineClock(DateTime(2026, 10, 15, 8, 14));
      expect(find.text(at.time), findsOneWidget);
      if (at.period != null) expect(find.text(at.period!), findsWidgets);
      // My own post says "You"; the meta names the owner and the due.
      expect(find.text(l10n.daybookYou), findsWidgets);
      expect(
        find.text(
          words.meta(
            s.sleevesDone(),
            me: DaybookSamples.islam,
            now: DaybookSamples.thursday,
          ),
        ),
        findsOneWidget,
      );
      // DONE on the item, and the large one on Omar's proof.
      expect(find.text(l10n.daybookStampDone), findsNWidgets(2));
      expect(find.text(l10n.daybookPoints(2)), findsWidgets);
      expect(find.text(l10n.daybookFileChip('M-201', 'Rev C')), findsOneWidget);
      expect(find.text(s.levelTwo), findsOneWidget);
      // The edit of the due, and the clips on what needs me.
      expect(
        find.text(words.editedDue(s.rebar().dueEdit, DaybookSamples.thursday)!),
        findsOneWidget,
      );
      expect(find.byType(BvPaperClip), findsNWidgets(2));
      expect(find.byType(BvPostBar), findsOneWidget);
      expect(find.text(l10n.daybookWorkItem), findsOneWidget);
    });

    testWidgets('D1: the proof slip: quote, photo, large stamp, note, hint '
        '[$lang]', (tester) async {
      await _open(tester, lang, posts: s.d1());
      final proof = find.byKey(const Key('daybook-entry-event-sleeves-done'));
      Finder inProof(Finder f) => find.descendant(of: proof, matching: f);
      expect(inProof(find.text(s.omarName)), findsOneWidget);
      expect(inProof(find.text(l10n.daybookSignedAsDone)), findsOneWidget);
      expect(inProof(find.byType(BvSlipQuote)), findsOneWidget);
      expect(inProof(find.text(s.sleeves)), findsOneWidget);
      expect(inProof(find.text(s.sleevesNote)), findsOneWidget);
      // The large stamp sits on the 190 photo, with Omar's short name.
      final photo = tester.widget<BvSlipPhoto>(
        inProof(find.byType(BvSlipPhoto)),
      );
      expect(photo.height, BvSlipSpec.photoHeightProof);
      final stamp = photo.stamp! as BvInkStamp;
      expect(stamp.size, BvInkStampSize.lg);
      expect(stamp.label, l10n.daybookStampDone);
      expect(
        stamp.subline,
        words.stampLine(s.omarName, DateTime(2026, 10, 15, 9, 40)),
      );
      // Mine to check: the hint and the clip.
      expect(inProof(find.text(l10n.daybookDoubleTapToCheck)), findsOneWidget);
      expect(inProof(find.byType(BvPaperClip)), findsOneWidget);
      // The item's own slip has no clip now (review 45 M2).
      expect(
        find.descendant(
          of: find.byKey(const Key('daybook-entry-post-sleeves')),
          matching: find.byType(BvPaperClip),
        ),
        findsNothing,
      );
    });

    testWidgets('a proof checked, sent back, or of a cancelled item [$lang]', (
      tester,
    ) async {
      final at = DateTime(2026, 10, 15, 10, 12);
      DaybookSignOff signOff(String id, DaybookOutcome outcome, int minute) =>
          DaybookSignOff(
            id: id,
            at: DateTime(2026, 10, 15, 9, minute),
            postId: 'post-sleeves',
            title: s.sleeves,
            actorId: DaybookSamples.omar,
            actorName: s.omarName,
            photos: const [WorkPhoto(path: 'p.jpg')],
            outcome: outcome,
          );
      await _open(
        tester,
        lang,
        posts: [
          s.sleevesDone(),
          signOff(
            'e-1',
            DaybookOutcome(
              kind: DaybookOutcomeKind.sentBack,
              at: at,
              byName: s.islamName,
            ),
            0,
          ),
          signOff(
            'e-2',
            DaybookOutcome(
              kind: DaybookOutcomeKind.checked,
              at: at,
              byName: s.islamName,
            ),
            20,
          ),
          signOff(
            'e-3',
            const DaybookOutcome(kind: DaybookOutcomeKind.cancelled),
            40,
          ),
        ],
      );
      BvInkStamp stampOf(String id) =>
          tester
                  .widget<BvSlipPhoto>(
                    find.descendant(
                      of: find.byKey(Key('daybook-entry-$id')),
                      matching: find.byType(BvSlipPhoto),
                    ),
                  )
                  .stamp!
              as BvInkStamp;
      expect(stampOf('e-1').label, l10n.daybookStampSentBack);
      expect(stampOf('e-1').tone, BvInkStampTone.destructive);
      expect(stampOf('e-2').label, l10n.daybookStampChecked);
      expect(stampOf('e-2').subline, words.stampLine(s.islamName, at));
      expect(stampOf('e-3').label, l10n.daybookStampCancelled);
      expect(
        find.descendant(
          of: find.byKey(const Key('daybook-entry-e-3')),
          matching: find.byKey(const Key('slip-cancelled')),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.daybookDoubleTapToCheck), findsNothing);
    });

    testWidgets('an update quotes its item; given to someone else [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        posts: [
          s.item(
            id: 'post-trays',
            at: DateTime(2026, 10, 15, 8),
            title: s.cableTraysTitle,
            authorId: DaybookSamples.islam,
            authorName: s.islamName,
            ownerId: DaybookSamples.rakesh,
            ownerName: s.rakeshName,
            givenTo: DaybookGivenTo(
              at: DateTime(2026, 10, 15, 12, 30),
              fromName: s.omarName,
              toName: s.rakeshName,
            ),
          ),
          DaybookUpdate(
            id: 'e-update',
            at: DateTime(2026, 10, 15, 13),
            postId: 'post-trays',
            title: s.cableTraysTitle,
            actorId: DaybookSamples.rakesh,
            actorName: s.rakeshName,
            note: 'Half done',
          ),
        ],
      );
      expect(
        find.text(
          l10n.daybookGivenTo(
            s.rakeshName,
            s.omarName,
            words.clock(DateTime(2026, 10, 15, 12, 30)),
          ),
        ),
        findsOneWidget,
      );
      // Y2: a small note quoting the item, the writer's face and words.
      final update = find.byKey(const Key('daybook-entry-e-update'));
      expect(
        find.descendant(of: update, matching: find.byType(BvUpdateNote)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: update, matching: find.text(s.cableTraysTitle)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: update, matching: find.text('Half done')),
        findsOneWidget,
      );
    });

    testWidgets('B1: a newest page with nothing to show loads the older one '
        '[$lang]', (tester) async {
      // 30 announcements (slice 2) fill the first page; the work item
      // before them still shows, with no scrolling.
      final announcements = [
        for (var i = 0; i < 30; i++)
          DaybookPost(
            id: 'ann-${i.toString().padLeft(2, '0')}',
            kind: 'announcement',
            createdAt: DateTime(2026, 10, 15, 9, i),
            title: 'Notice $i',
          ),
      ];
      final daybook = await _open(
        tester,
        lang,
        posts: [s.gate(), ...announcements],
      );
      expect(daybook.pageCalls, hasLength(2));
      expect(find.byKey(const Key('daybook-entry-post-gate')), findsOneWidget);
    });

    testWidgets(
      'the dots: needs you orange, checked green, else quiet [$lang]',
      (tester) async {
        await _open(tester, lang, posts: s.d1());
        BvSpineDot dot(String id) => tester
            .widget<BvSpineEntry>(find.byKey(Key('daybook-entry-$id')))
            .dot;
        // The clip for my check is on Omar's sign-off, not on the item.
        expect(dot('post-sleeves'), BvSpineDot.quiet);
        expect(dot('event-sleeves-done'), BvSpineDot.needsYou);
        expect(dot('post-rebar'), BvSpineDot.needsYou);
        await tester.drag(
          find.byKey(const Key('daybook')),
          const Offset(0, 600),
        );
        await tester.pumpAndSettle();
        expect(dot('post-gate'), BvSpineDot.checked);
      },
    );

    testWidgets('DY1: a divider between days; the masthead follows [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, posts: s.d1());
      final divider = tester.widget<BvDayDivider>(find.byType(BvDayDivider));
      expect(divider.weekday, words.weekday(DateTime(2026, 10, 15)));
      expect(divider.date, words.dayMonth(DateTime(2026, 10, 15)));
      // Back to yesterday: the masthead names Wednesday, day 40.
      await tester.drag(find.byKey(const Key('daybook')), const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(_masthead(tester).weekday, words.weekday(DateTime(2026, 10, 14)));
      expect(
        find.text(
          l10n.daybookDateLine(words.dayMonth(DateTime(2026, 10, 14)), 40),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no On site since: the date only [$lang]', (tester) async {
      final daybook = FakeDaybookRepository()
        ..posts[DaybookSamples.space] = s.d1();
      final spaces = FakeSpaceRepository()
        ..details[DaybookSamples.space] = SpaceDetail(
          id: DaybookSamples.space,
          name: s.spaceName,
          myPass: SpacePass.lead,
          iAmAdmin: true,
          myRights: const MemberRights(createItems: true),
        );
      await pumpApp(
        tester,
        language: lang,
        spaces: spaces,
        daybook: daybook,
        now: DaybookSamples.thursday,
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
      expect(find.text(words.dayMonth(DateTime(2026, 10, 15))), findsWidgets);
      expect(find.textContaining('41'), findsNothing);
    });

    testWidgets('L1: Late by 1 day and the Due today strip [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        posts: s.l1(),
        now: DaybookSamples.friday,
        calendar: [
          s.cableTraysDue(),
          // Another Space's, and one already done: not on this strip.
          CalendarWorkItem(
            spaceId: 'other',
            title: 'Elsewhere',
            day: DateTime(2026, 10, 16),
            status: WorkStatus.open,
          ),
          CalendarWorkItem(
            spaceId: DaybookSamples.space,
            title: 'Signed',
            day: DateTime(2026, 10, 16),
            status: WorkStatus.done,
          ),
        ],
      );
      expect(find.text(l10n.daybookLate(1)), findsOneWidget);
      expect(find.byType(BvSlipLate), findsOneWidget);
      expect(
        find.text(l10n.daybookDueTodayStrip(s.cableTraysTitle)),
        findsOneWidget,
      );
      expect(find.byType(BvDueTodayStrip), findsOneWidget);
      // The strip sits under the masthead, above the diary.
      expect(
        tester.getTopLeft(find.byType(BvDueTodayStrip)).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('daybook'))).dy + 1),
      );
    });

    testWidgets('V1: a Viewer reads only: no clips, the pass chip [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        // Even if the server said so, a Viewer's slip shows no clip.
        posts: s.d1(),
        pass: SpacePass.viewer,
        admin: false,
      );
      expect(find.byType(BvPaperClip), findsNothing);
      expect(find.text(l10n.daybookDoubleTapToCheck), findsNothing);
      expect(find.byType(BvPassChip), findsOneWidget);
      expect(find.text(l10n.spacesPassViewer), findsOneWidget);
      expect(find.text(l10n.daybookReadOnly), findsOneWidget);
      expect(find.text(l10n.daybookWorkItem), findsNothing);
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
      // The spine is still drawn.
      expect(find.byKey(const Key('daybook-spine-line')), findsOneWidget);
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

    testWidgets('other kinds of post wait for slice 2 [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [
          s.rebar(),
          DaybookPost(
            id: 'post-ann',
            kind: 'announcement',
            createdAt: DateTime(2026, 10, 15, 9),
            title: 'Crane closed today',
          ),
        ],
      );
      expect(find.text('Crane closed today'), findsNothing);
      expect(find.byType(BvSlip), findsOneWidget);
      expect(find.byType(BvFirstPage), findsNothing);
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
