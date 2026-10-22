import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_button.dart';

/// A centred dialog for a choice that can't be undone (S15c Leave, S15e
/// Transfer): a title, a short body, Cancel and the action. Returns true
/// when the action was chosen.
Future<bool> showBvDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String cancelLabel,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final yes = await showDialog<bool>(
    context: context,
    barrierColor: BvColors.overlayScrim,
    builder: (context) => BvDialog(
      title: title,
      body: body,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      destructive: destructive,
      onCancel: () => Navigator.of(context).pop(false),
      onConfirm: () => Navigator.of(context).pop(true),
    ),
  );
  return yes ?? false;
}

/// The same dialog for a choice between two ways on: true for
/// [confirmLabel], false for [cancelLabel], null when it was dismissed
/// (a tap outside, Back), which chooses neither.
Future<bool?> showBvChoiceDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String cancelLabel,
  required String confirmLabel,
}) => showDialog<bool>(
  context: context,
  barrierColor: BvColors.overlayScrim,
  builder: (context) => BvDialog(
    title: title,
    body: body,
    cancelLabel: cancelLabel,
    confirmLabel: confirmLabel,
    onCancel: () => Navigator.of(context).pop(false),
    onConfirm: () => Navigator.of(context).pop(true),
  ),
);

class BvDialog extends StatelessWidget {
  const BvDialog({
    super.key,
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.destructive = false,
  });

  final String title;
  final String body;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  /// The action in red (Leave, Delete); otherwise the primary button.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Dialog(
      key: const Key('bv-dialog'),
      backgroundColor: BvColors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: BvDialogSpec.inset),
      shape: const RoundedRectangleBorder(borderRadius: BvDialogSpec.radius),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(BvDialogSpec.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BvDialogSpec.gap,
          children: [
            Text(title, style: type.titleLg),
            Text(
              body,
              style: type.bodyMd.copyWith(color: BvColors.textSecondary),
            ),
            const SizedBox(height: BvDialogSpec.buttonsTop - BvDialogSpec.gap),
            Row(
              spacing: BvSpace.s12,
              children: [
                Expanded(
                  child: BvButton(
                    key: const Key('bv-dialog-cancel'),
                    label: cancelLabel,
                    style: BvButtonStyle.secondary,
                    size: BvButtonSize.medium,
                    expand: true,
                    onPressed: onCancel,
                  ),
                ),
                Expanded(
                  child: BvButton(
                    key: const Key('bv-dialog-confirm'),
                    label: confirmLabel,
                    style: destructive
                        ? BvButtonStyle.destructive
                        : BvButtonStyle.primary,
                    size: BvButtonSize.medium,
                    expand: true,
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
