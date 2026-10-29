import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../data/models/daybook.dart' show SpacePlace;
import 'bv_give_to_picker.dart' show BvPickerSearch;

/// A post's place (review 105C, SP2), built like Give to's picker
/// ([BvGiveToSpec]): a search field, then the Space's places A to Z, the
/// chosen one with a check. Typing filters; for who [canAdd] (may post
/// work), a name the Space hasn't got, whatever its case and spaces, offers
/// "Add place ‘…’" ([addLabel]). [onLongPress] (a Lead's) renames or
/// deletes one.
class BvPlacePicker extends StatefulWidget {
  const BvPlacePicker({
    super.key,
    required this.places,
    required this.currentId,
    required this.searchPlaceholder,
    required this.addLabel,
    required this.canAdd,
    required this.onPick,
    required this.onAdd,
    this.onLongPress,
    this.emptyLabel,
    this.inSheet = false,
  });

  /// A to Z.
  final List<SpacePlace> places;
  final String? currentId;
  final String searchPlaceholder;
  final String Function(String name) addLabel;
  final bool canAdd;
  final ValueChanged<SpacePlace> onPick;
  final ValueChanged<String> onAdd;
  final ValueChanged<SpacePlace>? onLongPress;

  /// With no places and nothing typed: what to do.
  final String? emptyLabel;
  final bool inSheet;

  @override
  State<BvPlacePicker> createState() => _BvPlacePickerState();
}

class _BvPlacePickerState extends State<BvPlacePicker> {
  final _search = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final typed = _search.text.trim();
    final query = typed.toLowerCase();
    // As the server compares names: no case and no spaces.
    final folded = SpacePlace.fold(typed);
    final shown = query.isEmpty
        ? widget.places
        : [
            for (final p in widget.places)
              if (p.name.toLowerCase().contains(query) ||
                  SpacePlace.fold(p.name).contains(folded))
                p,
          ];
    final known = widget.places.any((p) => SpacePlace.fold(p.name) == folded);
    final adds = widget.canAdd && typed.isNotEmpty && !known;
    final rows = [
      for (final p in shown)
        _Row(
          key: Key('place-row-${p.id}'),
          name: p.name,
          current: p.id == widget.currentId,
          type: type,
          onTap: () => widget.onPick(p),
          onLongPress: widget.onLongPress == null
              ? null
              : () => widget.onLongPress!(p),
        ),
      if (adds)
        _Row(
          key: const Key('place-add'),
          name: widget.addLabel(typed),
          icon: BvIcons.add,
          action: true,
          current: false,
          type: type,
          onTap: () => widget.onAdd(typed),
        ),
      if (shown.isEmpty && !adds && widget.emptyLabel != null)
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvGiveToSpec.rowPaddingHorizontal,
            vertical: BvGiveToSpec.rowPaddingVertical,
          ),
          child: Text(
            widget.emptyLabel!,
            style: type.metadata.copyWith(color: BvColors.textSecondary),
          ),
        ),
    ];
    final sheet = widget.inSheet;
    return Container(
      key: const Key('place-picker'),
      width: sheet ? null : BvGiveToSpec.width,
      padding: const EdgeInsetsDirectional.only(
        bottom: BvGiveToSpec.paddingBottom,
      ),
      decoration: sheet
          ? null
          : const BoxDecoration(
              color: BvColors.surfaceElevated,
              borderRadius: BvGiveToSpec.radius,
              boxShadow: BvShadow.popover,
            ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvGiveToSpec.searchPaddingHorizontal,
                BvGiveToSpec.paddingTop,
                BvGiveToSpec.searchPaddingHorizontal,
                BvGiveToSpec.searchPaddingBottom,
              ),
              child: BvPickerSearch(
                fieldKey: const Key('place-search'),
                controller: _search,
                focusNode: _focus,
                placeholder: widget.searchPlaceholder,
                autofocus: false,
              ),
            ),
            if (sheet)
              ...rows
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: rows,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.name,
    required this.current,
    required this.type,
    required this.onTap,
    this.onLongPress,
    this.icon = BvIcons.place,
    this.action = false,
  });

  final String name;
  final bool current;
  final BvTypeSet type;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData icon;

  /// "Add place ‘…’", in the action colour.
  final bool action;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: current,
    child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(minHeight: BvGiveToSpec.rowHeight),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvGiveToSpec.rowPaddingHorizontal,
          vertical: BvGiveToSpec.rowPaddingVertical,
        ),
        child: Row(
          spacing: BvGiveToSpec.rowGap,
          children: [
            Icon(
              icon,
              size: BvSize.iconMd,
              color: action ? BvColors.iconAction : BvColors.iconSecondary,
            ),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: type.bodyMd.copyWith(
                  color: action ? BvColors.textAction : BvColors.textPrimary,
                ),
              ),
            ),
            if (current)
              const Icon(
                BvIcons.check,
                size: BvGiveToSpec.check,
                color: BvColors.iconAction,
              ),
          ],
        ),
      ),
    ),
  );
}
