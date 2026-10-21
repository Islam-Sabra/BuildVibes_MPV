// Review 53 Part D on the daybook: an Activity row, a push or a Needs you
// card opens the exact card (F20); the masthead names the day at the top
// (F23); every field rides on the keyboard (F24).
import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/core/routing/app_routes.dart';
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_target.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_day_divider.dart';
import 'package:buildvibes/shared/widgets/bv_daybook_masthead.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/push_fakes.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

final _now = DaybookSamples.thursday;

/// The phone's keyboard in F24's tests: 300 points.
const _keyboard = 300.0;
const _screen = Size(390, 844);

Future<TestApp> _app(
  WidgetTester tester,
  String lang, {
  required List<DaybookCard> posts,
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  FakeDaybookRepository? daybook,
  FakeActivityRepository? activity,
  FakePushMessaging? push,
}) {
  final s = DaybookSamples(lang);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail(
      pass: pass,
      admin: me == DaybookSamples.islam,
    )
    ..spacePeople[DaybookSamples.space] = s.people();
  final fake = (daybook ?? FakeDaybookRepository())
    ..posts[DaybookSamples.space] = posts;
  return pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: spaces,
    daybook: fake,
    activity: activity,
    push: push,
    now: _now,
  );
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

Finder _card(String id) => find.byKey(Key('daybook-card-$id'));

Finder _ring(String id) => find.descendant(
  of: _card(id),
  matching: find.byKey(const Key('bv-highlight-ring')),
);

/// The daybook's part of the screen.
Rect _viewport(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('daybook')));

bool _onScreen(WidgetTester tester, Finder f) {
  final r = tester.getRect(f);
  final v = _viewport(tester);
  return r.top >= v.top - 1 && r.bottom <= v.bottom + 1;
}

/// Pumps frames until [f] shows, for at most a second: the highlight is
/// caught while it is on.
Future<void> _pumpUntil(WidgetTester tester, Finder f) async {
  for (var i = 0; i < 20 && f.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Forty work items of Tuesday and Wednesday, newer than [old]: the first
/// page doesn't reach it.
List<DaybookCard> _manyAndOld(DaybookSamples s, DaybookCard old) => [
  old,
  for (var i = 0; i < 40; i++)
    s.card(
      s.item(
        id: 'post-n${i.toString().padLeft(2, '0')}',
        at: DateTime(2026, 10, 13, 7).add(Duration(minutes: 50 * i)),
        title: 'Item $i',
        authorId: DaybookSamples.sara,
        ownerId: DaybookSamples.omar,
      ),
    ),
];

/// Three days old (Monday 12 October), signed as done that day.
DaybookCard _old(DaybookSamples s) => s.card(
  s.item(
    id: 'post-old',
    at: DateTime(2026, 10, 12, 8),
    title: s.t('Formwork props, level 1', 'دعامات الشدة، الدور 1'),
    ref: 'KCT-003',
    authorId: DaybookSamples.islam,
    ownerId: DaybookSamples.omar,
    status: WorkStatus.done,
  ),
  events: [
    s.event(
      'ev-old-done',
      DaybookEventKind.done,
      DateTime(2026, 10, 12, 9, 30),
      DaybookSamples.omar,
      note: s.t('Props tightened.', 'شُدّت الدعامات.'),
    ),
  ],
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final words = DaybookWords(l10n, lang, use24: false);
    final s = DaybookSamples(lang);

    // F20: the exact card.

    testWidgets('F20: a card three days old, past the first page: the '
        'daybook loads down to it, it is on screen and highlighted for '
        'about a second [$lang]', (tester) async {
      final app = await _app(tester, lang, posts: _manyAndOld(s, _old(s)));
      _router(
        tester,
      ).push(AppRoutes.spaceCard(DaybookSamples.space, 'post-old'));
      await _pumpUntil(tester, _ring('post-old'));
      expect(_ring('post-old'), findsOneWidget);
      // More than the first page was read, from Now down to it.
      expect(app.daybook.pageCalls.length, greaterThan(1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_onScreen(tester, _card('post-old')), isTrue);
      // The masthead names its day.
      expect(
        tester.widget<BvDaybookMasthead>(find.byType(BvDaybookMasthead)).date,
        words.dayMonth(DateTime(2026, 10, 12)),
      );
      await tester.pumpAndSettle();
      // About a second, then it fades.
      expect(_ring('post-old'), findsNothing);
      expect(_onScreen(tester, _card('post-old')), isTrue);
    });

    testWidgets('F20: for an event, the card opens with its history at that '
        'line [$lang]', (tester) async {
      await _app(tester, lang, posts: s.d1());
      _router(tester).push(
        AppRoutes.spaceCard(
          DaybookSamples.space,
          'post-sleeves',
          eventId: 'ev-sleeves-c1',
        ),
      );
      await tester.pumpAndSettle();
      // Wednesday's update is older than the last three lines: the
      // history is open, and the line is on screen.
      final line = find.descendant(
        of: _card('post-sleeves'),
        matching: find.textContaining(s.sleevesWedUpdate, findRichText: true),
      );
      expect(line, findsOneWidget);
      expect(_onScreen(tester, line), isTrue);
    });

    testWidgets('F20: an event past the card\'s first 50 lines is read with '
        'Show earlier [$lang]', (tester) async {
      final sleeves = s.sleevesCard();
      final early = s.event(
        'ev-early',
        DaybookEventKind.comment,
        DateTime(2026, 10, 14, 15, 40),
        DaybookSamples.omar,
        note: s.t('Marked the grid.', 'علّمت المحاور.'),
      );
      final daybook = FakeDaybookRepository()
        ..earlier['post-sleeves'] = [early];
      await _app(
        tester,
        lang,
        posts: [sleeves.copyWith(historyMore: true), s.rebar()],
        daybook: daybook,
      );
      _router(tester).push(
        AppRoutes.spaceCard(
          DaybookSamples.space,
          'post-sleeves',
          eventId: 'ev-early',
        ),
      );
      await tester.pumpAndSettle();
      expect(daybook.historyCalls, contains('post-sleeves'));
      final line = find.descendant(
        of: _card('post-sleeves'),
        matching: find.textContaining(early.note!, findRichText: true),
      );
      expect(line, findsOneWidget);
      expect(_onScreen(tester, line), isTrue);
    });

    testWidgets('F20: a deleted post: "This was removed" [$lang]', (
      tester,
    ) async {
      await _app(tester, lang, posts: s.d1());
      _router(
        tester,
      ).push(AppRoutes.spaceCard(DaybookSamples.space, 'post-gone'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.daybookRemoved), findsOneWidget);
      // The Space is open, on its daybook.
      expect(find.byType(SpaceScreen), findsOneWidget);
      expect(_card('post-sleeves'), findsOneWidget);
    });

    testWidgets('F20: an Activity row opens its card at its event; a Needs '
        'you card at its card [$lang]', (tester) async {
      final activity = FakeActivityRepository(
        rows: [
          ActivityRow(
            id: 'a1',
            kind: ActivityKind.itemDone,
            createdAt: DaybookSamples.sleevesFirstDoneAt,
            spaceId: DaybookSamples.space,
            spaceName: s.spaceName,
            workItemId: 'post-sleeves',
            workItemRef: 'KCT-014',
            workItemTitle: s.sleeves,
            actorId: DaybookSamples.omar,
            actorName: s.omarName,
            read: true,
            eventId: 'ev-sleeves-done1',
          ),
        ],
        cards: [
          NeedsCard(
            kind: NeedsKind.youCheck,
            spaceId: DaybookSamples.space,
            spaceName: s.spaceName,
            at: DaybookSamples.sleevesDoneAt,
            workItemId: 'post-sleeves',
            workItemRef: 'KCT-014',
            workItemTitle: s.sleeves,
            actorName: s.omarName,
          ),
        ],
      );
      await _app(tester, lang, posts: s.d1(), activity: activity);
      await tester.tap(find.byKey(const Key('nav-activity')));
      await tester.pumpAndSettle();
      final row = find.byKey(const Key('activity-row-a1'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SpaceScreen>(find.byType(SpaceScreen)).target,
        const DaybookTarget('post-sleeves', eventId: 'ev-sleeves-done1'),
      );
      _router(tester).pop();
      await tester.pumpAndSettle();

      _router(tester).push(AppRoutes.needs);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(s.sleeves).first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SpaceScreen>(find.byType(SpaceScreen)).target,
        const DaybookTarget('post-sleeves'),
      );
      expect(_card('post-sleeves'), findsOneWidget);
    });

    testWidgets('F20: a tapped push about a work item opens its card '
        '[$lang]', (tester) async {
      final push = FakePushMessaging(
        current: PushPermission.granted,
        firstTap: {
          'kind': 'item_done',
          'route': '/spaces/${DaybookSamples.space}/items/post-sleeves',
          'space_id': DaybookSamples.space,
          'work_item_id': 'post-sleeves',
        },
      );
      await _app(tester, lang, posts: s.d1(), push: push);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SpaceScreen>(find.byType(SpaceScreen)).target,
        const DaybookTarget('post-sleeves'),
      );
      // Taller than the page: it fills it.
      expect(
        tester.getRect(_card('post-sleeves')).overlaps(_viewport(tester)),
        isTrue,
      );
    });

    // F23: the masthead and the dividers.

    testWidgets('F23, F59: at Now the masthead reads Today; scrolled back it '
        'names the day at the top, with the Today chip; the chip goes back '
        '[$lang]', (tester) async {
      DaybookCard on(String id, DateTime at) => s.card(
        s.item(
          id: id,
          at: at,
          title: 'Item $id',
          authorId: DaybookSamples.sara,
          ownerId: DaybookSamples.omar,
        ),
      );
      final wednesday = DateTime(2026, 10, 14);
      await _app(
        tester,
        lang,
        posts: [
          for (var i = 0; i < 6; i++)
            on('post-w$i', DateTime(2026, 10, 14, 8 + i)),
          for (var i = 0; i < 6; i++)
            on('post-t$i', DateTime(2026, 10, 15, 7, 10 * i)),
        ],
      );
      _router(tester).push(AppRoutes.space(DaybookSamples.space));
      await tester.pumpAndSettle();
      BvDaybookMasthead masthead() =>
          tester.widget<BvDaybookMasthead>(find.byType(BvDaybookMasthead));
      bool shows(DateTime day) => tester
          .widget<Visibility>(
            find.byKey(Key('daybook-divider-${day.toIso8601String()}')),
          )
          .visible;
      final today = DateTime(2026, 10, 15);
      final todayChip = find.byKey(const Key('daybook-today'));
      // At Now: Today, then the date.
      expect(masthead().weekday, l10n.daybookTodayDivider);
      expect(
        masthead().date,
        l10n.daybookMastheadToday(words.compactDate(today)),
      );
      expect(find.byType(BvDayDivider), findsNWidgets(2));
      expect(shows(today), isTrue);
      expect(todayChip, findsNothing);
      // Back to Wednesday.
      await tester.drag(
        find.byKey(const Key('daybook')),
        const Offset(0, 3000),
      );
      await tester.pumpAndSettle();
      expect(masthead().weekday, words.weekday(wednesday));
      expect(masthead().date, words.dayMonth(wednesday));
      // Wednesday is in the masthead; its divider doesn't repeat it.
      expect(shows(wednesday), isFalse);
      expect(shows(today), isTrue);
      expect(todayChip, findsOneWidget);
      // The chip goes back to Now and Today.
      await tester.tap(todayChip);
      await tester.pumpAndSettle();
      expect(masthead().weekday, l10n.daybookTodayDivider);
      expect(todayChip, findsNothing);
    });

    testWidgets('F59: nothing yet today, yesterday filling the page: the '
        'masthead still reads Today, above a Today divider and "Nothing yet '
        'today" [$lang]', (tester) async {
      await _app(
        tester,
        lang,
        posts: [
          for (var i = 0; i < 6; i++)
            s.card(
              s.item(
                id: 'post-y$i',
                at: DateTime(2026, 10, 14, 8 + i),
                title: 'Item $i',
                authorId: DaybookSamples.sara,
                ownerId: DaybookSamples.omar,
              ),
            ),
        ],
      );
      _router(tester).push(AppRoutes.space(DaybookSamples.space));
      await tester.pumpAndSettle();
      final today = DateTime(2026, 10, 15);
      final masthead = tester.widget<BvDaybookMasthead>(
        find.byType(BvDaybookMasthead),
      );
      expect(masthead.weekday, l10n.daybookTodayDivider);
      final divider = find.byKey(
        Key('daybook-divider-${today.toIso8601String()}'),
      );
      expect(tester.widget<Visibility>(divider).visible, isTrue);
      final nothing = find.byKey(const Key('daybook-nothing-today'));
      expect(find.text(l10n.daybookNothingYetToday), findsOneWidget);
      // Yesterday's cards sit above the divider; the line under it.
      expect(
        tester.getBottomLeft(_card('post-y5')).dy,
        lessThan(tester.getTopLeft(divider).dy),
      );
      expect(
        tester.getTopLeft(nothing).dy,
        greaterThan(tester.getBottomLeft(divider).dy),
      );
    });

    // F24: the keyboard.

    /// [f] is whole on screen, above a 300-point keyboard.
    void aboveKeyboard(WidgetTester tester, Finder f) {
      final r = tester.getRect(f);
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(_screen.height - _keyboard + 0.5));
    }

    Future<void> keyboardUp(WidgetTester tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      addTearDown(tester.view.resetViewInsets);
      // From the first frame.
      await tester.pump();
    }

    Future<void> menu(WidgetTester tester, String id, String pick) async {
      await tester.ensureVisible(_card(id));
      await tester.pumpAndSettle();
      await tester.longPress(
        find.descendant(of: _card(id), matching: find.byType(BvSlip)).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('slip-menu')),
          matching: find.text(pick),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('F24: Add update sits on a 300-point keyboard; the item is '
        'quoted in one line with a small thumbnail [$lang]', (tester) async {
      await _app(tester, lang, posts: s.d1());
      _router(tester).push(AppRoutes.space(DaybookSamples.space));
      await tester.pumpAndSettle();
      await menu(tester, 'post-sleeves', l10n.daybookAddUpdate);
      await keyboardUp(tester);
      aboveKeyboard(tester, find.byKey(const Key('bv-send-field')));
      aboveKeyboard(tester, find.byKey(const Key('bv-send-field-send')));
      final quote = find.byKey(const Key('bv-item-quote'));
      aboveKeyboard(tester, quote);
      expect(
        find.descendant(of: quote, matching: find.textContaining(s.sleeves)),
        findsOneWidget,
      );
      expect(tester.getSize(quote).height, lessThanOrEqualTo(44));
      expect(
        tester.getSize(find.byKey(const Key('bv-item-quote-thumb'))),
        const Size(32, 32),
      );
      // The whole card isn't lifted over the page any more.
      expect(find.byKey(const Key('bv-field-sheet')), findsOneWidget);
    });

    testWidgets('F24: the send-back sheet and its note sit on the keyboard '
        '[$lang]', (tester) async {
      await _app(tester, lang, posts: s.d1());
      _router(tester).push(AppRoutes.space(DaybookSamples.space));
      await tester.pumpAndSettle();
      await menu(tester, 'post-sleeves', l10n.daybookSendBack);
      await tester.tap(find.text(l10n.daybookReasonOther));
      await tester.pumpAndSettle();
      // With the new date's choice above the note (F62).
      await tester.tap(find.byKey(const Key('send-back-due-tomorrow')));
      await tester.pumpAndSettle();
      await keyboardUp(tester);
      final sheet = find.byKey(const Key('send-back-card'));
      aboveKeyboard(
        tester,
        find.descendant(of: sheet, matching: find.byType(TextField)),
      );
      aboveKeyboard(
        tester,
        find.descendant(of: sheet, matching: find.text(l10n.daybookSendBack)),
      );
    });

    testWidgets('F24: the proof note and Send as done sit on the keyboard '
        '[$lang]', (tester) async {
      await _app(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      _router(tester).push(AppRoutes.space(DaybookSamples.space));
      await tester.pumpAndSettle();
      final sign = find.descendant(
        of: _card('post-sleeves'),
        matching: find.text(l10n.daybookSignAsDone),
      );
      // In the middle of the page, clear of the Today chip (F59).
      await Scrollable.ensureVisible(tester.element(sign.last), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(sign.last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proof-without-photo')));
      await tester.pumpAndSettle();
      await keyboardUp(tester);
      aboveKeyboard(tester, find.byKey(const Key('proof-note')));
      aboveKeyboard(tester, find.byKey(const Key('proof-send')));
    });

    testWidgets('F24: the writing card\'s Location field sits on the '
        'keyboard [$lang]', (tester) async {
      await _app(tester, lang, posts: s.d1());
      _router(tester).push(AppRoutes.space(DaybookSamples.space));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post-bar-notepad')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(l10n.daybookMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.daybookLocation));
      await tester.pumpAndSettle();
      await keyboardUp(tester);
      aboveKeyboard(tester, find.byKey(const Key('popover-field')));
    });
  }
}
