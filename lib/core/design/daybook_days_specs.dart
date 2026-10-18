// Measurements of the Daybook's day parts: the time spine, the masthead,
// the day divider, the post bar, the month drop-down and the day-one card.
// From the Figma frames 2518:33001, 2541:34679, 2541:34813, 2541:35060 and
// 2542:35109 (slice 1a spec, sections 5 to 8, 14 and 15).

import 'package:flutter/widgets.dart';

import 'bv_specs.dart';
import 'bv_tokens.dart';

/// Home's time spine and its entries (spec §5, H1 v3).
abstract final class BvSpineSpec {
  /// The time column.
  static const timeColumn = BvSize.touchMin; // 48

  /// The spine is centred on the end of the time column.
  static const lineWidth = BvStroke.medium; // 1.5

  /// The time label ends this far before the spine's centre.
  static const labelToSpine = BvSpace.s12;
  static const labelTop = 14.0;

  /// A 12-hour time's part of the day ("pm", "مساءً"), on its own smaller
  /// line under the time (review 50 F15).
  static const periodSize = 10.0;
  static const periodLine = 12.0;

  /// A 3.5 circle with a 2 px halo (or ring), 9 across in all.
  static const dotSize = 9.0;
  static const dotRadius = 3.5;
  static const dotStroke = BvStroke.thick; // 2
  static const dotTop = 17.0;

  /// The entry row's own height; the label and dot hang below it.
  static const rowHeight = BvSize.iconLg; // 24
  static const slipGap = BvSpace.s8;

  static const paddingTop = BvSpace.s16;
  static const paddingBottom = 18.0;
  static const paddingEnd = BvSpace.s16;
  static const entryGap = 22.0;
}

/// The masthead above the diary (spec §6; v13 2581:35635).
abstract final class BvMastheadSpec {
  // The daybook's one line: the day and the date.
  static const linePaddingHorizontal = BvSpace.s16;
  static const linePaddingVertical = BvSpace.s8;
  static const lineGap = BvSpace.s8;

  // Home.
  static const paddingHorizontal = BvSpace.s20;
  static const homePaddingTop = BvSpace.s12;
  static const homePaddingBottom = BvSpace.s6;
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
  static const actionPaddingVertical = 11.0;
  static const actionGap = BvSpace.s8;
  static const actionIcon = 18.0;
}

/// The "Due today" strip under the masthead (L1 2539:34715).
abstract final class BvDueTodaySpec {
  static const paddingStart = BvSpace.s20;
  static const paddingEnd = BvSpace.s16;
  static const paddingVertical = BvSpace.s8;
  static const gap = BvSpace.s8;
  static const icon = BvSize.iconSm; // 16
}
