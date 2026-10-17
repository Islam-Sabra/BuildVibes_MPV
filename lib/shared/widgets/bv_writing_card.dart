import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import 'bv_avatar.dart';
import 'bv_tap_target.dart';

/// A field without a box of its own, for text typed on a card, a note or a
/// search that draws its own fill. Overrides the theme's bordered fields.
InputDecoration bvBareField({required String hint, required TextStyle style}) =>
    InputDecoration(
      isCollapsed: true,
      filled: false,
      contentPadding: EdgeInsets.zero,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      hintText: hint,
      hintStyle: style.copyWith(color: BvColors.textSecondary),
    );

/// One item on the writing card's properties line: the owner (a small
/// avatar and the name), or an icon and text (due date, place).
class BvWritingProperty {
  const BvWritingProperty.person({
    required this.label,
    this.tint,
    this.image,
    this.onTap,
  }) : icon = null;

  const BvWritingProperty.icon({
    required this.icon,
    required this.label,
    this.onTap,
  }) : tint = null,
       image = null;

  final String label;
  final IconData? icon;
  final Color? tint;
  final ImageProvider? image;
  final VoidCallback? onTap;
}

/// The work item being written in place, in the Daybook (2527:33393,
/// AR 2547:35369): white paper in a straight dashed orange outline with a
/// small radius. A draft has no torn edge: it hasn't been torn off yet
/// (review 44, C3). It holds no text of its own: the screen gives the
/// controllers and saves the draft.
class BvWritingCard extends StatelessWidget {
  const BvWritingCard({
    super.key,
    required this.titleController,
    required this.titlePlaceholder,
    required this.bodyController,
    required this.bodyPlaceholder,
    this.titleFocusNode,
    this.bodyFocusNode,
    this.autofocus = false,
    this.onTitleChanged,
    this.onBodyChanged,
    this.draftLabel,
    this.kindLabel,
    this.onKindTap,
    this.properties = const [],
    this.cover,
    this.onRemoveCover,
    this.removeCoverLabel,
    this.titleMaxLength,
    this.bodyMaxLength,
  });

  final TextEditingController titleController;
  final String titlePlaceholder;
  final TextEditingController bodyController;
  final String bodyPlaceholder;
  final FocusNode? titleFocusNode;
  final FocusNode? bodyFocusNode;

  /// Focus the title when the card appears.
  final bool autofocus;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<String>? onBodyChanged;

  /// "Draft": shown when the card was reopened with unsaved text.
  final String? draftLabel;

  /// What is being posted ("Work item"); tapping opens the kind menu. With
  /// nothing to choose ([onKindTap] null) the chip has no drop-down caret.
  final String? kindLabel;
  final VoidCallback? onKindTap;

  /// The quiet line under the title (owner, due, place). Hidden when empty.
  final List<BvWritingProperty> properties;

  /// The cover photo, shown 128 high across the card.
  final Widget? cover;
  final VoidCallback? onRemoveCover;

  /// Read out for the cover's remove button.
  final String? removeCoverLabel;

  /// What the server takes; typing stops there.
  final int? titleMaxLength;
  final int? bodyMaxLength;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return CustomPaint(
      key: const Key('writing-card-outline'),
      foregroundPainter: const _DashedOutline(),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: BvColors.surfaceElevated,
          borderRadius: BvWritingCardSpec.radius,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            BvWritingCardSpec.paddingSide,
            BvWritingCardSpec.paddingTop,
            BvWritingCardSpec.paddingSide,
            BvWritingCardSpec.paddingBottom,
          ),
          // The cover's remove button reaches its 48 touch area into the
          // side padding.
          child: BvTapTarget(
            outset: const EdgeInsetsDirectional.symmetric(
              horizontal: BvWritingCardSpec.paddingSide,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvWritingCardSpec.gap,
              children: [
                if (draftLabel != null) _DraftMarker(label: draftLabel!),
                if (kindLabel != null)
                  _KindChip(label: kindLabel!, onTap: onKindTap),
                _field(
                  key: const Key('writing-title'),
                  controller: titleController,
                  focusNode: titleFocusNode,
                  placeholder: titlePlaceholder,
                  style: type.headingLg,
                  autofocus: autofocus,
                  onChanged: onTitleChanged,
                  maxLength: titleMaxLength,
                ),
                if (properties.isNotEmpty) _Properties(items: properties),
                _field(
                  key: const Key('writing-body'),
                  controller: bodyController,
                  focusNode: bodyFocusNode,
                  placeholder: bodyPlaceholder,
                  style: type.bodyLg,
                  onChanged: onBodyChanged,
                  maxLength: bodyMaxLength,
                ),
                if (cover != null)
                  _Cover(
                    onRemove: onRemoveCover,
                    removeLabel: removeCoverLabel,
                    child: cover!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required FocusNode? focusNode,
    required String placeholder,
    required TextStyle style,
    bool autofocus = false,
    ValueChanged<String>? onChanged,
    int? maxLength,
  }) => TextField(
    key: key,
    controller: controller,
    inputFormatters: [
      if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
    ],
    focusNode: focusNode,
    autofocus: autofocus,
    onChanged: onChanged,
    minLines: 1,
    maxLines: null,
    keyboardType: TextInputType.multiline,
    textCapitalization: TextCapitalization.sentences,
    style: style.copyWith(color: BvColors.textPrimary),
    cursorColor: BvColors.actionPrimary,
    cursorWidth: BvWritingCardSpec.cursorWidth,
    decoration: bvBareField(hint: placeholder, style: style),
  );
}

class _DraftMarker extends StatelessWidget {
  const _DraftMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: BvWritingCardSpec.draftGap,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: BvColors.actionPrimary,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(dimension: BvWritingCardSpec.draftDot),
        ),
        Text(
          label,
          style: BvType.of(
            context,
          ).labelSm.copyWith(color: BvColors.textAction),
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final choosable = onTap != null;
    final chip = Container(
      key: const Key('writing-kind-chip'),
      height: BvWritingCardSpec.chipHeight,
      padding: EdgeInsetsDirectional.only(
        start: BvWritingCardSpec.chipPaddingStart,
        end: choosable
            ? BvWritingCardSpec.chipPaddingEnd
            : BvWritingCardSpec.chipPaddingStart,
      ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvRadius.roundAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BvWritingCardSpec.chipGap,
        children: [
          Text(
            label,
            style: BvType.of(
              context,
            ).labelSm.copyWith(color: BvColors.textPrimary),
          ),
          if (choosable)
            const Icon(
              BvIcons.caretDown,
              size: BvWritingCardSpec.chipCaret,
              color: BvColors.iconPrimary,
            ),
        ],
      ),
    );
    if (!choosable) {
      return Align(alignment: AlignmentDirectional.centerStart, child: chip);
    }
    return BvTapTarget(
      outset: BvWritingCardSpec.chipTouchOutset,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: chip,
          ),
        ),
      ),
    );
  }
}

class _Properties extends StatelessWidget {
  const _Properties({required this.items});

  final List<BvWritingProperty> items;

  @override
  Widget build(BuildContext context) {
    final style = BvType.of(
      context,
    ).labelSm.copyWith(color: BvColors.textPrimary);
    final line = Wrap(
      spacing: BvWritingCardSpec.propertyGap,
      runSpacing: BvWritingCardSpec.propertyRunGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in items)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: p.onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: BvWritingCardSpec.propertyItemGap,
              children: [
                if (p.icon != null)
                  Icon(
                    p.icon,
                    size: BvWritingCardSpec.propertyIcon,
                    color: BvColors.iconSecondary,
                  )
                else
                  ExcludeSemantics(
                    child: BvAvatar(
                      name: p.label,
                      size: BvAvatarSize.xxs,
                      tint: p.tint,
                      image: p.image,
                    ),
                  ),
                Text(p.label, style: style),
              ],
            ),
          ),
      ],
    );
    if (items.every((p) => p.onTap == null)) return line;
    return BvTapTarget(
      outset: BvWritingCardSpec.propertyTouchOutset,
      child: line,
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.child,
    required this.onRemove,
    required this.removeLabel,
  });

  final Widget child;
  final VoidCallback? onRemove;
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    final cover = SizedBox(
      height: BvWritingCardSpec.coverHeight,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          ClipRRect(borderRadius: BvWritingCardSpec.coverRadius, child: child),
          if (onRemove != null)
            // A 48 square around the 26 button; it reaches past the cover's
            // top end corner.
            PositionedDirectional(
              top: BvWritingCardSpec.removeTop - BvWritingCardSpec.removeInset,
              end: BvWritingCardSpec.removeEnd - BvWritingCardSpec.removeInset,
              child: Semantics(
                button: true,
                label: removeLabel,
                child: GestureDetector(
                  key: const Key('writing-cover-remove-target'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: SizedBox.square(
                    dimension: BvSize.touchMin,
                    child: Center(
                      child: Container(
                        key: const Key('writing-cover-remove'),
                        width: BvWritingCardSpec.removeSize,
                        height: BvWritingCardSpec.removeSize,
                        decoration: BoxDecoration(
                          color: BvColors.surfaceElevated.withValues(
                            alpha: BvWritingCardSpec.removeOpacity,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          BvIcons.close,
                          size: BvWritingCardSpec.removeIcon,
                          color: BvColors.iconPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (onRemove == null) return cover;
    // The part of the square outside the cover still reaches the button.
    return BvTapTarget(
      outset: BvWritingCardSpec.removeTouchOutset,
      child: cover,
    );
  }
}

/// The card's outline: a straight dashed rectangle with the small radius.
class _DashedOutline extends CustomPainter {
  const _DashedOutline();

  @override
  void paint(Canvas canvas, Size size) {
    // Half the stroke inside, so the dashes stay on the paper.
    const inset = BvWritingCardSpec.border / 2;
    final outline = BvWritingCardSpec.radius
        .toRRect(Offset.zero & size)
        .deflate(inset);
    final paint = Paint()
      ..color = BvColors.actionPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = BvWritingCardSpec.border;
    final dashes = Path();
    for (final metric in (Path()..addRRect(outline)).computeMetrics()) {
      for (
        var d = 0.0;
        d < metric.length;
        d += BvWritingCardSpec.dashOn + BvWritingCardSpec.dashOff
      ) {
        dashes.addPath(
          metric.extractPath(d, d + BvWritingCardSpec.dashOn),
          Offset.zero,
        );
      }
    }
    canvas.drawPath(dashes, paint);
  }

  @override
  bool shouldRepaint(_DashedOutline old) => false;
}
