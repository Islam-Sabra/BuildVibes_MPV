import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_specs.dart';
import 'bv_avatar.dart';

/// One small face: the person's name (for the initials) and their tint
/// ([BvAvatarTints.forId]).
typedef BvFace = ({String name, Color tint});

/// Up to three small faces, overlapping (H1 v4's latest reply, F30; a
/// team in People, review 54 A4). Never a number (rule 3): the faces show
/// who, not how many.
class BvFaces extends StatelessWidget {
  const BvFaces(this.faces, {super.key});

  /// The first three are drawn.
  final List<BvFace> faces;

  static const max = 3;

  @override
  Widget build(BuildContext context) {
    final shown = faces.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    const face = BvAvatarSpec.face;
    const step = face - BvHomeSpec.faceOverlap;
    return SizedBox(
      width: face + step * (shown.length - 1),
      height: face,
      child: Stack(
        children: [
          for (final (i, f) in shown.indexed)
            PositionedDirectional(
              start: step * i,
              child: BvAvatar(
                name: f.name,
                size: BvAvatarSize.face,
                tint: f.tint,
              ),
            ),
        ],
      ),
    );
  }
}
