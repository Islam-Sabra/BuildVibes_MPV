import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';

/// A scheduled activity's calendar leaf (K2 v13 2594:36288): the weekday
/// on an orange band ("FRI"), the day large, and the month ("Oct"). A
/// graphic, so the day keeps its own size (review 58).
class BvCalendarLeaf extends StatelessWidget {
  const BvCalendarLeaf({
    super.key,
    required this.weekday,
    required this.day,
    required this.month,
  });

  final String weekday;
  final String day;
  final String month;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Container(
      key: const Key('calendar-leaf'),
      width: BvCalendarLeafSpec.width,
      // Arabic's taller lines make it a little taller.
      constraints: const BoxConstraints(minHeight: BvCalendarLeafSpec.height),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvCalendarLeafSpec.radius,
        border: Border.all(
          color: BvColors.borderDefault,
          width: BvCalendarLeafSpec.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            color: BvColors.actionPrimary,
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: BvCalendarLeafSpec.bandPaddingVertical,
            ),
            child: Text(
              weekday,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: type.overline.copyWith(
                fontWeight: FontWeight.w700,
                color: BvColors.actionPrimaryForeground,
              ),
            ),
          ),
          Text(
            day,
            maxLines: 1,
            style: type.titleLg.copyWith(
              fontSize: BvCalendarLeafSpec.daySize,
              height: BvCalendarLeafSpec.dayLineHeight,
              color: BvColors.textPrimary,
            ),
          ),
          Text(
            month,
            maxLines: 1,
            style: type.metadata.copyWith(color: BvColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
