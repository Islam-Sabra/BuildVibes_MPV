import 'package:flutter/widgets.dart';

import 'bv_tokens.dart';

/// Slice 5: a post's page, opened in place (N1 2537:34046, N2 2537:34235,
/// N3 2537:34497, N4 2537:34853).
abstract final class BvPageSpec {
  /// Lines drag on ⋮⋮ only where the screen's short side is this wide (a
  /// tablet): never on a phone (review 98).
  static const dragMinSide = 600.0;

  /// The sheet rises to here over the daybook (N1: its top at 180 of
  /// 844).
  static const heightFactor = 0.8;
  static const tearHeight = 7.0;

  static const grabberWidth = 36.0;
  static const grabberHeight = 4.0;
  static const grabberTop = BvSpace.s8;

  static const padding = BvSpace.gutter;
  static const headTop = BvSpace.s12;
  static const headGap = BvSpace.s8;
  static const titleTop = BvSpace.s12;
  static const factsTop = BvSpace.s8;
  static const blockGap = BvSpace.s12;
  static const bottom = BvSpace.s32;

  /// N2: the ⋮⋮ handle in the start margin.
  static const handleWidth = 20.0;
  static const handleIcon = BvSize.iconSm;

  /// A toggle's caret and the gap after it.
  static const caret = BvSize.iconSm;
  static const caretGap = BvSpace.s8;
  static const toggleIndent = BvSpace.s24;

  /// A table: rounded, hairlines, the header row filled.
  static const tableRadius = BorderRadius.all(Radius.circular(BvRadius.photo));
  static const cellPaddingHorizontal = BvSpace.s12;
  static const cellPaddingVertical = BvSpace.s8;
  static const columnWidth = 104.0;

  /// A file and a work item under this one: soft rounded rows.
  static const rowRadius = BorderRadius.all(Radius.circular(BvRadius.photo));
  static const rowPadding = BvSpace.s12;
  static const rowGap = BvSpace.s12;
  static const underGap = BvSpace.s8;
  static const statusSize = BvSize.iconMd;
  static const photoHeight = 200.0;

  /// The card's "Open the page ›".
  static const openTop = BvSpace.s4;
  static const openCaret = BvSize.iconSm;

  /// N3: the block menu, beside the line.
  static const menuWidth = 260.0;
  static const menuTile = 28.0;
}

/// Slice 6: a walk's card (R1b 2539:34396, on v13's card) and its rows.
abstract final class BvTargetSpec {
  static const photoGap = BvSpace.s4;
  static const photoRadius = BorderRadius.all(Radius.circular(BvRadius.tiny));
  static const photosShown = 4;
  static const rowsShown = 10;
  static const rowGap = BvSpace.s8;
  static const rowPadding = BvSpace.s12;
  static const rowRadius = BorderRadius.all(Radius.circular(BvRadius.photo));
  static const statusSize = BvSize.iconMd;
}

/// Slice 6: walk mode (R1 2539:34353).
abstract final class BvWalkSpec {
  static const padding = BvSpace.gutter;
  static const chipHeight = 36.0;
  static const lineRadius = BorderRadius.all(Radius.circular(BvRadius.card));
  static const linePadding = BvSpace.s16;
  static const thumb = 52.0;
  static const thumbGap = BvSpace.s8;
  static const thumbRadius = BorderRadius.all(Radius.circular(BvRadius.photo));
  static const shutter = 68.0;
  static const barGap = BvSpace.s16;

  /// The photo's label sits on the photo, as on the proof camera.
  static const labelScrim = 0.6;

  /// The shutter waits until this photo has its line and owner.
  static const shutterWaiting = 0.4;
}
