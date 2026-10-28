// Review 101 K2: the Daybook paints its rows with its own render classes
// over Flutter's slivers (review 101 A): top to bottom while it grows up
// from Now, so the paper clip stays drawn over the card above. If a change
// or a Flutter upgrade drops them, this says so before the shots do.
//
// After any Flutter upgrade, run the Daybook tests and test_screens before
// anything else.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

/// The render classes the Daybook's page is built of, by name: they are
/// private to it.
const _own = [
  '_RenderNowViewport',
  '_RenderPageGroup',
  '_RenderSliverListTopDown',
];

void main() {
  testWidgets('the Daybook is painted with its own render classes', (
    tester,
  ) async {
    final s = DaybookSamples('en');
    await pumpApp(
      tester,
      language: 'en',
      auth: FakeAuthRepository(
        userId: DaybookSamples.islam,
        phone: '+96550000001',
      ),
      spaces: FakeSpaceRepository()
        ..details[DaybookSamples.space] = s.detail(admin: true)
        ..spacePeople[DaybookSamples.space] = s.people(),
      daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = s.d1(),
      now: DateTime(2026, 10, 15, 10, 57),
    );
    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).push('/spaces/${DaybookSamples.space}');
    await tester.pumpAndSettle();
    final page = tester.renderObject(find.byKey(const Key('daybook')));
    final used = <String>{};
    void visit(RenderObject r) {
      used.add(r.runtimeType.toString());
      r.visitChildren(visit);
    }

    visit(page);
    for (final name in _own) {
      expect(used, contains(name), reason: '$name is no longer used');
    }
  });
}
