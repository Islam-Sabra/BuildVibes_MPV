import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_paper_clip.dart';
import 'bv_space_emblem.dart';

/// One Space in Needs you (2544:35078): its emblem (F28), its name, then
/// its rows.
class BvNeedsGroup extends StatelessWidget {
  const BvNeedsGroup({super.key, required this.name, required this.rows});

  final String name;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvNeedsSpec.rowGap,
      children: [
        Row(
          spacing: BvSpace.s8,
          children: [
            const BvSpaceEmblem(height: BvSpaceEmblemSpec.tile),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.labelMd,
              ),
            ),
          ],
        ),
        ...rows,
      ],
    );
  }
}

/// One thing that needs you (2544:35083): the photo when there is one,
/// what to do in orange ("Check it"), the title, who and when, and the
/// paper clip at the end. The whole row opens it.
class BvNeedsRow extends StatelessWidget {
  const BvNeedsRow({
    super.key,
    required this.label,
    required this.title,
    required this.onTap,
    this.meta,
    this.photo,
  });

  final String label;
  final String title;
  final String? meta;

  /// The proof or the cover; null leaves the row without a photo.
  final ImageProvider? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvNeedsSpec.rowRadius,
        boxShadow: BvShadow.needsRow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BvNeedsSpec.rowRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(BvNeedsSpec.rowPadding),
            child: Row(
              spacing: BvNeedsSpec.rowGapInside,
              children: [
                if (photo != null)
                  ClipRRect(
                    borderRadius: BvNeedsSpec.photoRadius,
                    child: Image(
                      image: photo!,
                      width: BvNeedsSpec.photo,
                      height: BvNeedsSpec.photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: BvColors.surfaceSubtle,
                        child: SizedBox.square(dimension: BvNeedsSpec.photo),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvNeedsSpec.lineGap,
                    children: [
                      Text(
                        label,
                        style: type.labelSm.copyWith(
                          color: BvColors.textAction,
                        ),
                      ),
                      Text(title, style: type.labelMd),
                      if (meta != null)
                        Text(
                          meta!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.metadata.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const BvPaperClip.row(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
