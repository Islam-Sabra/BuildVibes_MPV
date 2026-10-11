import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show Bidi;

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
    this.invalid = false,
    this.textCapitalization = TextCapitalization.none,
    this.suggestions = true,
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

  /// Red border without a message of its own, for a field whose message is
  /// shown by its parent (the phone row).
  final bool invalid;

  /// Which keyboard case opens (codes: [TextCapitalization.characters]).
  final TextCapitalization textCapitalization;

  /// False turns off autocorrect and word suggestions (codes, numbers).
  final bool suggestions;

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
    _contentDirection = directionOf(_controller.text);
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

  TextDirection? _contentDirection;

  /// The direction of what is typed: a Latin name in the Arabic app reads
  /// left to right (so "Co." keeps its full stop at the end).
  static TextDirection? directionOf(String text) {
    if (Bidi.startsWithRtl(text)) return TextDirection.rtl;
    if (Bidi.startsWithLtr(text)) return TextDirection.ltr;
    return null;
  }

  void _onText() {
    final direction = directionOf(_controller.text);
    if (widget.maxLength != null || direction != _contentDirection) {
      setState(() => _contentDirection = direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final l10n = AppLocalizations.of(context);
    final hasError = widget.error != null || widget.invalid;

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
      textCapitalization: widget.textCapitalization,
      autocorrect: widget.suggestions,
      enableSuggestions: widget.suggestions,
      maxLines: widget.maxLines,
      minLines: widget.maxLines > 1 ? 2 : null,
      maxLength: max,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      textDirection: widget.textDirection ?? _contentDirection,
      // Text stays aligned with the form, whatever its own direction.
      textAlign:
          widget.textAlign == TextAlign.start && widget.textDirection == null
          ? (Directionality.of(context) == TextDirection.rtl
                ? TextAlign.right
                : TextAlign.left)
          : widget.textAlign,
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
    final showErrorIcon = widget.error != null;
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
              if (showErrorIcon)
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
                    color: showErrorIcon
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

/// Phone number. [dialCode] comes from the market pack, never typed into
/// code. With [onDialCodeTap] the code is a box of its own that opens a
/// picker (E2p); without it the code is a fixed label inside the field.
/// The row is always left to right: numbers read that way in Arabic too.
class BvPhoneField extends StatelessWidget {
  const BvPhoneField({
    super.key,
    required this.dialCode,
    this.onDialCodeTap,
    this.label,
    this.placeholder,
    this.helper,
    this.error,
    this.controller,
    this.onChanged,
    this.autofocus = false,
  });

  final String dialCode;
  final VoidCallback? onDialCodeTap;
  final String? label;
  final String? placeholder;
  final String? helper;
  final String? error;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  static const _formatters = [
    BvWesternDigitsFormatter(),
    _DigitsOnlyFormatter(),
  ];

  @override
  Widget build(BuildContext context) {
    if (onDialCodeTap == null) {
      return BvTextField(
        label: label,
        placeholder: placeholder,
        helper: helper,
        error: error,
        controller: controller,
        onChanged: onChanged,
        autofocus: autofocus,
        prefixText: dialCode,
        textDirection: TextDirection.ltr,
        keyboardType: TextInputType.phone,
        inputFormatters: _formatters,
      );
    }

    final type = BvType.of(context);
    final hasError = error != null;
    final message = error ?? helper;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvFieldSpec.gap,
      children: [
        if (label != null)
          Text(
            label!,
            style: type.labelMd.copyWith(color: BvColors.textPrimary),
          ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            spacing: BvSpace.s8,
            children: [
              _DialCodeBox(
                dialCode: dialCode,
                invalid: hasError,
                onTap: onDialCodeTap!,
              ),
              Expanded(
                child: BvTextField(
                  placeholder: placeholder,
                  controller: controller,
                  onChanged: onChanged,
                  autofocus: autofocus,
                  invalid: hasError,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.phone,
                  inputFormatters: _formatters,
                ),
              ),
            ],
          ),
        ),
        if (message != null)
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
                  message,
                  style: type.metadata.copyWith(
                    color: hasError
                        ? BvColors.textDestructive
                        : BvColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _DigitsOnlyFormatter extends TextInputFormatter {
  const _DigitsOnlyFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => FilteringTextInputFormatter.digitsOnly.formatEditUpdate(
    oldValue,
    newValue,
  );
}

class _DialCodeBox extends StatelessWidget {
  const _DialCodeBox({
    required this.dialCode,
    required this.invalid,
    required this.onTap,
  });

  final String dialCode;
  final bool invalid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: BvColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BvRadius.controlAll,
          side: BorderSide(
            color: invalid ? BvColors.borderDestructive : BvColors.borderInput,
            width: invalid ? BvStroke.thick : BvStroke.thin,
          ),
        ),
        child: InkWell(
          key: const Key('dial-code-box'),
          onTap: onTap,
          borderRadius: BvRadius.controlAll,
          splashFactory: NoSplash.splashFactory,
          child: SizedBox(
            width: BvFieldSpec.dialBoxWidth,
            height: BvFieldSpec.height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: BvSpace.s8,
              children: [
                Text(
                  dialCode,
                  style: BvType.latin.bodyLg.copyWith(
                    color: BvColors.textPrimary,
                  ),
                ),
                const Icon(
                  BvIcons.caretDown,
                  size: BvFieldSpec.iconSize,
                  color: BvColors.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BvSelectOption<T> {
  const BvSelectOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.enabled = true,
    this.badge,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;
  final bool enabled;
  final String? badge;
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
              enabled: o.enabled,
              badge: o.badge,
            ),
        ],
        value: widget.value,
        onChanged: (v) => Navigator.of(sheetContext).pop(v),
      ),
    );
    if (picked != null) widget.onChanged?.call(picked);
  }
}
