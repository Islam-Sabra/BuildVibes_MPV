// Review 101 K1: on the Daybook, a tap goes to the card drawn on top. The
// page paints its rows top to bottom while it grows up from Now (custom
// render classes), so a card's paper clip is drawn over the gap and the
// shadow of the card above it. A tap on the clip never goes to the card
// above; on its card, to its card. A tap in the middle of each of three
// stacked cards hits that card. In English and Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/shared/widgets/bv_paper_clip.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

final _now = DateTime(2026, 10, 15, 10, 57);

/// Three short work items for me to sign, one under the other, each with
/// its paper clip.
const _ids = ['post-a', 'post-b', 'post-c'];

Future<void> _open(WidgetTester tester, String lang) async {
  final s = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(admin: true)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()
      ..posts[DaybookSamples.space] = [
        for (final (i, id) in _ids.indexed)
          s.card(
            s.item(
              id: id,
              at: DateTime(2026, 10, 15, 8 + i),
              title: 'Item $i',
              authorId: DaybookSamples.sara,
              ownerId: DaybookSamples.islam,
            ),
            need: DaybookNeed.toSign,
          ),
      ],
    now: _now,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
}

Finder _card(String id) => find.byKey(Key('daybook-card-$id'));

/// The card a tap at [at] goes to: the first one on its hit-test path.
String? _tapped(WidgetTester tester, Offset at) {
  final result = HitTestResult();
  tester.binding.hitTestInView(result, at, tester.view.viewId);
  for (final entry in result.path) {
    final target = entry.target;
    if (target is! RenderObject) continue;
    final creator = target.debugCreator;
    if (creator is! DebugCreator) continue;
    String? id;
    void look(Element e) {
      final key = e.widget.key;
      if (key is ValueKey<String> && key.value.startsWith('daybook-card-')) {
        id = key.value.substring('daybook-card-'.length);
      }
    }

    look(creator.element);
    creator.element.visitAncestorElements((e) {
      look(e);
      return id == null;
    });
    if (id != null) return id;
  }
  return null;
}

Rect _slip(WidgetTester tester, String id) => tester.getRect(
  find.descendant(of: _card(id), matching: find.byType(BvSlip)).first,
);

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets('a tap on a paper clip goes to its own card, never to the '
        'card above it [$lang]', (tester) async {
      await _open(tester, lang);
      // Newest at the bottom: c under b under a.
      for (final (upper, lower) in [
        ('post-a', 'post-b'),
        ('post-b', 'post-c'),
      ]) {
        final above = _slip(tester, upper);
        final own = _slip(tester, lower);
        final clip = tester.getRect(
          find.descendant(of: _card(lower), matching: find.byType(BvPaperClip)),
        );
        // The clip reaches up out of its card, over the gap and the shadow
        // of the card above (painted over them), short of that card.
        expect(clip.top, lessThan(own.top));
        expect(clip.top, greaterThan(above.bottom));
        // Its tip: not the card above.
        final tip = Offset(clip.center.dx, (clip.top + own.top) / 2);
        expect(_tapped(tester, tip), isNot(upper));
        // The rest of it, on its card: that card.
        final onCard = Offset(clip.center.dx, (own.top + clip.bottom) / 2);
        expect(_tapped(tester, onCard), lower);
      }
    });

    testWidgets('a tap in the middle of each of three stacked cards hits '
        'that card [$lang]', (tester) async {
      await _open(tester, lang);
      for (final id in _ids) {
        expect(_tapped(tester, _slip(tester, id).center), id);
      }
    });
  }
}
