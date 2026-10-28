import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import 'bv_writing_card.dart' show bvBareField;

/// One row of a [BvPopoverMenu].
class BvMenuItem<T> {
  const BvMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.note,
    this.key,
    this.shortcut,
    this.more = false,
    this.destructive = false,
    this.group,
    this.detail,
    this.onClear,
    this.clearKey,
    this.clearLabel,
  });

  final T value;
  final String label;
  final IconData icon;

  /// A small line under the label, saying what the choice does (review 50
  /// F50: "Each person confirms they received it").
  final String? note;

  /// The row's own key.
  final Key? key;

  /// The line menu (review 98): what to type for this kind ("1.", "[]"),
  /// small and grey at the row's end.
  final String? shortcut;

  /// The line menu: › at the row's end (Turn into opens the kinds).
  final bool more;

  /// The line menu: in the destructive colour (Delete).
  final bool destructive;

  /// The compact card (review 100 Part 4): the small caps label of the
  /// group this row starts or belongs to ("TEXT", "LISTS").
  final String? group;

  /// Its value once set, at the row's end ("Gate 2", "Fri 7:00"), and the
  /// ✕ after it that takes it off ([clearLabel] read out).
  final String? detail;
  final VoidCallback? onClear;
  final Key? clearKey;
  final String? clearLabel;
}

/// The small menus: a leading icon and a label per row. While writing
/// (2527:33433, 2535:34374), [BvPopoverMenu.more] lists things to add and
/// [BvPopoverMenu.picker] is one single choice (what is being posted), its
/// [selected] row in orange with a check. [BvPopoverMenu.screen] is a
/// screen's ⋯ menu (the Space menu, MN1 2566:35755).
class BvPopoverMenu<T> extends StatelessWidget {
  const BvPopoverMenu.more({
    super.key,
    required this.items,
    required this.onSelected,
  }) : selected = null,
       picker = false,
       screen = false,
       wide = false,
       line = false,
       scrolls = false,
       title = null,
       hint = null,
       checked = null,
       back = null,
       onBack = null,
       field = null,
       tiles = true;

  /// [wide]: the kind menu (E6 v14 2598:36413), whose small lines fit on
  /// one line.
  const BvPopoverMenu.picker({
    super.key,
    required this.items,
    required this.onSelected,
    required this.selected,
    this.wide = false,
  }) : picker = true,
       screen = false,
       line = false,
       scrolls = false,
       title = null,
       hint = null,
       checked = null,
       back = null,
       onBack = null,
       field = null,
       tiles = true;

  const BvPopoverMenu.screen({
    super.key,
    required this.items,
    required this.onSelected,
  }) : selected = null,
       picker = false,
       screen = true,
       wide = false,
       line = false,
       scrolls = false,
       title = null,
       hint = null,
       checked = null,
       back = null,
       onBack = null,
       field = null,
       tiles = true;

  /// The card next to a line (review 98): the line menu (NBY2), and the
  /// "/" card (NBY1) with its [title], the [selected] row tinted (Enter
  /// picks it) and its [hint].
  const BvPopoverMenu.line({
    super.key,
    required this.items,
    required this.onSelected,
    this.selected,
    this.title,
    this.hint,
    this.scrolls = false,
    this.checked,
    this.back,
    this.onBack,
    this.field,
    this.tiles = true,
  }) : picker = false,
       screen = false,
       wide = false,
       line = true;

  final List<BvMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final T? selected;
  final bool picker;
  final bool screen;
  final bool wide;
  final bool line;

  /// The line card's small grey words over its rows, and under them.
  final String? title;
  final String? hint;

  /// The "/" card: past [BvLineMenuSpec.rowsShown] rows it scrolls. The
  /// line menu never does: every row is always in sight.
  final bool scrolls;

  /// The compact card (review 100 Part 4): the row ticked as the current
  /// one (the line's kind), and a ‹ [back] row on top of a card's next
  /// level (Turn into ›): the same card, never a second one.
  final T? checked;
  final String? back;
  final VoidCallback? onBack;

  /// A field under the ‹ row (Share's "To": a search, review 100 H14).
  final Widget? field;

  /// Each row's icon on a grey tile (the block list's glyphs, BH8), or
  /// plain (📎 and the Filter, BH7, BH9; review 100 H10).
  final bool tiles;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    if (line) return _line(type);
    return Container(
      width: screen
          ? BvScreenMenuSpec.width
          : wide
          ? BvPopoverMenuSpec.widthKind
          : picker
          ? BvPopoverMenuSpec.widthPicker
          : BvPopoverMenuSpec.widthMore,
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: BvPopoverMenuSpec.paddingVertical,
      ),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvPopoverMenuSpec.radius,
        border: screen
            ? null
            : const Border.fromBorderSide(
                BorderSide(color: BvColors.borderSubtle, width: BvStroke.thin),
              ),
        boxShadow: screen ? BvShadow.screenMenu : BvShadow.menu,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              _row(type, item, picker && item.value == selected),
          ],
        ),
      ),
    );
  }

  Widget _line(BvTypeSet type) {
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    return TextFieldTapRegion(
      child: Container(
        width: BvLineMenuSpec.width,
        padding: const EdgeInsetsDirectional.all(BvLineMenuSpec.padding),
        decoration: const BoxDecoration(
          color: BvColors.surfaceElevated,
          borderRadius: BvLineMenuSpec.radius,
          border: Border.fromBorderSide(
            BorderSide(color: BvColors.borderSubtle, width: BvStroke.thin),
          ),
          boxShadow: BvShadow.lineMenu,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (back case final back?)
                Semantics(
                  button: true,
                  child: InkWell(
                    key: const Key('menu-back'),
                    canRequestFocus: false,
                    borderRadius: BvLineMenuSpec.rowRadius,
                    onTap: onBack,
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: BvLineMenuSpec.rowHeight,
                      ),
                      padding: BvLineMenuSpec.rowPadding,
                      child: Row(
                        spacing: BvLineMenuSpec.rowGap,
                        children: [
                          const Icon(
                            BvIcons.caretBack,
                            size: BvLineMenuSpec.caret,
                            color: BvColors.iconSecondary,
                          ),
                          Expanded(
                            child: Text(
                              back,
                              style: type.labelMd.copyWith(
                                color: BvColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ?field,
              if (title case final title?)
                Padding(
                  padding: BvLineMenuSpec.titlePadding,
                  child: Text(title, style: quiet),
                ),
              if (scrolls && items.length > BvLineMenuSpec.rowsShown)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight:
                        BvLineMenuSpec.rowHeight * BvLineMenuSpec.rowsShown,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _lineRows(type),
                    ),
                  ),
                )
              else
                ..._lineRows(type),
              if (hint case final hint?)
                Padding(
                  padding: BvLineMenuSpec.hintPadding,
                  child: Text(hint, style: quiet),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Every row of the card, each group under its label, a line between
  /// the groups.
  List<Widget> _lineRows(BvTypeSet type) {
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final out = <Widget>[];
    String? group;
    for (final item in items) {
      if (item.group != null && item.group != group) {
        if (group != null) {
          out.add(
            const Divider(
              height: BvLineMenuSpec.groupGap,
              thickness: BvStroke.thin,
              color: BvColors.borderSubtle,
            ),
          );
        }
        group = item.group;
        out.add(
          Padding(
            padding: BvLineMenuSpec.groupPadding,
            child: Text(item.group!, style: quiet),
          ),
        );
      }
      out.add(_lineRow(type, item, item.value == selected));
    }
    return out;
  }

  Widget _lineRow(BvTypeSet type, BvMenuItem<T> item, bool tinted) {
    final ink = item.destructive
        ? BvColors.textDestructive
        : BvColors.textPrimary;
    return Semantics(
      button: true,
      selected: tinted ? true : null,
      child: Material(
        key: item.key,
        color: tinted ? BvColors.surfaceBrandSoft : Colors.transparent,
        borderRadius: BvLineMenuSpec.rowRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          canRequestFocus: false,
          onTap: () => onSelected(item.value),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: BvLineMenuSpec.rowHeight,
            ),
            padding: BvLineMenuSpec.rowPadding,
            child: Row(
              spacing: BvLineMenuSpec.rowGap,
              children: [
                Container(
                  width: BvLineMenuSpec.tile,
                  height: BvLineMenuSpec.tile,
                  alignment: Alignment.center,
                  decoration: !tiles
                      ? null
                      : BoxDecoration(
                          color: item.destructive
                              ? BvColors.surfaceDestructiveSoft
                              : BvColors.surfaceSubtle,
                          borderRadius: BvLineMenuSpec.rowRadius,
                        ),
                  child: Icon(
                    item.icon,
                    size: BvLineMenuSpec.icon,
                    color: item.destructive
                        ? BvColors.textDestructive
                        : BvColors.iconPrimary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.labelMd.copyWith(color: ink),
                      ),
                      // What the row does (Share's "A public post on Home").
                      if (item.note case final note?)
                        Text(
                          note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.metadata.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (item.shortcut case final shortcut?)
                  Text(
                    shortcut,
                    // What is typed reads left to right in Arabic too.
                    textDirection: TextDirection.ltr,
                    style: type.metadata.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
                if (item.detail case final detail?)
                  Flexible(
                    child: Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ),
                if (item.onClear case final clear?)
                  Semantics(
                    button: true,
                    label: item.clearLabel,
                    excludeSemantics: true,
                    child: InkResponse(
                      key: item.clearKey,
                      canRequestFocus: false,
                      onTap: clear,
                      radius: BvLineMenuSpec.clear,
                      child: const Icon(
                        BvIcons.declined,
                        size: BvLineMenuSpec.clear,
                        color: BvColors.iconSecondary,
                      ),
                    ),
                  ),
                if (checked != null && item.value == checked)
                  const Icon(
                    BvIcons.check,
                    key: Key('menu-checked'),
                    size: BvLineMenuSpec.caret,
                    color: BvColors.iconAction,
                  ),
                if (item.more)
                  const Icon(
                    BvIcons.caretForward,
                    size: BvLineMenuSpec.caret,
                    color: BvColors.iconSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BvTypeSet type, BvMenuItem<T> item, bool isSelected) {
    final colour = isSelected ? BvColors.textAction : BvColors.textPrimary;
    return Semantics(
      selected: picker ? isSelected : null,
      inMutuallyExclusiveGroup: picker ? true : null,
      button: true,
      child: InkWell(
        onTap: () => onSelected(item.value),
        child: Container(
          constraints: BoxConstraints(
            minHeight: screen
                ? BvScreenMenuSpec.rowHeight
                : BvPopoverMenuSpec.rowHeight,
          ),
          padding: EdgeInsetsDirectional.only(
            top: item.note == null ? 0 : BvPopoverMenuSpec.noteRowPadding,
            bottom: item.note == null ? 0 : BvPopoverMenuSpec.noteRowPadding,
            start: BvPopoverMenuSpec.rowPaddingStart,
            end: screen
                ? BvScreenMenuSpec.rowPadding
                : picker
                ? BvPopoverMenuSpec.rowPaddingEndPicker
                : BvPopoverMenuSpec.rowPaddingEndMore,
          ),
          child: Row(
            spacing: BvPopoverMenuSpec.rowGap,
            children: [
              Icon(
                item.icon,
                size: BvPopoverMenuSpec.icon,
                color: isSelected ? BvColors.textAction : BvColors.iconPrimary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodyMd.copyWith(color: colour),
                    ),
                    if (item.note case final note?)
                      Text(
                        note,
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  BvIcons.check,
                  size: BvPopoverMenuSpec.check,
                  color: BvColors.textAction,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How a [BvSlipMenu] row reads: Check is green; Send back and Cancel are
/// red.
enum BvSlipMenuTone { plain, positive, destructive }

class BvSlipMenuItem<T> {
  const BvSlipMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.tone = BvSlipMenuTone.plain,
  });

  final T value;
  final String label;
  final IconData icon;
  final BvSlipMenuTone tone;
}

/// The long-press menu on a slip (2530:33626): the label at the start and
/// the icon at the end, a line between rows.
class BvSlipMenu<T> extends StatelessWidget {
  const BvSlipMenu({super.key, required this.items, required this.onSelected});

  final List<BvSlipMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Container(
      width: BvSlipMenuSpec.width,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvSlipMenuSpec.radius,
        boxShadow: BvShadow.popover,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++)
              _row(type, items[i], last: i == items.length - 1),
          ],
        ),
      ),
    );
  }

  Widget _row(BvTypeSet type, BvSlipMenuItem<T> item, {required bool last}) {
    final (text, icon) = switch (item.tone) {
      BvSlipMenuTone.plain => (BvColors.textPrimary, BvColors.iconPrimary),
      BvSlipMenuTone.positive => (BvColors.textPositive, BvColors.textPositive),
      BvSlipMenuTone.destructive => (
        BvColors.textDestructive,
        BvColors.textDestructive,
      ),
    };
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => onSelected(item.value),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvSlipMenuSpec.rowPaddingHorizontal,
            vertical: BvSlipMenuSpec.rowPaddingVertical,
          ),
          decoration: last
              ? null
              : const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: BvColors.borderSubtle,
                      width: BvStroke.thin,
                    ),
                  ),
                ),
          child: Row(
            spacing: BvSlipMenuSpec.rowGap,
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: type.bodyMd.copyWith(color: text),
                ),
              ),
              Icon(item.icon, size: BvSlipMenuSpec.icon, color: icon),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Daybook's dim behind long-press menus and the month drop-down:
/// ink at 38 % over the whole screen. Tapping it closes what is open.
class BvDim extends StatelessWidget {
  const BvDim({super.key, required this.onTap, this.label});

  final VoidCallback onTap;

  /// Read out for the dim ("Close").
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const ColoredBox(
          color: BvColors.overlayDim,
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Lifts [lifted] above the dim at [anchor] (its place on screen, in global
/// coordinates) and shows [popover] under it when there is room, otherwise
/// over it, lined up with its end. The popover closes the route with
/// `Navigator.pop(context, value)`; tapping the dim closes it with null.
///
/// Used for the long-press menu, send-back reasons and give-to.
Future<T?> showBvLifted<T>(
  BuildContext context, {
  required Rect anchor,
  required Widget lifted,
  required WidgetBuilder popover,
}) {
  return Navigator.of(context).push<T>(
    _LiftedRoute<T>(
      anchor: anchor,
      lifted: lifted,
      popover: popover,
      dimLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

/// [context]'s box on screen, for [showBvLifted].
Rect bvGlobalRect(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _LiftedRoute<T> extends PopupRoute<T> {
  _LiftedRoute({
    required this.anchor,
    required this.lifted,
    required this.popover,
    required this.dimLabel,
  });

  final Rect anchor;
  final Widget lifted;
  final WidgetBuilder popover;
  final String dimLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => BvMotion.fast;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final padding = MediaQuery.paddingOf(context);
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: BvMotion.standard),
      child: Stack(
        children: [
          Positioned.fill(
            child: BvDim(
              label: dimLabel,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned.fromRect(
            rect: anchor,
            // The page's text style: the slip's words keep their look.
            child: IgnorePointer(
              child: Material(type: MaterialType.transparency, child: lifted),
            ),
          ),
          Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: _BelowOrAbove(
                anchor: anchor,
                textDirection: Directionality.of(context),
                top: padding.top + BvSlipMenuSpec.screenMargin,
                bottom: padding.bottom + BvSlipMenuSpec.screenMargin,
              ),
              child: Builder(builder: popover),
            ),
          ),
        ],
      ),
    );
  }
}

/// Under the anchor if it fits, else over it; end edges lined up.
class _BelowOrAbove extends SingleChildLayoutDelegate {
  _BelowOrAbove({
    required this.anchor,
    required this.textDirection,
    required this.top,
    required this.bottom,
  });

  final Rect anchor;
  final TextDirection textDirection;
  final double top;
  final double bottom;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final below = anchor.bottom + BvSlipMenuSpec.anchorGap;
    final above = anchor.top - BvSlipMenuSpec.anchorGap - child.height;
    final y = below + child.height <= size.height - bottom
        ? below
        : above >= top
        ? above
        : top;
    final x = textDirection == TextDirection.rtl
        ? anchor.left
        : anchor.right - child.width;
    return Offset(x.clamp(0, size.width - child.width), y);
  }

  @override
  bool shouldRelayout(_BelowOrAbove old) =>
      old.anchor != anchor ||
      old.textDirection != textDirection ||
      old.top != top ||
      old.bottom != bottom;
}

/// One line typed in a popover over the diary (the writing card's
/// Location): the popover box, an icon and a bare field. [onDone] gets
/// the text when the keyboard's done key is pressed.
class BvPopoverField extends StatelessWidget {
  const BvPopoverField({
    super.key,
    required this.icon,
    required this.controller,
    required this.placeholder,
    required this.onDone,
    this.maxLength,
  });

  final IconData icon;
  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String> onDone;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final style = BvType.of(context).bodyMd;
    return Container(
      width: BvPopoverMenuSpec.placeWidth,
      padding: const EdgeInsetsDirectional.all(BvPopoverMenuSpec.placePadding),
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvPopoverMenuSpec.radius,
        border: Border.fromBorderSide(
          BorderSide(color: BvColors.borderSubtle, width: BvStroke.thin),
        ),
        boxShadow: BvShadow.menu,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          spacing: BvPopoverMenuSpec.rowGap,
          children: [
            Icon(
              icon,
              size: BvPopoverMenuSpec.icon,
              color: BvColors.iconPrimary,
            ),
            Expanded(
              child: TextField(
                key: const Key('popover-field'),
                controller: controller,
                autofocus: true,
                maxLength: maxLength,
                textInputAction: TextInputAction.done,
                onSubmitted: onDone,
                style: style.copyWith(color: BvColors.textPrimary),
                cursorColor: BvColors.actionPrimary,
                decoration: bvBareField(
                  hint: placeholder,
                  style: style,
                ).copyWith(counterText: ''),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A screen's ⋯ menu (MN1 2566:35619): the popover under the header's
/// end, over a scrim. The chosen value, or null when closed.
Future<T?> showBvScreenMenu<T>(
  BuildContext context, {
  required Key key,
  required List<BvMenuItem<T>> items,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: BvColors.overlayScrim,
  pageBuilder: (menuContext, _, _) => SafeArea(
    child: Align(
      alignment: AlignmentDirectional.topEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: BvScreenMenuSpec.top,
          end: BvScreenMenuSpec.end,
        ),
        child: BvPopoverMenu<T>.screen(
          key: key,
          items: items,
          onSelected: (v) => Navigator.of(menuContext).pop(v),
        ),
      ),
    ),
  ),
);
