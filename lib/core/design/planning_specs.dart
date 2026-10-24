// Slice 8, planning: My notebook (NB1 2557:35384, built on v13 paper with
// no hour spine, review 83) and My calendar (CAL1 2557:35587). Values
// that already exist as tokens point at them.

import 'package:flutter/widgets.dart';

import 'bv_tokens.dart';

/// My notebook (NB1): the Only you pill, the slips' gaps, a to-do's and a
/// checklist point's box, and the pinned band.
abstract final class BvNotebookSpec {
  /// The list's side gutter and the gap between slips.
  static const gutter = BvSpace.gutter;
  static const slipGap = BvSpace.s20;

  /// The Only you pill (2557:35400): 26 high, icon 14, 10 at the sides.
  static const pillHeight = 26.0;
  static const pillPadding = 10.0;
  static const pillIcon = 14.0;
  static const pillGap = 6.0;

  /// A to-do's box and a checklist point's (2557:35412): 18, 10 before
  /// the words, a check 12 inside.
  static const box = 18.0;
  static const boxCheck = 12.0;
  static const boxGap = 10.0;
  static const boxRadius = BvRadius.tiny;
  static const boxBorder = 1.5;

  /// A checklist's points stand 8 apart (26 − 18).
  static const pointGap = BvSpace.s8;

  /// A to-do's due line: icon 14, 6 before the words.
  static const dueIcon = 14.0;
  static const dueGap = 6.0;

  /// The pinned band (2557:35405): 14 inside, 16 at the sides.
  static const pinnedPadding = 14.0;

  /// The empty notebook's icon (N2).
  static const emptyIcon = 40.0;
}

/// My notebook writes in place (F106, review 90; NBW1 2613:36507): the
/// slip being written, its chips, and the kind menu over it.
abstract final class BvNoteWritingSpec {
  /// The slip: 14 inside (12 at the foot), its parts 8 apart.
  static const slipPadding = EdgeInsetsDirectional.fromSTEB(
    BvNotebookSpec.pinnedPadding,
    BvNotebookSpec.pinnedPadding,
    BvNotebookSpec.pinnedPadding,
    BvSpace.s12,
  );
  static const slipGap = BvSpace.s8;

  /// By when and Remind me (NBW3): pills as Only you, 6 apart, each with
  /// a 12 ×.
  static const chipGap = 5.0;
  static const chipsGap = BvSpace.s6;
  static const chipRemove = 12.0;

  /// The kind menu (NBW2) stands just above the kind chip, from its start.
  static const menuStart = 15.0;
  static const menuGap = BvSpace.s6;
}

/// My calendar (CAL1): the week strip, the rows and their colour bar.
abstract final class BvCalendarSpec {
  /// A day in the week strip: the weekday over the date, 64 high; the
  /// chosen day is a 50-wide pill in the action colour.
  static const dayHeight = 64.0;
  static const dayPill = 50.0;
  static const dayRadius = BvRadius.control;
  static const dot = 4.0;
  static const dotGap = BvSpace.s4;
  static const stripPadding = BvSpace.s12;

  /// A row (2557:35588): white, radius 10, 12 inside; the bar 4 wide and
  /// 40 high, then the time column, then the words.
  static const rowRadius = BvRadius.control;
  static const rowPadding = BvSpace.s12;
  static const rowGap = BvSpace.s8;
  static const bar = 4.0;
  static const barHeight = 40.0;
  static const barRadius = 2.0;

  /// Wide enough for "10:00 am" and "10:00 صباحًا" at the small size (the
  /// frame's 64 cuts them); a larger text size shrinks it to fit.
  static const timeWidth = 80.0;
  static const columnGap = BvSpace.s12;

  /// The paper clip at the row's end.
  static const clipWidth = 24.0;

  /// How far a swipe on the strip goes before it turns the week.
  static const swipe = 200.0;

  /// The calendar's colour for the notebook's own rows (the frame's slate).
  static const notebookColor = BvProjectColors.slate;
}
