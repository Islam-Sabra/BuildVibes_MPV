import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// Spec §17: a site photo with its stamp (place · time · person) at the
/// bottom start. While loading, or when the photo is missing, it shows a
/// plain subtle fill.
class BvSitePhoto extends StatelessWidget {
  const BvSitePhoto({
    super.key,
    required this.photo,
    required this.stamp,
    this.aspectRatio = BvSitePhotoSpec.aspectRatio,
  });

  final ImageProvider? photo;

  /// For example "Level 2 · Grid C7 · 09:40 · Omar Haddad".
  final String stamp;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      key: Key('site-photo-placeholder'),
      color: BvColors.surfaceSubtle,
    );

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BvSitePhotoSpec.radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo == null)
              placeholder
            else
              Image(
                image: photo!,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, sync) =>
                    frame == null && !sync ? placeholder : child,
                errorBuilder: (context, error, stack) => placeholder,
              ),
            if (stamp.isNotEmpty)
              PositionedDirectional(
                start: BvSitePhotoSpec.stampInset,
                bottom: BvSitePhotoSpec.stampInset,
                end: BvSitePhotoSpec.stampInset,
                child: Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: Container(
                    key: const Key('site-photo-stamp'),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: BvSitePhotoSpec.stampPaddingHorizontal,
                      vertical: BvSitePhotoSpec.stampPaddingVertical,
                    ),
                    decoration: const BoxDecoration(
                      color: BvColors.brandInk,
                      borderRadius: BvSitePhotoSpec.stampRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: BvSitePhotoSpec.stampGap,
                      children: [
                        const Icon(
                          BvIcons.place,
                          size: BvSitePhotoSpec.stampIconSize,
                          color: BvColors.iconInverse,
                        ),
                        Flexible(
                          child: Text(
                            stamp,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BvType.of(
                              context,
                            ).labelSm.copyWith(color: BvColors.textInverse),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
