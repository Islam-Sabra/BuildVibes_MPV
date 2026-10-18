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

/// Who is writing, at the top of a post being written on Home (H2
/// 2555:35420): a small face and "You · to everyone".
class BvWritingAuthor {
  const BvWritingAuthor({required this.name, required this.label, this.tint});

  final String name;
  final String label;
  final Color? tint;
}

/// Something being written in place: a work item in the Daybook
/// (2527:33393, AR 2547:35369), or a post on Home (H2 2555:35388, with
/// [author], no title, up to four [photos] and the project tag as
/// [footer]). White paper in a straight dashed orange outline with a small
/// radius. A draft has no torn edge: it hasn't been torn off yet (review
/// 44, C3). It holds no text of its own: the screen gives the controllers
/// and saves the draft.
class BvWritingCard extends StatelessWidget {
  const BvWritingCard({
    super.key,
    this.titleController,
    this.titlePlaceholder = '',
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
    this.author,
    this.photos = const [],
    this.photoHeight = BvWritingCardSpec.coverHeight,
    this.onRemovePhoto,
    this.removePhotoLabel,
    this.footer,
    this.titleMaxLength,
    this.bodyMaxLength,
    this.errorLine,
  });

  /// Null for a post: it has no title, only its text.
  final TextEditingController? titleController;
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

  /// Who is writing, above the text (a post).
  final BvWritingAuthor? author;

  /// The photos, side by side across the card, [photoHeight] high: a work
  /// item's one cover (128), or a post's one to four (110).
  final List<Widget> photos;
  final double photoHeight;

  /// Removes the photo at that index; null while read only.
  final ValueChanged<int>? onRemovePhoto;

  /// Read out for each photo's remove button.
  final String? removePhotoLabel;

  /// Under the photos: a post's project tag.
  final Widget? footer;

  /// What the server takes; typing stops there.
  final int? titleMaxLength;
  final int? bodyMaxLength;

  /// A red line at the foot of the card: the post was refused ("Couldn't
  /// send. Tap to fix", review 46).
  final String? errorLine;

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
                if (author != null) _Author(author: author!),
                if (titleController != null)
                  _field(
                    key: const Key('writing-title'),
                    controller: titleController!,
                    focusNode: titleFocusNode,
                    placeholder: titlePlaceholder,
                    style: type.headingMd,
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
                  // A post has no title: its text takes the focus.
                  autofocus: autofocus && titleController == null,
                  onChanged: onBodyChanged,
                  maxLength: bodyMaxLength,
                ),
                if (photos.isNotEmpty)
                  _PhotoRow(
                    removable: onRemovePhoto != null,
                    height: photoHeight,
                    child: Row(
                      spacing: BvWritingCardSpec.photoGap,
                      children: [
                        for (final (i, photo) in photos.indexed)
                          Expanded(
                            child: _Cover(
                              index: i,
                              onRemove: onRemovePhoto == null
                                  ? null
                                  : () => onRemovePhoto!(i),
                              removeLabel: removePhotoLabel,
                              child: photo,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (footer != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: footer,
                  ),
                if (errorLine != null)
                  Text(
                    errorLine!,
                    key: const Key('writing-card-error'),
                    style: type.labelSm.copyWith(
                      color: BvColors.textDestructive,
                    ),
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

/// The photos' row. Each remove button's touch area reaches past the
/// row's top and end, so the row passes those touches on too.
class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.removable,
    required this.height,
    required this.child,
  });

  final bool removable;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(height: height, child: child);
    if (!removable) return row;
    return BvTapTarget(outset: BvWritingCardSpec.removeTouchOutset, child: row);
  }
}

class _Author extends StatelessWidget {
  const _Author({required this.author});

  final BvWritingAuthor author;

  @override
  Widget build(BuildContext context) => Row(
    spacing: BvSpace.s8,
    children: [
      ExcludeSemantics(
        child: BvAvatar(
          name: author.name,
          size: BvAvatarSize.xs,
          tint: author.tint,
        ),
      ),
      Flexible(
        child: Text(
          author.label,
          key: const Key('writing-author'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BvType.of(
            context,
          ).labelSm.copyWith(color: BvColors.textPrimary),
        ),
      ),
    ],
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
                // A long one ("الأحد 18 أكتوبر، 2:00 ظهرًا") wraps
                // within the line instead of running off it.
                Flexible(child: Text(p.label, style: style)),
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
    required this.index,
    required this.child,
    required this.onRemove,
    required this.removeLabel,
  });

  final int index;
  final Widget child;
  final VoidCallback? onRemove;
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    final cover = SizedBox.expand(
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
                  key: Key('writing-photo-remove-target-$index'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: SizedBox.square(
                    dimension: BvSize.touchMin,
                    child: Center(
                      child: Container(
                        key: Key('writing-photo-remove-$index'),
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
