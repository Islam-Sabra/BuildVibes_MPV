// Review 101 A: a busy Space's Daybook builds only the cards on screen
// (and a small margin), not every card it has read. Opening it at a card
// far back still builds that card, shows it and highlights it. In English
// and Arabic.
import 'package:buildvibes/core/routing/app_routes.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/features/work/daybook_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

/// More cards than this built at once means the page builds them all: a
/// 390 × 844 screen shows about six.
const _bounded = 20;

final _now = DaybookSamples.thursday;

/// 500 work items over the last 30 days, newest first: post-000 is now,
/// post-499 thirty days back.
List<DaybookCard> _busy(DaybookSamples s) => [
  for (var i = 0; i < 500; i++)
    s.card(
      s.item(
        id: 'post-${i.toString().padLeft(3, '0')}',
        at: _now.subtract(Duration(minutes: 86 * i)),
        title: 'Item $i',
        authorId: DaybookSamples.sara,
        ownerId: DaybookSamples.omar,
      ),
    ),
];

Future<TestApp> _app(WidgetTester tester, String lang) {
  final s = DaybookSamples(lang);
  return pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(admin: true)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = _busy(s),
    now: _now,
  );
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

Finder _card(String id) => find.byKey(Key('daybook-card-$id'));

int _built() => find.byType(DaybookCardView).evaluate().length;

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets('500 posts over 30 days: only the cards on screen are '
        'built [$lang]', (tester) async {
      await _app(tester, lang);
      _router(tester).push(AppRoutes.space(DaybookSamples.space));
      await tester.pumpAndSettle();
      expect(_card('post-000'), findsOneWidget);
      expect(_built(), lessThanOrEqualTo(_bounded));
    });

    testWidgets('opened at post 450: it is built, on screen and '
        'highlighted, and the page still builds only what shows '
        '[$lang]', (tester) async {
      await _app(tester, lang);
      _router(
        tester,
      ).push(AppRoutes.spaceCard(DaybookSamples.space, 'post-450'));
      final ring = find.descendant(
        of: _card('post-450'),
        matching: find.byKey(const Key('bv-highlight-ring')),
      );
      for (var i = 0; i < 40 && ring.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(ring, findsOneWidget);
      final page = tester.getRect(find.byKey(const Key('daybook')));
      final card = tester.getRect(_card('post-450'));
      expect(card.top, greaterThanOrEqualTo(page.top - 1));
      expect(card.bottom, lessThanOrEqualTo(page.bottom + 1));
      expect(_built(), lessThanOrEqualTo(_bounded));
      await tester.pumpAndSettle();
    });
  }
}
