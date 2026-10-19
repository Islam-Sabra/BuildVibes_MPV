import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_paper_specs.dart';
import '../../core/l10n/bv_time.dart';
import 'bv_avatar.dart';
import 'bv_clock_text.dart';
import 'bv_paper_clip.dart';
import 'bv_tap_target.dart';
import 'bv_torn_edge.dart';

/// Spec §2: the Daybook's paper slip. White paper with a torn top edge and
/// the slip shadow; its [children] stack with a 10 gap (compose them from
/// [BvSlipHeader], [BvSlipTitle], [BvSlipFacts], [BvSlipLate],
/// [BvSlipChips], [BvSlipQuote], [BvSlipPhoto], [BvSlipNote], [BvSlipPill],
/// [BvSlipQuiet] and [BvSlipError]).
///
/// [stamp] (a [BvInkStamp]) sits at the top end corner; [clip] puts the
/// paper clip there, sticking out above the tear, when the slip needs you.
/// Both mirror in right to left. A [cancelled] slip fades; a [lifted] one
/// (under the long-press menu) casts a deeper shadow.
///
/// [menu] (a [BvSlipCornerMenu]) is the ⋯ at the top end corner, level with the
/// first line, its 48 touch area inside the paper (review 50 F19). Leave
/// [BvSlipCornerMenu.reserve] free at the end of the first child.
class BvSlip extends StatelessWidget {
  const BvSlip({
    super.key,
    required this.children,
    this.tear = 0,
    this.stamp,
    this.clip = false,
    this.cancelled = false,
    this.lifted = false,
    this.menu,
    this.menuLine = BvSlipSpec.firstLine,
    this.paddingTop = BvSlipSpec.paddingTop,
    this.paddingBottom = BvSlipSpec.paddingBottom,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  final List<Widget> children;

  /// The tear pattern ([BvSlipBorder.variant]); neighbouring slips differ.
  final int tear;
  final Widget? stamp;
  final bool clip;
  final bool cancelled;
  final bool lifted;
  final Widget? menu;

  /// The height of the first line the ⋯ centres on: 16 for a name over a
  /// headline, the avatar's when the name sits alone beside it.
  final double menuLine;

  /// Below the tear and at the bottom: a post card (H1 v4) is 14 and 6,
  /// its actions' row making up the rest of their 48 touch area.
  final double paddingTop;
  final double paddingBottom;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final border = BvSlipBorder(variant: tear);
    Widget slip = Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          key: const Key('slip-paper'),
          decoration: ShapeDecoration(
            color: BvColors.surfaceElevated,
            shape: border,
            shadows: lifted ? BvShadow.slipLifted : BvShadow.slip,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              top: border.edgeHeight + paddingTop,
              bottom: paddingBottom,
              start: BvSlipSpec.paddingSide,
              end: BvSlipSpec.paddingSide,
            ),
            // A small control at the bottom (Sign as done) reaches its 48
            // touch area into the bottom padding.
            child: BvTapTarget(
              outset: EdgeInsetsDirectional.only(bottom: paddingBottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BvSlipSpec.gap,
                children: children,
              ),
            ),
          ),
        ),
        if (stamp != null)
          PositionedDirectional(
            top:
                border.edgeHeight +
                (cancelled
                    ? BvSlipSpec.stampTopCancelled
                    : BvSlipSpec.stampTop),
            // Beside the paper clip when both show, never under it.
            end: clip ? BvSlipSpec.stampEndWithClip : BvSlipSpec.stampEnd,
            child: stamp!,
          ),
        if (clip)
          PositionedDirectional(
            top: border.edgeHeight + BvSlipSpec.clipTop,
            end: BvSlipSpec.clipEnd,
            child: const BvPaperClip(),
          ),
        if (menu != null)
          PositionedDirectional(
            top: border.edgeHeight + BvSlipSpec.menuTopFor(menuLine),
            end: 0,
            child: menu!,
          ),
      ],
    );
    if (cancelled) {
      slip = Opacity(
        key: const Key('slip-cancelled'),
        opacity: BvSlipSpec.cancelledOpacity,
        child: slip,
      );
    }
    if (onTap == null && onDoubleTap == null && onLongPress == null) {
      return slip;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: slip,
    );
  }
}

/// The ⋯ on a slip ([BvSlip.menu]): an 18 icon at the paper's top end
/// corner, centred on the first line, in a 48 × 48 touch area.
class BvSlipCornerMenu extends StatelessWidget {
  const BvSlipCornerMenu({super.key, required this.label, required this.onTap});

  /// Room the first line leaves at its end for the icon.
  static const reserve = BvSlipSpec.menuIcon + BvSlipSpec.menuGap;

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkResponse(
      radius: BvSize.touchMin / 2,
      onTap: onTap,
      child: const SizedBox.square(
        dimension: BvSize.touchMin,
        child: Padding(
          padding: EdgeInsetsDirectional.only(end: BvSlipSpec.paddingSide),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Icon(
              BvIcons.more,
              size: BvSlipSpec.menuIcon,
              color: BvColors.iconPrimary,
            ),
          ),
        ),
      ),
    ),
  );
}

/// §2a, v13 (2581:35658): avatar 24 in the person's tint, the name, the
/// work item's [ref] ("· KCT-014") and, at the end, the [time] of the
/// latest activity (two lines in Arabic on a 12-hour phone).
class BvSlipHeader extends StatelessWidget {
  const BvSlipHeader({
    super.key,
    required this.name,
    this.label,
    this.ref,
    this.time,
    this.tint,
    this.image,
  });

  /// The person's name; the avatar's initials come from it.
  final String name;

  /// Shown instead of [name] ("You" on your own posts); the avatar keeps
  /// the person's own initials.
  final String? label;
  final String? ref;

  /// From [BvTime.parts].
  final BvClockParts? time;

  /// [BvAvatarTints.forId] of the person.
  final Color? tint;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    // 24 high in Latin; Arabic's main line (26) makes it as tall as the line.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BvSlipSpec.headerHeight),
      child: Row(
        spacing: BvSlipSpec.headerGap,
        children: [
          BvAvatar(name: name, size: BvAvatarSize.xs, tint: tint, image: image),
          // The name gives way first; the ref is short.
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => Row(
                spacing: BvSlipSpec.headerGap,
                children: [
                  Flexible(
                    child: Text(
                      label ?? name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.labelMd.copyWith(color: BvColors.textPrimary),
                    ),
                  ),
                  // Never wider than the room left, even with large text.
                  if (ref != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.max(
                          0,
                          box.maxWidth - BvSlipSpec.headerGap,
                        ),
                      ),
                      child: Text(
                        ref!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: quiet,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (time != null) BvClockText(time!, style: quiet),
        ],
      ),
    );
  }
}

/// §2b: the work item's title; struck through when [cancelled].
class BvSlipTitle extends StatelessWidget {
  const BvSlipTitle(this.text, {super.key, this.cancelled = false});

  final String text;
  final bool cancelled;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: BvType.of(context).titleLg.copyWith(
      color: BvColors.textPrimary,
      decoration: cancelled ? TextDecoration.lineThrough : null,
      decorationColor: BvColors.textPrimary,
    ),
  );
}

/// §2c and §2d, v13 (2581:35669): one of the card's facts, a grey line
/// after its icon ("For Omar Haddad · by today 2 pm", the place).
class BvSlipFact extends StatelessWidget {
  const BvSlipFact({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = BvType.of(
      context,
    ).bodyMd.copyWith(color: BvColors.textSecondary);
    // The icon centres on the first line.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BvSlipSpec.factGap,
      children: [
        SizedBox(
          height: style.fontSize! * style.height!,
          child: Icon(
            icon,
            size: BvSlipSpec.factIconSize,
            color: BvColors.iconSecondary,
          ),
        ),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// The card's facts, 4 apart.
class BvSlipFacts extends StatelessWidget {
  const BvSlipFacts({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: BvSlipSpec.factsGap,
    children: children,
  );
}

/// L1: an open item past its due ("Late by 1 day"), a calendar and the
/// words in red.
class BvSlipLate extends StatelessWidget {
  const BvSlipLate(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    spacing: BvSlipSpec.lateGap,
    children: [
      const Icon(
        BvIcons.month,
        size: BvSlipSpec.lateIconSize,
        color: BvColors.textDestructive,
      ),
      Flexible(
        child: Text(
          text,
          style: BvType.of(
            context,
          ).labelSm.copyWith(color: BvColors.textDestructive),
        ),
      ),
    ],
  );
}

/// A slip's line in red when something went wrong ("Couldn't send. Tap
/// to fix").
class BvSlipError extends StatelessWidget {
  const BvSlipError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: BvType.of(context).labelSm.copyWith(color: BvColors.textDestructive),
  );
}

/// §2e: a row of [BvSlipChip]s; it wraps when they don't fit.
class BvSlipChips extends StatelessWidget {
  const BvSlipChips({super.key, required this.children});

  final List<Widget> children;

  // The row's touch area is 48 high, so a tappable chip's reaches past
  // the row into the gaps.
  @override
  Widget build(BuildContext context) => BvTapTarget(
    child: Wrap(
      spacing: BvSlipSpec.chipRowGap,
      runSpacing: BvSlipSpec.chipRowGap,
      children: children,
    ),
  );
}

/// §2e: an attachment on a slip: a Library file ("M-201 Rev C") or a
/// checklist ("2 points").
class BvSlipChip extends StatelessWidget {
  const BvSlipChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      height: BvSlipSpec.chipHeight,
      padding: const EdgeInsetsDirectional.only(
        start: BvSlipSpec.chipPaddingStart,
        end: BvSlipSpec.chipPaddingEnd,
        top: BvSlipSpec.chipPaddingVertical,
        bottom: BvSlipSpec.chipPaddingVertical,
      ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvSlipSpec.chipRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BvSlipSpec.chipGap,
        children: [
          Icon(
            icon,
            size: BvSlipSpec.chipIconSize,
            color: BvColors.iconPrimary,
          ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BvType.of(
                context,
              ).labelSm.copyWith(color: BvColors.textPrimary),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return BvTapTarget(
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: chip,
        ),
      ),
    );
  }
}

/// §2f: a proof quoting its work item: an orange bar and one line.
class BvSlipQuote extends StatelessWidget {
  const BvSlipQuote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    spacing: BvSlipSpec.quoteGap,
    children: [
      const SizedBox(
        key: Key('slip-quote-bar'),
        width: BvSlipSpec.quoteBarWidth,
        height: BvSlipSpec.quoteBarHeight,
        child: ColoredBox(color: BvColors.actionPrimary),
      ),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BvType.of(
            context,
          ).bodySm.copyWith(color: BvColors.textSecondary),
        ),
      ),
    ],
  );
}

/// §2g: a full-width photo, rounded 8, cropped to [height]. A large
/// [stamp] (DONE, CHECKED) sits on it near the top start. Double-tap
/// checks a proof.
class BvSlipPhoto extends StatelessWidget {
  const BvSlipPhoto({
    super.key,
    required this.height,
    this.image,
    this.stamp,
    this.onDoubleTap,
  });

  /// [BvSlipSpec.photoHeightProof] on a proof.
  final double height;

  /// Null while loading: the subtle surface shows.
  final ImageProvider? image;
  final Widget? stamp;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    Widget photo = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          key: const Key('slip-photo'),
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: BvColors.surfaceSubtle,
            borderRadius: BvSlipSpec.photoRadius,
            image: image == null
                ? null
                : DecorationImage(image: image!, fit: BoxFit.cover),
          ),
        ),
        if (stamp != null)
          PositionedDirectional(
            top: BvSlipSpec.photoStampTop,
            start: BvSlipSpec.photoStampStart,
            child: stamp!,
          ),
      ],
    );
    if (onDoubleTap != null) {
      photo = GestureDetector(onDoubleTap: onDoubleTap, child: photo);
    }
    return photo;
  }
}

/// §2h: the note under a proof photo.
class BvSlipNote extends StatelessWidget {
  const BvSlipNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: BvType.of(context).bodyMd.copyWith(color: BvColors.textPrimary),
  );
}

/// A quiet small line on a slip ("Waiting to send").
class BvSlipQuiet extends StatelessWidget {
  const BvSlipQuiet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: BvType.of(context).metadata.copyWith(color: BvColors.textSecondary),
  );
}

/// §2i and §2j (§20): the brand-soft round pill on a slip. [BvSlipPill.hint]
/// tells what to do ("Double-tap the photo to check it");
/// [BvSlipPill.action] does it ("Sign as done", with a camera). Both hug
/// their label at the start of the slip.
class BvSlipPill extends StatelessWidget {
  const BvSlipPill.hint({super.key, required this.label})
    : icon = null,
      onTap = null;

  const BvSlipPill.action({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final action = icon != null;
    final pill = Container(
      padding: action
          ? const EdgeInsetsDirectional.only(
              start: BvSlipSpec.actionPaddingStart,
              end: BvSlipSpec.actionPaddingEnd,
              top: BvSlipSpec.actionPaddingVertical,
              bottom: BvSlipSpec.actionPaddingVertical,
            )
          : const EdgeInsetsDirectional.symmetric(
              horizontal: BvSlipSpec.hintPaddingHorizontal,
              vertical: BvSlipSpec.hintPaddingVertical,
            ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceBrandSoft,
        borderRadius: BvRadius.roundAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BvSlipSpec.actionGap,
        children: [
          if (action)
            Icon(
              icon,
              size: BvSlipSpec.actionIconSize,
              color: BvColors.textAction,
            ),
          Flexible(
            child: Text(
              label,
              style: (action ? type.labelMd : type.labelSm).copyWith(
                color: BvColors.textAction,
              ),
            ),
          ),
        ],
      ),
    );
    if (!action) {
      return Align(alignment: AlignmentDirectional.centerStart, child: pill);
    }
    // Under 48 high: the touch area reaches into the gap above and the
    // slip's padding below.
    return BvTapTarget(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          button: true,
          child: GestureDetector(
            key: const Key('slip-pill-action'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: pill,
          ),
        ),
      ),
    );
  }
}
