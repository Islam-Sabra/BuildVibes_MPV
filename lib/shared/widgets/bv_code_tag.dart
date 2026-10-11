import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// A code on a site tag (S16 invite code): the tag's shape and punched
/// hole, an overline [label], the [code] large and always left to right,
/// and an optional [note] ("Works until 18 Oct").
class BvCodeTag extends StatelessWidget {
  const BvCodeTag({
    super.key,
    required this.label,
    required this.code,
    this.note,
  });

  final String label;
  final String code;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    const border = BorderSide(
      color: BvColors.borderDefault,
      width: BvSiteTagSpec.border,
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvSiteTagSpec.radius,
        border: Border.fromBorderSide(border),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: BvCodeTagSpec.paddingTop,
              start: BvCodeTagSpec.paddingSide,
              end: BvCodeTagSpec.paddingSide,
              bottom: BvCodeTagSpec.paddingBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvCodeTagSpec.gap,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: type.overline.copyWith(color: BvColors.textSecondary),
                ),
                Text(
                  code,
                  key: const Key('code-tag-code'),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: type.headingXl.copyWith(
                    letterSpacing: BvCodeTagSpec.codeLetterSpacing,
                  ),
                ),
                if (note != null)
                  Text(
                    note!,
                    textAlign: TextAlign.center,
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  ),
              ],
            ),
          ),
          // The punched hole, top centre.
          const PositionedDirectional(
            top: BvSiteTagSpec.holeTop,
            start: 0,
            end: 0,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BvColors.surfaceApp,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(border),
                ),
                child: SizedBox.square(dimension: BvSiteTagSpec.holeSize),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
