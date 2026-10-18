import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';

/// The day at the top of the Daybook and of Home's feed (spec §6), on the
/// page colour: one line (v13 2581:35635, H1 v4 2587:35871), the weekday in
/// bold and the date in grey ("Thursday 15 October"). No weather, no day
/// count. With [onTap] the screen opens the month drop-down.
///
/// Home → Spaces adds [after] ("· 2 things need you", in the action
/// colour while [afterAction]), and sits in its list's own padding
/// ([padded] false; review 54 A6).
class BvDaybookMasthead extends StatelessWidget {
  const BvDaybookMasthead({
    super.key,
    required this.weekday,
    required this.date,
    this.onTap,
    this.after,
    this.afterAction = false,
    this.padded = true,
  });

  /// "Thursday".
  final String weekday;

  /// "15 October".
  final String date;
  final VoidCallback? onTap;

  /// After the date, behind a "·".
  final String? after;
  final bool afterAction;
  final bool padded;

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
          child: Text.rich(
            TextSpan(
              text: date,
              children: [
                if (after != null) ...[
                  const TextSpan(text: ' · '),
                  TextSpan(
                    text: after,
                    style: afterAction
                        ? type.bodyLg.copyWith(color: BvColors.textAction)
                        : null,
                  ),
                ],
              ],
            ),
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
        child: padded ? Padding(padding: padding, child: content) : content,
      ),
    );
  }
}
