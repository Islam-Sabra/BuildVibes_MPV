import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import 'bv_writing_card.dart' show bvBareField;
import 'bv_avatar.dart';

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
/// filters by name or Team.
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
  });

  final List<BvGiveToPerson> people;
  final String? currentOwnerId;

  /// The current owner's sub line ("now").
  final String currentLabel;
  final String searchPlaceholder;
  final ValueChanged<BvGiveToPerson> onPick;
  final TextEditingController? searchController;
  final bool autofocus;

  @override
  State<BvGiveToPicker> createState() => _BvGiveToPickerState();
}

class _BvGiveToPickerState extends State<BvGiveToPicker> {
  TextEditingController? _own;
  TextEditingController get _search =>
      widget.searchController ?? (_own ??= TextEditingController());

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

    return Container(
      width: BvGiveToSpec.width,
      padding: const EdgeInsetsDirectional.only(
        top: BvGiveToSpec.paddingTop,
        bottom: BvGiveToSpec.paddingBottom,
      ),
      decoration: const BoxDecoration(
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
                0,
                BvGiveToSpec.searchPaddingHorizontal,
                BvGiveToSpec.searchPaddingBottom,
              ),
              child: _Search(
                controller: _search,
                placeholder: widget.searchPlaceholder,
                autofocus: widget.autofocus,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final p in shown)
                    _Row(
                      person: p,
                      current: p.id == widget.currentOwnerId,
                      currentLabel: widget.currentLabel,
                      type: type,
                      onTap: () => widget.onPick(p),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({
    required this.controller,
    required this.placeholder,
    required this.autofocus,
  });

  final TextEditingController controller;
  final String placeholder;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final style = BvType.of(context).bodyMd;
    return Container(
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
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.person,
    required this.current,
    required this.currentLabel,
    required this.type,
    required this.onTap,
  });

  final BvGiveToPerson person;
  final bool current;
  final String currentLabel;
  final BvTypeSet type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = current ? currentLabel : person.team;
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
                      person.name,
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
