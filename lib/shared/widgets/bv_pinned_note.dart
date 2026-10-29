import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart' show BvStroke;
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../l10n/gen/app_localizations.dart';
import 'bv_tap_target.dart';

/// A pinned announcement under the masthead (K1 v13 2594:36070): on the
/// brand-soft surface, the pin, who wrote it and for whom ("· to
/// everyone") and when, the words in bold, until when on the facts line
/// under them (review 50 F85: "Until Friday 23 Oct · 2:00 pm", at the main
/// size), and a row at the foot with the author's faces ([leading]) and
/// the reader's one action ([action], Got it).
///
/// The lead's check of 105A, H2: a tap opens it ([onTap]) and a hold
/// selects it ([onLongPress], [selected]), as a card; folding is its own
/// chevron at the start of the head ([onFold], review 106 T2).
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
    this.onFold,
    this.selected = false,
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

  /// Opens it.
  final VoidCallback? onTap;

  /// Selects it.
  final VoidCallback? onLongPress;

  /// ⌄ at the start of the head: folds it back to its slim line, when it
  /// can fold.
  final VoidCallback? onFold;

  /// Held and selected: an edge in the action colour, as a card's.
  final bool selected;

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
      decoration: BoxDecoration(
        color: BvColors.surfaceBrandSoft,
        borderRadius: BvPinnedSpec.radius,
        border: selected ? _selectedEdge : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvPinnedSpec.gap,
        children: [
          Row(
            spacing: BvPinnedSpec.headerGap,
            children: [
              if (onFold != null) BvPinnedFold(open: true, onTap: onFold!),
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
/// mirrors in right to left.
///
/// H2: › at its start unfolds it ([onFold]); a tap on the line opens it
/// ([onTap]) and a hold selects it ([onLongPress], [selected]).
class BvPinnedLine extends StatelessWidget {
  const BvPinnedLine({
    super.key,
    required this.text,
    this.until,
    this.faces,
    this.onTap,
    this.onLongPress,
    this.onFold,
    this.selected = false,
  });

  final String text;

  /// "until Fri", in grey before ›.
  final String? until;

  /// For its author: the faces of who tapped Got it (F104), before ›.
  final Widget? faces;

  /// Opens it.
  final VoidCallback? onTap;

  /// Selects it.
  final VoidCallback? onLongPress;

  /// › at the start: shows it in full.
  final VoidCallback? onFold;
  final bool selected;

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
          decoration: BoxDecoration(
            color: BvColors.surfaceBrandSoft,
            borderRadius: BvPinnedSpec.radius,
            border: selected ? _selectedEdge : null,
          ),
          child: Row(
            spacing: BvPinnedSpec.lineGap,
            children: [
              if (onFold != null) BvPinnedFold(open: false, onTap: onFold!),
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
            ],
          ),
        ),
      ),
    );
  }
}

const _selectedEdge = Border.fromBorderSide(
  BorderSide(color: BvColors.textAction, width: BvStroke.medium),
);

/// The fold control of a pinned announcement (H2, as review 106 T2): a 24
/// chevron, ⌄ when open, › when folded (‹ in right to left), with a touch
/// area past it (rule 2).
class BvPinnedFold extends StatelessWidget {
  const BvPinnedFold({super.key, required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      expanded: open,
      label: open ? l10n.pinnedFold : l10n.pinnedUnfold,
      excludeSemantics: true,
      child: BvTapTarget(
        child: GestureDetector(
          key: const Key('pinned-fold'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Icon(
            open ? BvIcons.caretDown : BvIcons.caretForward,
            size: BvPinnedSpec.fold,
            color: BvColors.iconSecondary,
          ),
        ),
      ),
    );
  }
}
