import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import 'bv_avatar.dart';

/// One kind on [BvKindChips]: its icon and its word.
@immutable
class BvKindChoice<T> {
  const BvKindChoice({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// The kinds of what is written, as one choice that scrolls sideways
/// (review 105 SP2 2667:38511, rule 6): the chosen one in the action
/// colour on the brand's soft paper.
class BvKindChips<T> extends StatelessWidget {
  const BvKindChips({
    super.key,
    required this.choices,
    required this.selected,
    required this.onSelected,
  });

  final List<BvKindChoice<T>> choices;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: BvKindChipsSpec.gap,
        children: [
          for (final c in choices)
            _chip(type, c, selected: c.value == selected),
        ],
      ),
    );
  }

  Widget _chip(BvTypeSet type, BvKindChoice<T> c, {required bool selected}) {
    final ink = selected ? BvColors.textAction : BvColors.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        key: Key('kind-chip-${c.value}'),
        color: selected ? BvColors.surfaceBrandSoft : BvColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BvKindChipsSpec.radius,
          side: BorderSide(
            color: selected ? BvColors.textAction : BvColors.borderSubtle,
            width: BvStroke.thin,
          ),
        ),
        child: InkWell(
          borderRadius: BvKindChipsSpec.radius,
          onTap: () => onSelected(c.value),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvKindChipsSpec.paddingHorizontal,
              vertical: BvKindChipsSpec.paddingVertical,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: BvKindChipsSpec.iconGap,
              children: [
                Icon(c.icon, size: BvKindChipsSpec.icon, color: ink),
                Text(c.label, style: type.labelMd.copyWith(color: ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of [BvWritingRows]: its word ("For"), then what is chosen (a
/// person with their face, or words), or [empty] in grey while nothing is.
@immutable
class BvWritingRow {
  const BvWritingRow({
    required this.key,
    required this.label,
    required this.value,
    this.person,
    this.tint,
    this.empty = false,
    this.ask,
    this.onTap,
  });

  final Key key;
  final String label;
  final String value;

  /// The person's name for the face, when [value] is someone.
  final String? person;
  final Color? tint;
  final bool empty;

  /// Each new value pulses the row once: Post was tapped while it was still
  /// to choose (F56).
  final Object? ask;

  /// Opens its picker; null keeps it as it is (an edit keeps the owner).
  final VoidCallback? onTap;
}

/// For · Place · Due · Team (review 105 SP2, review 104 N10): each a row
/// that opens its picker, with a caret while it does; only the rows the
/// kind uses.
class BvWritingRows extends StatelessWidget {
  const BvWritingRows({super.key, required this.rows});

  final List<BvWritingRow> rows;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Container(
      key: const Key('writing-rows'),
      decoration: BoxDecoration(
        borderRadius: BvWritingRowsSpec.radius,
        border: Border.all(color: BvColors.borderSubtle, width: BvStroke.thin),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0)
              const Divider(
                height: BvStroke.thin,
                thickness: BvStroke.thin,
                color: BvColors.borderSubtle,
              ),
            _row(type, r),
          ],
        ],
      ),
    );
  }

  Widget _row(BvTypeSet type, BvWritingRow r) {
    final quiet = type.bodyMd.copyWith(color: BvColors.textSecondary);
    final value = Text(
      r.value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: r.empty
          ? quiet
          : type.labelLg.copyWith(color: BvColors.textPrimary),
    );
    return Semantics(
      button: r.onTap != null,
      child: InkWell(
        key: r.key,
        onTap: r.onTap,
        child: _Pulse(
          ask: r.ask,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvWritingRowsSpec.paddingHorizontal,
              vertical: BvWritingRowsSpec.paddingVertical,
            ),
            child: Row(
              spacing: BvWritingRowsSpec.gap,
              children: [
                Text(r.label, style: quiet),
                Expanded(
                  child: r.person == null
                      ? value
                      : Row(
                          spacing: BvWritingRowsSpec.personGap,
                          children: [
                            BvAvatar(
                              name: r.person!,
                              size: BvAvatarSize.xs,
                              tint: r.tint,
                            ),
                            Flexible(child: value),
                          ],
                        ),
                ),
                if (r.onTap != null)
                  const Icon(
                    BvIcons.caretForward,
                    size: BvWritingRowsSpec.caret,
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

/// A row asked for (F56): the action colour flashes on it once for each
/// new [ask].
class _Pulse extends StatefulWidget {
  const _Pulse({required this.ask, required this.child});

  final Object? ask;
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _flash = AnimationController(vsync: this, duration: BvMotion.base);

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    if (widget.ask != null && widget.ask != old.ask) {
      _flash.forward(from: 0).then((_) {
        if (mounted) _flash.reverse();
      });
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _flash,
    builder: (context, child) => ColoredBox(
      color: Color.lerp(
        BvColors.surfaceElevated.withValues(alpha: 0),
        BvColors.surfaceBrandSoft,
        _flash.value,
      )!,
      child: child,
    ),
    child: widget.child,
  );
}
