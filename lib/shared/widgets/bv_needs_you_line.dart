import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/daybook_days_specs.dart';
import '../../core/design/bv_tokens.dart';

/// Review 105 Part 6 (SP1 2666:38504): one line at the top of Work, "3 need
/// you · 2 due today ›", on the brand's soft paper. A tap filters Work to
/// what waits on me; while it does ([on]), the caret is a ✕ that shows
/// everything again. No charts, no percentages.
class BvNeedsYouLine extends StatelessWidget {
  const BvNeedsYouLine({
    super.key,
    required this.need,
    this.due,
    required this.on,
    required this.onTap,
    required this.offLabel,
  });

  /// "3 need you".
  final String need;

  /// "· 2 due today", when something is.
  final String? due;
  final bool on;
  final VoidCallback onTap;

  /// Read out while [on]: the tap shows everything again.
  final String offLabel;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Semantics(
      button: true,
      selected: on,
      hint: on ? offLabel : null,
      child: Material(
        color: BvColors.surfaceBrandSoft,
        borderRadius: BvNeedsYouSpec.radius,
        child: InkWell(
          borderRadius: BvNeedsYouSpec.radius,
          onTap: onTap,
          child: Padding(
            padding: BvNeedsYouSpec.padding,
            child: Row(
              spacing: BvNeedsYouSpec.gap,
              children: [
                const Icon(
                  BvIcons.scheduled,
                  size: BvNeedsYouSpec.icon,
                  color: BvColors.iconAction,
                ),
                Text(
                  need,
                  style: type.emphasis.copyWith(color: BvColors.textAction),
                ),
                if (due != null)
                  Flexible(
                    child: Text(
                      due!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodyMd.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ),
                const Spacer(),
                Icon(
                  on ? BvIcons.close : BvIcons.caretForward,
                  key: on ? const Key('needs-you-on') : null,
                  size: BvNeedsYouSpec.icon,
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
