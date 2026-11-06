import 'package:flutter/widgets.dart';

import 'bv_tokens.dart';

/// Slice 4's People (P1 2542:34824, P2 2542:34982).
abstract final class BvPeopleSpec {
  /// The join request: a quiet bordered card on the app colour.
  static const requestRadius = BvRadius.cardAll;
  static const requestPadding = BvSpace.s12;
  static const requestTop = BvSpace.s16;
  static const requestGap = BvSpace.s12;

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

/// Review 111's Teams (TM1 to TM5).
abstract final class BvTeamsSpec {
  static const rowPaddingVertical = BvSpace.s12;
  static const rowGap = BvSpace.s12;
  static const lineGap = BvSpace.s2;

  /// A Team's mark on the make card (TM1) and in Who sees it (TM5).
  static const cardDisc = 40.0;
  static const whoDisc = 32.0;
  static const cardPadding = BvSpace.s12;

  /// The look-alike spelling's pill (TM2).
  static const mergePadding = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s12,
    vertical: BvSpace.s6,
  );

  /// Between the confirm sheet's parts (TM4).
  static const confirmGap = BvSpace.s12;
}

/// Review 121: Who to call (KP1, KP2), the Space as an organisation (OC1),
/// Key people (KP3, KP4) and the phone number (NUM1).
abstract final class BvKeyPeopleSpec {
  /// A key person's card: face, name, role tag and Call for, then Call and
  /// Message side by side.
  static const cardPadding = BvSpace.s12;
  static const cardGap = BvSpace.s12;
  static const faceGap = BvSpace.s12;
  static const lineGap = BvSpace.s4;
  static const actionsTop = BvSpace.s12;
  static const actionsGap = BvSpace.s8;
  static const headIcon = BvSize.iconSm;
  static const headGap = BvSpace.s6;

  /// OC1's Who to call chips and a Team card's faces (up to 5, never a
  /// count).
  static const chipPadding = EdgeInsetsDirectional.fromSTEB(
    BvSpace.s6,
    BvSpace.s6,
    BvSpace.s16,
    BvSpace.s6,
  );
  static const chipGap = BvSpace.s8;
  static const faces = 5;
  static const faceSpacing = BvSpace.s4;

  /// KP3's rows and KP4's holders.
  static const rowPaddingVertical = BvSpace.s12;
  static const tagBottom = BvSpace.s6;

  /// NUM1's choice rows and the lock line.
  static const choicePadding = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s12,
    vertical: BvSpace.s12,
  );
  static const noteGap = BvSpace.s8;

  /// Review 122 TM0's note under Teams.
  static const hintPadding = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s12,
    vertical: 10,
  );
  static const hintGap = BvSpace.s8;
  static const hintRadius = BorderRadius.all(Radius.circular(BvRadius.toast));
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

/// Review 105 SP9 (2670:38924): the removal sheet. Each open work item:
/// its reference and title, then a soft Give to row.
abstract final class BvHandoverSpec {
  static const gap = BvSpace.s12;
  static const itemGap = BvSpace.s8;
  static const refGap = BvSpace.s6;
  static const rowRadius = BvRadius.controlAll;
  static const rowPaddingHorizontal = BvSpace.s12;
  static const rowPaddingVertical = BvSpace.s12;
  static const rowGap = BvSpace.s8;
}

/// Review 113 LB1, LB2 (2730:40149, 2730:40228): the Library's folders,
/// their sheet, and the Need you now sheet (NN1, 2730:39983).
abstract final class BvFolderSpec {
  /// A folder row: the tile, the name over who sees it, the chevron.
  static const rowPaddingVertical = BvSpace.s12;
  static const rowGap = BvSpace.s12;
  static const tile = 36.0;
  static const tileRadius = BorderRadius.all(Radius.circular(BvRadius.control));
  static const tileIcon = BvSize.iconMd;
  static const lineIcon = 12.0;
  static const lineGap = BvSpace.s4;

  /// A linked folder's service, in its own colour.
  static const linkInk = BvProjectColors.slate;

  /// LB2's sheet: the gaps between its parts, and the warning box.
  static const sheetGap = BvSpace.s12;
  static const warningPadding = EdgeInsetsDirectional.all(BvSpace.s12);
  static const warningRadius = BvRadius.controlAll;
}
