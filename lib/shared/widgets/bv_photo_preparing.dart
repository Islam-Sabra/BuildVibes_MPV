import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// A photo's slot while the photo is made safe to leave the phone (review
/// 74 H2): the small spinner and "Preparing…", where the photo will
/// appear. It fills its slot. [inverse] is for the dark proof camera;
/// [compact] (a small thumbnail) shows the spinner alone, the words read
/// out.
class BvPhotoPreparing extends StatelessWidget {
  const BvPhotoPreparing({
    super.key,
    required this.label,
    this.inverse = false,
    this.compact = false,
  });

  final String label;
  final bool inverse;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox.square(
      dimension: BvSize.iconMd,
      child: CircularProgressIndicator(
        strokeWidth: BvStroke.thick,
        // The theme's spinner colour, white on the dark proof camera.
        color: inverse ? BvColors.iconInverse : null,
      ),
    );
    final content = Center(
      child: compact
          ? spinner
          : Column(
              mainAxisSize: MainAxisSize.min,
              spacing: BvSpace.s8,
              children: [
                spinner,
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: BvType.of(context).labelSm.copyWith(
                    color: inverse
                        ? BvColors.textInverse
                        : BvColors.textSecondary,
                  ),
                ),
              ],
            ),
    );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: inverse
          ? content
          : ColoredBox(color: BvColors.surfaceSubtle, child: content),
    );
  }
}
