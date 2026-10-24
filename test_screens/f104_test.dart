// F104 (review 50): the author's folded pinned announcement with the faces
// of who tapped Got it: 3 faces, and 3 faces + "+2" for 5. English and
// Arabic, at 390 × 844, in the app's fonts.
// Run:
//   flutter test test_screens/f104_test.dart --update-goldens
import 'package:buildvibes/data/models/daybook.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/f104/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/f104/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

const _people = [
  DaybookSamples.omar,
  DaybookSamples.mona,
  DaybookSamples.rakesh,
  DaybookSamples.lina,
  DaybookSamples.islam,
];

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    for (final n in [3, 5]) {
      testWidgets('the author\'s folded line with $n Got it [$lang]', (
        tester,
      ) async {
        final post = s.halfDayPost();
        final daybook = FakeDaybookRepository()
          ..posts[DaybookSamples.space] = [
            s.handover(),
            DaybookCard(post: post, lastActivityAt: post.createdAt),
          ]
          ..pointsByPost[DaybookSamples.handoverId] = s.handoverPoints()
          ..extrasBySpace[DaybookSamples.space] = DaybookExtras(pinned: [post])
          ..acksByPost[DaybookSamples.halfDayId] = [
            for (final (i, id) in _people.take(n).indexed)
              DaybookAckFace(
                profileId: id,
                name: s.nameOf(id),
                kind: DaybookAck.gotIt,
                at: DateTime(2026, 10, 15, 9, i),
              ),
          ];
        await pumpApp(
          tester,
          language: lang,
          auth: FakeAuthRepository(
            userId: DaybookSamples.sara,
            phone: '+96550000001',
          ),
          spaces: FakeSpaceRepository()
            ..details[DaybookSamples.space] = s.detail()
            ..spacePeople[DaybookSamples.space] = s.people(),
          daybook: daybook,
          now: DaybookSamples.thursday,
        );
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).push('/spaces/${DaybookSamples.space}');
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            const Key('pinned-line-faces-${DaybookSamples.halfDayId}'),
          ),
          findsOneWidget,
        );
        await _snap(tester, 'pinned_line_${n}_got_it', lang);
      });
    }
  }
}
