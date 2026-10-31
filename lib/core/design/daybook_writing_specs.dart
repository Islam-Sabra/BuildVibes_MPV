// The Daybook's writing and action parts (slice 1a): the writing card, its
// toolbar and menus, the long-press menu, send back, give to and the undo
// bar. Measured from Figma "DS · Daybook components" and frames 2524:33180,
// 2527:33393, 2530:33480, 2530:33802, 2540:34840 and 2519:33161.

import 'package:flutter/widgets.dart';

import 'bv_specs.dart';
import 'bv_tokens.dart';

/// The work item being written in place (2527:33393).
abstract final class BvWritingCardSpec {
  /// A straight dashed rectangle with the slip's small radius (review 44,
  /// C3).
  static const radius = BorderRadius.all(Radius.circular(BvRadius.slip));

  static const paddingTop = 18.0;
  static const paddingBottom = BvSpace.s16;
  static const paddingSide = BvSpace.s16;
  static const padding = EdgeInsetsDirectional.fromSTEB(
    paddingSide,
    paddingTop,
    paddingSide,
    paddingBottom,
  );
  static const gap = 10.0;

  /// The dashed border.
  static const border = BvStroke.dash;
  static const dashOn = 4.0;
  static const dashOff = 3.0;

  static const draftDot = BvSpace.s6;
  static const draftGap = BvSpace.s6;

  static const chipHeight = 26.0;
  static const chipPaddingStart = 10.0;
  static const chipPaddingEnd = BvSpace.s8;
  static const chipGap = BvSpace.s4;
  static const chipCaret = 14.0;

  /// The chip's 48 high touch area: the gap below (the title starts
  /// there), and the rest above.
  static const chipTouchOutset = EdgeInsetsDirectional.only(
    top: BvSize.touchMin - chipHeight - gap,
    bottom: gap,
  );

  static const cursorWidth = 2.0;

  /// The properties line: a wrap of owner, due and place.
  static const propertyGap = BvSpace.s12;
  static const propertyRunGap = BvSpace.s6;
  static const propertyItemGap = 5.0;
  static const propertyIcon = 15.0;

  /// The caret after a row a tap chooses again ("For: Choose", review 79
  /// A2).
  static const propertyCaret = 12.0;

  /// One line of properties, as laid out.
  static const propertyHeight = 18.0;

  /// The line's 48 high touch area: the gap below (the body starts there),
  /// and the rest above, into the gap and the title.
  static const propertyTouchOutset = EdgeInsetsDirectional.only(
    top: BvSize.touchMin - propertyHeight - gap,
    bottom: gap,
  );

  static const coverHeight = 128.0;

  /// A post's photos (H2 2555:35428): 110 high, side by side.
  static const postPhotoHeight = 110.0;

  /// Up to four photos share the width; more scroll sideways.
  static const photosSideBySide = 4;
  static const photoGap = BvSpace.s4;
  static const coverRadius = BorderRadius.all(Radius.circular(BvRadius.photo));
  static const removeSize = 26.0;
  static const removeTop = BvSpace.s8;
  static const removeEnd = BvSpace.s6;
  static const removeIcon = 14.0;
  static const removeOpacity = 0.92;

  /// The remove button's touch area: a 48 square around it. Past the
  /// cover's top and end it reaches into the card's gap and padding.
  static const removeInset = (BvSize.touchMin - removeSize) / 2;
  static const removeTouchOutset = EdgeInsetsDirectional.only(
    top: removeInset - removeTop,
    end: removeInset - removeEnd,
  );
}

/// The bar on the keyboard while writing (2527:33399).
/// Review 108 V3: "Tomorrow 7:00" in the Reminder sheet and Post later.
abstract final class BvLaterSpec {
  static const morningHour = 7;
}

abstract final class BvWritingToolbarSpec {
  /// Review 100 Part 5: a tool in use has a dot, 6 wide, 8 in from its
  /// corner.
  static const dot = 6.0;
  static const dotInset = BvSpace.s8;

  static const height = 56.0;

  /// Each tool and Post sit centred in a 48 square touch area (review 44,
  /// C4), side by side; the padding gives back what the squares add, so
  /// the first tool and Post keep their places.
  static const touch = BvSize.touchMin; // 48
  static const paddingStart = BvSpace.s8 - (touch - tool) / 2;
  static const paddingEnd = 10.0 - (touch - post) / 2;
  static const paddingVertical = (height - touch) / 2;
  static const tool = BvSize.controlMd; // 44
  static const toolRadius = BvRadius.controlAll; // 10
  static const toolIcon = BvSize.iconLg; // 24
  static const post = BvSize.avatarMd; // 40
  static const postIcon = BvSize.iconMd; // 20
  // 40 // 40
}

/// The More menu (2527:33433) and the kind picker (2535:34374).
abstract final class BvPopoverMenuSpec {
  static const widthMore = 184.0;
  static const widthPicker = 230.0;

  /// The kind menu: six plain rows (E6 v14 2598:36413, review 50 F63).
  static const widthKind = 322.0;
  static const radius = BvRadius.cardAll; // 14
  static const paddingVertical = BvSpace.s6;
  static const rowHeight = 42.0;
  static const rowPaddingStart = BvSpace.s16;
  static const rowPaddingEndMore = BvSpace.s20;
  static const rowPaddingEndPicker = BvSpace.s16;
  static const rowGap = BvSpace.s12;
  static const icon = BvSize.iconMd; // 20
  static const check = 18.0;

  /// Above and below a row with a small line under its label (F50).
  static const noteRowPadding = BvSpace.s8;

  // Writing (E2 2524:33369): the More menu, the assign picker and the
  // place field open over the diary, start 80, just above the toolbar.
  static const writingStart = 80.0;
  static const writingGap = BvSpace.s6;

  /// The place field's box (no frame draws it): the give-to picker's.
  static const placeWidth = 270.0;
  static const placePadding = BvSpace.s12;
}

/// The line menu and the "/" card next to a line (review 98, NBY1
/// 2629:37434, NBY2 2629:37564): 272 wide, white, a hairline edge, radius
/// 12, 6 inside; 44-high rows, 8 × 6 inside, radius 8, the kind's icon (18)
/// on a 32 tile, 10 before the words; the shortcut or › at the end. The
/// "/" card's title 8 × 4 (6 under) and its hint 6 over.
abstract final class BvLineMenuSpec {
  /// Review 100 Part 4: the one compact card, 260 wide.
  static const width = 260.0;
  static const padding = BvSpace.s6;
  static const radius = BorderRadius.all(Radius.circular(BvRadius.toast));
  static const rowPadding = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s8,
    vertical: BvSpace.s6,
  );
  static const rowGap = 10.0;
  static const rowHeight = 44.0;
  static const rowRadius = BorderRadius.all(Radius.circular(BvRadius.photo));

  /// The "/" card with every kind shows five and a half rows, so it keeps
  /// clear of the line and the keyboard; the rest scroll.
  static const rowsShown = 5.5;

  static const tile = BvSize.avatarSm; // 32

  /// A group's small caps label (review 100 Part 5), the line between two
  /// groups, and a set row's ✕.
  static const groupPadding = EdgeInsetsDirectional.fromSTEB(
    BvSpace.s8,
    BvSpace.s6,
    BvSpace.s8,
    BvSpace.s2,
  );
  static const groupGap = BvSpace.s8;
  static const clear = BvSize.iconSm;
  static const icon = 18.0;
  static const caret = BvSize.iconSm; // 16
  static const titlePadding = EdgeInsetsDirectional.fromSTEB(
    BvSpace.s8,
    BvSpace.s4,
    BvSpace.s8,
    BvSpace.s6,
  );
  static const hintPadding = EdgeInsetsDirectional.fromSTEB(
    BvSpace.s8,
    BvSpace.s6,
    BvSpace.s8,
    0,
  );

  /// Under the line: the menu 4 below its row, the "/" card 10 below its
  /// words; kept 16 clear of the screen's edges and the keyboard.
  static const menuGap = BvSpace.s4;
  static const cardGap = 10.0;
  static const screenMargin = BvSpace.s16;

  /// It opens from 96 % of its size.
  static const openScale = 0.96;

  /// The line the menu is for, tinted while it is open (NBY2) and while
  /// its Undo shows after a move (NBY5).
  static const lineRadius = BvRadius.smallAll;
}

/// The long-press menu on a slip (2530:33626, 2530:34246).
abstract final class BvSlipMenuSpec {
  static const width = 230.0;
  static const radius = BvRadius.cardAll; // 14
  static const rowPaddingHorizontal = BvSpace.s16;
  static const rowPaddingVertical = BvSpace.s12;
  static const rowGap = BvSpace.s12;
  static const icon = BvSize.iconMd; // 20

  /// Between the lifted slip and what shows under or over it.
  static const anchorGap = 10.0;

  /// Kept clear of the screen's top and bottom.
  static const screenMargin = BvSpace.s16;
}

/// Send-back reasons (2530:33802).
abstract final class BvSendBackSpec {
  static const width = 300.0;
  static const radius = BvRadius.cardAll; // 14
  static const paddingHorizontal = BvSpace.s16;
  static const paddingVertical = 14.0;
  static const gap = BvSpace.s2;

  /// 42 high rows (20 radio, 11 above and below): full-width rows, so a
  /// gloved finger finds them (review 44, C4).
  static const reasonPaddingVertical = 11.0;
  static const reasonGap = BvSpace.s12;
  static const noteRadius = BvRadius.controlAll; // 10
  static const notePaddingStart = BvSpace.s12;
  static const notePaddingEnd = 10.0;
  static const notePaddingVertical = 10.0;
  static const microphone = 18.0;

  /// The microphone's touch area: 48 wide at the note's end, the note's
  /// full height.
  static const microphoneTouch = BvSize.touchMin;
  static const buttonTop = BvSpace.s8;

  /// The new date (F62): a small label, then one line of chips that wraps.
  static const dueTop = BvSpace.s8;
  static const dueLabelGap = BvSpace.s6;
  static const dueChipGap = BvSpace.s8;
}

/// The Daybook's small radio mark (send-back reasons).
abstract final class BvRadioSmallSpec {
  static const size = BvSize.iconMd; // 20
  static const offBorder = BvStroke.medium; // 1.5
  static const onRing = BvSpace.s6;
}

/// Give to someone else (2540:34840).
abstract final class BvGiveToSpec {
  static const width = 270.0;
  static const radius = BvRadius.cardAll; // 14
  static const paddingTop = 10.0;
  static const paddingBottom = BvSpace.s8;
  static const searchPaddingHorizontal = BvSpace.s12;
  static const searchPaddingBottom = BvSpace.s6;
  static const fieldRadius = BvRadius.controlAll; // 10
  static const fieldPaddingHorizontal = BvSpace.s12;
  static const fieldPaddingVertical = BvSpace.s8;
  static const fieldGap = BvSpace.s8;
  static const searchIcon = BvSize.iconSm; // 16

  /// The search field's touch area takes the padding above and below it.
  static const searchTouchOutset = EdgeInsetsDirectional.only(
    top: paddingTop,
    bottom: searchPaddingBottom,
  );
  static const rowHeight = 52.0;
  static const rowPaddingHorizontal = 14.0;
  static const rowPaddingVertical = BvSpace.s8;
  static const rowGap = 10.0;
  static const check = 18.0;
}

/// "Checked · Undo" (2519:33161).
abstract final class BvUndoBarSpec {
  static const radius = BorderRadius.all(Radius.circular(BvRadius.toast));
  static const paddingHorizontal = BvSpace.s16;
  static const paddingVertical = BvSpace.s12;
  static const gap = 14.0;
  static const side = BvSpace.gutter;

  /// Above the Daybook's post bar (65 high), 12 clear of it.
  static const postBarHeight = 65.0;
  static const lift = BvSpace.s12;

  /// Then the check is locked (daybook.md).
  static const duration = Duration(seconds: 5);
}

/// A message quoted in a post (DM5 2561:76753, review 64): a soft panel
/// with an orange bar at its start, "From Omar Haddad · 10:42" small and
/// grey, then the words.
abstract final class BvQuoteSpec {
  static const radius = BorderRadius.all(Radius.circular(BvRadius.photo)); // 8
  static const bar = 3.0;
  static const paddingStart = BvSpace.s12;
  static const paddingEnd = BvSpace.s12;
  static const paddingVertical = BvSpace.s8;
  static const lineGap = BvSpace.s2;

  /// The words: four lines while writing, three on the card.
  static const linesWriting = 4;
  static const linesCard = 3;
}

/// Review 105 SP2 (2667:38511): the kinds as one choice that scrolls
/// sideways, at the top of the writing card.
abstract final class BvKindChipsSpec {
  static const radius = BorderRadius.all(Radius.circular(BvRadius.round));
  static const paddingHorizontal = BvSpace.s12;
  static const paddingVertical = BvSpace.s6;
  static const gap = BvSpace.s8;
  static const iconGap = BvSpace.s6;
  static const icon = BvSize.iconSm;
}

/// Review 105 SP2: For · Place · Due · Team, each a row that opens its
/// picker, in one box with a line between rows.
abstract final class BvWritingRowsSpec {
  static const radius = BorderRadius.all(Radius.circular(BvRadius.control));
  static const paddingHorizontal = BvSpace.s12;
  static const paddingVertical = BvSpace.s12;
  static const gap = BvSpace.s12;
  static const personGap = BvSpace.s6;
  static const caret = BvSize.iconSm;
}

/// Review 105 Part 7 (SP7 2670:38787): the proof moment's toast, shown
/// for [duration].
abstract final class BvProofMomentSpec {
  static const padding = EdgeInsetsDirectional.fromSTEB(
    BvSpace.s12,
    BvSpace.s12,
    BvSpace.s16,
    BvSpace.s12,
  );
  static const gap = BvSpace.s12;
  static const seal = BvSize.avatarMd;
  static const icon = BvSize.iconLg;
  static const lineGap = BvSpace.s2;
  static const duration = Duration(seconds: 4);

  /// Only a check this recent shows it (a phone opened days later
  /// doesn't).
  static const recent = Duration(days: 1);
}
