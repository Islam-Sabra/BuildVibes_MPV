import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// Spec §5: subtle fill and no border; white with a focus border when
/// focused.
class BvSearchField extends StatefulWidget {
  const BvSearchField({
    super.key,
    required this.placeholder,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<BvSearchField> createState() => _BvSearchFieldState();
}

class _BvSearchFieldState extends State<BvSearchField> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final focused = _focus.hasFocus;
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: TextInputAction.search,
      style: type.bodyMd.copyWith(color: BvColors.textPrimary),
      cursorColor: BvColors.borderFocus,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: type.bodyMd.copyWith(color: BvColors.textSecondary),
        filled: true,
        fillColor: focused ? BvColors.surfaceElevated : BvColors.surfaceSubtle,
        isDense: true,
        constraints: const BoxConstraints(
          minHeight: BvFieldSpec.height,
          maxHeight: BvFieldSpec.height,
        ),
        contentPadding: EdgeInsetsDirectional.symmetric(
          horizontal: BvFieldSpec.paddingHorizontal,
          vertical: BvFieldSpec.paddingFor(type.bodyMd),
        ),
        prefixIcon: const Padding(
          padding: EdgeInsetsDirectional.only(
            start: BvFieldSpec.paddingHorizontal,
            end: BvSpace.s8,
          ),
          child: Icon(
            BvIcons.search,
            size: BvFieldSpec.iconSize,
            color: BvColors.iconSecondary,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BvRadius.controlAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BvRadius.controlAll,
          borderSide: BorderSide(
            color: BvColors.borderFocus,
            width: BvStroke.thick,
          ),
        ),
      ),
    );
  }
}
