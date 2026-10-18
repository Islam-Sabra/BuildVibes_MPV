// The work item loop (slice 1 part 1d): the update note, the swipe that
// adds one, and the proof photo before it is sent. Measured from Figma
// Y1 (2530:33953), Y2 (2530:34038) and O2 (2529:33493). Values that already
// exist as tokens point at them.

import 'bv_specs.dart';
import 'bv_tokens.dart';

/// An update hanging under its work item (Y2 2530:34124): a small note on
/// the subtle surface, quoting the item.
abstract final class BvUpdateNoteSpec {
  static const radius = BvRadius.controlAll; // 10
  static const paddingHorizontal = BvSpace.s12;
  static const paddingVertical = 10.0;
  static const gap = BvSpace.s6;
  static const quoteGap = BvSpace.s8;
  static const quoteBarWidth = BvSpace.s2;
  static const quoteBarHeight = 14.0;
  static const rowGap = BvSpace.s8;
}

/// Swiping a work item slip towards the end side (Y1 2530:33953): the slip
/// gives way at its start and a round + shows there.
abstract final class BvSwipeRevealSpec {
  /// How far the slip gives way (64 → 116 in Y1).
  static const reveal = 52.0;

  /// A swipe past this much stays open.
  static const openAt = reveal / 2;

  /// The round + (36), 8 in from the slip's start.
  static const button = 36.0;
  static const buttonStart = BvSpace.s8;
  static const icon = 18.0;
}

/// The proof photo before it is sent (O2 2529:33493): the photo over the
/// ink, the linked work item at the top, its label at the bottom, and the
/// round send button.
abstract final class BvProofCameraSpec {
  // The linked work item: a white pill at the top.
  static const linkTop = BvSpace.s12;
  static const linkPaddingStart = BvSpace.s12;
  static const linkPaddingEnd = 10.0;
  static const linkPaddingVertical = BvSpace.s8;
  static const linkGap = BvSpace.s8;
  static const linkOpacity = 0.95;
  static const linkIcon = BvSize.iconSm; // 16

  // Answer 3 (review 47): the item name opens your other open items, in
  // the writing card's single-choice menu, just under it. No frame draws
  // it; the menu is the kind picker's.
  static const switchGap = BvSpace.s8;
  static const switchMaxHeight = 0.5; // of the photo

  // The label on the photo: place, date and time, name.
  static const labelInset = BvSpace.s12;
  static const labelPaddingHorizontal = 10.0;
  static const labelPaddingVertical = BvSpace.s6;
  static const labelGap = BvSpace.s6;
  static const labelRadius = BvRadius.smallAll; // 6
  static const labelOpacity = 0.78;
  static const labelIcon = 14.0;

  // Under the photo: the photos taken, the note, the round button.
  static const controlsPadding = BvSpace.s16;
  static const controlsGap = BvSpace.s12;
  static const thumb = 44.0;
  static const thumbBorder = BvStroke.thick;
  static const thumbRadius = BvRadius.photo; // 8
  static const thumbGap = BvSpace.s8;
  static const ring = 88.0;
  static const ringStroke = 4.0;
  static const button = 68.0;
  static const noteRadius = BvRadius.controlAll; // 10
  static const notePaddingHorizontal = BvSpace.s12;
  static const notePaddingVertical = 10.0;
  static const noteOpacity = 0.12;
  static const hintOpacity = 0.7;
  static const noteLines = 3;

  /// A sign-off note's length on the server (work_item_events.note).
  static const noteMax = 1000;

  // F6 (review 50): before the first photo, the camera is one tap away
  // in the middle (a white ring, unlike the orange Send as done), with
  // "Without a photo" under it all. No frame draws it; sizes follow O2.
  static const shutter = 72.0;
  static const shutterStroke = BvStroke.thick;
  static const shutterIcon = BvSize.iconLg; // 24
  static const shutterGap = BvSpace.s8;

  /// Without a photo the note says what was done: more room for it.
  static const noteLinesRequired = 5;

  /// Send as done before the note is written (without a photo).
  static const sendDisabledOpacity = 0.4;
}
