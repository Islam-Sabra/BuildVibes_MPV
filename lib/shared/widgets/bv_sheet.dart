import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_button.dart';

/// Spec §11 ("DS · Sheet"). Opens a [BvSheet] over a scrim; tapping the
/// scrim closes it.
Future<T?> showBvSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  BvSheetFooter? footer,
  WidgetBuilder? foot,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: BvColors.overlayScrim,
    sheetAnimationStyle: const AnimationStyle(
      duration: BvMotion.sheet,
      reverseDuration: BvMotion.base,
      curve: BvMotion.enter,
      reverseCurve: BvMotion.exit,
    ),
    builder: (context) => BvSheet(
      title: title,
      subtitle: subtitle,
      footer: footer,
      foot: foot?.call(context),
      child: builder(context),
    ),
  );
}

/// Two Large buttons that share the width: Secondary (Cancel) and
/// Primary (Confirm).
class BvSheetFooter {
  const BvSheetFooter({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onConfirm,
    this.onCancel,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  /// Defaults to closing the sheet.
  final VoidCallback? onCancel;
}

class BvSheet extends StatelessWidget {
  const BvSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.footer,
    this.foot,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final BvSheetFooter? footer;

  /// Stays at the foot while the content scrolls (a picker's Done).
  final Widget? foot;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final media = MediaQuery.of(context);
    final bottom =
        media.viewPadding.bottom +
        media.viewInsets.bottom +
        BvSheetSpec.paddingBottom;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height * BvSheetSpec.maxHeightRatio,
      ),
      child: DecoratedBox(
        key: const Key('bv-sheet'),
        decoration: const BoxDecoration(
          color: BvColors.surfaceApp,
          borderRadius: BvRadius.sheetTop,
          boxShadow: BvShadow.sheet,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            top: BvSheetSpec.paddingTop,
            start: BvSheetSpec.paddingSide,
            end: BvSheetSpec.paddingSide,
            bottom: bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BvSheetSpec.gap,
            children: [
              const Center(
                child: DecoratedBox(
                  key: Key('bv-sheet-handle'),
                  decoration: BoxDecoration(
                    color: BvColors.borderDefault,
                    borderRadius: BvSheetSpec.handleRadius,
                  ),
                  child: SizedBox(
                    width: BvSheetSpec.handleWidth,
                    height: BvSheetSpec.handleHeight,
                  ),
                ),
              ),
              if (title != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSheetSpec.subtitleGap,
                  children: [
                    Text(title!, style: type.titleLg),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: type.bodySm.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              Flexible(child: SingleChildScrollView(child: child)),
              ?foot,
              if (footer != null)
                Row(
                  spacing: BvSheetSpec.footerGap,
                  children: [
                    Expanded(
                      child: BvButton(
                        key: const Key('bv-sheet-cancel'),
                        label: footer!.cancelLabel,
                        style: BvButtonStyle.secondary,
                        expand: true,
                        onPressed:
                            footer!.onCancel ??
                            () => Navigator.of(context).pop(),
                      ),
                    ),
                    Expanded(
                      child: BvButton(
                        key: const Key('bv-sheet-confirm'),
                        label: footer!.confirmLabel,
                        expand: true,
                        onPressed: footer!.onConfirm,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
