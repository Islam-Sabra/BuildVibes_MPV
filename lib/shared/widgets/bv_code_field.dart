import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_text_field.dart';

/// One-time sign-in code: six boxes (E3, E3e, OB3). One hidden text field
/// takes the input, so the phone's automatic code fill and paste both work.
/// Always left to right, also in Arabic. With [inputFormatters], it takes
/// another kind of 6-character code, such as a Space's invite code (OB6):
/// letters too, and no one-time-code fill.
class BvCodeField extends StatefulWidget {
  const BvCodeField({
    super.key,
    this.label,
    this.semanticLabel,
    this.error,
    this.controller,
    this.onCompleted,
    this.onChanged,
    this.autofocus = false,
    this.enabled = true,
    this.inputFormatters,
  });

  final String? label;

  /// Read by screen readers for the boxes as a whole.
  final String? semanticLabel;
  final String? error;
  final TextEditingController? controller;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool enabled;

  /// In place of the sign-in code's (Western digits only); the length is
  /// still six.
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<BvCodeField> createState() => _BvCodeFieldState();
}

class _BvCodeFieldState extends State<BvCodeField> {
  TextEditingController? _ownController;
  final _focus = FocusNode();

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _focus.addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _ownController?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final text = _controller.text;
    final hasError = widget.error != null;
    const length = BvFieldSpec.codeLength;
    // The sign-in code, or another 6-character code ([inputFormatters]).
    final code = widget.inputFormatters == null;

    Widget box(int i) {
      final filled = i < text.length;
      final current = _focus.hasFocus && i == text.length.clamp(0, length - 1);
      final border = hasError
          ? const BorderSide(
              color: BvColors.borderDestructive,
              width: BvStroke.thick,
            )
          : current
          ? const BorderSide(color: BvColors.borderFocus, width: BvStroke.thick)
          : const BorderSide(color: BvColors.borderInput, width: BvStroke.thin);
      return Expanded(
        child: Container(
          key: Key('code-box-$i'),
          height: BvFieldSpec.codeBoxHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.enabled
                ? BvColors.surfaceElevated
                : BvColors.surfaceSubtle,
            borderRadius: BvRadius.controlAll,
            border: Border.fromBorderSide(border),
          ),
          child: Text(
            filled ? text[i] : '',
            style: BvType.latin.headingLg.copyWith(color: BvColors.textPrimary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvFieldSpec.gap,
      children: [
        if (widget.label != null)
          Text(
            widget.label!,
            style: type.labelMd.copyWith(color: BvColors.textPrimary),
          ),
        Semantics(
          label: widget.semanticLabel,
          textField: true,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Row(
                  spacing: BvFieldSpec.codeBoxGap,
                  children: [for (var i = 0; i < length; i++) box(i)],
                ),
                // The real input, invisible, over the boxes.
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      key: const Key('code-input'),
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
                      enabled: widget.enabled,
                      maxLength: length,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      keyboardType: code
                          ? TextInputType.number
                          : TextInputType.visiblePassword,
                      textCapitalization: code
                          ? TextCapitalization.none
                          : TextCapitalization.characters,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: code
                          ? const [AutofillHints.oneTimeCode]
                          : null,
                      inputFormatters: [
                        ...?widget.inputFormatters,
                        if (code) ...[
                          const BvWesternDigitsFormatter(),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        LengthLimitingTextInputFormatter(length),
                      ],
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      onChanged: (v) {
                        widget.onChanged?.call(v);
                        if (v.length == length) widget.onCompleted?.call(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Text(
            widget.error!,
            key: const Key('code-error'),
            style: type.metadata.copyWith(color: BvColors.textDestructive),
          ),
      ],
    );
  }
}
