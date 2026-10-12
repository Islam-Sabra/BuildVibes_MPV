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
  static const paddingVertical = BvSpace.s6;
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
  static const sm = BvSize.avatarSm; // 32
  static const md = BvSize.avatarMd; // 40
  static const lg = BvSize.avatarLg; // 56
  static const xl = BvSize.avatarXl; // 88
  static const companyRadiusSmall = BorderRadius.all(Radius.circular(8));
  static const companyRadiusLarge = BvRadius.cardAll; // 14

  /// Icon share of the tile on project and Space avatars.
  static const projectIconRatio = 0.5;
}

abstract final class BvBadgeSpec {
  static const height = 20.0;
  static const paddingVertical = BvSpace.s2;
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

  // Large: the proof stamp across a site tag ("CHECKED · 10 OCT · …",
  // review 10): about 30 high, a 2 px border, bold, −4°.
  static const largeHeight = 30.0;
  static const largePaddingHorizontal = BvSpace.s12;
  static const largeTiltDegrees = 4.0;
}

abstract final class BvSiteTagSpec {
  static const radius = BorderRadius.all(Radius.circular(16));
  static const border = BvStroke.medium;
  static const holeSize = 12.0;
  static const holeTop = BvSpace.s8;
  static const headPaddingTop = 14.0;
  static const headPaddingSide = BvSpace.s16;
  static const headPaddingBottom = 10.0;
  static const bodyPaddingSide = BvSpace.s16;
  static const bodyPaddingBottom = 14.0;
  static const bodyGap = BvSpace.s8;
  static const placeIconSize = BvSize.iconSm; // 16
  static const placeGap = BvSpace.s6;
  static const cellPaddingVertical = 10.0;
  static const cellPaddingHorizontal = BvSpace.s12;
  static const cellGap = BvSpace.s4;
  static const headGap = BvSpace.s8;
}

/// RE1 · the label column of the facts table.
abstract final class BvDeliveredSpec {
  static const labelWidth = 96.0;
}

/// W4 · Sign DONE sheet.
abstract final class BvSignDoneSpec {
  static const thumb = 96.0;
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

abstract final class BvSignOffSpec {
  static const labelGap = BvSpace.s8;
  static const radius = BorderRadius.all(Radius.circular(12));
  static const cellPaddingTop = 10.0;
  static const cellPaddingSide = 10.0;
  static const cellPaddingBottom = BvSpace.s12;
  static const cellGap = BvSpace.s6;
}

abstract final class BvWorkItemCardSpec {
  static const radius = BvRadius.cardAll; // 14
  static const headerPaddingVertical = BvSpace.s12;
  static const paddingHorizontal = BvSpace.s16;
  static const bodyPaddingVertical = 14.0;
  static const bodyGap = BvSpace.s4;
  static const thumbSize = BvSize.avatarMd; // 40
  static const thumbRadius = BorderRadius.all(Radius.circular(8));
  static const evidenceGap = BvSpace.s8;
  static const actionPaddingBottom = 14.0;
  static const headerGap = BvSpace.s8;
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
  static const bubbleMaxWidth = 0.78;
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
}
