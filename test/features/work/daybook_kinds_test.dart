import 'dart:async';

import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_ack_pill.dart';
import 'package:buildvibes/shared/widgets/bv_checklist_point.dart';
import 'package:buildvibes/shared/widgets/bv_faces.dart';
import 'package:buildvibes/shared/widgets/bv_paper_clip.dart';
import 'package:buildvibes/shared/widgets/bv_pinned_note.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

/// The Space's daybook as [me] (Islam by default), with K1–K3's posts.
Future<FakeDaybookRepository> _open(
  WidgetTester tester,
  String lang, {
  required List<DaybookCard> posts,
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  DateTime? now,
  DaybookExtras extras = const DaybookExtras(),
  Map<String, List<DaybookAckFace>> acks = const {},
}) async {
  final s = DaybookSamples(lang);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail(pass: pass)
    ..spacePeople[DaybookSamples.space] = s.people();
  final fake = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = posts
    ..extrasBySpace[DaybookSamples.space] = extras
    ..pointsByPost[DaybookSamples.handoverId] = s.handoverPoints()
    ..acksByPost.addAll(acks);
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: spaces,
    daybook: fake,
    now: now ?? DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return fake;
}

Finder _card(String id) => find.byKey(Key('daybook-card-$id'));
Finder _in(String id, Finder f) => find.descendant(of: _card(id), matching: f);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);
    final words = DaybookWords(l10n, lang, use24: false);

    group('K1 v13: the checklist card [$lang]', () {
      testWidgets('its people, due, "2 of 5 ticked" and the points with who '
          'ticked them; the clip for one of its people', (tester) async {
        await _open(
          tester,
          lang,
          me: DaybookSamples.sara,
          posts: [s.handover(need: DaybookNeed.toTick)],
        );
        const id = DaybookSamples.handoverId;
        expect(_in(id, find.text(s.handoverTitle)), findsOneWidget);
        expect(_in(id, find.text(l10n.daybookTicked(2, 5))), findsOneWidget);
        expect(
          _in(
            id,
            find.text(
              words.peopleFor(
                s.handover().post.people,
                me: DaybookSamples.sara,
              ),
            ),
          ),
          findsOneWidget,
        );
        expect(_in(id, find.byType(BvChecklistPoint)), findsNWidgets(5));
        final ticked = tester.widget<BvChecklistPoint>(
          find.byKey(const Key('checklist-point-pt-0')),
        );
        expect(ticked.tick!.name, s.saraName);
        expect(_in(id, find.byType(BvPaperClip)), findsOneWidget);
        // Review 61 G2: the points say who ticked them; the card's history
        // doesn't repeat it.
        expect(
          _in(id, find.textContaining(l10n.daybookLineTicked(s.omarName))),
          findsNothing,
        );
      });

      testWidgets("G2: an un-tick stays in the card's history; Show earlier "
          'has the ticks too', (tester) async {
        final base = s.handover();
        final untick = DaybookEvent(
          id: 'untick-pt-3',
          kind: DaybookEventKind.unticked,
          at: DateTime(2026, 10, 15, 10, 41),
          byId: DaybookSamples.sara,
          byName: s.saraName,
          pointId: 'pt-3',
          point: 'Doors',
        );
        final tick = DaybookEvent(
          id: 'tick-pt-3',
          kind: DaybookEventKind.ticked,
          at: DateTime(2026, 10, 15, 10, 30),
          byId: DaybookSamples.sara,
          byName: s.saraName,
          pointId: 'pt-3',
          point: 'Doors',
        );
        await _open(
          tester,
          lang,
          posts: [
            base.copyWith(
              lastActivityAt: untick.at,
              history: [untick, ...base.history, tick],
              historyMore: true,
            ),
          ],
        );
        const id = DaybookSamples.handoverId;
        expect(
          _in(id, find.textContaining(l10n.daybookLineUnticked(s.saraName))),
          findsOneWidget,
        );
        expect(
          _in(id, find.textContaining(l10n.daybookLineTicked(s.saraName))),
          findsNothing,
        );
        final earlier = _in(id, find.byKey(const Key('card-history-earlier')));
        await tester.ensureVisible(earlier);
        await tester.pumpAndSettle();
        await tester.tap(earlier);
        await tester.pumpAndSettle();
        expect(
          _in(id, find.textContaining(l10n.daybookLineTicked(s.saraName))),
          findsWidgets,
        );
      });

      testWidgets('ticking writes my name and time on the point at once and '
          'moves the card to Now; tick_point goes', (tester) async {
        final daybook = await _open(
          tester,
          lang,
          me: DaybookSamples.sara,
          posts: [
            s.handover(need: DaybookNeed.toTick),
            s.rebar(),
          ],
        );
        const id = DaybookSamples.handoverId;
        // Before: the checklist (10:40) is above the rebar card (10:05?):
        // whichever is older sits higher.
        final hold = Completer<void>();
        daybook.holdMarks = hold;
        await tester.tap(find.byKey(const Key('checklist-point-pt-2')));
        await tester.pump();
        final point = tester.widget<BvChecklistPoint>(
          find.byKey(const Key('checklist-point-pt-2')),
        );
        expect(point.tick, isNotNull);
        expect(point.tick!.name, s.saraName);
        expect(_in(id, find.text(l10n.daybookTicked(3, 5))), findsOneWidget);
        // The point says it; no tick line on the card (G2).
        expect(
          _in(id, find.textContaining(l10n.daybookLineYouTicked)),
          findsNothing,
        );
        // At Now: under the rebar card.
        expect(
          tester.getTopLeft(_card(id)).dy,
          greaterThan(tester.getTopLeft(_card('post-rebar')).dy),
        );
        hold.complete();
        await tester.pumpAndSettle();
        expect(daybook.marks, ['tick pt-2 true']);
      });

      testWidgets('a Viewer reads the points but can\'t tick them', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          me: DaybookSamples.mona,
          pass: SpacePass.viewer,
          posts: [s.handover()],
        );
        final point = tester.widget<BvChecklistPoint>(
          find.byKey(const Key('checklist-point-pt-2')),
        );
        expect(point.onTap, isNull);
      });

      testWidgets('my own tick can be unticked; someone else\'s can\'t (not '
          'the author)', (tester) async {
        final daybook = await _open(
          tester,
          lang,
          me: DaybookSamples.sara,
          posts: [s.handover(need: DaybookNeed.toTick)],
        );
        expect(
          tester
              .widget<BvChecklistPoint>(
                find.byKey(const Key('checklist-point-pt-1')),
              )
              .onTap,
          isNull,
        );
        await tester.tap(find.byKey(const Key('checklist-point-pt-0')));
        await tester.pumpAndSettle();
        expect(daybook.marks, ['tick pt-0 false']);
      });
    });

    group('K1 v13: the pinned announcement [$lang]', () {
      testWidgets('under the masthead, not in the list; Got it goes and the '
          'card does not move', (tester) async {
        final post = s.halfDayPost();
        final daybook = await _open(
          tester,
          lang,
          posts: [
            DaybookCard(post: post, lastActivityAt: post.createdAt),
            s.rebar(),
          ],
          extras: DaybookExtras(pinned: [post]),
        );
        final note = find.byType(BvPinnedNote);
        expect(note, findsOneWidget);
        expect(find.text(s.halfDay), findsOneWidget);
        expect(_card(DaybookSamples.halfDayId), findsNothing);
        expect(
          find.descendant(
            of: note,
            matching: find.text(
              l10n.daybookPinnedUntil(
                words.pinnedDay(post.pinnedUntil!, DaybookSamples.thursday),
              ),
            ),
          ),
          findsOneWidget,
        );
        // Islam isn't the author: Got it, and no faces.
        expect(
          find.descendant(of: note, matching: find.byType(BvFaces)),
          findsNothing,
        );
        final hold = Completer<void>();
        daybook.holdMarks = hold;
        await tester.tap(find.byKey(const Key('ack-got_it')));
        await tester.pump();
        // Review 61 G1: given, it folds to one slim line at once.
        expect(find.byType(BvPinnedNote), findsNothing);
        expect(find.byType(BvPinnedLine), findsOneWidget);
        hold.complete();
        await tester.pumpAndSettle();
        expect(daybook.marks, ['ack ${DaybookSamples.halfDayId} got_it true']);
      });

      testWidgets('G1: the slim line opens in full with Got it shown as '
          'given; a tap folds it again', (tester) async {
        final post = s.halfDayPost(myAcks: const {DaybookAck.gotIt});
        await _open(
          tester,
          lang,
          posts: [DaybookCard(post: post, lastActivityAt: post.createdAt)],
          extras: DaybookExtras(pinned: [post]),
        );
        expect(find.byType(BvPinnedNote), findsNothing);
        await tester.tap(find.byType(BvPinnedLine));
        await tester.pumpAndSettle();
        final pill = tester.widget<BvAckPill>(
          find.byKey(const Key('ack-got_it')),
        );
        expect(pill.tone, BvAckPillTone.done);
        await tester.tap(find.text(s.halfDay));
        await tester.pumpAndSettle();
        expect(find.byType(BvPinnedLine), findsOneWidget);
      });

      testWidgets('G1: an edit since my Got it opens it in full again, with '
          'Got it to give again', (tester) async {
        final post = s.halfDayPost(
          myAcks: const {DaybookAck.gotIt},
          editedAt: DateTime(2026, 10, 15, 9, 30),
        );
        final daybook = await _open(
          tester,
          lang,
          posts: [
            DaybookCard(
              post: post,
              lastActivityAt: post.createdAt,
              history: [
                DaybookEvent(
                  id: 'gotit-islam',
                  kind: DaybookEventKind.gotIt,
                  at: DateTime(2026, 10, 15, 9),
                  byId: DaybookSamples.islam,
                  byName: s.islamName,
                ),
              ],
            ),
          ],
          extras: DaybookExtras(pinned: [post]),
        );
        expect(find.byType(BvPinnedNote), findsOneWidget);
        final pill = tester.widget<BvAckPill>(
          find.byKey(const Key('ack-got_it')),
        );
        expect(pill.tone, BvAckPillTone.soft);
        await tester.tap(find.byKey(const Key('ack-got_it')));
        await tester.pumpAndSettle();
        // Taken back and given anew, so its time is after the edit.
        expect(daybook.marks, [
          'ack ${DaybookSamples.halfDayId} got_it false',
          'ack ${DaybookSamples.halfDayId} got_it true',
        ]);
      });

      testWidgets("G1: the first card's header is fully visible below a "
          'pinned announcement (390 x 844)', (tester) async {
        final post = s.halfDayPost();
        await _open(
          tester,
          lang,
          now: DateTime(2026, 10, 15, 10, 41),
          // The test font is wider than the app's, so a shorter card than
          // K1's; test_screens/slice2_test.dart checks K1 itself in the
          // app's fonts.
          posts: [
            s.rebar(),
            DaybookCard(post: post, lastActivityAt: post.createdAt),
          ],
          extras: DaybookExtras(pinned: [post]),
        );
        expect(tester.view.physicalSize, const Size(390, 844));
        final note = tester.getRect(find.byType(BvPinnedNote));
        final header = tester.getRect(
          _in('post-rebar', find.byType(BvSlipHeader)),
        );
        expect(header.top, greaterThanOrEqualTo(note.bottom));
        expect(header.bottom, lessThanOrEqualTo(844));
      });

      testWidgets('its author sees who got it, faces only, and no button', (
        tester,
      ) async {
        final post = s.halfDayPost();
        await _open(
          tester,
          lang,
          me: DaybookSamples.sara,
          posts: [DaybookCard(post: post, lastActivityAt: post.createdAt)],
          extras: DaybookExtras(pinned: [post]),
          acks: {
            DaybookSamples.halfDayId: [
              DaybookAckFace(
                profileId: DaybookSamples.omar,
                name: s.omarName,
                kind: DaybookAck.gotIt,
                at: DateTime(2026, 10, 15, 9),
              ),
            ],
          },
        );
        // G1: its author sees the slim line from the start.
        expect(find.byType(BvPinnedNote), findsNothing);
        await tester.tap(find.byType(BvPinnedLine));
        await tester.pumpAndSettle();
        final note = find.byType(BvPinnedNote);
        expect(
          find.descendant(of: note, matching: find.byType(BvFaces)),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ack-got_it')), findsNothing);
      });

      testWidgets('a Got it on an announcement off its pin leaves the card '
          'where it is (review 60 S1)', (tester) async {
        final post = DaybookPost(
          id: 'post-crane',
          kind: DaybookPost.announcementKind,
          createdAt: DateTime(2026, 10, 15, 8),
          title: 'Crane closed today',
          authorId: DaybookSamples.sara,
          authorName: s.saraName,
        );
        final daybook = await _open(
          tester,
          lang,
          posts: [
            DaybookCard(post: post, lastActivityAt: post.createdAt),
            s.rebar(),
          ],
        );
        final above = tester.getTopLeft(_card('post-crane')).dy;
        expect(above, lessThan(tester.getTopLeft(_card('post-rebar')).dy));
        final hold = Completer<void>();
        daybook.holdMarks = hold;
        await tester.tap(find.byKey(const Key('ack-got_it')));
        await tester.pump();
        expect(
          tester.getTopLeft(_card('post-crane')).dy,
          lessThan(tester.getTopLeft(_card('post-rebar')).dy),
        );
        hold.complete();
        await tester.pumpAndSettle();
      });
    });

    group('K2, K3 v13: the scheduled activity [$lang]', () {
      testWidgets('the calendar leaf, when, where and who; Add to my '
          'calendar', (tester) async {
        final daybook = await _open(
          tester,
          lang,
          me: DaybookSamples.omar,
          pass: SpacePass.crew,
          posts: [s.siteWalkCard()],
        );
        const id = DaybookSamples.siteWalkId;
        expect(_in(id, find.byKey(const Key('calendar-leaf'))), findsOneWidget);
        expect(
          _in(
            id,
            find.text(
              words.activityWhen(
                DateTime(2026, 10, 16, 7),
                DateTime(2026, 10, 16, 8),
                DaybookSamples.thursday,
              ),
            ),
          ),
          findsOneWidget,
        );
        expect(_in(id, find.byType(BvFaces)), findsOneWidget);
        await tester.tap(find.byKey(const Key('ack-in_my_calendar')));
        await tester.pumpAndSettle();
        expect(daybook.marks, ['ack $id in_my_calendar true']);
      });

      testWidgets('on its day it shows again at Today, On my way is the main '
          'action, and its author sees who is on the way', (tester) async {
        final card = s.siteWalkCard(
          onTheWay: [
            (DaybookSamples.omar, DateTime(2026, 10, 16, 6, 22)),
            (DaybookSamples.sara, DateTime(2026, 10, 16, 6, 25)),
          ],
        );
        await _open(
          tester,
          lang,
          now: DateTime(2026, 10, 16, 6, 30),
          posts: [card],
          extras: DaybookExtras(activities: [card.post]),
        );
        final pill = tester.widget<BvAckPill>(
          find.byKey(const Key('ack-on_my_way')),
        );
        expect(pill.tone, BvAckPillTone.primary);
        expect(
          _in(
            DaybookSamples.siteWalkId,
            find.textContaining(l10n.daybookLineOnMyWay(s.omarName)),
          ),
          findsOneWidget,
        );
        // Under Today's divider.
        expect(
          tester.getTopLeft(_card(DaybookSamples.siteWalkId)).dy,
          greaterThan(
            tester.getTopLeft(find.text(l10n.daybookTodayDivider)).dy,
          ),
        );
      });
    });

    group('K2 v13: the file card [$lang]', () {
      testWidgets('NEW VERSION, its facts, who received it, and Received '
          'moves the card', (tester) async {
        final daybook = await _open(
          tester,
          lang,
          posts: [s.m201(), s.rebar()],
          acks: {DaybookSamples.m201Id: s.m201Received()},
        );
        const id = DaybookSamples.m201Id;
        expect(
          _in(id, find.byKey(const Key('stamp-new-version'))),
          findsOneWidget,
        );
        expect(
          _in(
            id,
            find.text(
              l10n.daybookReceivedBy(
                words.someNames([s.omarName, s.rakeshName]),
              ),
            ),
          ),
          findsOneWidget,
        );
        final hold = Completer<void>();
        daybook.holdMarks = hold;
        await tester.tap(find.byKey(const Key('ack-received')));
        await tester.pump();
        // A Received is seen by everyone: the card moves to Now.
        expect(
          tester.getTopLeft(_card(id)).dy,
          greaterThan(tester.getTopLeft(_card('post-rebar')).dy),
        );
        hold.complete();
        await tester.pumpAndSettle();
        expect(daybook.marks, ['ack $id received true']);
      });

      testWidgets('its author long-presses to Cancel post', (tester) async {
        final daybook = await _open(
          tester,
          lang,
          me: DaybookSamples.lina,
          pass: SpacePass.crew,
          posts: [s.m201()],
        );
        // The author has nothing to receive.
        expect(find.byKey(const Key('ack-received')), findsNothing);
        await tester.longPress(_card(DaybookSamples.m201Id));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.daybookCancelPost));
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(daybook.calls, ['cancel ${DaybookSamples.m201Id}']);
      });
    });
  }
}
