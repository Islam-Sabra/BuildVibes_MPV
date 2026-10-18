import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';

/// The day at the top of the Daybook and of Home's feed (spec §6), on the
/// page colour: one line (v13 2581:35635, H1 v4 2587:35871), the weekday in
/// bold and the date in grey ("Thursday 15 October"). No weather, no day
/// count. With [onTap] the screen opens the month drop-down.
class BvDaybookMasthead extends StatelessWidget {
  const BvDaybookMasthead({
    super.key,
    required this.weekday,
    required this.date,
    this.onTap,
  });

  /// "Thursday".
  final String weekday;

  /// "15 October".
  final String date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final secondary = BvColors.textSecondary;
    const padding = EdgeInsetsDirectional.symmetric(
      horizontal: BvMastheadSpec.linePaddingHorizontal,
      vertical: BvMastheadSpec.linePaddingVertical,
    );
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      spacing: BvMastheadSpec.lineGap,
      children: [
        Text(weekday, maxLines: 1, style: type.titleLg),
        Flexible(
          child: Text(
            date,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.bodyLg.copyWith(color: secondary),
          ),
        ),
      ],
    );

    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(padding: padding, child: content),
      ),
    );
  }
}
