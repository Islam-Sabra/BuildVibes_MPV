import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';

enum _MastheadKind { full, compact, home }

/// The day at the top of the Daybook (spec §6). It sits on the page colour
/// and is tappable: the screen opens the month drop-down.
///
/// - Full: the weekday, a date line ("15 October, day 41 on site") and,
///   when there is weather, the temperature and weather text at the end.
/// - [BvDaybookMasthead.compact]: one line while writing
///   ("Thursday 15 October") with the temperature.
/// - [BvDaybookMasthead.home]: Home's weekday and subline, no weather.
class BvDaybookMasthead extends StatelessWidget {
  const BvDaybookMasthead({
    super.key,
    required this.weekday,
    required String this.dateLine,
    this.temperature,
    this.weather,
    this.onTap,
  }) : _kind = _MastheadKind.full;

  const BvDaybookMasthead.compact({
    super.key,
    required String title,
    this.temperature,
    this.onTap,
  }) : weekday = title,
       dateLine = null,
       weather = null,
       _kind = _MastheadKind.compact;

  const BvDaybookMasthead.home({
    super.key,
    required this.weekday,
    required String this.dateLine,
    this.onTap,
  }) : temperature = null,
       weather = null,
       _kind = _MastheadKind.home;

  /// The weekday ("Thursday"), or the compact one-line title.
  final String weekday;
  final String? dateLine;

  /// "34°". Null hides the weather block.
  final String? temperature;

  /// "Sunny, light wind", under the temperature (full only).
  final String? weather;
  final VoidCallback? onTap;
  final _MastheadKind _kind;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final secondary = BvColors.textSecondary;

    final Widget content;
    final EdgeInsetsDirectional padding;
    if (_kind == _MastheadKind.compact) {
      padding = const EdgeInsetsDirectional.only(
        start: BvMastheadSpec.paddingHorizontal,
        end: BvMastheadSpec.paddingHorizontal,
        top: BvMastheadSpec.compactPaddingTop,
        bottom: BvMastheadSpec.compactPaddingBottom,
      );
      content = Row(
        spacing: BvMastheadSpec.gap,
        children: [
          Expanded(
            child: Text(
              weekday,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.titleLg,
            ),
          ),
          if (temperature != null) Text(temperature!, style: type.titleLg),
        ],
      );
    } else {
      padding = EdgeInsetsDirectional.only(
        start: BvMastheadSpec.paddingHorizontal,
        end: BvMastheadSpec.paddingHorizontal,
        top: _kind == _MastheadKind.home
            ? BvMastheadSpec.homePaddingTop
            : BvMastheadSpec.paddingTop,
        bottom: _kind == _MastheadKind.home
            ? BvMastheadSpec.homePaddingBottom
            : BvMastheadSpec.paddingBottom,
      );
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: BvMastheadSpec.gap,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weekday,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.displayBrand,
                ),
                Text(
                  dateLine!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySm.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          if (temperature != null || weather != null)
            Column(
              key: const Key('masthead-weather'),
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (temperature != null)
                  Text(temperature!, style: type.titleLg),
                if (weather != null)
                  Text(
                    weather!,
                    style: type.metadata.copyWith(color: secondary),
                  ),
              ],
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
