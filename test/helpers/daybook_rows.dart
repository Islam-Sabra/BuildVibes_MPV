import 'dart:math' as math;

import 'package:buildvibes/shared/widgets/lazy_rows.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Review 101 A: the Daybook builds only the rows on screen, and a margin
// that finders count as off screen. A test goes to a row before it reads it,
// and reads rows in the order they are on screen.

/// The Daybook's page.
Finder get daybookPage => find
    .descendant(
      of: find.byKey(const Key('daybook')),
      matching: find.byType(Scrollable),
    )
    .first;

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(daybookPage).position;

/// Takes the page to its top, the oldest day loaded.
Future<void> toPageTop(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    final p = _position(tester);
    if (p.pixels <= p.minScrollExtent) return;
    p.jumpTo(p.minScrollExtent);
    await tester.pump();
  }
}

/// Half a screen at a time towards Now, until [until] or Now.
Future<void> _down(WidgetTester tester, bool Function() until) async {
  for (var i = 0; i < 400 && !until(); i++) {
    final p = _position(tester);
    if (p.pixels >= p.maxScrollExtent) return;
    p.jumpTo(math.min(p.pixels + p.viewportDimension / 2, p.maxScrollExtent));
    await tester.pump();
  }
}

/// Scrolls the page until [finder] is on screen: from the page's top down
/// to Now. The page stays where it was found.
Future<void> scrollToRow(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  await toPageTop(tester);
  await _down(tester, () => finder.evaluate().isNotEmpty);
}

/// What [finder] finds down the whole page, top to bottom as on screen,
/// read from the page's top down to Now. The page is then put back where it
/// was.
Future<List<T>> readPage<T extends Widget>(
  WidgetTester tester,
  Finder finder,
) async {
  final start = _position(tester).pixels;
  // By row (a higher one is older, further up; the writing card, in none,
  // is under them all), then by its place in the row.
  final seen = <(int, double), T>{};
  void read() {
    for (final e in finder.evaluate()) {
      Element? row;
      e.visitAncestorElements((a) {
        if (a.widget is! LazyRow) return true;
        row = a;
        return false;
      });
      final box = e.renderObject! as RenderBox;
      final top = row == null
          ? 0.0
          : (row!.renderObject! as RenderBox).localToGlobal(Offset.zero).dy;
      final index = (row?.widget as LazyRow?)?.index ?? -1;
      seen[(index, (box.localToGlobal(Offset.zero).dy - top).roundToDouble())] =
          e.widget as T;
    }
  }

  await toPageTop(tester);
  read();
  await _down(tester, () {
    read();
    return false;
  });
  read();
  _position(tester).jumpTo(start);
  await tester.pump();
  final places = seen.keys.toList()
    ..sort((a, b) {
      final rows = b.$1.compareTo(a.$1);
      return rows != 0 ? rows : a.$2.compareTo(b.$2);
    });
  return [for (final p in places) seen[p]!];
}

/// The keys starting with [prefix] down the whole page, top to bottom
/// ([readPage]): the cards' order is `daybook-card-`.
Future<List<String>> pageKeys(WidgetTester tester, String prefix) async => [
  for (final w in await readPage<Widget>(
    tester,
    find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && _key(w).startsWith(prefix),
    ),
  ))
    _key(w),
];

String _key(Widget w) => (w.key! as ValueKey<String>).value;
