import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_avatar.dart';
import 'bv_stamp.dart';
import 'bv_torn_edge.dart';

/// Proof of work on a profile (R1 v4 2556:35433, 2544:35381): a torn slip
/// with the Done photo and its CHECKED stamp, the work item's title, the
/// project, and who checked it and when. Only work that was checked and
/// closed in a Space; never a count (rule 3).
class BvProofCard extends StatelessWidget {
  const BvProofCard({
    super.key,
    required this.id,
    required this.title,
    required this.stamp,
    this.project,
    this.checkedLine,
    this.checkerName,
    this.photo,
    this.onTap,
  });

  /// The work item's id: picks the tear.
  final String id;
  final String title;

  /// "CHECKED" / "تم التحقق".
  final String stamp;
  final String? project;

  /// "Checked by Islam Ahmed · 15 Oct".
  final String? checkedLine;

  /// The checker, for the small avatar; null across a block.
  final String? checkerName;
  final ImageProvider? photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final shape = BvSlipBorder.forId(
      id,
      edgeHeight: BvSlipBorder.edgeHeightProof,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: BvColors.surfaceElevated,
        shape: shape,
        shadows: BvShadow.proof,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvProofCardSpec.paddingHorizontal,
              BvProofCardSpec.paddingTop,
              BvProofCardSpec.paddingHorizontal,
              BvProofCardSpec.paddingBottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BvProofCardSpec.gap,
              children: [
                SizedBox.square(
                  dimension: BvProofCardSpec.photo,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(BvRadius.photo),
                          ),
                          child: ColoredBox(
                            color: BvColors.surfaceSubtle,
                            child: photo == null
                                ? null
                                : Image(
                                    key: const Key('proof-card-photo'),
                                    image: photo!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: BvProofCardSpec.stampInset,
                        bottom: BvProofCardSpec.stampInset,
                        child: BvInkStamp(
                          label: stamp,
                          size: BvInkStampSize.xs8,
                          tone: BvInkStampTone.positive,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvProofCardSpec.textGap,
                    children: [
                      Text(title, style: type.labelMd),
                      if (project != null)
                        Text(
                          project!,
                          style: type.metadata.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                      if (checkedLine != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: BvProofCardSpec.checkerPaddingTop,
                          ),
                          child: Row(
                            spacing: BvProofCardSpec.checkerGap,
                            children: [
                              if (checkerName != null)
                                BvAvatar(
                                  name: checkerName!,
                                  size: BvAvatarSize.xxs,
                                  tint: BvAvatarTints.plain,
                                ),
                              Flexible(
                                child: Text(
                                  checkedLine!,
                                  style: type.metadata.copyWith(
                                    color: BvColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
