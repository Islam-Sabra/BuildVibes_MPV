import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

enum BvStampTone { action, positive, muted }

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
  };

  /// The tilt in radians for [direction].
  static double tiltFor(TextDirection direction) {
    final radians = BvStampSpec.tiltDegrees * math.pi / 180;
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
      child: Text(
        label,
        maxLines: 1,
        style: BvType.of(context).labelMd.copyWith(color: color),
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
