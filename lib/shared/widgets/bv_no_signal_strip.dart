import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';

/// OF (2544:35135): one quiet line under the masthead on the subtle
/// surface, a grey dot and the words, while the phone can't reach the
/// server. Never a count of what waits (rule 3).
class BvNoSignalStrip extends StatelessWidget {
  const BvNoSignalStrip({super.key, required this.text});

  final String text;

  static const dot = 8.0;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return ColoredBox(
      color: BvColors.surfaceSubtle,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.gutter,
          vertical: BvSpace.s8,
        ),
        child: Row(
          spacing: BvSpace.s8,
          children: [
            Container(
              width: dot,
              height: dot,
              decoration: const BoxDecoration(
                color: BvColors.iconSecondary,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: type.metadata.copyWith(color: BvColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
