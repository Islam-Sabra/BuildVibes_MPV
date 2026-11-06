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
  bool form = false,
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
      form: form,
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
    this.form = false,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final BvSheetFooter? footer;

  /// Stays at the foot while the content scrolls (a picker's Done).
  final Widget? foot;

  /// [child] is a [BvSheetForm], which scrolls its own fields.
  final bool form;

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
              Flexible(
                child: form ? child : SingleChildScrollView(child: child),
              ),
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

/// Review 123: a sheet's form. [body] (the fields) scrolls; [action] (the
/// main button) stays at the sheet's foot, so with the keyboard up it sits
/// right above it. Open it with `showBvSheet(form: true)`. While the fields
/// run on under it, a 1 px line tops the action.
class BvSheetForm extends StatefulWidget {
  const BvSheetForm({
    super.key,
    required this.body,
    required this.action,
    this.gap = BvSheetSpec.gap,
  });

  final Widget body;
  final Widget action;

  /// Between [body] and [action].
  final double gap;

  @override
  State<BvSheetForm> createState() => _BvSheetFormState();
}

class _BvSheetFormState extends State<BvSheetForm> {
  static const _inside = BvSpace.s4;

  var _under = false;

  bool _onMetrics(ScrollMetrics m) {
    final under = m.extentAfter > 0;
    if (under != _under) setState(() => _under = under);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) => _onMetrics(n.metrics),
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (n) => _onMetrics(n.metrics),
              // Part of the gap scrolls with the fields, so letters that
              // reach below their line (Arabic) are not cut.
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.only(bottom: _inside),
                child: widget.body,
              ),
            ),
          ),
        ),
        DecoratedBox(
          key: const Key('bv-sheet-form-action'),
          decoration: BoxDecoration(
            color: BvColors.surfaceApp,
            border: _under
                ? const Border(
                    top: BorderSide(
                      color: BvColors.borderSubtle,
                      width: BvStroke.thin,
                    ),
                  )
                : null,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.only(top: widget.gap - _inside),
            child: widget.action,
          ),
        ),
      ],
    );
  }
}
