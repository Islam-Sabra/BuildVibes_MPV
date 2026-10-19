// Slice 2's posts in Daybook v13: the checklist, announcement, scheduled
// activity and file cards (K1–K3 v13, EN 2594:35942, 2594:36161,
// 2594:77364), the pinned announcement and the attach sheet (K4 v13
// 2594:77482). Values that already exist as tokens point at them.

import 'package:flutter/widgets.dart';

import 'bv_specs.dart';
import 'bv_tokens.dart';

/// A checklist's point (K1 v13 2594:36130) and its progress line
/// (2594:36125).
abstract final class BvChecklistSpec {
  /// Review 56: 48-point rows, so a gloved thumb ticks the right one
  /// (Figma draws 44).
  static const rowMinHeight = BvSize.touchMin;
  static const rowPaddingVertical = BvSpace.s8;
  static const rowGap = 10.0;

  static const box = 22.0;
  static const boxRadius = BorderRadius.all(Radius.circular(5));
  static const boxBorder = BvStroke.medium;
  static const boxCheck = BvSize.iconSm; // 16

  static const progressHeight = 4.0;
  static const progressRadius = BorderRadius.all(Radius.circular(2));
  static const progressGap = 10.0;
}

/// The calendar leaf on a scheduled activity (2594:36288): a graphic, so
/// its day keeps its own size (review 58).
abstract final class BvCalendarLeafSpec {
  static const width = 56.0;
  static const height = 66.0;
  static const radius = BorderRadius.all(Radius.circular(BvRadius.small));
  static const border = BvStroke.thin;
  static const bandPaddingVertical = BvSpace.s2;
  static const daySize = 22.0;
  static const dayLineHeight = 26.0 / 22.0;

  /// Between the leaf and the activity's words.
  static const gap = BvSpace.s12;

  /// Between the title, the time and the place.
  static const linesGap = BvSpace.s4;
}

/// The pinned announcement under the masthead (K1 v13 2594:36070).
abstract final class BvPinnedSpec {
  static const paddingHorizontal = 14.0;
  static const paddingVertical = BvSpace.s12;
  static const radius = BorderRadius.all(Radius.circular(BvRadius.photo));
  static const gap = BvSpace.s8;
  static const headerGap = BvSpace.s8;
  static const pin = BvSize.iconSm; // 16

  /// Folded to one slim line (review 61 G1): the pin, the first line of
  /// the words, and ›, as a trace is drawn.
  static const lineMinHeight = 40.0;
  static const linePaddingStart = BvSpace.s12;
  static const linePaddingEnd = BvSpace.s8;
  static const linePaddingVertical = BvSpace.s6;
  static const lineGap = BvSpace.s8;
  static const caret = BvSize.iconSm; // 16

  /// Under the masthead, 16 from each edge, 8 above the daybook.
  static const outer = EdgeInsetsDirectional.only(
    start: BvSpace.s16,
    end: BvSpace.s16,
    bottom: BvSpace.s8,
  );
}

/// The soft and the main pills of a post's one action: Got it, Received,
/// Add to my calendar (2594:36097) and On my way (2594:77465).
abstract final class BvAckPillSpec {
  static const paddingStart = 14.0;
  static const paddingEnd = 14.0;
  static const paddingPrimary = BvSpace.s16;
  static const paddingVertical = 10.0;
  static const gap = BvSpace.s6;
  static const icon = BvSize.iconSm; // 16

  /// The faces and the pill share one row, 10 apart.
  static const rowGap = 10.0;
}

/// A file post's preview (2594:36329).
abstract final class BvFileCardSpec {
  static const previewHeight = 170.0;
  static const stampTop = BvSpace.s24;
  static const stampStart = BvSpace.s16;
}

/// The attach sheet (K4 v13 2594:77576): two rows, each an icon on the
/// brand-soft surface, a title and a small line, and ›.
abstract final class BvAttachSpec {
  static const rowMinHeight = 56.0;
  static const rowPaddingVertical = 10.0;
  static const rowGap = BvSpace.s12;
  static const chipPadding = BvSpace.s8;
  static const chipRadius = BorderRadius.all(Radius.circular(BvRadius.control));
  static const icon = BvSize.iconMd; // 20
  static const caret = 18.0;
  static const linesGap = BvSpace.s2;
}

/// The checklist's points while writing: an empty box and a line to type
/// on, one under the other.
abstract final class BvWritingPointSpec {
  static const gap = 10.0;
  static const rowMinHeight = BvSize.touchMin;

  /// At most 50 points on a checklist (create_space_post), each 1 to 300
  /// characters.
  static const max = 50;
  static const textMax = 300;
}
