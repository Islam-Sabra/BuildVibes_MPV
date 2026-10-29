import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_button.dart';
import 'bv_text_field.dart';

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

/// The dialog with one field, [initial] in it (a rename): the words typed,
/// trimmed, or null when cancelled or left empty.
Future<String?> showBvFieldDialog({
  required BuildContext context,
  required String title,
  required String initial,
  required String cancelLabel,
  required String confirmLabel,
  Key? fieldKey,
  int? maxLength,
}) async {
  final text = await showDialog<String>(
    context: context,
    barrierColor: BvColors.overlayScrim,
    builder: (context) => _FieldDialog(
      title: title,
      initial: initial,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      fieldKey: fieldKey,
      maxLength: maxLength,
    ),
  );
  final kept = text?.trim() ?? '';
  return kept.isEmpty ? null : kept;
}

class _FieldDialog extends StatefulWidget {
  const _FieldDialog({
    required this.title,
    required this.initial,
    required this.cancelLabel,
    required this.confirmLabel,
    this.fieldKey,
    this.maxLength,
  });

  final String title;
  final String initial;
  final String cancelLabel;
  final String confirmLabel;
  final Key? fieldKey;
  final int? maxLength;

  @override
  State<_FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends State<_FieldDialog> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BvDialog(
    title: widget.title,
    body: '',
    cancelLabel: widget.cancelLabel,
    confirmLabel: widget.confirmLabel,
    onCancel: () => Navigator.of(context).pop(),
    onConfirm: () => Navigator.of(context).pop(_field.text),
    child: BvTextField(
      key: widget.fieldKey,
      controller: _field,
      maxLength: widget.maxLength,
      autofocus: true,
      textInputAction: TextInputAction.done,
    ),
  );
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
    this.child,
  });

  final String title;
  final String body;

  /// Under the words: a field (a rename, review 105C).
  final Widget? child;
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
            if (body.isNotEmpty)
              Text(
                body,
                style: type.bodyMd.copyWith(color: BvColors.textSecondary),
              ),
            ?child,
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
