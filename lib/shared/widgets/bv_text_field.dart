import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import 'bv_choice_card.dart';
import 'bv_sheet.dart';

/// Spec §4 ("DS · Inputs"): label, field, then helper or error, gap 6.
///
/// Multi-line when [maxLines] is more than 1; with a [maxLength] it shows a
/// counter once the text is near the limit.
class BvTextField extends StatefulWidget {
  const BvTextField({
    super.key,
    this.label,
    this.placeholder,
    this.helper,
    this.error,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.prefixText,
    this.suffixIcon,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.valueStyle,
    this.autofocus = false,
  });

  final String? label;
  final String? placeholder;
  final String? helper;

  /// Shown instead of [helper], in red with a warning icon.
  final String? error;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  /// Fixed text before the value, such as a dial code.
  final String? prefixText;
  final IconData? suffixIcon;

  /// Forces a direction for values that are always left to right (phone
  /// numbers, codes), even in Arabic.
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final TextStyle? valueStyle;
  final bool autofocus;

  @override
  State<BvTextField> createState() => _BvTextFieldState();
}

class _BvTextFieldState extends State<BvTextField> {
  TextEditingController? _own;
  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(BvTextField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_onText);
      _controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _own?.dispose();
    super.dispose();
  }

  void _onText() {
    if (widget.maxLength != null) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final l10n = AppLocalizations.of(context);
    final hasError = widget.error != null;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BvRadius.controlAll,
      borderSide: BorderSide(color: color, width: width),
    );

    final max = widget.maxLength;
    final length = _controller.text.characters.length;
    final showCounter =
        max != null &&
        widget.maxLines > 1 &&
        length >= max * BvFieldSpec.counterThreshold;

    final valueStyle = widget.valueStyle ?? type.bodyLg;
    final field = TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      keyboardType:
          widget.keyboardType ??
          (widget.maxLines > 1 ? TextInputType.multiline : null),
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      maxLines: widget.maxLines,
      minLines: widget.maxLines > 1 ? 2 : null,
      maxLength: max,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      textDirection: widget.textDirection,
      textAlign: widget.textAlign,
      style: valueStyle.copyWith(
        color: widget.enabled
            ? BvColors.textPrimary
            : BvColors.actionDisabledForeground,
      ),
      cursorColor: BvColors.borderFocus,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: valueStyle.copyWith(color: BvColors.textSecondary),
        // Shown as a fixed label so it is visible before the field is
        // focused (Material's prefixText only appears once focused).
        prefixIcon: widget.prefixText == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: BvFieldSpec.paddingHorizontal,
                  end: BvSpace.s8,
                ),
                child: Text(
                  widget.prefixText!,
                  key: const Key('field-prefix'),
                  style: valueStyle.copyWith(color: BvColors.textSecondary),
                ),
              ),
        prefixIconConstraints: const BoxConstraints(),
        suffixIcon: widget.suffixIcon == null
            ? null
            : Icon(
                widget.suffixIcon,
                size: BvFieldSpec.iconSize,
                color: BvColors.iconSecondary,
              ),
        filled: true,
        fillColor: widget.enabled
            ? BvColors.surfaceElevated
            : BvColors.surfaceSubtle,
        isDense: true,
        counterText: '',
        constraints: const BoxConstraints(minHeight: BvFieldSpec.height),
        contentPadding: EdgeInsetsDirectional.symmetric(
          horizontal: BvFieldSpec.paddingHorizontal,
          vertical: BvFieldSpec.paddingFor(valueStyle),
        ),
        enabledBorder: hasError
            ? border(BvColors.borderDestructive, BvStroke.thick)
            : border(BvColors.borderInput, BvStroke.thin),
        focusedBorder: hasError
            ? border(BvColors.borderDestructive, BvStroke.thick)
            : border(BvColors.borderFocus, BvStroke.thick),
        disabledBorder: border(BvColors.actionDisabled, BvStroke.thin),
      ),
    );

    // A forced direction (phone, code) applies to the whole field, so a
    // prefix such as the dial code stays before the number.
    final directedField = widget.textDirection == null
        ? field
        : Directionality(textDirection: widget.textDirection!, child: field);

    final helperText = widget.error ?? widget.helper;
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
        directedField,
        if (helperText != null || showCounter)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvSpace.s4,
            children: [
              if (hasError)
                const Padding(
                  padding: EdgeInsetsDirectional.only(top: BvSpace.s2),
                  child: Icon(
                    BvIcons.warning,
                    key: Key('field-error-icon'),
                    size: BvFieldSpec.helperIconSize,
                    color: BvColors.textDestructive,
                  ),
                ),
              Expanded(
                child: Text(
                  helperText ?? '',
                  style: type.metadata.copyWith(
                    color: hasError
                        ? BvColors.textDestructive
                        : BvColors.textSecondary,
                  ),
                ),
              ),
              if (showCounter)
                Text(
                  l10n.fieldCharacterCount(length, max),
                  key: const Key('field-counter'),
                  style: type.metadata.copyWith(
                    color: length >= max
                        ? BvColors.textDestructive
                        : BvColors.textSecondary,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Turns Arabic-Indic and Persian digits into Western digits (0–9), which
/// the app always uses.
class BvWesternDigitsFormatter extends TextInputFormatter {
  const BvWesternDigitsFormatter();

  static String normalise(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        out.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        out.writeCharCode(0x30 + rune - 0x06F0);
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = normalise(newValue.text);
    return text == newValue.text ? newValue : newValue.copyWith(text: text);
  }
}

/// Phone number. [dialCode] comes from the market pack (for example the
/// person's home market); it is never typed into code.
class BvPhoneField extends StatelessWidget {
  const BvPhoneField({
    super.key,
    required this.dialCode,
    this.label,
    this.placeholder,
    this.helper,
    this.error,
    this.controller,
    this.onChanged,
  });

  final String dialCode;
  final String? label;
  final String? placeholder;
  final String? helper;
  final String? error;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return BvTextField(
      label: label,
      placeholder: placeholder,
      helper: helper,
      error: error,
      controller: controller,
      onChanged: onChanged,
      // Numbers read left to right in Arabic too: the field is LTR.
      prefixText: dialCode,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        const BvWesternDigitsFormatter(),
        FilteringTextInputFormatter.digitsOnly,
      ],
    );
  }
}

/// One-time sign-in code: 6 digits.
class BvCodeField extends StatelessWidget {
  const BvCodeField({
    super.key,
    this.label,
    this.helper,
    this.error,
    this.controller,
    this.onCompleted,
    this.autofocus = false,
  });

  final String? label;
  final String? helper;
  final String? error;
  final TextEditingController? controller;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return BvTextField(
      label: label,
      helper: helper,
      error: error,
      controller: controller,
      autofocus: autofocus,
      placeholder: '0' * BvFieldSpec.codeLength,
      maxLength: BvFieldSpec.codeLength,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      valueStyle: BvType.of(
        context,
      ).headingMd.copyWith(letterSpacing: BvSpace.s8),
      keyboardType: TextInputType.number,
      inputFormatters: [
        const BvWesternDigitsFormatter(),
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (v) {
        if (v.length == BvFieldSpec.codeLength) onCompleted?.call(v);
      },
    );
  }
}

class BvSelectOption<T> {
  const BvSelectOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;
}

/// A field with a caret that opens a sheet with one single-choice list.
class BvSelect<T> extends StatefulWidget {
  const BvSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.placeholder,
    this.helper,
    this.error,
    this.sheetTitle,
  });

  final List<BvSelectOption<T>> options;
  final T? value;

  /// Null makes the select disabled.
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? placeholder;
  final String? helper;
  final String? error;
  final String? sheetTitle;

  @override
  State<BvSelect<T>> createState() => _BvSelectState<T>();
}

class _BvSelectState<T> extends State<BvSelect<T>> {
  final _text = TextEditingController();

  String get _currentLabel =>
      widget.options.where((o) => o.value == widget.value).firstOrNull?.label ??
      '';

  @override
  void initState() {
    super.initState();
    _text.text = _currentLabel;
  }

  @override
  void didUpdateWidget(BvSelect<T> old) {
    super.didUpdateWidget(old);
    _text.text = _currentLabel;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BvTextField(
      label: widget.label,
      placeholder: widget.placeholder,
      helper: widget.helper,
      error: widget.error,
      readOnly: true,
      enabled: widget.onChanged != null,
      controller: _text,
      suffixIcon: BvIcons.caretDown,
      onTap: _open,
    );
  }

  Future<void> _open() async {
    final picked = await showBvSheet<T>(
      context: context,
      title: widget.sheetTitle ?? widget.label,
      builder: (sheetContext) => BvChoiceList<T>(
        options: [
          for (final o in widget.options)
            BvChoiceOption(
              value: o.value,
              title: o.label,
              description: o.description,
              icon: o.icon,
            ),
        ],
        value: widget.value,
        onChanged: (v) => Navigator.of(sheetContext).pop(v),
      ),
    );
    if (picked != null) widget.onChanged?.call(picked);
  }
}
