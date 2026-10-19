import 'package:buildvibes/core/l10n/months.dart';
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/post.dart';
import 'package:buildvibes/data/repositories/safety_repository.dart';
import 'package:buildvibes/features/safety/removed_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/post_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/safety_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

FakePostRepository _posts() => FakePostRepository(now: testNow)
  ..posts.addAll([
    Post(
      id: 'p1',
      authorId: 'p-omar2',
      authorName: 'Omar Haddad',
      authorHeadline: 'Site Engineer',
      body: 'First pour on the podium transfer slab is done.',
      lang: 'en',
      createdAt: testNow.subtract(const Duration(hours: 3)),
    ),
  ])
  ..home.add('p1');

Removal _removal({
  AppealStatus status = AppealStatus.none,
  bool canAppeal = true,
}) => Removal(
  id: 'rm-1',
  kind: ReportKind.post,
  reason: ReportReason.privateInfo,
  removedAt: DateTime(2026, 9, 12),
  appealStatus: status,
  canAppeal: canAppeal,
  excerpt: 'Site photos from level 3, including the client’s floor plan.',
  postedAt: DateTime(2026, 9, 10),
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('R1 → R2: report a post; it leaves your feed; Block from R2 '
        '[$lang]', (tester) async {
      final posts = _posts();
      final app = await pumpApp(
        tester,
        language: lang,
        posts: posts,
        safety: FakeSafetyRepository(posts: posts),
      );
      expect(find.byKey(const Key('post-p1')), findsOneWidget);
      await _tap(tester, 'post-menu-p1');
      await _tap(tester, 'post-report');
      expect(find.text(l10n.reportTitle('post')), findsOneWidget);
      // The six reasons as drawn.
      for (final r in ReportReason.values) {
        expect(find.byKey(Key('report-reason-${r.json}')), findsOneWidget);
      }
      await _tap(tester, 'report-reason-spam');
      expect(app.safety.calls, ['report post p1 spam']);
      expect(find.text(l10n.reportSentTitle), findsOneWidget);
      await _tap(tester, 'report-block');
      expect(find.text(l10n.blockConfirmBody), findsOneWidget);
      await _tap(tester, 'bv-dialog-confirm');
      expect(app.safety.calls.last, 'block p-omar2 true');
      expect(find.byKey(const Key('block-toast')), findsOneWidget);
      // Hidden for you at once.
      expect(find.byKey(const Key('post-p1')), findsNothing);
    });

    testWidgets('"Something else" needs a few words [$lang]', (tester) async {
      final app = await pumpApp(tester, language: lang, posts: _posts());
      await _tap(tester, 'post-menu-p1');
      await _tap(tester, 'post-report');
      await _tap(tester, 'report-reason-other');
      expect(find.text(l10n.reportNoteTitle), findsOneWidget);
      // Send waits for words.
      await _tap(tester, 'report-send');
      expect(app.safety.calls, isEmpty);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('report-note')),
          matching: find.byType(TextField),
        ),
        'Copies my company logo.',
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'report-send');
      expect(app.safety.calls, [
        'report post p1 other Copies my company logo.',
      ]);
      await _tap(tester, 'report-done');
      expect(find.byKey(const Key('post-p1')), findsNothing);
    });

    testWidgets('S7: who you blocked, your own count, and Unblock [$lang]', (
      tester,
    ) async {
      final safety = FakeSafetyRepository(
        blocked: [
          const BlockedPerson(
            id: 'p-hassan',
            firstName: 'Hassan',
            lastName: 'Ibrahim',
            headline: 'Civil Engineer',
          ),
        ],
      );
      final app = await pumpApp(tester, language: lang, safety: safety);
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-settings');
      await _tap(tester, 'row-privacy');
      await _tap(tester, 'row-blocked');
      expect(find.text(l10n.blockedCount(1)), findsOneWidget);
      expect(find.text(l10n.blockedNote), findsOneWidget);
      await _tap(tester, 'unblock-p-hassan');
      expect(app.safety.calls, ['block p-hassan false']);
      expect(find.text(l10n.blockedNone), findsOneWidget);
    });

    testWidgets('R3 → R4 → R5: the notice, one appeal, received [$lang]', (
      tester,
    ) async {
      final safety = FakeSafetyRepository(removals: {'rm-1': _removal()});
      final app = await pumpApp(tester, language: lang, safety: safety);
      _router(tester).push('/removals/rm-1');
      await tester.pumpAndSettle();
      expect(find.text(l10n.removedHeading('post')), findsOneWidget);
      expect(
        find.text(l10n.removedBody(l10n.reasonPhrase('private_info'))),
        findsOneWidget,
      );
      // The pilot has one reviewer: "We'll look at it again".
      expect(find.text(l10n.removedAppealNote), findsOneWidget);
      expect(find.byKey(const Key('removed-excerpt')), findsOneWidget);
      // The date it was posted (10 Sep), not removed (12 Sep).
      expect(
        find.text(
          l10n.removedYour('post', formatDayMonth(DateTime(2026, 9, 10), lang)),
        ),
        findsOneWidget,
      );
      await _tap(tester, 'removed-appeal');
      expect(find.text(l10n.appealHeading), findsOneWidget);
      await _tap(tester, 'appeal-send');
      expect(app.safety.calls, isEmpty, reason: 'it waits for words');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('appeal-note')),
          matching: find.byType(TextField),
        ),
        'The plan on the wall was blurred.',
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'appeal-send');
      expect(app.safety.calls, [
        'appeal rm-1 The plan on the wall was blurred.',
      ]);
      expect(find.text(l10n.appealReceived), findsOneWidget);
      await _tap(tester, 'appeal-done');
      // Back on R3: the appeal is open, and there's no second one.
      expect(find.byType(RemovedScreen), findsOneWidget);
      expect(find.byKey(const Key('removed-appeal')), findsNothing);
    });

    testWidgets('R3 after the 14 days, or after a decision [$lang]', (
      tester,
    ) async {
      final safety = FakeSafetyRepository(
        removals: {
          'rm-1': _removal(canAppeal: false),
          'rm-2': _removal(status: AppealStatus.upheld, canAppeal: false),
        },
      );
      await pumpApp(tester, language: lang, safety: safety);
      _router(tester).push('/removals/rm-1');
      await tester.pumpAndSettle();
      expect(find.text(l10n.removedClosed), findsOneWidget);
      expect(find.byKey(const Key('removed-appeal')), findsNothing);
      _router(tester).push('/removals/rm-2');
      await tester.pumpAndSettle();
      expect(find.text(l10n.removedUpheld), findsOneWidget);
      // Not yours, or gone.
      _router(tester).push('/removals/rm-x');
      await tester.pumpAndSettle();
      expect(find.text(l10n.removedGone), findsOneWidget);
    });

    testWidgets('Activity: "Your post was removed" opens R3 [$lang]', (
      tester,
    ) async {
      final activity = FakeActivityRepository(
        rows: [
          ActivityRow(
            id: 'n1',
            kind: ActivityKind.contentRemoved,
            createdAt: testNow,
            removalId: 'rm-1',
            targetKind: 'post',
          ),
        ],
      );
      final safety = FakeSafetyRepository(removals: {'rm-1': _removal()});
      await pumpApp(tester, language: lang, activity: activity, safety: safety);
      await _tap(tester, 'nav-activity');
      expect(
        find.text(l10n.activityRemoved('post'), findRichText: true),
        findsOneWidget,
      );
      await _tap(tester, 'activity-row-n1');
      expect(find.byType(RemovedScreen), findsOneWidget);
    });
  }
}
