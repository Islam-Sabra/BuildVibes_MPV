import 'package:flutter/widgets.dart' show EdgeInsetsDirectional;

import 'bv_tokens.dart';

/// Review 113 RX1 (2730:39887): React · Share at the foot of every card,
/// and the reactions as their icons with the small faces of who reacted
/// (never a number); the React picker, Like · Heart · Bravo, on a white
/// pill over the card.
abstract final class BvCardReactSpec {
  /// Above the row, under the rest of the card.
  static const top = BvSpace.s8;
  static const gap = BvSpace.s12;

  /// React and Share: an icon and a word, at least a thumb high.
  static const actionIcon = BvSize.iconSm;
  static const actionGap = BvSpace.s4;
  static const actionPaddingHorizontal = BvSpace.s4;

  /// One kind's icon before its faces; the kinds a little apart.
  static const kindIcon = BvSize.iconSm;
  static const kindGap = BvSpace.s2;
  static const groupGap = BvSpace.s8;

  /// The picker: three icons on a white pill with a soft shadow.
  static const pickerIcon = BvSize.iconLg;
  static const pickerButton = BvSize.touchMin;
  static const pickerPadding = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s8,
    vertical: BvSpace.s4,
  );
  static const pickerRadius = BvRadius.roundAll;

  /// Above the React button, this far up.
  static const pickerLift = BvSpace.s8;
  static const pickerShadow = BvShadow.popover;

  /// The kinds' colours: Like slate blue, Heart red, Bravo the brand's
  /// orange.
  static const like = BvProjectColors.slate;
  static const heart = BvColors.textDestructive;
  static const bravo = BvColors.iconAction;

  /// The names sheet: a face and a name a row.
  static const nameRowGap = BvSpace.s12;
}
