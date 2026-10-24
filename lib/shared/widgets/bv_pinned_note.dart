import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';

/// A pinned announcement under the masthead (K1 v13 2594:36070): on the
/// brand-soft surface, the pin, who wrote it and for whom ("· to
/// everyone") and when, the words in bold, until when on the facts line
/// under them (review 50 F85: "Until Friday 23 Oct · 2:00 pm", at the main
/// size), and a row at the foot with the author's faces ([leading]) and
/// the reader's one action ([action], Got it).
class BvPinnedNote extends StatelessWidget {
  const BvPinnedNote({
    super.key,
    required this.author,
    required this.audience,
    required this.time,
    required this.until,
    this.untilToday = false,
    required this.title,
    this.body,
    this.quote,
    this.leading,
    this.action,
    this.onTap,
    this.onLongPress,
  });

  final String author;

  /// "· to everyone", "· to MEP".
  final String audience;

  /// When it was posted, at the header's end ("8:38").
  final String time;

  /// "Until Friday 23 Oct · 2:00 pm".
  final String until;

  /// Its last day is today: [until] in ink, not grey.
  final bool untilToday;
  final String title;
  final String? body;

  /// The message it was made from (F83), under the words.
  final Widget? quote;
  final Widget? leading;
  final Widget? action;

  /// Folds it back to its slim line, when it can fold.
  final VoidCallback? onTap;

  /// The same long-press menu as a card's (review 50 F44).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final facts = Row(
      key: const Key('pinned-until'),
      spacing: BvPinnedSpec.headerGap,
      children: [
        const Icon(
          BvIcons.pin,
          size: BvPinnedSpec.pin,
          color: BvColors.iconSecondary,
        ),
        Expanded(
          child: Text(
            until,
            style: type.bodyMd.copyWith(
              color: untilToday ? BvColors.textPrimary : BvColors.textSecondary,
            ),
          ),
        ),
      ],
    );
    final note = Container(
      key: const Key('pinned-note'),
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvPinnedSpec.paddingHorizontal,
        vertical: BvPinnedSpec.paddingVertical,
      ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceBrandSoft,
        borderRadius: BvPinnedSpec.radius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvPinnedSpec.gap,
        children: [
          Row(
            spacing: BvPinnedSpec.headerGap,
            children: [
              const Icon(
                BvIcons.pin,
                size: BvPinnedSpec.pin,
                color: BvColors.iconAction,
              ),
              Flexible(
                child: Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.labelMd.copyWith(color: BvColors.textPrimary),
                ),
              ),
              Expanded(
                child: Text(
                  audience,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: quiet,
                ),
              ),
              Text(time, style: quiet),
            ],
          ),
          Text(
            title,
            style: type.titleLg.copyWith(color: BvColors.textPrimary),
          ),
          facts,
          if ((body ?? '').isNotEmpty)
            Text(
              body!,
              style: type.bodyMd.copyWith(color: BvColors.textPrimary),
            ),
          ?quote,
          if (leading != null || action != null)
            Row(
              spacing: BvAckPillSpec.rowGap,
              children: [
                ?leading,
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: action,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    if (onTap == null && onLongPress == null) return note;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: note,
    );
  }
}

/// A pinned announcement folded to one slim line under the masthead
/// (review 61 G1): after Got it, or for its author. The pin, the first
/// line of its words, how long it lasts ("until Fri", F85) and ›, which
/// mirrors in right to left. A tap opens it in full.
class BvPinnedLine extends StatelessWidget {
  const BvPinnedLine({
    super.key,
    required this.text,
    this.until,
    this.faces,
    this.onTap,
    this.onLongPress,
  });

  final String text;

  /// "until Fri", in grey before ›.
  final String? until;

  /// For its author: the faces of who tapped Got it (F104), before ›.
  final Widget? faces;
  final VoidCallback? onTap;

  /// The same long-press menu as a card's (review 50 F44).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('pinned-line'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: BvPinnedSpec.lineMinHeight,
          ),
          padding: const EdgeInsetsDirectional.only(
            start: BvPinnedSpec.linePaddingStart,
            end: BvPinnedSpec.linePaddingEnd,
            top: BvPinnedSpec.linePaddingVertical,
            bottom: BvPinnedSpec.linePaddingVertical,
          ),
          decoration: const BoxDecoration(
            color: BvColors.surfaceBrandSoft,
            borderRadius: BvPinnedSpec.radius,
          ),
          child: Row(
            spacing: BvPinnedSpec.lineGap,
            children: [
              const Icon(
                BvIcons.pin,
                size: BvPinnedSpec.pin,
                color: BvColors.iconAction,
              ),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                ),
              ),
              if (until != null)
                Text(
                  until!,
                  key: const Key('pinned-line-until'),
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
                ),
              ?faces,
              const Icon(
                BvIcons.caretForward,
                size: BvPinnedSpec.caret,
                color: BvColors.iconSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
