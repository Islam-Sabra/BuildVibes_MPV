import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';
import 'bv_tap_target.dart';

/// One way to start an empty Daybook, on [BvFirstPage].
class BvFirstPageAction {
  const BvFirstPageAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// The main action: filled in the action colour.
  final bool primary;
}

/// The day-one card of an empty Daybook (spec §15): a plain sheet of paper
/// (no torn edge) with a title, a line of help and a few ways to start.
/// The screen insets it [BvFirstPageSpec.insetStart] from the start.
class BvFirstPage extends StatelessWidget {
  const BvFirstPage({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final String body;
  final List<BvFirstPageAction> actions;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvFirstPageSpec.radius,
        boxShadow: BvShadow.firstPage,
      ),
      padding: const EdgeInsetsDirectional.only(
        top: BvFirstPageSpec.paddingTop,
        bottom: BvFirstPageSpec.paddingBottom,
        start: BvFirstPageSpec.paddingHorizontal,
        end: BvFirstPageSpec.paddingHorizontal,
      ),
      // The last action reaches its 48 touch area into the bottom padding.
      child: BvTapTarget(
        outset: const EdgeInsetsDirectional.only(
          bottom: BvFirstPageSpec.paddingBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: BvFirstPageSpec.gap,
          children: [
            Text(title, textAlign: TextAlign.center, style: type.titleLg),
            Text(
              body,
              textAlign: TextAlign.center,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
            for (final a in actions) _ActionRow(action: a),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final BvFirstPageAction action;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final foreground = action.primary
        ? BvColors.actionPrimaryForeground
        : BvColors.textPrimary;
    // 40 high, as drawn; the touch area reaches 48 into the gaps.
    final row = Material(
      key: Key('first-page-action-${action.label}'),
      color: action.primary ? BvColors.actionPrimary : BvColors.surfaceSubtle,
      borderRadius: BvFirstPageSpec.actionRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvFirstPageSpec.actionPaddingHorizontal,
            vertical: BvFirstPageSpec.actionPaddingVertical,
          ),
          child: Row(
            spacing: BvFirstPageSpec.actionGap,
            children: [
              Icon(
                action.icon,
                size: BvFirstPageSpec.actionIcon,
                color: foreground,
              ),
              Expanded(
                child: Text(
                  action.label,
                  style: type.labelMd.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return action.onTap == null ? row : BvTapTarget(child: row);
  }
}
