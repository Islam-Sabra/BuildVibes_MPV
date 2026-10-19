import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_loop_specs.dart';
import 'bv_writing_card.dart' show bvBareField;

/// Opens a [BvFieldSheet] (W1 v13c 2582:77206, F24): it sits on the
/// keyboard from the first frame, so what is being typed and its send
/// button are always in view.
Future<T?> showBvFieldSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
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
    builder: (context) => BvFieldSheet(title: title, child: builder(context)),
  );
}

/// A sheet with a field: the handle, the title, then [child] (the quoted
/// item, the field). It is lifted by the keyboard's height
/// (`viewInsets.bottom`), read on every frame. When the keyboard leaves
/// too little room, the top of [child] scrolls away and its end (the field
/// and the send button) stays above the keyboard.
class BvFieldSheet extends StatelessWidget {
  const BvFieldSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    // Over the keyboard, the phone's own bottom bar is behind it.
    final bottom = keyboard > 0 ? keyboard : media.viewPadding.bottom;
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (media.size.height - keyboard - media.viewPadding.top)
              .clamp(0, media.size.height * BvSheetSpec.maxHeightRatio),
        ),
        child: DecoratedBox(
          key: const Key('bv-field-sheet'),
          decoration: const BoxDecoration(
            color: BvColors.surfaceElevated,
            borderRadius: BvFieldSheetSpec.radius,
            boxShadow: BvShadow.sheet,
          ),
          child: Stack(
            children: [
              const PositionedDirectional(
                top: BvFieldSheetSpec.handleTop,
                start: 0,
                end: 0,
                child: Center(
                  child: DecoratedBox(
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
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: BvFieldSheetSpec.paddingTop,
                  start: BvFieldSheetSpec.paddingSide,
                  end: BvFieldSheetSpec.paddingSide,
                  bottom: BvFieldSheetSpec.paddingBottom,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: BvFieldSheetSpec.gap,
                    children: [
                      Text(
                        title,
                        style: type.titleLg.copyWith(
                          color: BvColors.textPrimary,
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          // Short of room, the end stays in view.
                          reverse: true,
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The work item, quoted in one line (F24): a small thumbnail of its
/// latest photo (or the work item mark), then "KCT-014 · Sleeves at grid
/// C7 before the pour", cut at the end.
class BvItemQuote extends StatelessWidget {
  const BvItemQuote({super.key, required this.text, this.image});

  final String text;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Container(
      key: const Key('bv-item-quote'),
      padding: const EdgeInsetsDirectional.only(
        start: BvFieldSheetSpec.quotePaddingStart,
        end: BvFieldSheetSpec.quotePaddingEnd,
        top: BvFieldSheetSpec.quotePaddingVertical,
        bottom: BvFieldSheetSpec.quotePaddingVertical,
      ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvFieldSheetSpec.quoteRadius,
      ),
      child: Row(
        spacing: BvFieldSheetSpec.quoteGap,
        children: [
          ClipRRect(
            borderRadius: BvFieldSheetSpec.thumbRadius,
            child: SizedBox.square(
              key: const Key('bv-item-quote-thumb'),
              dimension: BvFieldSheetSpec.thumb,
              child: image == null
                  ? const ColoredBox(
                      color: BvColors.surfaceElevated,
                      child: Icon(
                        BvIcons.workItems,
                        size: BvFieldSheetSpec.thumbIcon,
                        color: BvColors.iconSecondary,
                      ),
                    )
                  : Image(image: image!, fit: BoxFit.cover),
            ),
          ),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.bodyLg.copyWith(color: BvColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A field and its round send button (F24). One line: the keyboard's
/// action key sends too. [multiline] notes take a new line on that key
/// instead, and only the button sends.
class BvSendField extends StatelessWidget {
  const BvSendField({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.sendLabel,
    required this.onSend,
    this.onChanged,
    this.maxLength,
    this.multiline = false,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final String placeholder;

  /// Read out for the send button.
  final String sendLabel;

  /// Null while there is nothing to send.
  final VoidCallback? onSend;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final bool multiline;
  final bool autofocus;

  /// Most lines a [multiline] note grows to before it scrolls.
  static const maxLines = 4;

  @override
  Widget build(BuildContext context) {
    final style = BvType.of(context).bodyLg;
    final send = onSend;
    return Row(
      // A note that grows keeps its button at its last line.
      crossAxisAlignment: multiline
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.center,
      spacing: BvFieldSheetSpec.fieldGap,
      children: [
        Expanded(
          child: TextField(
            key: const Key('bv-send-field'),
            controller: controller,
            autofocus: autofocus,
            maxLength: maxLength,
            minLines: 1,
            maxLines: multiline ? maxLines : 1,
            keyboardType: multiline
                ? TextInputType.multiline
                : TextInputType.text,
            textInputAction: multiline
                ? TextInputAction.newline
                : TextInputAction.send,
            textCapitalization: TextCapitalization.sentences,
            onChanged: onChanged,
            onSubmitted: multiline || send == null ? null : (_) => send(),
            style: style.copyWith(color: BvColors.textPrimary),
            cursorColor: BvColors.actionPrimary,
            decoration: bvBareField(hint: placeholder, style: style).copyWith(
              counterText: '',
              filled: true,
              fillColor: BvColors.surfaceApp,
              contentPadding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvFieldSheetSpec.fieldPaddingHorizontal,
                vertical: BvFieldSheetSpec.fieldPaddingVertical,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BvFieldSheetSpec.fieldRadius,
                borderSide: BorderSide(
                  color: BvColors.borderDefault,
                  width: BvFieldSheetSpec.fieldBorder,
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BvFieldSheetSpec.fieldRadius,
                borderSide: BorderSide(
                  color: BvColors.borderFocus,
                  width: BvFieldSheetSpec.fieldBorder,
                ),
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          enabled: send != null,
          label: sendLabel,
          excludeSemantics: true,
          child: Material(
            key: const Key('bv-send-field-send'),
            color: send != null
                ? BvColors.actionPrimary
                : BvColors.actionDisabled,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: send,
              child: SizedBox.square(
                dimension: BvFieldSheetSpec.send,
                child: Icon(
                  BvIcons.send,
                  size: BvFieldSheetSpec.sendIcon,
                  color: send != null
                      ? BvColors.iconInverse
                      : BvColors.actionDisabledForeground,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
