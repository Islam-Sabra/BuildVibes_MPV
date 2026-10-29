// Measurements of the Daybook's day parts: the masthead,
// the day divider, the post bar, the month drop-down and the day-one card.
// From the Figma frames 2518:33001, 2541:34679, 2541:34813, 2541:35060 and
// 2542:35109 (slice 1a spec, sections 5 to 8, 14 and 15).

import 'package:flutter/widgets.dart';

import 'bv_specs.dart';
import 'bv_tokens.dart';

/// The masthead above the diary (spec §6; v13 2581:35635).
abstract final class BvMastheadSpec {
  // The daybook's one line: the day and the date.
  static const linePaddingHorizontal = BvSpace.s16;
  static const linePaddingVertical = BvSpace.s8;
  static const lineGap = BvSpace.s8;

  /// F23: the masthead names the day of what is at this line, just under
  /// the top of the page: a sliver of the day before above it doesn't
  /// count.
  static const readingLine = BvSpace.s40;
}

/// The line between days (v13 2581:35639): a thin rule on each side of the
/// day's name.
abstract final class BvDayDividerSpec {
  static const gap = 10.0;
  static const lineWidth = BvStroke.thin; // 1
}

/// The post bar under the diary (spec §8).
abstract final class BvPostBarSpec {
  static const paddingHorizontal = BvSpace.s12;
  static const paddingVertical = BvSpace.s8;
  static const gap = 10.0;
  static const border = BvStroke.thin;

  static const notepadHeight = BvSize.controlMd; // 44
  static const notepadRadius = BorderRadius.all(Radius.circular(22));
  static const notepadPadding = 14.0;
  static const notepadGap = BvSpace.s8;
  static const notepadIcon = 18.0;

  static const cameraSize = BvSize.touchMin; // 48
  static const cameraIcon = BvSize.iconLg; // 24

  // Viewer: read only.
  static const viewerPadding = BvSpace.s12;
  static const viewerGap = BvSpace.s8;
}

/// The small pass chip in the Viewer post bar (spec §8).
abstract final class BvPassChipSpec {
  static const border = BvStroke.medium; // 1.5
  static const radius = BorderRadius.all(Radius.circular(BvRadius.tiny));
  static const paddingHorizontal = BvSpace.s8;
  static const paddingVertical = 3.0;
  static const gap = BvSpace.s4;
  static const dot = 5.0;
}

/// The month drop-down under the Space header (spec §14).
abstract final class BvMonthDropdownSpec {
  static const radius = BorderRadius.vertical(
    bottom: Radius.circular(BvRadius.dropdown),
  );
  static const padding = BvSpace.s16;
  static const gap = 10.0;

  static const caret = BvSize.iconLg; // 24

  /// Each caret's touch square. It reaches past the caret by [caretInset]
  /// into the top and end padding, and takes the gap under the header row,
  /// so the weekday names follow it directly.
  static const caretTouch = BvSize.touchMin; // 48
  static const caretInset = (caretTouch - caret) / 2;

  static const cellPaddingVertical = BvSpace.s4;
  static const cellGap = 3.0;
  static const circle = BvSize.avatarSm; // 32
  static const ring = BvStroke.medium; // 1.5
  static const dot = 5.0;
  static const daysInWeek = 7;

  static const legendGap = BvSpace.s16;
  static const legendItemGap = BvSpace.s6;
  static const legendDot = 6.0;
  static const legendRing = 10.0;
}

/// The day-one card in an empty Daybook (spec §15).
abstract final class BvFirstPageSpec {
  static const radius = BorderRadius.all(Radius.circular(BvRadius.toast));
  static const paddingTop = BvSpace.s24;
  static const paddingBottom = 22.0;
  static const paddingHorizontal = BvSpace.s20;
  static const gap = 14.0;

  static const actionRadius = BorderRadius.all(Radius.circular(BvRadius.toast));
  static const actionPaddingHorizontal = 14.0;
  static const actionHeight = 40.0;
  static const actionPaddingVertical = BvSpace.s6;
  static const actionGap = BvSpace.s8;
  static const actionIcon = 18.0;
}

/// Review 105 Part 6 (SP1 2666:38504): the Needs you line at the top of
/// Work.
abstract final class BvNeedsYouSpec {
  static const radius = BorderRadius.all(Radius.circular(BvRadius.toast));
  static const padding = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s12,
    vertical: BvSpace.s12,
  );
  static const gap = BvSpace.s8;
  static const icon = BvSize.iconMd;

  /// Around it, under the masthead.
  static const outer = EdgeInsetsDirectional.fromSTEB(
    BvSpace.gutter,
    BvSpace.s8,
    BvSpace.gutter,
    0,
  );
}
