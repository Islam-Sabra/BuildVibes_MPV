// Review 51 Part B: the daybook is never stale (F11) and a work item made
// with no signal is one slip without "Waiting to send" once it is sent
// (F17).
import 'dart:convert';

import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _outboxKey = 'work_outbox:${DaybookSamples.islam}';

/// The Space's daybook as Islam (Lead).
Future<TestApp> _open(
  WidgetTester tester,
  String lang,
  FakeDaybookRepository daybook, {
  List<DaybookRecord>? posts,
  List<Duration> retryLater = const [Duration(seconds: 30)],
  Map<String, Object> stored = const {},
}) async {
  final s = DaybookSamples(lang);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail()
    ..spacePeople[DaybookSamples.space] = s.people();
  daybook.posts[DaybookSamples.space] ??= posts ?? s.d1();
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: spaces,
    daybook: daybook,
    now: DaybookSamples.thursday,
    retryLater: retryLater,
    stored: stored,
  );
  _router(tester).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

/// Sara gives Omar a work item while Islam has the daybook open.
DaybookPost _saraPosts(DaybookSamples s, String title, {int minute = 20}) =>
    s.item(
      id: 'post-new-$minute',
      at: DateTime(2026, 10, 15, 10, minute),
      title: title,
      authorId: DaybookSamples.sara,
      authorName: s.saraName,
      ownerId: DaybookSamples.omar,
      ownerName: s.omarName,
    );

/// Ten days of work items before today, so the page scrolls.
List<DaybookRecord> _weeks(DaybookSamples s) => [
  for (var d = 1; d <= 10; d++)
    s.item(
      id: 'post-old-$d',
      at: DateTime(2026, 10, 15 - d, 9),
      title: 'Older item $d',
      authorId: DaybookSamples.islam,
      authorName: s.islamName,
      ownerId: DaybookSamples.omar,
      ownerName: s.omarName,
    ),
  ...s.d1(),
];

Future<void> _writeOffline(
  WidgetTester tester,
  DaybookSamples s,
  FakeDaybookRepository daybook,
) async {
  daybook.offline = true;
  await tester.tap(find.byKey(const Key('post-bar-notepad')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('writing-title')),
    s.cableTraysTitle,
  );
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(tester.element(find.byType(BvWritingCard)));
  await tester.tap(find.bySemanticsLabel(l10n.daybookMore));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.daybookAssign));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(BvGiveToPicker),
      matching: find.text(s.omarName),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('writing-post')));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);
    final fresh = s.t('Pump truck at gate 3', 'شاحنة المضخة عند البوابة 3');

    testWidgets('F11: a push opens the Space on its newest page, even with '
        'the Space already open underneath [$lang]', (tester) async {
      final daybook = FakeDaybookRepository();
      final app = await _open(tester, lang, daybook);
      daybook.posts[DaybookSamples.space]!.add(_saraPosts(s, fresh));
      app.push.tap({
        'kind': 'work_item_given',
        'route': '/spaces/${DaybookSamples.space}/items/post-new-20',
        'space_id': DaybookSamples.space,
      });
      await tester.pumpAndSettle();
      expect(find.text(fresh), findsOneWidget);
      // The one underneath is current too.
      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(find.text(fresh), findsOneWidget);
    });

    testWidgets('F11: back to the app, the daybook reads again [$lang]', (
      tester,
    ) async {
      final daybook = FakeDaybookRepository();
      await _open(tester, lang, daybook);
      daybook.posts[DaybookSamples.space]!.add(_saraPosts(s, fresh));
      await backToTheApp(tester);
      expect(find.text(fresh), findsOneWidget);
    });

    testWidgets('F11: a push for this Space while it is open reads it again; '
        'one for another Space doesn\'t [$lang]', (tester) async {
      final daybook = FakeDaybookRepository();
      final app = await _open(tester, lang, daybook);
      daybook.posts[DaybookSamples.space]!.add(_saraPosts(s, fresh));
      final reads = daybook.pageCalls.length;
      app.push.arrive({'kind': 'join_request', 'space_id': 'space-other'});
      await tester.pumpAndSettle();
      expect(daybook.pageCalls, hasLength(reads));
      expect(find.text(fresh), findsNothing);
      app.push.arrive({
        'kind': 'work_item_given',
        'space_id': DaybookSamples.space,
      });
      await tester.pumpAndSettle();
      expect(find.text(fresh), findsOneWidget);
    });

    testWidgets('F11: shown again after a page on top closes, it reads '
        'again [$lang]', (tester) async {
      final daybook = FakeDaybookRepository();
      await _open(tester, lang, daybook);
      _router(tester).push('/spaces/${DaybookSamples.space}/info');
      await tester.pumpAndSettle();
      daybook.posts[DaybookSamples.space]!.add(_saraPosts(s, fresh));
      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(find.text(fresh), findsOneWidget);
    });

    testWidgets('F11: pull down to refresh, however short the page [$lang]', (
      tester,
    ) async {
      final daybook = FakeDaybookRepository();
      // One slip: the page is shorter than the screen.
      await _open(tester, lang, daybook, posts: [s.rebar()]);
      daybook.posts[DaybookSamples.space]!.add(_saraPosts(s, fresh));
      await tester.fling(
        find.byKey(const Key('daybook')),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text(fresh), findsOneWidget);
    });

    testWidgets('F11: reading older days, new entries don\'t move the page; '
        '"New" takes the reader to Now [$lang]', (tester) async {
      final daybook = FakeDaybookRepository();
      await _open(tester, lang, daybook, posts: _weeks(s));
      // Back through older days (the list runs bottom up).
      await tester.drag(find.byKey(const Key('daybook')), const Offset(0, 500));
      await tester.pumpAndSettle();
      final read = [
        for (var d = 1; d <= 10; d++) 'Older item $d',
      ].firstWhere((t) => find.text(t).evaluate().isNotEmpty);
      final before = tester.getTopLeft(find.text(read));
      expect(find.byKey(const Key('daybook-new')), findsNothing);

      daybook.posts[DaybookSamples.space]!.add(_saraPosts(s, fresh));
      await backToTheApp(tester);
      expect(tester.getTopLeft(find.text(read)), before);
      expect(find.byKey(const Key('daybook-new')), findsOneWidget);
      expect(find.text(l10n.daybookNew), findsOneWidget);

      await tester.tap(find.byKey(const Key('daybook-new')));
      await tester.pumpAndSettle();
      expect(find.text(fresh), findsOneWidget);
      expect(find.byKey(const Key('daybook-new')), findsNothing);
    });

    testWidgets('F11: at Now, new entries just come in, with no chip '
        '[$lang]', (tester) async {
      final daybook = FakeDaybookRepository();
      await _open(tester, lang, daybook, posts: _weeks(s));
      daybook.posts[DaybookSamples.space]!.add(_saraPosts(s, fresh));
      await backToTheApp(tester);
      expect(find.text(fresh), findsOneWidget);
      expect(find.byKey(const Key('daybook-new')), findsNothing);
    });

    testWidgets('F17: made with no signal, then the signal is back: one slip, '
        'without "Waiting to send", within seconds [$lang]', (tester) async {
      final daybook = FakeDaybookRepository()
        ..asPosted = (i) => s.posted(i, DateTime(2026, 10, 15, 10, 30));
      final app = await _open(
        tester,
        lang,
        daybook,
        retryLater: const [Duration(seconds: 2)],
      );
      await _writeOffline(tester, s, daybook);
      expect(find.text(s.cableTraysTitle), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsOneWidget);

      // The signal is back: the outbox tries again by itself.
      daybook.offline = false;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(daybook.created, hasLength(1));
      expect(find.text(s.cableTraysTitle), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      expect(app.prefs.getString(_outboxKey), '[]');
    });

    testWidgets('F17: sent, but the page couldn\'t read it back yet: the '
        'label goes at once, still one slip [$lang]', (tester) async {
      final daybook = FakeDaybookRepository()
        ..asPosted = (i) => s.posted(i, DateTime(2026, 10, 15, 10, 30));
      final app = await _open(tester, lang, daybook);
      await _writeOffline(tester, s, daybook);
      // Sending works; the page read after it doesn't.
      daybook
        ..offline = false
        ..failPages = true;
      await backToTheApp(tester);
      expect(daybook.created, hasLength(1));
      expect(find.text(s.cableTraysTitle), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      expect(app.prefs.getString(_outboxKey), contains('"sent":true'));

      daybook.failPages = false;
      await backToTheApp(tester);
      expect(find.text(s.cableTraysTitle), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      expect(app.prefs.getString(_outboxKey), '[]');
      expect(daybook.created, hasLength(1));
    });

    for (final onServer in [false, true]) {
      testWidgets('F17: after the app is opened again, one slip without the '
          'label (${onServer ? 'it had reached the server' : 'sent on '
                    'opening'}) [$lang]', (tester) async {
        final daybook = FakeDaybookRepository()
          ..asPosted = (i) => s.posted(i, DateTime(2026, 10, 15, 10, 30));
        final app = await _open(tester, lang, daybook);
        await _writeOffline(tester, s, daybook);
        final kept = app.prefs.getString(_outboxKey)!;
        daybook.offline = false;
        if (onServer) {
          // It reached the server, but the answer was lost.
          final item = (jsonDecode(kept) as List).single as Map;
          daybook.posts[DaybookSamples.space]!.add(
            s.item(
              id: item['id'] as String,
              at: DateTime(2026, 10, 15, 10, 30),
              title: s.cableTraysTitle,
              authorId: DaybookSamples.islam,
              authorName: s.islamName,
              ownerId: DaybookSamples.omar,
              ownerName: s.omarName,
            ),
          );
          // Sent again, the server keeps the one it has.
          daybook.asPosted = null;
        }

        // Closed, then opened again.
        await tester.pumpWidget(const SizedBox());
        final again = await _open(
          tester,
          lang,
          daybook,
          stored: {_outboxKey: kept},
        );
        expect(find.text(s.cableTraysTitle), findsOneWidget);
        expect(find.text(l10n.daybookWaitingToSend), findsNothing);
        expect(again.prefs.getString(_outboxKey), '[]');
        expect(
          daybook.posts[DaybookSamples.space]!.where(
            (r) => r is DaybookPost && r.title == s.cableTraysTitle,
          ),
          hasLength(1),
        );
      });
    }
  }
}
