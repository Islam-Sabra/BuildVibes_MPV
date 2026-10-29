import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import 'bv_avatar.dart';
import 'bv_highlight.dart';
import 'bv_marked_text.dart';
import 'bv_photo_preparing.dart';
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
      // A Draft's fields are off (read only): no box there either (F106).
      disabledBorder: InputBorder.none,
      hintText: hint,
      hintStyle: style.copyWith(color: BvColors.textSecondary),
    );

/// One item on the writing card's properties line: the owner (a small
/// avatar and the name), or an icon and text (due date, place).
class BvWritingProperty {
  const BvWritingProperty.person({
    required this.label,
    this.name,
    this.marks = const [],
    this.tint,
    this.image,
    this.onTap,
    this.caret = false,
    this.key,
  }) : icon = null,
       onRemove = null,
       removeLabel = null,
       empty = false,
       ask = null;

  const BvWritingProperty.icon({
    required this.icon,
    required this.label,
    this.onTap,
    this.onRemove,
    this.removeLabel,
    this.caret = false,
    this.key,
    this.empty = false,
    this.ask,
  }) : tint = null,
       image = null,
       name = null,
       marks = const [];

  final String label;

  /// The person's name for the avatar, when [label] says more ("For Islam
  /// Ahmed", F66).
  final String? name;

  /// With marks, [label] reads as a card's facts line (F34): in grey, each
  /// mark's part standing out.
  final List<BvMark> marks;

  /// On the row, for finding it.
  final Key? key;

  /// Still to choose ("For: Choose"): in grey (F56).
  final bool empty;

  /// Each new value pulses the row once, in the action colour: Post was
  /// tapped while it was still to choose (F56).
  final Object? ask;
  final IconData? icon;
  final Color? tint;
  final ImageProvider? image;
  final VoidCallback? onTap;

  /// A small caret after the label: a tap chooses again (F56, F66). The
  /// icon mirrors in right to left; a string never carries one (review 79
  /// A2).
  final bool caret;

  /// A small × after the label that takes it off (a file on the post).
  final VoidCallback? onRemove;
  final String? removeLabel;
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
    this.padding = BvWritingCardSpec.padding,
    this.gap = BvWritingCardSpec.gap,
    this.properties = const [],
    this.author,
    this.photos = const [],
    this.photoHeight = BvWritingCardSpec.coverHeight,
    this.onRemovePhoto,
    this.removePhotoLabel,
    this.preparing = 0,
    this.preparingLabel = '',
    this.footer,
    this.titleMaxLength,
    this.bodyMaxLength,
    this.errorLine,
    this.extra,
    this.showBody = true,
    this.kinds,
    this.rows,
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

  /// Inside the dashed outline, and between the card's parts: the Daybook
  /// card's by default; the notebook's slip is tighter (F106).
  final EdgeInsetsDirectional padding;
  final double gap;

  /// The quiet line under the title (owner, due, place). Hidden when empty.
  final List<BvWritingProperty> properties;

  /// Who is writing, above the text (a post).
  final BvWritingAuthor? author;

  /// The photos, side by side across the card, [photoHeight] high: a work
  /// item's cover (128), or a post's one to four (110). More than four (a
  /// Daybook post takes up to ten from the gallery, K4) scroll sideways as
  /// squares.
  final List<Widget> photos;
  final double photoHeight;

  /// Removes the photo at that index; null while read only.
  final ValueChanged<int>? onRemovePhoto;

  /// Read out for each photo's remove button.
  final String? removePhotoLabel;

  /// Photos still being made safe to leave the phone: as many
  /// "Preparing…" slots ([preparingLabel]) after [photos], with no remove
  /// button (review 74 H2).
  final int preparing;
  final String preparingLabel;

  /// Under the photos: a post's project tag.
  final Widget? footer;

  /// What the server takes; typing stops there.
  final int? titleMaxLength;
  final int? bodyMaxLength;

  /// A red line at the foot of the card: the post was refused ("Couldn't
  /// send. Tap to fix", review 46).
  final String? errorLine;

  /// What the kind of post adds under the text: a checklist's points, a
  /// file post's file.
  final Widget? extra;

  /// The words box under the title; a kind with its own sections (a daily
  /// report) draws them in [extra] instead.
  final bool showBody;

  /// Review 105 SP2: the kinds as one choice at the top, in place of the
  /// kind chip ([BvKindChips]).
  final Widget? kinds;

  /// Review 105 SP2: For · Place · Due · Team under the words
  /// ([BvWritingRows]).
  final Widget? rows;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final slots = [
      for (final (i, photo) in photos.indexed) _cover(i, photo),
      for (var i = 0; i < preparing; i++)
        ClipRRect(
          key: Key('writing-photo-preparing-$i'),
          borderRadius: BvWritingCardSpec.coverRadius,
          child: BvPhotoPreparing(label: preparingLabel),
        ),
    ];
    return CustomPaint(
      key: const Key('writing-card-outline'),
      foregroundPainter: const _DashedOutline(),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: BvColors.surfaceElevated,
          borderRadius: BvWritingCardSpec.radius,
        ),
        child: Padding(
          padding: padding,
          // The cover's remove button reaches its 48 touch area into the
          // side padding.
          child: BvTapTarget(
            outset: EdgeInsetsDirectional.only(
              start: padding.start,
              end: padding.end,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: [
                if (draftLabel != null) _DraftMarker(label: draftLabel!),
                if (kinds != null)
                  kinds!
                else if (kindLabel != null)
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
                if (showBody)
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
                ?extra,
                if (slots.isNotEmpty)
                  _PhotoRow(
                    removable: onRemovePhoto != null,
                    height: photoHeight,
                    child: slots.length > BvWritingCardSpec.photosSideBySide
                        ? ListView(
                            key: const Key('writing-photos-scroll'),
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final (i, slot) in slots.indexed)
                                Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    end: i == slots.length - 1
                                        ? 0
                                        : BvWritingCardSpec.photoGap,
                                  ),
                                  child: SizedBox.square(
                                    dimension: photoHeight,
                                    child: slot,
                                  ),
                                ),
                            ],
                          )
                        : Row(
                            spacing: BvWritingCardSpec.photoGap,
                            children: [
                              for (final slot in slots) Expanded(child: slot),
                            ],
                          ),
                  ),
                ?rows,
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

  Widget _cover(int i, Widget photo) => _Cover(
    index: i,
    onRemove: onRemovePhoto == null ? null : () => onRemovePhoto!(i),
    removeLabel: removePhotoLabel,
    child: photo,
  );

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
    final type = BvType.of(context);
    final style = type.labelSm.copyWith(color: BvColors.textPrimary);
    // A facts line at the small size: grey, its marks standing out.
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final line = Wrap(
      spacing: BvWritingCardSpec.propertyGap,
      runSpacing: BvWritingCardSpec.propertyRunGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in items)
          _ask(
            p,
            GestureDetector(
              key: p.key,
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
                        name: p.name ?? p.label,
                        size: BvAvatarSize.xxs,
                        tint: p.tint,
                        image: p.image,
                      ),
                    ),
                  // A long one ("الأحد 18 أكتوبر، 2:00 ظهرًا") wraps
                  // within the line instead of running off it.
                  Flexible(
                    child: p.marks.isNotEmpty
                        ? Text.rich(
                            TextSpan(
                              children: bvMarkedSpans(p.label, quiet, p.marks),
                            ),
                          )
                        : Text(
                            p.label,
                            style: p.ask != null
                                ? style.copyWith(color: BvColors.textAction)
                                : p.empty
                                ? style.copyWith(color: BvColors.textSecondary)
                                : style,
                          ),
                  ),
                  if (p.caret)
                    const Icon(
                      BvIcons.caretForward,
                      size: BvWritingCardSpec.propertyCaret,
                      color: BvColors.iconSecondary,
                    ),
                  if (p.onRemove != null)
                    Semantics(
                      button: true,
                      label: p.removeLabel,
                      child: GestureDetector(
                        key: const Key('writing-property-remove'),
                        behavior: HitTestBehavior.opaque,
                        onTap: p.onRemove,
                        child: const Icon(
                          BvIcons.close,
                          size: BvWritingCardSpec.propertyIcon,
                          color: BvColors.iconSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
    if (items.every((p) => p.onTap == null && p.onRemove == null)) {
      return line;
    }
    return BvTapTarget(
      outset: BvWritingCardSpec.propertyTouchOutset,
      child: line,
    );
  }
}

/// [child], pulsed once for each new [BvWritingProperty.ask].
Widget _ask(BvWritingProperty p, Widget child) =>
    p.ask == null ? child : BvHighlight(flash: p.ask, child: child);

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
