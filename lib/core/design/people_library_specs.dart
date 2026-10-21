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
