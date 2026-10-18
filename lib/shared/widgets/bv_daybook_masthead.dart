import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';

/// The day at the top of the Daybook (spec §6). It sits on the page colour
/// and is tappable: the screen opens the month drop-down.
///
/// - The daybook's one line (v13 2581:35635): the weekday in bold and the
///   date in grey ("Thursday 15 October"). No weather, no day count.
/// - [BvDaybookMasthead.home]: Home's weekday and subline.
class BvDaybookMasthead extends StatelessWidget {
  const BvDaybookMasthead({
    super.key,
    required this.weekday,
    required this.date,
    this.onTap,
  }) : _home = false;

  const BvDaybookMasthead.home({
    super.key,
    required this.weekday,
    required String dateLine,
    this.onTap,
  }) : date = dateLine,
       _home = true;

  /// "Thursday".
  final String weekday;

  /// "15 October"; on Home, its date line.
  final String date;
  final VoidCallback? onTap;
  final bool _home;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final secondary = BvColors.textSecondary;

    final Widget content;
    final EdgeInsetsDirectional padding;
    if (!_home) {
      padding = const EdgeInsetsDirectional.symmetric(
        horizontal: BvMastheadSpec.linePaddingHorizontal,
        vertical: BvMastheadSpec.linePaddingVertical,
      );
      content = Row(
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
    } else {
      padding = const EdgeInsetsDirectional.only(
        start: BvMastheadSpec.paddingHorizontal,
        end: BvMastheadSpec.paddingHorizontal,
        top: BvMastheadSpec.homePaddingTop,
        bottom: BvMastheadSpec.homePaddingBottom,
      );
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            weekday,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.displayBrand,
          ),
          Text(
            date,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.bodySm.copyWith(color: secondary),
          ),
        ],
      );
    }

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
