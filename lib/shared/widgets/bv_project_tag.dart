import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';

/// The project a post is tagged to (H1 v3 2555:35321, H2 2555:35429): a
/// dot in the project's colour, its name (in its own direction) and its
/// place. A tap opens the project record; null while writing.
class BvProjectTag extends StatelessWidget {
  const BvProjectTag({
    super.key,
    required this.projectId,
    required this.name,
    this.place,
    this.onTap,
  });

  final String projectId;
  final String name;
  final String? place;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final tag = Container(
      padding: const EdgeInsetsDirectional.only(
        start: BvHomeSpec.tagPaddingStart,
        end: BvHomeSpec.tagPaddingEnd,
        top: BvHomeSpec.tagPaddingVertical,
        bottom: BvHomeSpec.tagPaddingVertical,
      ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvHomeSpec.tagRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BvHomeSpec.tagGap,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: BvProjectColors.forId(projectId),
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: BvHomeSpec.tagDot),
          ),
          Flexible(
            child: Text(
              inOwnDirection(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.labelSm,
            ),
          ),
          if (place != null)
            Text(
              place!,
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
        ],
      ),
    );
    if (onTap == null) return tag;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tag,
      ),
    );
  }
}
