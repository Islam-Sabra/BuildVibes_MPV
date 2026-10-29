import 'package:flutter/widgets.dart';

import 'bv_tokens.dart';

/// Slice 4's People (P1 2542:34824, P2 2542:34982).
abstract final class BvPeopleSpec {
  /// The join request: a quiet bordered card on the app colour.
  static const requestRadius = BvRadius.cardAll;
  static const requestPadding = BvSpace.s12;
  static const requestTop = BvSpace.s16;
  static const requestGap = BvSpace.s12;

  /// P2's three passes: a radio and the name; the chosen one outlined.
  static const optionHeight = 40.0;
  static const optionRadius = BvRadius.controlAll;
  static const optionPadding = BvSpace.s12;
  static const optionGap = BvSpace.s12;
  static const optionsTop = BvSpace.s12;
  static const optionsGap = BvSpace.s4;

  /// Section labels: Leads, Crew, Viewers, Teams.
  static const sectionTop = BvSpace.s16;
  static const sectionBottom = BvSpace.s4;

  /// A member row: avatar, name, role line, the pass tag at the end.
  static const rowPaddingVertical = BvSpace.s12;
  static const rowGap = BvSpace.s12;

  /// Review 105 SP8: a row's name, title · company and tags lines, and the
  /// pass and Team tags.
  static const lineGap = BvSpace.s4;
  static const tagGap = BvSpace.s6;
  static const tagPadding = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s8,
    vertical: BvSpace.s2,
  );

  /// The Team chips.
  static const chipHeight = 32.0;
  static const chipPadding = BvSpace.s12;
  static const chipGap = BvSpace.s8;

  /// The invite row at the bottom.
  static const inviteTop = BvSpace.s16;
  static const invitePadding = BvSpace.s12;
  static const inviteIcon = BvSize.iconSm;
  static const inviteGap = BvSpace.s12;
}

/// Slice 4's Library (LV1 2543:34980) and a file's page (LV2 2543:35101).
abstract final class BvLibrarySpec {
  /// A row: the thumbnail, the name and its line, the faces at the end.
  static const rowPaddingVertical = BvSpace.s12;
  static const rowGap = BvSpace.s12;
  static const tagTop = BvSpace.s4;

  /// The drawing's thumbnail; older versions show as paper stacked behind.
  static const thumbWidth = 56.0;
  static const thumbHeight = 44.0;
  static const thumbRadius = BorderRadius.all(Radius.circular(BvRadius.tiny));
  static const stackOffset = 3.0;
  static const thumbIcon = BvSize.iconMd;

  /// LV2: the preview card, the Received line and the versions.
  static const previewHeight = 250.0;
  static const previewRadius = BvRadius.cardAll;
  static const receivedTop = BvSpace.s16;
  static const receivedGap = BvSpace.s8;
  static const versionDot = 8.0;
  static const versionGap = BvSpace.s16;
  static const versionPaddingVertical = BvSpace.s12;
  static const sectionTop = BvSpace.s16;
}

/// S · Search inside the Space (2543:35148).
abstract final class BvSearchSpec {
  static const paddingStart = BvSpace.s12;
  static const paddingEnd = BvSpace.gutter;
  static const cancelGap = BvSpace.s8;
  static const groupTop = BvSpace.s16;
  static const rowPaddingVertical = BvSpace.s12;
  static const rowGap = BvSpace.s12;
  static const tile = 36.0;
  static const tileIcon = BvSize.iconMd;
}
