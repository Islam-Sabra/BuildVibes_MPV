// Review 54 A1: one time format everywhere. The same moment reads the
// same on a daybook card's header, its history line, a Home post card, a
// reply on the post page and an Activity row, in both clock settings and
// both languages.
import 'package:buildvibes/core/l10n/bv_time.dart';
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/post.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_card_history.dart';
import 'package:buildvibes/shared/widgets/bv_clock_text.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/activity_fakes.dart';
import '../helpers/daybook_fakes.dart';
import '../helpers/daybook_samples.dart';
import '../helpers/fakes.dart';
import '../helpers/post_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/space_fakes.dart';

/// Omar's sign-off on the sleeves: the card's latest activity and its last
/// history line.
final _at = DaybookSamples.sleevesDoneAt;
final _now = DateTime(2026, 10, 15, 10, 57);

/// What a time slot shows, its lines joined by a space.
String _shown(WidgetTester tester, Finder slot) {
  final clock = tester.widget<BvClockText>(slot);
  return [clock.parts.time, ?clock.parts.period].join(' ');
}

void main() {
  for (final lang in ['en', 'ar']) {
    for (final use24 in [true, false]) {
      final l10n = lookupAppLocalizations(Locale(lang));
      final time = BvTime(l10n, lang, use24: use24);
      final mode = use24 ? '24-hour' : '12-hour';

      testWidgets('the same time on a card, a history line, a feed card, a '
          'reply and an Activity row [$lang, $mode]', (tester) async {
        tester.platformDispatcher.alwaysUse24HourFormatTestValue = use24;
        addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
        final s = DaybookSamples(lang);
        final posts = FakePostRepository(now: _now)
          ..posts.add(
            Post(
              id: 'p1',
              authorId: DaybookSamples.omar,
              authorName: s.omarName,
              body: s.sleeves,
              lang: lang,
              createdAt: _at,
            ),
          )
          ..home.add('p1')
          ..repliesByPost['p1'] = [
            PostReply(
              id: 'r1',
              postId: 'p1',
              authorId: DaybookSamples.sara,
              authorName: s.saraName,
              body: s.sleevesFirstNote,
              createdAt: _at,
            ),
          ];
        final daybook = FakeDaybookRepository()
          ..posts[DaybookSamples.space] = [s.sleevesCard()];
        final spaces = FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail()
          ..spacePeople[DaybookSamples.space] = s.people();
        await pumpApp(
          tester,
          language: lang,
          now: _now,
          posts: posts,
          daybook: daybook,
          spaces: spaces,
          activity: FakeActivityRepository(
            rows: [
              ActivityRow(
                id: 'a1',
                kind: ActivityKind.follow,
                createdAt: _at,
                actorId: DaybookSamples.sara,
                actorName: s.saraName,
              ),
            ],
          ),
          auth: FakeAuthRepository(
            userId: DaybookSamples.islam,
            phone: '+96550000001',
          ),
        );
        await tester.pumpAndSettle();

        // The one line every one-line place shows.
        final line = time.clock(_at);
        expect(line, switch ((lang, use24)) {
          (_, true) => '10:56',
          ('en', false) => '10:56 am',
          _ => '10:56 صباحًا',
        });

        // A post card on Home.
        expect(
          tester.widget<Text>(find.byKey(const Key('post-time-p1'))).data,
          line,
        );

        // A reply on the post page.
        final router = GoRouter.of(
          tester.element(find.byType(Navigator).first),
        );
        router.push('/posts/p1');
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.byKey(const Key('reply-time-r1'))).data,
          line,
        );

        // An Activity row.
        router.go('/activity');
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const Key('activity-row-a1')),
            matching: find.text(line),
          ),
          findsOneWidget,
        );

        // The daybook card's header and its last history line: the same
        // words; in Arabic on a 12-hour phone, the part of the day on a
        // second line (F15).
        router.go('/spaces/${DaybookSamples.space}');
        await tester.pumpAndSettle();
        final card = find.byKey(const Key('daybook-card-post-sleeves'));
        final header = find.descendant(
          of: find.descendant(of: card, matching: find.byType(BvSlipHeader)),
          matching: find.byType(BvClockText),
        );
        final history = find.descendant(
          of: find.descendant(of: card, matching: find.byType(BvCardHistory)),
          matching: find.byType(BvClockText),
        );
        expect(_shown(tester, header), line);
        expect(_shown(tester, history.last), line);
        final twoLines = lang == 'ar' && !use24;
        expect(
          find.descendant(
            of: header,
            matching: find.byKey(const Key('clock-period')),
          ),
          twoLines ? findsOneWidget : findsNothing,
        );
        if (twoLines) {
          expect(
            tester
                .getTopLeft(
                  find.descendant(
                    of: header,
                    matching: find.byKey(const Key('clock-period')),
                  ),
                )
                .dy,
            greaterThan(
              tester
                  .getTopLeft(
                    find.descendant(of: header, matching: find.text('10:56')),
                  )
                  .dy,
            ),
          );
        }
      });
    }
  }
}
