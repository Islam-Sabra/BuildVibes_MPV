// Slice 9: meeting notes into work items (R3 2540:34503) and the week
// report (MR1 2566:35515). Values that already exist as tokens point at
// them.

import 'package:flutter/widgets.dart';

import 'bv_icons.dart';
import 'bv_tokens.dart';

/// R3's message card: outlined in the action colour, a row per line with
/// a 20 tick box, 8 before the words, the owner's face at the end.
abstract final class BvMeetingSpec {
  static const cardPadding = 13.5;
  static const cardBorder = 1.5;
  static const box = 20.0;
  static const boxBorder = 1.5;
  static const boxRadius = BorderRadius.all(Radius.circular(BvRadius.tiny));
  static const check = 14.0;
  static const checkIcon = BvIcons.check;
  static const lineGap = BvSpace.s8;
}

/// MR1: the masthead's week arrows, the sections on their slips, the
/// proof strip and the target's progress line.
abstract final class BvWeekReportSpec {
  static const arrow = 36.0;
  static const arrowIcon = 18.0;
  static const arrowGap = BvSpace.s8;
  static const sectionGap = BvSpace.s20;
  static const headingGap = BvSpace.s8;
  static const rowPadding = BvSpace.s12;
  static const stampGap = BvSpace.s12;

  /// A proof card in "Checked this week": 158 wide, 10 apart.
  static const proofWidth = 158.0;
  static const proofGap = 10.0;
  static const proofHeight = 216.0;
  static const proofPhoto = 96.0;
  static const proofPadding = BvSpace.s8;
  static const proofPaddingTop = 14.0;

  /// The target's progress line: 6 high, round.
  static const progress = 6.0;

  /// The Share in chat pill: 28 high, icon 16.
  static const pillHeight = 28.0;
  static const pillIcon = 16.0;
  static const pillPadding = BvSpace.s12;
}
