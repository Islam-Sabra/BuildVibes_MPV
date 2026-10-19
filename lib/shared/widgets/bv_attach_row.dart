import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';

/// One choice on the attach sheet (K4 v13 2594:77647): an icon on the
/// brand-soft surface, the [title], a small [subtitle] ("Up to 10
/// photos") and ›, which mirrors in right to left.
class BvAttachRow extends StatelessWidget {
  const BvAttachRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: BvAttachSpec.rowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: BvAttachSpec.rowPaddingVertical,
            ),
            child: Row(
              spacing: BvAttachSpec.rowGap,
              children: [
                Container(
                  padding: const EdgeInsetsDirectional.all(
                    BvAttachSpec.chipPadding,
                  ),
                  decoration: const BoxDecoration(
                    color: BvColors.surfaceBrandSoft,
                    borderRadius: BvAttachSpec.chipRadius,
                  ),
                  child: Icon(
                    icon,
                    size: BvAttachSpec.icon,
                    color: BvColors.iconAction,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvAttachSpec.linesGap,
                    children: [
                      Text(
                        title,
                        style: type.labelMd.copyWith(
                          color: BvColors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  BvIcons.caretForward,
                  size: BvAttachSpec.caret,
                  color: BvColors.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
