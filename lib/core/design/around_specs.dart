// Slice 1 part 1e, around the daybook: the Space header and its menu
// (MN1 2566:35619), Space info (SI1 2562:35576), Needs you across Spaces
// (2544:35068), proof of work on a profile (R1 v4 2556:35424, 2544:35381)
// and Home in Daybook (H1 v3 2555:35276). Values that already exist as
// tokens point at them.

import 'package:flutter/painting.dart';

import 'bv_specs.dart';
import 'daybook_paper_specs.dart';
import 'bv_tokens.dart';

/// The Space emblem (Space/Plan 2307:68648): a floor plan on the subtle
/// surface, people as dots (the orange one is you), an open doorway at the
/// bottom. Drawn on a 72 × 56 grid and scaled to its height.
abstract final class BvSpaceEmblemSpec {
  static const width = 72.0;
  static const height = 56.0;

  /// Before a Space's name in lists sorted by Space (Home → Spaces, Needs
  /// you, Create's Space list; review 50 F28): the emblem, not a letter.
  static const tile = 28.0;
  static const radius = 10.0;
  static const room = Rect.fromLTRB(15, 13, 57, 43);
  static const roomStroke = BvStroke.thick;
  static const dot = 3.5;
  static const you = Offset(24, 22);
  static const others = [Offset(34, 28), Offset(44, 22), Offset(30, 36)];
  static const doorway = Rect.fromLTWH(29, 41, 14, 6);

  /// In the Space header (MN1): 40 high.
  static const header = 40.0;

  /// In Space info (SI1): 56 high.
  static const info = 56.0;
}

/// The Space header (2080:11849): back, the emblem, the name and its line,
/// and ⋯, 60 high with a line under it.
abstract final class BvSpaceHeaderSpec {
  static const height = 60.0;
  static const paddingHorizontal = BvSpace.s4;
  static const gap = BvSpace.s8;
}

/// A menu opened from a screen's ⋯ (the Space menu, MN1 2566:35755): 220
/// wide, 44 rows, a little under the header's end.
abstract final class BvScreenMenuSpec {
  static const width = 220.0;
  static const rowHeight = 44.0;
  static const rowPadding = BvSpace.s16;

  /// From the top of the safe area (96 in the frame, under its 44 status
  /// bar): over the header's lower edge.
  static const top = 52.0;
  static const end = 10.0;
}

/// Space info (SI1): groups of rows on white slips.
abstract final class BvInfoSpec {
  static const bodyPaddingTop = BvSpace.s4;
  static const groupGap = 14.0;
  static const labelGap = BvSpace.s6;
  static const labelPaddingStart = BvSpace.s4;
  static const slipRadius = BorderRadius.all(Radius.circular(BvRadius.toast));
  static const slipPaddingHorizontal = 14.0;
  static const rowPaddingVertical = BvSpace.s12;
  static const rowGap = 10.0;
  // A value on the end side takes at most this share of the row.
  static const valueMaxShare = 0.6;
  static const identityGap = 14.0;
  static const identityPaddingVertical = BvSpace.s4;
  static const nameGap = BvSpace.s4;

  // The project tag under the name.
  static const tagPaddingStart = BvSpace.s8;
  static const tagPaddingEnd = 10.0;
  static const tagPaddingVertical = BvSpace.s4;
  static const tagGap = BvSpace.s6;
  static const tagDot = 8.0;
  static const tagCaret = 14.0;

  // The pass tag (Lead) and the Copy pill.
  static const passPaddingHorizontal = BvSpace.s8;
  static const passPaddingVertical = 3.0;
  static const passIcon = 14.0;
  static const pillPaddingHorizontal = BvSpace.s12;
  static const pillPaddingVertical = 7.0;
  static const pillIcon = BvSize.iconSm;

  /// The invite code: 16 SemiBold, tracked 8 %.
  static const codeTrackingEm = 0.08;
}

/// One single choice as a pill track (SI1 Notifications, Who can invite).
abstract final class BvSegmentedSpec {
  static const padding = 3.0;
  static const gap = BvSpace.s2;
  static const segmentPaddingHorizontal = BvSpace.s8;
  static const segmentPaddingVertical = 7.0;
}

/// Needs you, across Spaces (2544:35068): each Space's things under its
/// name, as white rows with the paper clip.
abstract final class BvNeedsSpec {
  static const titlePaddingTop = 14.0;
  static const titlePaddingBottom = 10.0;
  static const titlePaddingHorizontal = BvSpace.s20;
  static const groupGap = 18.0;
  static const rowGap = BvSpace.s8;
  static const rowPadding = BvSpace.s12;
  static const rowRadius = BvRadius.controlAll;
  static const rowGapInside = BvSpace.s12;
  static const photo = 46.0;
  static const photoRadius = BvRadius.smallAll;
  static const lineGap = BvSpace.s2;

  /// The small paper clip at the row's end: one rounded rectangle.
  static const clip = Size(12, 28);
  static const clipRadius = 6.0;
}

/// Proof of work (R1 v4 2556:35433): a torn slip with the Done photo and
/// its CHECKED stamp, the title, the project and who checked it.
abstract final class BvProofCardSpec {
  static const paddingTop = BvSpace.s16;
  static const paddingHorizontal = BvSpace.s12;
  static const paddingBottom = BvSpace.s12;
  static const gap = BvSpace.s12;
  static const photo = 84.0;
  static const stampInset = 4.5;
  static const textGap = 3.0;
  static const checkerPaddingTop = BvSpace.s4;
  static const checkerGap = BvSpace.s6;
  static const listGap = BvSpace.s12;
}

/// "Projects, confirmed by teammates" (R1 v4 2556:35504).
abstract final class BvProjectProofSpec {
  static const gap = BvSpace.s8;
  static const rowPaddingHorizontal = 10.0;
  static const rowPaddingVertical = BvSpace.s8;
  static const rowGap = 10.0;
  static const dot = 9.0;
}

/// The Daybook's small tabs (H1 v3 Feed / Spaces, R1 v4 profile tabs): a
/// label and a short line under the chosen one.
abstract final class BvSmallTabsSpec {
  static const paddingHorizontal = BvSpace.s20;
  static const gap = 22.0;
  static const paddingTop = BvSpace.s6;
  static const lineGap = BvSpace.s6;
  static const lineWidth = 28.0;
  static const lineHeight = 2.5;
  static const lineRadius = BorderRadius.all(Radius.circular(2));
}

/// The profile header in Daybook (R1 v4).
abstract final class BvProfileHeadSpec {
  static const paddingTop = BvSpace.s16;
  static const paddingBottom = BvSpace.s12;
  static const paddingHorizontal = BvSpace.s20;
  static const gap = 14.0;
  static const lineGap = BvSpace.s2;
  static const actionsPaddingBottom = BvSpace.s8;
  static const pillPaddingHorizontal = 14.0;
  static const pillPaddingVertical = BvSpace.s8;
  static const bodyPaddingTop = 14.0;
}

/// Home in Daybook (H1 v3): the app bar and the feed on the spine.
abstract final class BvHomeSpec {
  static const barPaddingStart = BvSpace.s20;
  static const barPaddingEnd = BvSpace.s8;
  static const barPaddingVertical = BvSpace.s2;
  static const barGap = BvSpace.s2;
  static const barButton = BvSize.controlMd; // 44

  /// The Messages icon's unread dot, from the button's corner.
  static const dotInset = BvSpace.s8;
  static const wordmarkSize = 22.0;
  static const wordmarkLineHeight = 28.0;

  static const tagRadius = BorderRadius.all(Radius.circular(BvRadius.tiny));
  static const tagPaddingStart = BvSpace.s8;
  static const tagPaddingEnd = BvSpace.s12;
  static const tagPaddingVertical = 5.0;
  static const tagGap = BvSpace.s8;
  static const tagDot = 8.0;
  static const actionIcon = 18.0;
  static const actionGap = BvSpace.s6;

  /// A reply's author on the post page (review 50 F19): avatar 28.
  static const authorAvatar = BvAvatarSpec.xsm;

  // The post card (H1 v4 2587:35875): full width, 16 from each edge, 12
  // apart; 14 inside at the top, 6 at the bottom under the actions' row,
  // which is 48 high for its touch areas.
  static const feedPaddingTop = BvSpace.s4;
  static const cardGap = BvSpace.s12;
  static const cardPaddingTop = 14.0;
  static const cardPaddingBottom = BvSpace.s6;
  static const authorGap = 10.0;
  static const menuIcon = BvSize.iconMd; // 20
  static const photoHeight = 170.0;
  static const cardActionsGap = BvSpace.s20;
  static const cardActionsHeight = BvSize.touchMin;

  // The latest reply (2587:35889): the faces, "{name}: {words}" and ›.
  static const replyRadius = BorderRadius.all(Radius.circular(BvRadius.photo));
  static const replyPaddingStart = 10.0;
  static const replyPaddingEnd = BvSpace.s6;
  static const replyPaddingVertical = BvSpace.s8;
  static const replyGap = BvSpace.s8;
  static const faceOverlap = BvSpace.s6;
  static const replyCaret = BvSize.iconSm; // 16
}

/// The post page's replies (review 50 F19): small slips one under the
/// other, an answer indented so its slip starts under the name above it.
abstract final class BvReplySpec {
  static const sectionTop = BvSpace.s16;
  static const gap = BvSpace.s12;

  /// Opened at a reply (F30): it comes to the upper part of the page.
  static const scrollAlignment = 0.2;

  /// The avatar and its gap: the text and the actions start under the
  /// name.
  static const indent = BvHomeSpec.authorAvatar + BvSpace.s8;

  /// An answer's slip starts under the name above it.
  static const answerIndent = BvSlipSpec.paddingSide + indent;
  static const nameGap = BvSpace.s6;
  static const actionsGap = BvSpace.s20;

  // The reply bar, in the Daybook post bar's style (spec §8).
  static const barAvatar = BvAvatarSpec.sm;
  static const sendSize = BvSize.touchMin;
  static const sendIcon = BvSize.iconMd;
}
