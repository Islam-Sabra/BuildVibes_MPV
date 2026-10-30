// Review 107 OB7: the first time Work opens, three short tips, one at a
// time, each with a spotlight on the real control: the camera, a card to
// hold, and Sign as done (the first time an item is given to me). Skip tips
// or Next; each is kept as seen per account on the server, so it shows
// once. In English and Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/first_run_tip.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(_key(key).first);
  await tester.pumpAndSettle();
}

/// The Space's Work as Omar (Crew), with [posts], and the tips [seen].
Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<DaybookCard> posts = const [],
  Set<FirstRunTip> seen = const {},
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.omar,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: SpacePass.crew,
        admin: false,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = posts,
    tips: FakeTipsRepository(seen: Set.of(seen)),
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

/// The spotlight's hole is around [target].
void _spotlightOn(WidgetTester tester, Finder target) {
  final hole = tester.getRect(_key('tip-spotlight'));
  final at = tester.getRect(target.first);
  expect(hole.contains(at.center), isTrue);
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    /// A work item given to Omar: it waits for his Sign as done.
    DaybookCard mine() => s.card(
      s.item(
        id: 'post-mine',
        at: DateTime(2026, 10, 15, 9),
        title: s.t('Sleeves at grid C7', 'جلبات عند المحور C7'),
        authorId: DaybookSamples.islam,
        ownerId: DaybookSamples.omar,
      ),
      need: DaybookNeed.toSign,
    );

    /// Someone else's item: no Sign as done for Omar.
    DaybookCard theirs() => s.card(
      s.item(
        id: 'post-theirs',
        at: DateTime(2026, 10, 15, 8),
        title: s.t('Formwork check', 'فحص القوالب'),
        authorId: DaybookSamples.islam,
        ownerId: DaybookSamples.sara,
      ),
    );

    testWidgets('the first time: tip 1 of 3 on the camera, then Next to the '
        'card to hold, then Sign as done; each kept as seen [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang, posts: [theirs(), mine()]);
      expect(find.text(l10n.obTipOf(1, 3)), findsOneWidget);
      expect(find.text(l10n.obTipCamera), findsOneWidget);
      expect(find.text(l10n.obTipSkip), findsOneWidget);
      _spotlightOn(tester, _key('post-bar-camera'));

      await _tap(tester, 'tip-next');
      expect(app.tips.marked, [FirstRunTip.camera]);
      expect(find.text(l10n.obTipOf(2, 3)), findsOneWidget);
      expect(find.text(l10n.obTipHold), findsOneWidget);
      _spotlightOn(tester, _key('daybook-card-post-theirs'));

      await _tap(tester, 'tip-next');
      expect(find.text(l10n.obTipOf(3, 3)), findsOneWidget);
      expect(find.text(l10n.obTipSignDone), findsOneWidget);
      _spotlightOn(tester, find.text(l10n.daybookSignAsDone));

      await _tap(tester, 'tip-next');
      expect(app.tips.marked, [
        FirstRunTip.camera,
        FirstRunTip.hold,
        FirstRunTip.signDone,
      ]);
      expect(_key('tip-card'), findsNothing);
    });

    testWidgets('Skip tips: none show again [$lang]', (tester) async {
      final app = await _open(tester, lang, posts: [mine()]);
      await _tap(tester, 'tip-skip');
      expect(_key('tip-card'), findsNothing);
      expect(app.tips.marked.toSet(), FirstRunTip.values.toSet());
    });

    testWidgets('seen on another phone: no tip [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [mine()],
        seen: FirstRunTip.values.toSet(),
      );
      expect(_key('tip-card'), findsNothing);
    });

    testWidgets('with no card to hold and nothing given to me, only the '
        'camera; Sign as done waits for my first item [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      expect(find.text(l10n.obTipCamera), findsOneWidget);
      await _tap(tester, 'tip-next');
      expect(_key('tip-card'), findsNothing);
      expect(app.tips.marked, [FirstRunTip.camera]);
    });

    testWidgets('the first item given to me: Sign as done, on its own [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        posts: [mine()],
        seen: {FirstRunTip.camera, FirstRunTip.hold},
      );
      expect(find.text(l10n.obTipSignDone), findsOneWidget);
      expect(find.text(l10n.obTipOf(3, 3)), findsOneWidget);
      _spotlightOn(tester, find.text(l10n.daybookSignAsDone));
    });
  }
}
