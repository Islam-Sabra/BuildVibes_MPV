import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_faces.dart';

/// A post card's latest reply (H1 v4 2587:35889, AR 2588:438; review 50
/// F30): one quiet line on the subtle surface with up to three small faces
/// of who replied, "{name}: {words}" cut to one line, and ›. Never a
/// number: the faces and the words show that there are replies and who
/// replied.
///
/// [unseen]: a reply to the reader, not yet seen by opening the post. The
/// line is bold and in ink until then.
class BvLatestReply extends StatelessWidget {
  const BvLatestReply({
    super.key,
    required this.name,
    required this.words,
    this.faces = const [],
    this.unseen = false,
    this.onTap,
  });

  final String name;
  final String words;

  /// The most recent first; at most three are drawn.
  final List<BvFace> faces;
  final bool unseen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final line = Container(
      padding: const EdgeInsetsDirectional.only(
        start: BvHomeSpec.replyPaddingStart,
        end: BvHomeSpec.replyPaddingEnd,
        top: BvHomeSpec.replyPaddingVertical,
        bottom: BvHomeSpec.replyPaddingVertical,
      ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvHomeSpec.replyRadius,
      ),
      child: Row(
        spacing: BvHomeSpec.replyGap,
        children: [
          if (faces.isNotEmpty)
            BvFaces(faces, key: const Key('latest-reply-faces')),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$name: ',
                    style: (unseen ? type.headingMd : type.labelMd).copyWith(
                      color: BvColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: words,
                    style: (unseen ? type.titleMd : type.bodyMd).copyWith(
                      color: unseen
                          ? BvColors.textPrimary
                          : BvColors.textSecondary,
                    ),
                  ),
                ],
              ),
              key: const Key('latest-reply-text'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(
            BvIcons.caretForward,
            size: BvHomeSpec.replyCaret,
            color: BvColors.iconSecondary,
          ),
        ],
      ),
    );
    if (onTap == null) return line;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: line,
      ),
    );
  }
}
