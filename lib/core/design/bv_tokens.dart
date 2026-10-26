// BuildVibes design tokens.
//
// Source of truth: Figma file IcoK4u8JFO6K8l4YYiHNkm, local variables
// (collections "Color / Primitive", "Color / Semantic", "Color / Project",
// "Spacing", "Radius", "Size", "Motion") and text styles "Type/Latin/*",
// "Type/Arabic/*". Exported 11 Oct 2026 from the signed-off prototype.
//
// Rules:
// - Widgets use BvColors / BvSpace / BvRadius / BvSize / BvMotion / BvType only.
// - Never type a hex colour, a font size or a magic number into a widget.
// - Light mode only for V1 (dark mode is deferred by the founder).
// - The "Legacy / BV *" Figma collections are not used.

import 'package:flutter/widgets.dart';

/// Raw palette. Do not use in widgets; use [BvColors].
abstract final class BvPrimitive {
  static const ink = Color(0xFF141B33);
  static const energy = Color(0xFFE65A28);
  static const energySoft = Color(0xFFFCEEE7);
  static const energyStrong = Color(0xFFC24417);
  static const energyPressed = Color(0xFFA33812);
  static const warmBase = Color(0xFFF8F4EE);
  static const elevated = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFF1EDE6);
  static const border = Color(0xFFE5DFD6);
  static const borderStrong = Color(0xFFA08A6A);
  static const textSecondary = Color(0xFF6B6578);
  static const disabled = Color(0xFFD4CFC7);
  static const positive = Color(0xFF2D8A5E);
  static const positiveStrong = Color(0xFF297C55);
  static const warning = Color(0xFFD4921A);
  static const warningStrong = Color(0xFF946612);
  static const destructive = Color(0xFFC23B3B);
  // Hold to confirm (review 94): a destructive hold at rest.
  static const destructiveSoft = Color(0xFFF8E6E3);
  // The line menu's Delete tile (review 98, NBY2).
  static const destructiveTint = Color(0xFFFBEAEA);
  static const ink48 = Color(0x7A141B33);
  static const ink38 = Color(0x61141B33);
  // The app icon's cube (review 91): its left and right faces.
  static const cubeLeft = Color(0xFFF8F1E8);
  static const cubeRight = Color(0xFFE6DACA);
}

/// Semantic colours ("Color / Semantic", Light mode).
abstract final class BvColors {
  // Surfaces
  static const surfaceApp = BvPrimitive.warmBase;
  static const surfaceElevated = BvPrimitive.elevated;
  static const surfaceSubtle = BvPrimitive.subtle;
  static const surfaceSelected = BvPrimitive.energy;
  static const surfaceBrandSoft = BvPrimitive.energySoft;

  // Text
  static const textPrimary = BvPrimitive.ink;
  static const textSecondary = BvPrimitive.textSecondary;
  static const textInverse = BvPrimitive.elevated;
  static const textAction = BvPrimitive.energyStrong;
  static const textPositive = BvPrimitive.positiveStrong;
  static const textWarning = BvPrimitive.warningStrong;
  static const textDestructive = BvPrimitive.destructive;

  // Borders
  static const borderDefault = BvPrimitive.border;
  static const borderSubtle = BvPrimitive.border;
  static const borderSelected = BvPrimitive.energy;
  static const borderDestructive = BvPrimitive.destructive;
  static const borderFocus = BvPrimitive.energy;
  static const borderInput = BvPrimitive.borderStrong;

  // Actions
  static const actionPrimary = BvPrimitive.energyStrong;
  static const actionPrimaryPressed = BvPrimitive.energyPressed;
  static const actionPrimaryForeground = BvPrimitive.elevated;
  static const actionSecondary = BvPrimitive.elevated;
  static const actionDisabled = BvPrimitive.disabled;
  static const actionDisabledForeground = BvPrimitive.textSecondary;

  // Icons
  static const iconPrimary = BvPrimitive.ink;
  static const iconSecondary = BvPrimitive.textSecondary;
  static const iconAction = BvPrimitive.energy;
  static const iconInverse = BvPrimitive.elevated;

  // Feedback
  static const feedbackSuccess = BvPrimitive.positive;
  static const feedbackWarning = BvPrimitive.warning;
  static const feedbackError = BvPrimitive.destructive;

  // Overlay
  static const overlayScrim = BvPrimitive.ink48;

  /// Behind the Daybook's long-press menus and month drop-down (lighter
  /// than the sheet scrim).
  static const overlayDim = BvPrimitive.ink38;

  // Brand (wordmark, Lead pass band)
  static const brandInk = BvPrimitive.ink;
  static const brandEnergy = BvPrimitive.energy;
  static const brandEnergySoft = BvPrimitive.energySoft;

  /// The app icon's and the native splash's terracotta (review 91); the
  /// first screen fades in from it.
  static const brandSplash = BvPrimitive.energyStrong;

  /// The cube on the splash (review 91 addendum): its outline while it
  /// traces itself, its three faces, and the B and V.
  static const brandCubeOutline = BvPrimitive.elevated;
  static const brandCubeTop = BvPrimitive.elevated;
  static const brandCubeLeft = BvPrimitive.cubeLeft;
  static const brandCubeRight = BvPrimitive.cubeRight;
  static const brandCubeLetters = BvPrimitive.energyStrong;

  /// Hold to confirm (review 94): the button at rest, the fill that runs
  /// from the start side while it is held, and their words. Cancel and
  /// Remove from Space hold in red.
  static const holdRest = BvPrimitive.energySoft;
  static const holdFill = BvPrimitive.energyStrong;
  static const holdLabel = BvPrimitive.energyStrong;
  static const holdLabelFilled = BvPrimitive.elevated;
  static const holdRestDestructive = BvPrimitive.destructiveSoft;

  /// The line menu (review 98): a destructive row's tile.
  static const surfaceDestructiveSoft = BvPrimitive.destructiveTint;
  static const holdFillDestructive = BvPrimitive.destructive;
  static const holdLabelDestructive = BvPrimitive.destructive;
}

/// Accent colours for project and Space avatars ("Color / Project").
abstract final class BvProjectColors {
  static const slate = Color(0xFF4F6D94);
  static const sage = Color(0xFF5E8A6E);
  static const ochre = Color(0xFFA8812F);
  static const clay = Color(0xFF9C5F52);
  static const plum = Color(0xFF76628F);
  static const teal = Color(0xFF3F8283);
  static const neutral = Color(0xFF8A8478);

  static const all = [slate, sage, ochre, clay, plum, teal, neutral];

  /// Stable colour for an id, so a project keeps its colour everywhere.
  static Color forId(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return all[h % all.length];
  }
}

/// Avatar fills for people without a photo, in the Daybook (Figma Avatar
/// variants). Stable for a person id, so someone keeps their colour.
abstract final class BvAvatarTints {
  static const plain = BvPrimitive.subtle;
  static const green = Color(0xFFE0F0E3);
  static const clay = Color(0xFFF2E0D6);
  static const ochre = Color(0xFFF5E8D1);

  static const all = [plain, green, clay, ochre];

  static Color forId(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return all[h % all.length];
  }
}

/// Spacing scale ("Spacing").
abstract final class BvSpace {
  static const s2 = 2.0;
  static const s4 = 4.0;
  static const s6 = 6.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
  static const s48 = 48.0;
  static const s64 = 64.0;

  /// Side gutter of every screen.
  static const gutter = s16;
  static const borderWidth = 1.0;
}

/// Corner radii ("Radius").
abstract final class BvRadius {
  static const small = 6.0;
  static const control = 10.0;
  static const card = 14.0;
  static const sheet = 20.0;
  static const round = 999.0;

  // The Daybook's paper: stamps and pass chips (4), photos (8), the bottom
  // of a slip (10), toasts and the day-one card (12), the month drop-down (18).
  static const tiny = 4.0;
  static const photo = 8.0;
  static const slip = control;
  static const toast = 12.0;
  static const dropdown = 18.0;

  static const smallAll = BorderRadius.all(Radius.circular(small));
  static const controlAll = BorderRadius.all(Radius.circular(control));
  static const cardAll = BorderRadius.all(Radius.circular(card));
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
  static const roundAll = BorderRadius.all(Radius.circular(round));
}

/// Sizes ("Size").
abstract final class BvSize {
  static const touchMin = 48.0;
  static const controlMd = 44.0;
  static const controlLg = 52.0;

  /// A screen's top bar (the theme's app bar; review 100 D7: what a card
  /// next to a line stays under).
  static const topBar = 56.0;
  static const iconSm = 16.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;
  static const avatarSm = 32.0;
  static const avatarMd = 40.0;
  static const avatarLg = 56.0;
  static const avatarXl = 88.0;
}

/// Bottom bar sizes, from the Figma component "DS · Navigation / Bottom nav"
/// (2022:18). Review 01, 11 Oct 2026.
abstract final class BvBottomBarSize {
  /// Bar height, not counting the phone's safe area.
  static const height = 64.0;
  static const paddingTop = BvSpace.s4;
  static const paddingSide = BvSpace.s8;
  static const slotWidth = 72.0;
  static const slotHeight = 56.0;
  static const gap = BvSpace.s2;

  /// Orange line above the active tab's icon.
  static const indicatorWidth = 20.0;
  static const indicatorHeight = 2.0;
  static const indicatorRadius = BorderRadius.all(Radius.circular(1));

  static const createWidth = 40.0;
  static const createHeight = 28.0;
}

/// Motion ("Motion").
abstract final class BvMotion {
  static const instant = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 360);
  static const sheet = Duration(milliseconds: 420);
  static const stagger = Duration(milliseconds: 40);

  /// Hold to confirm (review 94): held this long, it acts; let go early,
  /// the fill runs back in [holdBack].
  static const hold = Duration(milliseconds: 600);
  static const holdBack = Duration(milliseconds: 150);

  /// Review 98: the line menu and the "/" card open in [menu], from the
  /// line; Move up and Move down, and a fold, slide in [slide].
  static const menu = Duration(milliseconds: 150);
  static const slide = Duration(milliseconds: 180);

  static const standard = Cubic(0.2, 0, 0, 1);
  static const enter = Cubic(0.05, 0.7, 0.1, 1);
  static const exit = Cubic(0.3, 0, 1, 1);
}

/// Elevation ("Elevation/Sheet" effect style).
abstract final class BvShadow {
  static const sheet = [
    BoxShadow(color: Color(0x0F141B33), offset: Offset(0, 4), blurRadius: 16),
  ];

  // The Daybook (Figma "DS · Daybook components").
  static const slip = [
    BoxShadow(color: Color(0x1A594026), offset: Offset(0, 2), blurRadius: 3),
  ];
  static const slipLifted = [
    BoxShadow(color: Color(0x4D1A1208), offset: Offset(0, 10), blurRadius: 14),
  ];
  // Long-press menu, send-back reasons, give-to.
  static const popover = [
    BoxShadow(color: Color(0x401A1208), offset: Offset(0, 8), blurRadius: 24),
  ];
  // The More and kind menus while writing.
  static const menu = [
    BoxShadow(color: Color(0x2E261A0D), offset: Offset(0, 8), blurRadius: 24),
  ];
  static const dropdown = [
    BoxShadow(color: Color(0x331A1208), offset: Offset(0, 8), blurRadius: 24),
  ];
  static const firstPage = [
    BoxShadow(color: Color(0x1A594026), offset: Offset(0, 2), blurRadius: 6),
  ];
  static const proof = [
    BoxShadow(color: Color(0x14594026), offset: Offset(0, 1), blurRadius: 2),
  ];
  // Around the daybook (slice 1e): Space info's slips (SI1), the Space
  // menu (MN1), Needs you rows (2544:35068).
  static const infoSlip = [
    BoxShadow(color: Color(0x12332414), offset: Offset(0, 1), blurRadius: 3),
  ];
  // The line menu and the "/" card next to a line (review 98).
  static const lineMenu = [
    BoxShadow(color: Color(0x2E141A33), offset: Offset(0, 8), blurRadius: 28),
  ];
  static const screenMenu = [
    BoxShadow(color: Color(0x29000000), offset: Offset(0, 8), blurRadius: 24),
  ];
  static const needsRow = [
    BoxShadow(color: Color(0x14594026), offset: Offset(0, 1), blurRadius: 4),
  ];
}

/// Font families bundled in assets/fonts.
abstract final class BvFonts {
  static const latin = 'PlusJakartaSans';
  static const arabic = 'Almarai';
}

/// One text style set per script. Use [BvType.of] to get the right one for
/// the current locale. Colours are not part of the type scale: set them with
/// `.copyWith(color: BvColors.…)` or rely on the theme default (textPrimary).
class BvTypeSet {
  const BvTypeSet({
    required this.displayBrand,
    required this.headingXl,
    required this.headingLg,
    required this.headingMd,
    required this.titleLg,
    required this.titleMd,
    required this.bodyLg,
    required this.bodyMd,
    required this.bodySm,
    required this.labelLg,
    required this.labelMd,
    required this.labelSm,
    required this.metadata,
    required this.button,
    required this.overline,
    required this.emphasis,
    required this.emphasisSm,
  });

  final TextStyle displayBrand;
  final TextStyle headingXl;
  final TextStyle headingLg;
  final TextStyle headingMd;
  final TextStyle titleLg;
  final TextStyle titleMd;
  final TextStyle bodyLg;
  final TextStyle bodyMd;
  final TextStyle bodySm;
  final TextStyle labelLg;
  final TextStyle labelMd;
  final TextStyle labelSm;
  final TextStyle metadata;
  final TextStyle button;

  /// Small caps-style section label (e.g. "NEEDS YOU"). In Arabic it maps to
  /// label-sm because Arabic has no capitals.
  final TextStyle overline;

  /// The one name in a line that must stand out (review 50 F34: who a
  /// work item is for): Medium at the main size; in Arabic, Almarai Bold,
  /// since Almarai has no Medium.
  final TextStyle emphasis;

  /// [emphasis] at the small size, in a small grey line (Needs you rows).
  final TextStyle emphasisSm;
}

TextStyle _t(
  String family,
  FontWeight w,
  double size,
  double lineHeight, [
  double letterSpacing = 0,
]) => TextStyle(
  fontFamily: family,
  // Each script falls back to the other bundled font. Almarai is subset to
  // the Arabic blocks (plus the space), so Latin words and digits in Arabic
  // text (BIM, emails, company names, times) use Plus Jakarta Sans, and
  // Arabic in Latin text uses Almarai.
  fontFamilyFallback: [
    family == BvFonts.arabic ? BvFonts.latin : BvFonts.arabic,
  ],
  fontWeight: w,
  fontSize: size,
  height: lineHeight / size,
  letterSpacing: letterSpacing,
  color: BvColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

abstract final class BvType {
  static const _l = BvFonts.latin;
  static const _a = BvFonts.arabic;

  // Text sizes v2 (review 53 Part C, Figma 2583:76944): two sizes on every
  // working screen. Main is 15/22 Latin and 16/26 Arabic; small is 12/16
  // Latin and 13/18 Arabic. displayBrand, headingXl and headingLg are for
  // the entry screens and three named exceptions only (see
  // test/core/design/large_type_guard_test.dart).
  static final latin = BvTypeSet(
    displayBrand: _t(_l, FontWeight.w700, 28, 34),
    headingXl: _t(_l, FontWeight.w700, 24, 30),
    headingLg: _t(_l, FontWeight.w700, 20, 26),
    headingMd: _t(_l, FontWeight.w700, 15, 22),
    titleLg: _t(_l, FontWeight.w700, 15, 22),
    titleMd: _t(_l, FontWeight.w600, 15, 22),
    bodyLg: _t(_l, FontWeight.w400, 15, 22),
    bodyMd: _t(_l, FontWeight.w400, 15, 22),
    bodySm: _t(_l, FontWeight.w400, 15, 22),
    labelLg: _t(_l, FontWeight.w600, 15, 22),
    labelMd: _t(_l, FontWeight.w500, 15, 22),
    labelSm: _t(_l, FontWeight.w500, 12, 16),
    metadata: _t(_l, FontWeight.w400, 12, 16),
    button: _t(_l, FontWeight.w600, 15, 22),
    overline: _t(_l, FontWeight.w600, 12, 16),
    emphasis: _t(_l, FontWeight.w500, 15, 22),
    emphasisSm: _t(_l, FontWeight.w500, 12, 16),
  );

  // Almarai has Regular and Bold only: semibold and bold roles are Bold,
  // medium and regular roles are Regular. No tracking, as it breaks the
  // letter joins.
  static final arabic = BvTypeSet(
    displayBrand: _t(_a, FontWeight.w700, 32, 40, -0.5),
    headingXl: _t(_a, FontWeight.w700, 28, 36, -0.3),
    headingLg: _t(_a, FontWeight.w700, 20, 28),
    headingMd: _t(_a, FontWeight.w700, 16, 26),
    titleLg: _t(_a, FontWeight.w700, 16, 26),
    titleMd: _t(_a, FontWeight.w700, 16, 26),
    bodyLg: _t(_a, FontWeight.w400, 16, 26),
    bodyMd: _t(_a, FontWeight.w400, 16, 26),
    bodySm: _t(_a, FontWeight.w400, 16, 26),
    labelLg: _t(_a, FontWeight.w700, 16, 26),
    labelMd: _t(_a, FontWeight.w400, 16, 26),
    labelSm: _t(_a, FontWeight.w400, 13, 18),
    metadata: _t(_a, FontWeight.w400, 13, 18),
    button: _t(_a, FontWeight.w700, 16, 26),
    overline: _t(_a, FontWeight.w700, 13, 18),
    emphasis: _t(_a, FontWeight.w700, 16, 26),
    emphasisSm: _t(_a, FontWeight.w700, 13, 18),
  );

  /// The type set for the app language in [context].
  static BvTypeSet of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return locale?.languageCode == 'ar' ? arabic : latin;
  }
}
