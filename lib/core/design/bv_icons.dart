// BuildVibes icons: Phosphor, regular weight (the Figma icon set).
//
// Rules:
// - Widgets use BvIcons only. Never use Material `Icons.*`.
// - One glyph per meaning. Active tabs use the same glyph as inactive tabs.
// - Only arrows and carets mirror in right-to-left. Mirroring is set per icon.
//
// The font is bundled in assets/fonts (family "PhosphorRegular"), not used
// through the phosphor_flutter package: its latest version (2.1.0) doesn't
// compile on Flutter 3.44. Code points come from that package's
// `PhosphorIconsRegular` table. See assets/fonts/SOURCE.md.

import 'package:flutter/widgets.dart';

abstract final class BvIcons {
  static const _family = 'PhosphorRegular';

  // Bottom bar
  // Phosphor: house
  static const home = IconData(0xe2c2, fontFamily: _family);
  // Phosphor: compass
  static const explore = IconData(0xe1c8, fontFamily: _family);
  // Phosphor: plus
  static const create = IconData(0xe3d4, fontFamily: _family);
  // Phosphor: bell
  static const activity = IconData(0xe0ce, fontFamily: _family);
  // Phosphor: user
  static const profile = IconData(0xe4c2, fontFamily: _family);

  // General
  // Phosphor: magnifying-glass
  static const search = IconData(0xe30c, fontFamily: _family);
  // Phosphor: x
  static const close = IconData(0xe4f6, fontFamily: _family);
  // Phosphor: check
  static const check = IconData(0xe182, fontFamily: _family);
  // Phosphor: translate
  static const language = IconData(0xe4a2, fontFamily: _family);

  // Directional: mirrored in right-to-left.
  /// Points to the next screen: right in English, left in Arabic.
  static const caretForward = IconData(
    0xe13a,
    fontFamily: _family,
    matchTextDirection: true,
  );
  static const caretBack = IconData(
    0xe138,
    fontFamily: _family,
    matchTextDirection: true,
  );
  static const arrowForward = IconData(
    0xe06c,
    fontFamily: _family,
    matchTextDirection: true,
  );
  static const arrowBack = IconData(
    0xe058,
    fontFamily: _family,
    matchTextDirection: true,
  );
}
