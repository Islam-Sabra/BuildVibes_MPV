// Review 105 Part 7, the proof-moment card only (SP7 2670:38787, AR
// 2670:38980): when my work item is Checked, I see once, for 4 s, "Added
// to your proof of work · Checked by Islam Ahmed · 5:30 pm · View"; View
// opens my proof of work. Only the owner's phone, only once. In English
// and Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/profile/delivered_work.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
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

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  required List<DaybookCard> posts,
  String me = DaybookSamples.omar,
  DateTime? now,
  TestApp? again,
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: SpacePass.crew,
        admin: me == DaybookSamples.islam,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = posts,
    now: now ?? DaybookSamples.thursday,
    // The same phone again: what it kept.
    stored: {
      if (again != null)
        for (final k in again.prefs.getKeys())
          if (k != 'app_language') k: again.prefs.get(k)!,
    },
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('Part 7 the proof moment [$lang]', () {
      testWidgets('my item, just Checked: "Added to your proof of work · '
          'Checked by … · time", for 4 s', (tester) async {
        await _open(tester, lang, posts: [s.gate()]);
        expect(_key('proof-moment'), findsOneWidget);
        expect(find.text(l10n.proofMomentTitle), findsOneWidget);
        final time = DaybookWords(
          l10n,
          lang,
          use24: false,
        ).time.clock(DateTime(2026, 10, 14, 17, 30));
        expect(
          find.text(l10n.proofMomentBy(s.islamName, time)),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(_key('proof-moment'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(_key('proof-moment'), findsNothing);
      });

      testWidgets('View opens my proof of work', (tester) async {
        await _open(tester, lang, posts: [s.gate()]);
        await tester.tap(_key('proof-moment-view'));
        await tester.pumpAndSettle();
        expect(find.byType(DeliveredScreen), findsOneWidget);
      });

      testWidgets('only once', (tester) async {
        final first = await _open(tester, lang, posts: [s.gate()]);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await _open(tester, lang, posts: [s.gate()], again: first);
        expect(_key('proof-moment'), findsNothing);
      });

      testWidgets('only on the owner\'s phone', (tester) async {
        await _open(tester, lang, posts: [s.gate()], me: DaybookSamples.islam);
        expect(_key('proof-moment'), findsNothing);
      });

      testWidgets('not for a check long past', (tester) async {
        await _open(
          tester,
          lang,
          posts: [s.gate()],
          now: DateTime(2026, 10, 20, 9),
        );
        expect(_key('proof-moment'), findsNothing);
      });
    });
  }
}
