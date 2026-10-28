import 'dart:math' as math;

import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/widgets.dart';

/// Review 101 A: a long list builds only the rows on screen, plus a small
/// margin. Each row says it is built here, so the list can be taken to a row
/// that isn't ([scrollUntilBuilt]).
class LazyRow extends StatefulWidget {
  const LazyRow({
    super.key,
    required this.index,
    required this.built,
    required this.child,
  });

  final int index;

  /// The rows built now, by index.
  final Map<int, BuildContext> built;
  final Widget child;

  @override
  State<LazyRow> createState() => _LazyRowState();
}

class _LazyRowState extends State<LazyRow> {
  @override
  void initState() {
    super.initState();
    widget.built[widget.index] = context;
  }

  @override
  void didUpdateWidget(LazyRow old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index || old.built != widget.built) {
      if (old.built[old.index] == context) old.built.remove(old.index);
      widget.built[widget.index] = context;
    }
  }

  @override
  void dispose() {
    if (widget.built[widget.index] == context) {
      widget.built.remove(widget.index);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Scrolls the list at [position] until row [index] is built, a jump a
/// frame: each jump is worked out from how far apart the built rows are.
/// Rows run the way the list scrolls (a higher index further on), or, with
/// [up], against it (rows growing up from a centre: a higher index at a
/// lower offset). False when the row can't be reached.
Future<bool> scrollUntilBuilt(
  ScrollPosition position,
  Map<int, BuildContext> built,
  int index, {
  bool up = false,
}) async {
  for (var i = 0; i < 60; i++) {
    if (built.containsKey(index)) return true;
    if (!position.hasContentDimensions || built.isEmpty) return false;
    final first = built.keys.reduce(math.min);
    final last = built.keys.reduce(math.max);
    // What is built covers the screen and the margin both sides.
    final perRow =
        (position.viewportDimension + 2 * _margin) / (last - first + 1);
    final middle = (first + last) / 2;
    final step = (index - middle) * perRow;
    final to = (position.pixels + (up ? -step : step)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (to == position.pixels) return false;
    position.jumpTo(to);
    await WidgetsBinding.instance.endOfFrame;
  }
  return built.containsKey(index);
}

/// The margin a list builds beyond the screen: Flutter's default.
const _margin = RenderAbstractViewport.defaultCacheExtent;
