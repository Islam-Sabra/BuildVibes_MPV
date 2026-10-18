import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';

/// Where one day begins on the Daybook (v13 2581:35639): the day's name
/// ("Wednesday 14 October", "Today") between two thin rules, across the
/// page's width.
class BvDayDivider extends StatelessWidget {
  const BvDayDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const rule = Expanded(
      child: SizedBox(
        key: Key('day-divider-line'),
        height: BvDayDividerSpec.lineWidth,
        child: ColoredBox(color: BvColors.borderSubtle),
      ),
    );
    return Row(
      spacing: BvDayDividerSpec.gap,
      children: [
        rule,
        Text(
          label,
          maxLines: 1,
          style: BvType.of(
            context,
          ).labelSm.copyWith(color: BvColors.textSecondary),
        ),
        rule,
      ],
    );
  }
}
