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
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvUndoBarSpec.paddingHorizontal,
        vertical: BvUndoBarSpec.paddingVertical,
      ),
      decoration: const BoxDecoration(
        color: BvColors.brandInk,
        borderRadius: BvUndoBarSpec.radius,
      ),
      child: Row(
        spacing: BvUndoBarSpec.gap,
        children: [
          Expanded(child: Text(message, style: style)),
          Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Text(
                actionLabel,
                style: style.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: BvColors.textInverse,
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
