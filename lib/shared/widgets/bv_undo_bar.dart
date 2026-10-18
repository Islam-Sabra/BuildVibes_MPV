import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';

/// The Daybook's toast with one way back ("Checked · Undo", 2519:33161):
/// ink, the message at the start and the underlined action at the end.
class BvUndoBar extends StatelessWidget {
  const BvUndoBar({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final style = BvType.of(
      context,
    ).labelMd.copyWith(color: BvColors.textInverse);
    // The action's touch area takes the bar's end padding and is at least
    // 48 × 48 (review 44, C4).
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: BvUndoBarSpec.paddingHorizontal,
      ),
      decoration: const BoxDecoration(
        color: BvColors.brandInk,
        borderRadius: BvUndoBarSpec.radius,
      ),
      child: Row(
        spacing: BvUndoBarSpec.gap,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: BvUndoBarSpec.paddingVertical,
              ),
              child: Text(message, style: style),
            ),
          ),
          Semantics(
            button: true,
            child: GestureDetector(
              key: const Key('undo-bar-action'),
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: BvSize.touchMin,
                  minHeight: BvSize.touchMin,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: BvUndoBarSpec.paddingHorizontal,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    widthFactor: 1,
                    child: Text(
                      actionLabel,
                      style: style.copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: BvColors.textInverse,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a [BvUndoBar] for 5 seconds, floating 12 above [bottom] (the
/// Daybook's post bar by default). Undo closes it first.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showBvUndoBar(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
  double bottom = BvUndoBarSpec.postBarHeight,
}) {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: BvUndoBarSpec.duration,
      // The bar paints itself; the theme's toast stays as it is elsewhere.
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: EdgeInsetsDirectional.fromSTEB(
        BvUndoBarSpec.side,
        0,
        BvUndoBarSpec.side,
        bottom + BvUndoBarSpec.lift,
      ),
      content: BvUndoBar(
        message: message,
        actionLabel: actionLabel,
        onAction: () {
          messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
          onAction();
        },
      ),
    ),
  );
}
