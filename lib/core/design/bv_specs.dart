// Component measurements from the Figma DS pages ("DS · Button",
// "DS · Chip & Tab", "DS · Inputs", "DS · Controls", "DS · Rows",
// "DS · Avatar & Badge", "DS · Sheet") and the Spaces screens W3a, W3e,
// S10k-C and S20 v3. Written down in docs/product/components.md.
//
// Widgets in lib/shared/widgets read their sizes from here and from
// bv_tokens.dart only. Values that already exist as tokens point at them.

import 'package:flutter/widgets.dart';

import 'bv_tokens.dart';

/// Border widths used by components.
abstract final class BvStroke {
  static const thin = BvSpace.borderWidth; // 1
  static const medium = 1.5;
  static const thick = 2.0;
  // The Daybook's inks: writing card (1.25), small stamps (1.6, 1.8),
  // paper clip (2.2), the large proof stamp (2.5).
  static const dash = 1.25;
  static const stampXs = 1.6;
  static const stampSm = 1.8;
  static const clip = 2.2;
  static const stampLg = 2.5;
}

abstract final class BvButtonSpec {
  static const heightLarge = BvSize.controlLg; // 52
  static const heightMedium = BvSize.controlMd; // 44
  static const paddingLarge = BvSpace.s20;
  static const paddingMedium = BvSpace.s16;
  static const gap = BvSpace.s8;
  static const iconSize = BvSize.iconMd; // 20
}

abstract final class BvChipSpec {
  static const height = 36.0;
  // The height holds the line (22 Latin, 26 Arabic) centred.
  static const paddingVertical = BvSpace.s4;
  static const paddingHorizontal = BvSpace.s12;
  static const gap = BvSpace.s6;
  static const iconSize = BvSize.iconSm; // 16
  static const rowGap = BvSpace.s8;
}

abstract final class BvTabsSpec {
  static const height = BvSize.touchMin; // 48
  static const paddingHorizontal = BvSpace.s16;
  static const indicatorHeight = 2.0;
  static const indicatorRadius = BorderRadius.all(Radius.circular(1));
}

abstract final class BvFieldSpec {
  static const height = BvSize.touchMin; // 48
  static const paddingHorizontal = BvSpace.s12;
  static const gap = BvSpace.s6;
  static const iconSize = BvSize.iconMd; // 20
  static const helperIconSize = 14.0;
  static const codeLength = 6;
  static const dialBoxWidth = 92.0;
  static const codeBoxHeight = 56.0;
  static const codeBoxGap = BvSpace.s8;

  /// Vertical padding that centres one line of [style] in a 48 field.
  static double paddingFor(TextStyle style) {
    final line = (style.fontSize ?? 0) * (style.height ?? 1);
    return line >= height ? 0 : (height - line) / 2;
  }

  /// Share of the limit after which a multi-line field shows its counter.
  static const counterThreshold = 0.8;
}

abstract final class BvControlSpec {
  static const tapArea = BvSize.touchMin; // 48

  static const switchWidth = 48.0;
  static const switchHeight = 28.0;
  static const switchRadius = BorderRadius.all(Radius.circular(14));
  static const switchPadding = BvSpace.s2;
  static const switchThumb = BvSize.iconLg; // 24

  static const checkboxSize = 22.0;
  static const checkboxRadius = BvRadius.smallAll; // 6
  static const checkIconSize = BvSize.iconSm; // 16

  static const radioSize = 22.0;
  static const radioDot = 10.0;
}

abstract final class BvListRowSpec {
  static const paddingVertical = BvSpace.s12;
  static const paddingHorizontal = BvSpace.s16;
  static const gap = BvSpace.s12;
  static const minHeight = 64.0;
  static const leadingSize = BvSize.avatarMd; // 40
  static const leadingIconSize = BvSize.iconLg; // 24
  static const textGap = BvSpace.s2;
  static const chevronSize = BvSize.iconMd; // 20

  /// Divider inset when the row has a leading tile.
  static const dividerInset = paddingHorizontal + leadingSize + gap;
}

abstract final class BvChoiceCardSpec {
  static const paddingVertical = BvSpace.s12;
  static const paddingHorizontal = BvSpace.s16;
  static const gap = BvSpace.s12;
  static const iconSize = BvSize.iconLg; // 24
  static const listGap = BvSpace.s8;
}

abstract final class BvAvatarSpec {
  // The Daybook's small faces: properties line (18), an update (20), slip
  // header (24), Home slip (28), the give-to list (30).
  static const xxs = 18.0;
  static const note = 20.0;
  static const xs = 24.0;
  static const xsm = 28.0;
  static const list = 30.0;
  static const xxsInitials = 9.0;

  /// Two letters inside 20 (Figma's 12 spills over the edge).
  static const noteInitials = 10.0;

  /// The faces before a post's latest reply (H1 v4 2587:35890), and their
  /// letters.
  static const face = 22.0;
  static const faceInitials = 9.0;
  static const sm = BvSize.avatarSm; // 32

  /// A post card's author (H1 v4 2587:35877).
  static const post = 36.0;
  static const md = BvSize.avatarMd; // 40
  static const lg = BvSize.avatarLg; // 56

  /// The profile header in Daybook (R1 v4).
  static const profile = 64.0;
  static const xl = BvSize.avatarXl; // 88
  static const companyRadiusSmall = BorderRadius.all(Radius.circular(8));
  static const companyRadiusLarge = BvRadius.cardAll; // 14

  /// Icon share of the tile on project and Space avatars.
  static const projectIconRatio = 0.5;
}

abstract final class BvBadgeSpec {
  static const height = 20.0;
  // The height holds the small line (16 Latin, 18 Arabic) centred.
  static const paddingVertical = 1.0;
  static const paddingHorizontal = BvSpace.s8;
  static const radius = BvRadius.smallAll; // 6
  static const iconSize = 12.0;
}

abstract final class BvSheetSpec {
  static const paddingTop = 10.0;
  static const paddingSide = BvSpace.s16;
  static const paddingBottom = BvSpace.s16;
  static const gap = BvSpace.s12;
  static const handleWidth = 36.0;
  static const handleHeight = 4.0;
  static const handleRadius = BorderRadius.all(Radius.circular(2));
  static const subtitleGap = BvSpace.s2;
  static const footerGap = BvSpace.s12;

  /// Tallest a sheet may grow, as a share of the screen height.
  static const maxHeightRatio = 0.9;
}

abstract final class BvStampSpec {
  static const border = BvStroke.thick;
  static const radius = BvRadius.smallAll; // 6
  static const paddingVertical = 3.0;
  static const paddingHorizontal = BvSpace.s8;

  /// −3° in left-to-right, +3° in right-to-left.
  static const tiltDegrees = 3.0;
}

/// The site tag's shape (a punched card), which the invite code card keeps.
abstract final class BvSiteTagSpec {
  static const radius = BorderRadius.all(Radius.circular(16));
  static const border = BvStroke.medium;
  static const holeSize = 12.0;
  static const holeTop = BvSpace.s8;
}

/// RE1 · the label column of the facts table.
abstract final class BvDeliveredSpec {
  static const labelWidth = 96.0;
}

/// A centred dialog for a choice that can't be undone (S15c Leave, S15e
/// Transfer).
abstract final class BvDialogSpec {
  static const radius = BorderRadius.all(Radius.circular(BvRadius.sheet));
  static const inset = 36.0; // from the screen edges
  static const padding = BvSpace.s24;
  static const gap = BvSpace.s12;
  static const buttonsTop = BvSpace.s24;
}

/// The invite code card (S16, MVP): the site tag's shape around one large
/// code.
abstract final class BvCodeTagSpec {
  static const paddingTop = 28.0; // below the punched hole
  static const paddingSide = BvSpace.s16;
  static const paddingBottom = BvSpace.s16;
  static const gap = BvSpace.s8;
  static const codeLetterSpacing = 4.0;
}

abstract final class BvPassCardSpec {
  static const radius = BorderRadius.all(Radius.circular(12));
  static const bandWidth = BvSpace.s8;
  static const paddingVertical = 10.0;
  static const paddingHorizontal = BvSpace.s12;
  static const gap = 3.0;
  static const listGap = BvSpace.s8;
}

abstract final class BvSitePhotoSpec {
  static const radius = BvRadius.cardAll; // 14
  static const stampInset = BvSpace.s12;
  static const stampRadius = BorderRadius.all(Radius.circular(8));
  static const stampPaddingVertical = BvSpace.s6;
  static const stampPaddingHorizontal = 10.0;
  static const stampGap = BvSpace.s6;
  static const stampIconSize = 14.0;
  static const aspectRatio = 4 / 3;
}

/// Gallery layout (debug screen only).
abstract final class BvGallerySpec {
  static const sectionGap = BvSpace.s32;
  static const itemGap = BvSpace.s12;
}

abstract final class BvStepProgressSpec {
  static const height = 4.0;
  static const gap = BvSpace.s8;
  static const radius = BorderRadius.all(Radius.circular(2));
}

/// Entry screens (E1, E2): the hero with the wordmark and skyline.
abstract final class BvEntrySpec {
  static const heroHeight = 200.0;
  static const pillPaddingVertical = BvSpace.s6;
  static const pillPaddingHorizontal = BvSpace.s16;
  static const audienceCardHeight = 196.0;
  static const audienceIconTile = BvSize.avatarLg; // 56
  static const accentBarWidth = 3.0;
  static const accentBarHeight = BvSpace.s16;
  static const dotSize = BvSpace.s6;
  static const dotActiveWidth = BvSpace.s20;
  static const rotateEvery = Duration(seconds: 4);
  static const skylineOpacity = 0.6;

  /// Skyline blocks: (start as a share of the width, width, height).
  static const skyline = [
    (0.0, 54.0, 40.0),
    (0.16, 54.0, 90.0),
    (0.66, 54.0, 98.0),
    (0.84, 46.0, 50.0),
    (0.96, 20.0, 82.0),
  ];
}

/// Sign-in codes (E3).
abstract final class BvAuthSpec {
  /// Matches the server's minimum time between codes (config.toml).
  static const resendAfter = Duration(seconds: 60);
  static const searchDebounce = Duration(milliseconds: 300);
}

/// Title block (PJ1, P14): a drawing title block for a project record.
abstract final class BvTitleBlockSpec {
  static const border = BvStroke.medium;
  static const radius = BvRadius.smallAll; // 6
  static const headerPaddingVertical = BvSpace.s12;
  static const cellPaddingVertical = BvSpace.s12;
  static const paddingHorizontal = BvSpace.s16;
  static const cellGap = BvSpace.s4;
  static const iconSize = BvSize.iconMd; // 20
}

/// Month picker sheet.
abstract final class BvMonthPickerSpec {
  static const columns = 3;
  static const gap = BvSpace.s8;
  static const firstYear = 1970;
  static const yearsAhead = 10;
  static const cellAspect = 2.4;
}

/// Profile header (R1, R5).
abstract final class BvProfileSpec {
  static const avatarGap = BvSpace.s16;
  static const sectionGap = BvSpace.s24;
  static const cardPadding = BvSpace.s16;
  static const iconButton = BvSize.controlMd; // 44
}

/// Space chat threads (S8k, S9k).
abstract final class BvChatSpec {
  /// A bubble is at most this share of the screen width.
  static const bubbleMaxWidth = 0.75;
  static const bubbleRadius = BvRadius.cardAll; // 14
  static const bubblePaddingHorizontal = BvSpace.s12;
  static const bubblePaddingVertical = BvSpace.s8;
  static const avatar = BvSize.avatarSm; // 32
  static const avatarGap = BvSpace.s8;

  /// Between messages of one person, and between people.
  static const runGap = BvSpace.s4;
  static const groupGap = BvSpace.s12;

  /// The quoted message in a reply: a bar on the start side.
  static const replyBar = 3.0;

  /// One photo shows large; several make a grid of squares.
  static const photoLarge = 220.0;
  static const photoLargeAspect = 0.75;
  static const photoSmall = 108.0;

  /// A picked file's name above the message box.
  static const pickedName = 140.0;

  /// A voice note in a bubble, and its progress bar.
  static const voiceWidth = 200.0;
  static const voiceBar = 4.0;

  /// The red dot while recording, and how far to slide to cancel.
  static const recordDot = 10.0;
  static const slideToCancel = 80.0;
}

/// F1 · Drawing preview.
abstract final class BvPreviewSpec {
  /// The drawing sheet: wider than tall, like an A-size sheet.
  static const sheetAspect = 1.4;
  static const maxZoom = 5.0;
}

/// Toasts (snack bars).
abstract final class BvToastSpec {
  /// Lifted clear of a floating action such as "Add file" or "New item":
  /// its height, and the 16 it sits off the edge, plus 16 between.
  static const lift = BvButtonSpec.heightLarge + BvSpace.s16 * 2;
}

/// Post cards on Home (H1 v3).
abstract final class BvPostSpec {
  static const photoGap = BvSpace.s2;

  /// Shown at most while the first page loads (H4), then the copy kept on
  /// the phone, if any.
  static const skeletonFor = Duration(seconds: 3);
}

/// Week 7 part 2: the "something new" dot, Home H1b and Activity A1.
abstract final class BvActivitySpec {
  /// On the Spaces tab label and the Activity tab icon. Never a number.
  static const newDot = BvSpace.s6;

  static const needsOnHome = 3;

  /// F10: a Needs you card and a Your Spaces row are easy to hit.
  static const cardMinHeight = 64.0;
  static const cardPadding = BvSpace.s12;
  static const cardPaddingStart = BvSpace.s16;
  static const cardGap = BvSpace.s12;
  static const lineGap = BvSpace.s2;

  /// Home → Spaces: New Space and Join with a code above the list.
  static const actionsGap = BvSpace.s8;

  // Activity v3 (A1 v3 2587:76920): one list, 8 apart, 16 from each edge.
  static const listGap = BvSpace.s8;
  static const listPaddingTop = BvSpace.s4;

  /// The slim "Needs you ›" line at the top, on the brand's soft surface.
  static const needsLineRadius = BorderRadius.all(
    Radius.circular(BvRadius.toast),
  );
  static const needsLinePaddingStart = BvSpace.s12;
  static const needsLinePaddingEnd = BvSpace.s8;
  static const needsLinePaddingVertical = BvSpace.s12;
  static const needsLineGap = 10.0;
  static const needsLineIcon = 18.0;

  /// A day's name above its rows.
  static const dayPaddingTop = 10.0;
  static const dayPaddingBottom = BvSpace.s2;

  /// A row: the face (40), what happened and where, then the time with the
  /// unread dot and the paper clip under it. At least 64 high.
  static const rowPaddingVertical = 10.0;
  static const rowGap = BvSpace.s12;
  static const rowDot = BvSpace.s8;
  static const rowClip = BvSize.iconSm; // 16
  static const rowEndGap = BvSpace.s6;
}

/// Week 7 part 3: Settings → Notifications (S3, S4).
abstract final class BvPushSpec {
  /// S4: the switches fade while the phone blocks notifications. They still
  /// work, so a person can set them before turning push on.
  static const offOpacity = 0.55;
}

/// S11 and S14: the message sits in the upper third, as drawn.
abstract final class BvAccountSpec {
  static const resultAlignment = Alignment(0, -0.45);
}

/// F9: "Notifications aren't reaching this phone", a quiet line with Fix
/// it, on Home and in Settings → Notifications. No Figma frame: the Due
/// today strip's build, in the subtle surface.
abstract final class BvQuietLineSpec {
  static const paddingStart = BvSpace.gutter;

  /// Fix it's tap area reaches nearly to the edge.
  static const paddingEnd = BvSpace.s4;
  static const gap = BvSpace.s8;
  static const icon = BvSize.iconSm;
  static const actionPadding = BvSpace.s12;
}

/// F11: the "New" chip when new entries arrive while the reader is away
/// from Now (the Daybook's bottom, the Home feed's top).
abstract final class BvNewChipSpec {
  static const height = BvSpace.s32;
  static const paddingHorizontal = BvSpace.s12;
  static const gap = BvSpace.s4;
  static const icon = BvSize.iconSm;
  static const tapPadding = (BvSize.touchMin - height) / 2;

  /// From the list's edge at Now.
  static const offset = BvSpace.s12;

  /// Further than this from Now, the reader is up in older entries: new
  /// ones wait behind the chip instead of moving the page.
  static const awayFromNow = BvSpace.s64 + BvSpace.s32;
}

/// F81: a direct message that arrives while the app is open, as a quiet
/// banner at the top; a tap opens its conversation.
abstract final class BvMessageBannerSpec {
  static const margin = BvSpace.s8;
  static const padding = BvSpace.s12;
  static const gap = BvSpace.s2;
  static const radius = BvRadius.cardAll;

  /// Long enough to read a line; it goes by itself. A newer message of the
  /// same conversation starts it again (F99).
  static const shown = Duration(seconds: 4);

  /// It slides down from above the top, and back up when it goes.
  static const slide = BvMotion.base;
  static const from = Offset(0, -1.5);
}

/// Review 91: the handover from the native splash. Once start-up knows the
/// first screen, that screen fades in from the splash colour: a plain fade
/// with no text and no extra wait, on every start.
///
/// Addendum (25 Oct): while start-up is still running after [traceAfter],
/// the cube traces itself ([trace], then [fill], then [letters]); never
/// longer than [loaderMax] after the native splash goes. Reduce motion: no
/// trace.
abstract final class BvSplashSpec {
  static const colour = BvColors.brandSplash;
  static const fade = Duration(milliseconds: 350);

  /// Decided before this, there's no trace.
  static const traceAfter = Duration(milliseconds: 300);
  static const trace = Duration(milliseconds: 600);
  static const fill = Duration(milliseconds: 200);
  static const letters = Duration(milliseconds: 150);
  static const loader = Duration(milliseconds: 950); // trace + fill + letters

  /// Decided mid-trace: the rest plays in this time.
  static const finishIn = Duration(milliseconds: 150);
  static const loaderMax = Duration(milliseconds: 1200);
  static const traceCurve = Curves.easeInOutCubic;
  static const stroke = 2.5;

  /// Where the native splash draws the cube: its image is 288 dp across
  /// for the SVG's 108 units, centred, with the cube at 0.72 scale
  /// (assets/brand/bv_splash.svg). One cube unit in dp.
  static const cubeUnit = 288 / 108 * 0.72;
}

/// Hold to confirm (review 94): a round pill like the slip's action, or a
/// full-width bar in a sheet; the hint 6 under it.
abstract final class BvHoldSpec {
  static const paddingStart = BvSpace.s12;
  static const paddingEnd = 14.0;
  static const paddingVertical = 9.0;
  static const gap = BvSpace.s8;
  static const icon = 18.0;
  static const barHeight = BvSize.touchMin;
  static const hintGap = BvSpace.s6;

  /// In a sheet: the words, then the bar 16 under them.
  static const sheetGap = BvSpace.s16;

  /// A finger that wanders this far off the button lets go.
  static const slop = BvSpace.s24;

  /// The "Keep holding to confirm" line shows after the first two early
  /// lets-go on a phone, then no more.
  static const hintTimes = 2;
}

/// Back by swipe on an iPhone (review 100 B6): a swipe in from the leading
/// edge, as wide as the iPhone's own, goes back once it has crossed a
/// third of the screen or was flung.
abstract final class BvBackSwipeSpec {
  static const edge = BvSpace.s20;
  static const distance = 1 / 3;
  static const fling = 300.0;
}

/// A card that swipes (review 100 Part 3b, BH3): round 48 buttons on the
/// page's background, each in a 72 slot; a quarter of the card's width
/// opens them, 60% is the full swipe; the card flies off in 200 ms and its
/// row closes in 180 ms; the buttons grow from 60%.
abstract final class BvSwipeSpec {
  static const button = 48.0;
  static const icon = BvSize.iconMd;
  static const slot = 72.0;
  static const inset = BvSpace.s8;
  static const pillPadding = BvSpace.s16;
  static const halfSwipe = 0.25;
  static const fullSwipe = 0.6;
  static const flyPast = 1.1;
  static const growFrom = 0.6;

  /// The second button a step behind the first (40 ms of a swipe).
  static const lag = BvSpace.s12;

  /// Not from the screen's edges: the system's back gesture keeps them.
  static const edge = 24.0;
  static const fly = Duration(milliseconds: 200);
  static const rowClose = Duration(milliseconds: 180);
  static const settle = Duration(milliseconds: 220);
  static const hintHold = Duration(seconds: 1);
  static const cardRadius = BorderRadius.all(Radius.circular(BvRadius.photo));
}
