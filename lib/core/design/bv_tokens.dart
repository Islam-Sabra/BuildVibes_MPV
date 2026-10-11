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
  static const ink48 = Color(0x7A141B33);
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

  // Brand (wordmark, Lead pass band)
  static const brandInk = BvPrimitive.ink;
  static const brandEnergy = BvPrimitive.energy;
  static const brandEnergySoft = BvPrimitive.energySoft;
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
  static const iconSm = 16.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;
  static const avatarSm = 32.0;
  static const avatarMd = 40.0;
  static const avatarLg = 56.0;
  static const avatarXl = 88.0;
}

/// Motion ("Motion").
abstract final class BvMotion {
  static const instant = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 360);
  static const sheet = Duration(milliseconds: 420);
  static const stagger = Duration(milliseconds: 40);

  static const standard = Cubic(0.2, 0, 0, 1);
  static const enter = Cubic(0.05, 0.7, 0.1, 1);
  static const exit = Cubic(0.3, 0, 1, 1);
}

/// Elevation ("Elevation/Sheet" effect style).
abstract final class BvShadow {
  static const sheet = [
    BoxShadow(color: Color(0x0F141B33), offset: Offset(0, 4), blurRadius: 16),
  ];
}

/// Font families bundled in assets/fonts.
abstract final class BvFonts {
  static const latin = 'PlusJakartaSans';
  static const arabic = 'NotoSansArabic';
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
}

TextStyle _t(
  String family,
  FontWeight w,
  double size,
  double lineHeight, [
  double letterSpacing = 0,
]) => TextStyle(
  fontFamily: family,
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

  static final latin = BvTypeSet(
    displayBrand: _t(_l, FontWeight.w700, 28, 34),
    headingXl: _t(_l, FontWeight.w700, 24, 30),
    headingLg: _t(_l, FontWeight.w700, 20, 26),
    headingMd: _t(_l, FontWeight.w600, 18, 24),
    titleLg: _t(_l, FontWeight.w600, 16, 22),
    titleMd: _t(_l, FontWeight.w600, 15, 20),
    bodyLg: _t(_l, FontWeight.w400, 16, 24),
    bodyMd: _t(_l, FontWeight.w400, 14, 20),
    bodySm: _t(_l, FontWeight.w400, 13, 18),
    labelLg: _t(_l, FontWeight.w600, 14, 18),
    labelMd: _t(_l, FontWeight.w500, 13, 16),
    labelSm: _t(_l, FontWeight.w500, 12, 16),
    metadata: _t(_l, FontWeight.w400, 12, 16),
    button: _t(_l, FontWeight.w600, 14, 18),
    overline: _t(_l, FontWeight.w700, 11, 16),
  );

  static final arabic = BvTypeSet(
    displayBrand: _t(_a, FontWeight.w700, 32, 40, -0.5),
    headingXl: _t(_a, FontWeight.w700, 28, 36, -0.3),
    headingLg: _t(_a, FontWeight.w700, 20, 28),
    headingMd: _t(_a, FontWeight.w700, 18, 26),
    titleLg: _t(_a, FontWeight.w600, 18, 26),
    titleMd: _t(_a, FontWeight.w600, 16, 24),
    bodyLg: _t(_a, FontWeight.w400, 16, 26),
    bodyMd: _t(_a, FontWeight.w400, 14, 22),
    bodySm: _t(_a, FontWeight.w400, 13, 20),
    labelLg: _t(_a, FontWeight.w500, 14, 20, 0.1),
    labelMd: _t(_a, FontWeight.w500, 13, 18),
    labelSm: _t(_a, FontWeight.w500, 11, 16, 0.2),
    metadata: _t(_a, FontWeight.w400, 12, 18),
    button: _t(_a, FontWeight.w600, 15, 20, 0.2),
    overline: _t(_a, FontWeight.w500, 11, 16, 0.2),
  );

  /// The type set for the app language in [context].
  static BvTypeSet of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return locale?.languageCode == 'ar' ? arabic : latin;
  }
}
