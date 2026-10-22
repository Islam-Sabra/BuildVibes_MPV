import 'package:flutter/widgets.dart';

import '../../core/l10n/bv_time.dart';

/// A time in a two-line slot (the daybook card's history lines and a
/// checklist tick): the time, and in Arabic on a 12-hour phone the part of the day
/// on a small second line under it (review 51 F15, review 54 A1). Both
/// lines in [style], ending on the same edge.
class BvClockText extends StatelessWidget {
  const BvClockText(this.parts, {super.key, required this.style});

  /// From [BvTime.parts].
  final BvClockParts parts;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final period = parts.period;
    if (period == null) return Text(parts.time, maxLines: 1, style: style);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(parts.time, maxLines: 1, style: style),
        Text(period, key: const Key('clock-period'), maxLines: 1, style: style),
      ],
    );
  }
}
