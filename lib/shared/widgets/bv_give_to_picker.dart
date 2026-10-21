import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import 'bv_writing_card.dart' show bvBareField;
import 'bv_avatar.dart';
import 'bv_tap_target.dart';

/// A Space member who can own a work item.
class BvGiveToPerson {
  const BvGiveToPerson({
    required this.id,
    required this.name,
    this.team,
    this.image,
  });

  final String id;
  final String name;

  /// Their Space Team ("MEP", "Site").
  final String? team;
  final ImageProvider? image;
}

/// Give a work item to someone else (2540:34840): a search field and the
/// Space's people, the current owner marked "now" with a check. Typing
/// filters by name or Team. With [chosenIds] it picks several (who a
/// checklist or an activity is for): each chosen person has the check, and
/// a pick adds or takes them out.
class BvGiveToPicker extends StatefulWidget {
  const BvGiveToPicker({
    super.key,
    required this.people,
    required this.currentOwnerId,
    required this.currentLabel,
    required this.searchPlaceholder,
    required this.onPick,
    this.searchController,
    this.autofocus = false,
    this.chosenIds,
    this.inSheet = false,
    this.footer,
    this.meId,
    this.meLabel,
  });

  final List<BvGiveToPerson> people;
  final String? currentOwnerId;

  /// The current owner's sub line ("now").
  final String currentLabel;
  final String searchPlaceholder;
  final ValueChanged<BvGiveToPerson> onPick;
  final TextEditingController? searchController;
  final bool autofocus;
  final Set<String>? chosenIds;

  /// On a sheet: as wide as the sheet, with no card of its own; the sheet
  /// scrolls the list.
  final bool inSheet;

  /// Under the list, always in view: another way out (F56, "Post as a
  /// Note").
  final Widget? footer;

  /// The viewer (review 50 F69): listed once, first, as [meLabel] ("You")
  /// with their face, then a hairline, then everyone else. A search shows
  /// them only when their own name matches.
  final String? meId;
  final String? meLabel;

  @override
  State<BvGiveToPicker> createState() => _BvGiveToPickerState();
}

class _BvGiveToPickerState extends State<BvGiveToPicker> {
  TextEditingController? _own;
  TextEditingController get _search =>
      widget.searchController ?? (_own ??= TextEditingController());
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearch);
  }

  @override
  void didUpdateWidget(BvGiveToPicker old) {
    super.didUpdateWidget(old);
    if (old.searchController != widget.searchController) {
      (old.searchController ?? _own)?.removeListener(_onSearch);
      _search.addListener(_onSearch);
    }
  }

  @override
  void dispose() {
    _search.removeListener(_onSearch);
    _own?.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearch() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final query = _search.text.trim().toLowerCase();
    final shown = query.isEmpty
        ? widget.people
        : [
            for (final p in widget.people)
              if (p.name.toLowerCase().contains(query) ||
                  (p.team?.toLowerCase().contains(query) ?? false))
                p,
          ];

    final sheet = widget.inSheet;
    _Row row(BvGiveToPerson p, {String? label}) => _Row(
      key: label == null ? null : const Key('give-to-me'),
      person: p,
      label: label,
      current:
          widget.chosenIds?.contains(p.id) ?? p.id == widget.currentOwnerId,
      currentLabel: widget.chosenIds == null ? widget.currentLabel : null,
      type: type,
      onTap: () => widget.onPick(p),
    );
    final meLabel = widget.meLabel;
    final me = meLabel == null
        ? null
        : shown.where((p) => p.id == widget.meId).firstOrNull;
    final others = [
      for (final p in shown)
        if (me == null || p.id != me.id) p,
    ];
    final rows = [
      if (me != null) ...[
        row(me, label: meLabel),
        if (others.isNotEmpty)
          const Divider(
            key: Key('give-to-me-hairline'),
            height: BvStroke.thin,
            thickness: BvStroke.thin,
            color: BvColors.borderSubtle,
          ),
      ],
      for (final p in others) row(p),
    ];
    return Container(
      width: sheet ? null : BvGiveToSpec.width,
      // The top padding sits with the search field, inside its touch area.
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
              child: _Search(
                controller: _search,
                focusNode: _searchFocus,
                placeholder: widget.searchPlaceholder,
                autofocus: widget.autofocus,
              ),
            ),
            // On a sheet, the sheet scrolls the rows.
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
            ?widget.footer,
          ],
        ),
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.autofocus,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final style = BvType.of(context).bodyMd;
    // The whole field focuses the search, and its touch area reaches into
    // the padding above and below (48 high in all).
    final field = Container(
      key: const Key('give-to-search'),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvGiveToSpec.fieldPaddingHorizontal,
        vertical: BvGiveToSpec.fieldPaddingVertical,
      ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvGiveToSpec.fieldRadius,
      ),
      child: Row(
        spacing: BvGiveToSpec.fieldGap,
        children: [
          const Icon(
            BvIcons.search,
            size: BvGiveToSpec.searchIcon,
            color: BvColors.iconSecondary,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              style: style.copyWith(color: BvColors.textPrimary),
              cursorColor: BvColors.actionPrimary,
              decoration: bvBareField(hint: placeholder, style: style),
            ),
          ),
        ],
      ),
    );
    return BvTapTarget(
      outset: BvGiveToSpec.searchTouchOutset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: focusNode.requestFocus,
        child: field,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.person,
    this.label,
    required this.current,
    required this.currentLabel,
    required this.type,
    required this.onTap,
  });

  final BvGiveToPerson person;

  /// Shown instead of the name ("You", F69).
  final String? label;
  final bool current;

  /// The current owner's sub line; null when several can be chosen.
  final String? currentLabel;
  final BvTypeSet type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = current ? currentLabel ?? person.team : person.team;
    return Semantics(
      button: true,
      selected: current,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // At least 52; Arabic's taller lines may need more.
          constraints: const BoxConstraints(minHeight: BvGiveToSpec.rowHeight),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvGiveToSpec.rowPaddingHorizontal,
            vertical: BvGiveToSpec.rowPaddingVertical,
          ),
          child: Row(
            spacing: BvGiveToSpec.rowGap,
            children: [
              ExcludeSemantics(
                child: BvAvatar(
                  name: person.name,
                  size: BvAvatarSize.list,
                  tint: BvAvatarTints.forId(person.id),
                  image: person.image,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label ?? person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                    ),
                    if (sub != null)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (current)
                const Icon(
                  BvIcons.check,
                  size: BvGiveToSpec.check,
                  color: BvColors.textAction,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
