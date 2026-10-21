// The Daybook's paper: slip, ink stamp and paper clip. Measured from Figma
// D1 (2518:33001) and the Daybook frames, slice 1a ("DS · Daybook
// components"). Values that already exist as tokens point at them.

import 'package:flutter/widgets.dart';

import 'bv_specs.dart';
import 'bv_tokens.dart';

/// The paper card (spec §2) and its parts.
abstract final class BvSlipSpec {
  // Box. The tear sits inside the top of the shape, so it adds to the top
  // padding.
  static const paddingTop = BvSpace.s16;
  static const paddingBottom = 14.0;
  static const paddingSide = 14.0;
  static const gap = 10.0;
  static const cancelledOpacity = 0.55;

  // Overlays, placed before their tilt and measured from below the tear
  // (Figma draws the tear above the slip box). The paper clip sticks out
  // above the torn edge.
  static const stampTop = 14.0;
  static const stampTopCancelled = BvSpace.s16;
  static const stampEnd = BvSpace.s16;
  static const clipTop = -14.0;
  static const clipEnd = BvSpace.s16;

  /// The stamp moves past the clip (14 wide, tilted to about 21) when a
  /// slip has both, so they never overlap (review 45, 1b note).
  static const stampEndWithClip = 44.0;

  /// The ⋯ menu (H1 v3 2555:35317): 18, 8 after the first line, centred
  /// on its 16-high first line in a 48 touch area that starts at the top
  /// of the paper (review 50 F19).
  static const menuIcon = 18.0;
  static const menuGap = BvSpace.s8;
  static const firstLine = BvSpace.s16;
  static double menuTopFor(double line) =>
      paddingTop + line / 2 - BvSize.touchMin / 2;

  /// A proof with no photo (F6, review 50): the large stamp is pressed
  /// under the note at the end side, in its own room (with some for its
  /// tilt), never over the header. No frame draws it.
  static const stampNoPhotoPadding = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s8,
    vertical: BvSpace.s6,
  );

  // Header: avatar 24, name, action phrase.
  static const headerHeight = BvAvatarSpec.xs;
  static const headerGap = BvSpace.s8;

  // Facts (v13 2581:35668): an icon 14 and a grey line, 4 apart.
  static const factsGap = BvSpace.s4;
  static const factGap = BvSpace.s6;
  static const factIconSize = 14.0;

  // Attachment chip.
  static const chipRowGap = BvSpace.s6;
  static const chipHeight = 26.0;
  static const chipRadius = BvRadius.smallAll; // 6
  static const chipPaddingStart = BvSpace.s8;
  static const chipPaddingEnd = 10.0;
  // 26 high holds the small line (16 Latin, 18 Arabic).
  static const chipPaddingVertical = BvSpace.s4;
  static const chipGap = 5.0;
  static const chipIconSize = 14.0;

  // Quote row: a short orange bar before the quoted work item.
  static const quoteGap = BvSpace.s8;
  static const quoteBarWidth = BvSpace.s2;
  static const quoteBarHeight = BvSpace.s16;

  // Photo. 190 on Home's proof; 132 on a daybook card (v13), the latest
  // proof or the cover.
  static const photoRadius = BorderRadius.all(Radius.circular(BvRadius.photo));
  static const photoHeightProof = 190.0;
  static const photoHeightCard = 132.0;
  // The stamp sits near the middle of a card's photo (v13 2581:35678).
  static const photoStampTop = 44.0;
  static const photoStampStart = 88.0;

  // Pills: the hint and the action ("Sign as done").
  static const hintPaddingHorizontal = 10.0;
  static const hintPaddingVertical = BvSpace.s6;
  static const actionPaddingStart = BvSpace.s12;
  static const actionPaddingEnd = 14.0;
  static const actionPaddingVertical = 9.0;
  static const actionGap = BvSpace.s8;
  static const actionIconSize = 18.0;

  // Late line (L1 2539:34737): a calendar 14 and the words, in red.
}

/// The daybook in v13 (review 53, F25 and F26): one full-width card per
/// work item, 16 from each edge, 12 apart (2581:35638).
abstract final class BvCardSpec {
  static const paddingSide = BvSpace.s16;
  static const paddingTop = BvSpace.s4;
  static const paddingBottom = BvSpace.s12;
  static const gap = BvSpace.s12;
}

/// A card's history (v13 2581:35681): a thin line on the leading side, then
/// one line per event with a small face and its time.
abstract final class BvCardHistorySpec {
  static const rule = BvStroke.thick; // 2
  static const paddingStart = 10.0;
  static const gap = BvSpace.s8;
  static const lineGap = BvSpace.s8;
}

/// A trace on an earlier day (v13 2581:35643): one line on the subtle
/// surface, the face, the words, the time and ›.
abstract final class BvTraceSpec {
  static const minHeight = 40.0;
  static const paddingStart = 10.0;
  static const paddingEnd = BvSpace.s6;
  static const paddingVertical = BvSpace.s6;
  static const radius = BorderRadius.all(Radius.circular(BvRadius.photo));
  static const gap = BvSpace.s8;
  static const caret = BvSize.iconSm; // 16
}

/// The Daybook's ink stamp (spec §3): white fill, ExtraBold capitals,
/// tilted clockwise in left to right.
abstract final class BvInkStampSpec {
  static const borderLg = BvStroke.stampLg;
  static const borderMd = BvStroke.thick;
  static const borderSm = BvStroke.stampSm;
  static const borderXs = BvStroke.stampXs;

  static const radius = BorderRadius.all(Radius.circular(BvRadius.small));
  static const radiusXs = BorderRadius.all(Radius.circular(BvRadius.tiny));

  static const paddingLg = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s12,
    vertical: BvSpace.s6,
  );
  static const paddingMd = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s8,
    vertical: BvSpace.s4,
  );
  static const paddingSm = EdgeInsetsDirectional.symmetric(
    horizontal: 7.0,
    vertical: 3.0,
  );
  static const paddingXs = EdgeInsetsDirectional.symmetric(
    horizontal: BvSpace.s6,
    vertical: BvSpace.s2,
  );

  static const fontSizeLg = 22.0;
  static const fontSizeMd = 15.0;
  static const fontSizeSm = 11.0;
  static const fontSizeXs = 10.0;
  static const fontSizeXs9 = 9.0;
  static const fontSizeXs8 = 8.0;

  /// The second line of the large stamp ("OMAR H · 09:40").
  static const sublineFontSize = 10.0;

  /// Tracking as a share of the font size (Latin only; Arabic is 0).
  static const trackingEm = 0.14;
  static const trackingEmXs = 0.12;
  static const sublineTrackingEm = 0.08;

  /// Figma line height "normal".
  static const lineHeight = 1.26;

  /// Clockwise in left to right, mirrored in right to left.
  static const tiltLg = 9.0;
  static const tiltMd = 7.0;
  static const tiltSm = 7.0;
  static const tiltXs = 5.0;

  /// md and lg print at 90 %; sm and xs at full ink.
  static const opacityInk = 0.9;
  static const opacityFull = 1.0;

  // Landing (2519:33157): from scale 1.3, 6° more tilt (lg: 15° → 9°) and
  // opacity 0.18, in 180 ms.
  static const landScale = 1.3;
  static const landExtraTilt = 6.0;
  static const landOpacity = 0.18;
  static const landDuration = Duration(milliseconds: 180);
}

/// The paper clip on a slip that needs you (spec §4): two rounded
/// rectangles, tilted +12° in left to right.
abstract final class BvPaperClipSpec {
  static const outerSize = Size(14, 34);
  static const outerRadius = 7.0;
  static const outerStroke = BvStroke.clip;
  static const innerSize = Size(7, 22);
  static const innerOffset = Offset(3.5, 7);
  static const innerRadius = 3.5;
  static const innerStroke = BvStroke.thick;
  static const tiltDegrees = 12.0;
}
