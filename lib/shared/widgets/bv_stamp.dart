import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

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
    this.large = false,
  });

  final String label;
  final BvStampTone tone;
  final bool tilted;

  /// The large proof stamp (W3d CHECKED): bold, taller, tilted −4°.
  final bool large;

  static Color colorOf(BvStampTone tone) => switch (tone) {
    BvStampTone.action => BvColors.textAction,
    BvStampTone.positive => BvColors.textPositive,
    BvStampTone.muted => BvColors.textSecondary,
    BvStampTone.ink => BvColors.brandInk,
  };

  /// The tilt in radians for [direction].
  static double tiltFor(TextDirection direction, {bool large = false}) {
    final degrees = large
        ? BvStampSpec.largeTiltDegrees
        : BvStampSpec.tiltDegrees;
    final radians = degrees * math.pi / 180;
    return direction == TextDirection.rtl ? radians : -radians;
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(tone);
    final type = BvType.of(context);
    final stamp = Container(
      height: large ? BvStampSpec.largeHeight : null,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: large
            ? BvStampSpec.largePaddingHorizontal
            : BvStampSpec.paddingHorizontal,
        vertical: large ? 0 : BvStampSpec.paddingVertical,
      ),
      decoration: BoxDecoration(
        borderRadius: BvStampSpec.radius,
        border: Border.all(color: color, width: BvStampSpec.border),
      ),
      // A row hugs the label's width and centres it in the large height.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              style: large
                  ? type.labelLg.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    )
                  : type.labelMd.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
    if (!tilted) return stamp;
    return Transform.rotate(
      key: const Key('stamp-tilt'),
      angle: tiltFor(Directionality.of(context), large: large),
      child: stamp,
    );
  }
}
