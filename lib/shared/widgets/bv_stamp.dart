import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_paper_specs.dart';

/// [ink] is for record stamps such as "SHARED RECORD · NO OWNER" (PJ1).
enum BvStampTone { action, positive, muted, ink }

/// Spec §12: the site-paperwork stamp. An outlined label whose text and
/// border share one colour.
///
/// [tilted] is for status stamps (CHECKED, SELECTED), never for IDs. It
/// leans −3° in left to right and +3° in right to left.
class BvStamp extends StatelessWidget {
  const BvStamp({
    super.key,
    required this.label,
    this.tone = BvStampTone.action,
    this.tilted = false,
  });

  final String label;
  final BvStampTone tone;
  final bool tilted;

  static Color colorOf(BvStampTone tone) => switch (tone) {
    BvStampTone.action => BvColors.textAction,
    BvStampTone.positive => BvColors.textPositive,
    BvStampTone.muted => BvColors.textSecondary,
    BvStampTone.ink => BvColors.brandInk,
  };

  /// The tilt in radians for [direction].
  static double tiltFor(TextDirection direction) {
    const radians = BvStampSpec.tiltDegrees * math.pi / 180;
    return direction == TextDirection.rtl ? radians : -radians;
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(tone);
    final stamp = Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvStampSpec.paddingHorizontal,
        vertical: BvStampSpec.paddingVertical,
      ),
      decoration: BoxDecoration(
        borderRadius: BvStampSpec.radius,
        border: Border.all(color: color, width: BvStampSpec.border),
      ),
      // A row hugs the label's width.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              style: BvType.of(context).labelMd.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
    if (!tilted) return stamp;
    return Transform.rotate(
      key: const Key('stamp-tilt'),
      angle: tiltFor(Directionality.of(context)),
      child: stamp,
    );
  }
}

/// [xs9] and [xs8] are xs with 9 and 8 px words: the profile's CONFIRMED
/// and WAITING (R1 v4 2556:35511), and CHECKED on a proof card's photo
/// (2556:35435).
enum BvInkStampSize { xs8, xs9, xs, sm, md, lg }

/// DONE and NEW ROLE are [action], CHECKED and CONFIRMED [positive],
/// CANCELLED [muted], SENT BACK [destructive].
enum BvInkStampTone { action, positive, muted, destructive }

/// Spec §3: the Daybook's ink stamp. A white label inside a border of its
/// text colour, tilted clockwise in left to right and mirrored in right to
/// left. [lg] sits on a proof photo and may carry a second line ("OMAR H ·
/// 09:40").
///
/// Latin labels are ExtraBold and tracked; Arabic labels are Bold with no
/// tracking (tracking breaks the letter joins, and Noto Sans Arabic has no
/// 800). Pass capitals in Latin; Arabic has none.
///
/// [land] plays the landing once, as the stamp is put down (Check).
class BvInkStamp extends StatelessWidget {
  const BvInkStamp({
    super.key,
    required this.label,
    this.size = BvInkStampSize.md,
    this.tone = BvInkStampTone.action,
    this.subline,
    this.land = false,
  });

  final String label;
  final BvInkStampSize size;
  final BvInkStampTone tone;

  /// Second line, large stamp only.
  final String? subline;
  final bool land;

  static Color colorOf(BvInkStampTone tone) => switch (tone) {
    BvInkStampTone.action => BvColors.textAction,
    BvInkStampTone.positive => BvColors.textPositive,
    BvInkStampTone.muted => BvColors.textSecondary,
    BvInkStampTone.destructive => BvColors.textDestructive,
  };

  static double tiltDegreesOf(BvInkStampSize size) => switch (size) {
    BvInkStampSize.lg => BvInkStampSpec.tiltLg,
    BvInkStampSize.md => BvInkStampSpec.tiltMd,
    BvInkStampSize.sm => BvInkStampSpec.tiltSm,
    BvInkStampSize.xs ||
    BvInkStampSize.xs9 ||
    BvInkStampSize.xs8 => BvInkStampSpec.tiltXs,
  };

  static double opacityOf(BvInkStampSize size) => switch (size) {
    BvInkStampSize.lg || BvInkStampSize.md => BvInkStampSpec.opacityInk,
    BvInkStampSize.sm ||
    BvInkStampSize.xs ||
    BvInkStampSize.xs9 ||
    BvInkStampSize.xs8 => BvInkStampSpec.opacityFull,
  };

  /// The tilt in radians for [direction]: clockwise (positive) in left to
  /// right.
  static double tiltFor(BvInkStampSize size, TextDirection direction) {
    final radians = _radians(tiltDegreesOf(size));
    return direction == TextDirection.rtl ? -radians : radians;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  static double _border(BvInkStampSize size) => switch (size) {
    BvInkStampSize.lg => BvInkStampSpec.borderLg,
    BvInkStampSize.md => BvInkStampSpec.borderMd,
    BvInkStampSize.sm => BvInkStampSpec.borderSm,
    BvInkStampSize.xs ||
    BvInkStampSize.xs9 ||
    BvInkStampSize.xs8 => BvInkStampSpec.borderXs,
  };

  static EdgeInsetsDirectional _padding(BvInkStampSize size) => switch (size) {
    BvInkStampSize.lg => BvInkStampSpec.paddingLg,
    BvInkStampSize.md => BvInkStampSpec.paddingMd,
    BvInkStampSize.sm => BvInkStampSpec.paddingSm,
    BvInkStampSize.xs ||
    BvInkStampSize.xs9 ||
    BvInkStampSize.xs8 => BvInkStampSpec.paddingXs,
  };

  static double _fontSize(BvInkStampSize size) => switch (size) {
    BvInkStampSize.lg => BvInkStampSpec.fontSizeLg,
    BvInkStampSize.md => BvInkStampSpec.fontSizeMd,
    BvInkStampSize.sm => BvInkStampSpec.fontSizeSm,
    BvInkStampSize.xs => BvInkStampSpec.fontSizeXs,
    BvInkStampSize.xs9 => BvInkStampSpec.fontSizeXs9,
    BvInkStampSize.xs8 => BvInkStampSpec.fontSizeXs8,
  };

  bool get _xs =>
      size == BvInkStampSize.xs ||
      size == BvInkStampSize.xs9 ||
      size == BvInkStampSize.xs8;

  @override
  Widget build(BuildContext context) {
    final color = colorOf(tone);
    final type = BvType.of(context);
    final arabic = identical(type, BvType.arabic);
    TextStyle ink(double fontSize, FontWeight latinWeight, double em) =>
        type.labelSm.copyWith(
          color: color,
          fontSize: fontSize,
          height: BvInkStampSpec.lineHeight,
          fontWeight: arabic ? FontWeight.w700 : latinWeight,
          letterSpacing: arabic ? 0 : fontSize * em,
        );
    final fontSize = _fontSize(size);
    final stamp = Container(
      padding: _padding(size),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: _xs ? BvInkStampSpec.radiusXs : BvInkStampSpec.radius,
        border: Border.all(color: color, width: _border(size)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            style: ink(
              fontSize,
              FontWeight.w800,
              _xs ? BvInkStampSpec.trackingEmXs : BvInkStampSpec.trackingEm,
            ),
          ),
          if (subline != null && size == BvInkStampSize.lg)
            Text(
              subline!,
              maxLines: 1,
              style: ink(
                BvInkStampSpec.sublineFontSize,
                FontWeight.w700,
                BvInkStampSpec.sublineTrackingEm,
              ),
            ),
        ],
      ),
    );
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final tilt = tiltDegreesOf(size);
    final opacity = opacityOf(size);

    Widget placed(double t) {
      final scale = 1 + (BvInkStampSpec.landScale - 1) * (1 - t);
      final degrees = tilt + BvInkStampSpec.landExtraTilt * (1 - t);
      final alpha = opacity - (opacity - BvInkStampSpec.landOpacity) * (1 - t);
      return Opacity(
        key: const Key('ink-stamp-opacity'),
        opacity: alpha,
        child: Transform.rotate(
          key: const Key('ink-stamp-tilt'),
          angle: rtl ? -_radians(degrees) : _radians(degrees),
          child: Transform.scale(scale: scale, child: stamp),
        ),
      );
    }

    if (!land) return placed(1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: BvInkStampSpec.landDuration,
      curve: BvMotion.standard,
      builder: (context, t, _) => placed(t),
    );
  }
}
