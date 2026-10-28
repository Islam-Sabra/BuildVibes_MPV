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
/// slip being written and its chips.
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
}

/// F107 (review 92): a note as a page of blocks. The categories grid in
/// place of the keyboard (NBX2 2619:36869), the location sheet (NBX4
/// 2619:37151), the additions at the slip's end (NBX3) and the saved
/// slip's lines.
abstract final class BvNoteBlocksSpec {
  /// A line's start (review 100 Part 0, BH12): a strip a finger wide held
  /// to select the line, its faint dot under the finger; a selected line
  /// tinted on 6 round.
  static const startStrip = BvSize.iconLg;
  static const startDot = 6.0;
  static const pickedRadius = BorderRadius.all(Radius.circular(BvRadius.small));

  /// The slip's parts stand 10 apart (NBX1 "Slip · Being written").
  static const slipGap = 10.0;

  /// The location sheet: 16 at the sides, 14 on top, 16 under, its parts
  /// 12 apart; the typed field 12 × 11 inside, radius 10; the GPS row 12 ×
  /// 10, its pin on a 32 circle, its words 2 apart, × 14.
  static const locationPadding = EdgeInsetsDirectional.fromSTEB(
    BvSpace.gutter,
    14.0,
    BvSpace.gutter,
    BvSpace.gutter,
  );
  static const locationGap = BvSpace.s12;
  static const locationTitleIcon = 18.0;
  static const fieldPadding = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s12,
    vertical: 11.0,
  );
  static const fieldRadius = BvRadius.controlAll;
  static const gpsPadding = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s12,
    vertical: 10.0,
  );
  static const gpsCircle = BvSize.avatarSm; // 32
  static const gpsIcon = 18.0;
  static const gpsGap = 10.0;
  static const gpsLinesGap = 2.0;
  static const remove = 14.0;

  /// NBX3: photos 76 × 64, radius 8, 6 apart; a file's PDF on a 32 square,
  /// radius 8, its icon 18, 8 before its name.
  static const photoWidth = 76.0;
  static const photoHeight = 64.0;
  static const photoRadius = BorderRadius.all(Radius.circular(BvRadius.photo));
  static const photoGap = BvSpace.s6;
  static const fileBox = BvSize.avatarSm; // 32
  static const fileIcon = 18.0;
  static const fileGap = BvSpace.s8;

  /// A to-do's box, and the start of a list line (bullet, number, quote's
  /// bar) 10 before its words; a callout 12 inside on the subtle fill.
  static const lineGap = 10.0;
  static const bullet = 6.0;
  static const numberWidth = 18.0;
  static const quoteBar = 3.0;
  static const calloutPadding = EdgeInsetsDirectional.all(BvSpace.s12);
  static const calloutIcon = BvSize.iconMd;
  static const blockGap = BvSpace.s8;

  /// A line's ⋮⋮ (the line being written's only): as high as the line.
  static const handleHeight = BvSize.iconLg;

  /// Review 93: each level 24 further in; a fold arrow (16) on a 20 slot
  /// before the line's number, bullet or words.
  static const indent = BvSpace.s24;
  static const fold = 20.0;
  static const foldIcon = BvSize.iconSm;

  /// Review 98: shut, the arrow turns a quarter, to point forward.
  static const foldTurn = 0.25;

  /// The saved slip: the title, then the first three lines of the page.
  static const slipLines = 3;
  static const chipIcon = 14.0;
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

/// My notebook's pages (review 99A, PG1–PG5b): a page's row, its icon box,
/// the page chip and its picker, a page's title, the selection bar.
abstract final class BvNotebookPagesSpec {
  /// A row (PG1): 60 high, 73 with its open to-dos; the icon box 4 in.
  static const rowPaddingStart = 4.0;
  static const rowPaddingEnd = 4.0;
  static const rowPaddingVertical = 10.0;
  static const rowGap = BvSpace.s12;
  static const rowsGap = BvSpace.s4;
  static const rowRadius = BvRadius.controlAll;
  static const linesGap = BvSpace.s2;
  static const caret = BvSize.iconSm;

  /// The icon box: 40 with a 20 glyph; 32 with 18 in the picker.
  static const box = 40.0;
  static const boxGlyph = 20.0;
  static const boxRadius = BvRadius.controlAll;
  static const pickBox = BvSize.avatarSm; // 32
  static const pickGlyph = 18.0;

  /// The pin after a title, and the new dot.
  static const titleMarkGap = 6.0;
  static const pin = 14.0;
  static const newDot = 8.0;

  /// The open to-dos' icon.
  static const todosIcon = 13.0;
  static const todosGap = BvSpace.s4;

  /// A list's label ("Pinned", "Pages", a day): 8 above its words.
  static const labelTop = BvSpace.s8;
  static const labelBottom = BvSpace.s4;

  /// The checkbox while selecting (PG5).
  static const checkGap = BvSpace.s12;

  /// "New entry" (PG1) and "Write in this page" (PG4).
  static const actionTop = BvSpace.s8;
  static const writeHereBottom = BvSpace.s32;

  /// A page's top (PG4): the path, then the icon and title.
  static const pathBottom = BvSpace.s8;
  static const pathGap = BvSpace.s2;
  static const pathCaret = 12.0;
  static const titleBox = 40.0;
  static const titleGlyph = 22.0;
  static const titleGap = 10.0;
  static const titleBottom = BvSpace.s8;

  /// An entry's card (PG4): white, 8 round, 14 in at the sides and 12
  /// at the top and bottom; its ⋯ a 24 target.
  static const entryGap = BvSpace.s8;
  static const dayTop = BvSpace.s8;
  static const entryRadius = BorderRadius.all(Radius.circular(BvRadius.photo));
  static const entryPadding = EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12);
  static const entryLinesGap = BvSpace.s4;
  static const entryMenu = BvSize.iconLg;

  /// "Write in this page" (PG4): a round pill, 48 high, 20 to the sides.
  static const writeHereHeight = 48.0;
  static const writeHerePadding = BvSpace.s20;
  static const writeHereIcon = BvSize.iconMd;
  static const writeHereGap = BvSpace.s8;

  /// The page chip (PG2): 32 high, a 16 icon, a 14 caret.
  static const chipHeight = 32.0;
  static const chipPaddingStart = 13.0;
  static const chipPaddingEnd = BvSpace.s12;
  static const chipIcon = BvSize.iconSm;
  static const chipCaret = 14.0;
  static const chipGap = BvSpace.s6;

  /// The picker (PG3): 300 wide, 9 in, its rows 44 high.
  static const pickerWidth = 300.0;
  static const pickerPadding = 9.0;
  static const pickerRow = 44.0;
  static const pickerRowPadding = 6.0;
  static const pickerRowGap = 10.0;
  static const pickerRadius = BvRadius.cardAll;
  static const pickerSearchHeight = 39.0;
  static const pickerMostRows = 5;

  /// The icon sheet: four to a row.
  static const iconColumns = 4;
  static const iconTile = 64.0;
  static const iconGlyph = BvSize.iconLg;

  /// The selection bar (PG5): 78 high, each action an icon over its word.
  static const barHeight = 78.0;
  static const barTop = 11.0;
  static const barIcon = 22.0;
  static const barGap = BvSpace.s4;

  /// The merge sheet's choices (PG5b): 44 high.
  static const choiceHeight = 44.0;
}
