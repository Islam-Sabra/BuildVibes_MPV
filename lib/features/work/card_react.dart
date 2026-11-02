import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/card_react_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/daybook.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_faces.dart';
import '../../shared/widgets/bv_popover_menu.dart' show bvGlobalRect;
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_tap_target.dart';
import '../spaces/former_member.dart' show personName;

/// A reaction's icon: Like (thumbs up), Heart, Bravo (hands clapping).
IconData reactionIcon(PostReaction r) => switch (r) {
  PostReaction.like => BvIcons.like,
  PostReaction.heart => BvIcons.heart,
  PostReaction.bravo => BvIcons.bravo,
};

Color reactionColor(PostReaction r) => switch (r) {
  PostReaction.like => BvCardReactSpec.like,
  PostReaction.heart => BvCardReactSpec.heart,
  PostReaction.bravo => BvCardReactSpec.bravo,
};

String reactionName(AppLocalizations l10n, PostReaction r) => switch (r) {
  PostReaction.like => l10n.reactLike,
  PostReaction.heart => l10n.reactHeart,
  PostReaction.bravo => l10n.reactBravo,
};

/// Review 113 RX1 (2730:39887): the foot of every card. At the start, the
/// reactions as their icons with the small faces of who reacted (never a
/// number; a tap shows the names); at the end, React (none on a Check-in)
/// and Share. [onReact] gets where React is, for the picker over it.
class DaybookCardReact extends StatelessWidget {
  const DaybookCardReact({
    super.key,
    required this.post,
    this.onReact,
    this.onReactors,
    this.onShare,
  });

  final DaybookPost post;
  final ValueChanged<Rect>? onReact;
  final VoidCallback? onReactors;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final groups = post.isCheckIn
        ? const <DaybookReactionGroup>[]
        : post.reactions;
    final mine = post.isCheckIn ? null : post.myReaction;
    final reactKey = GlobalKey();

    Widget action({
      required Key key,
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback? onTap,
      GlobalKey? anchor,
    }) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      // 48 to the thumb, without making the card taller.
      child: BvTapTarget(
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            key: anchor,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvCardReactSpec.actionPaddingHorizontal,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: BvCardReactSpec.actionGap,
              children: [
                Icon(icon, size: BvCardReactSpec.actionIcon, color: color),
                Text(label, style: quiet.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: BvCardReactSpec.top),
      child: Row(
        key: Key('card-react-row-${post.id}'),
        spacing: BvCardReactSpec.gap,
        children: [
          Expanded(
            child: groups.isEmpty
                ? const SizedBox.shrink()
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Semantics(
                      button: true,
                      label: l10n.reactWho,
                      child: BvTapTarget(
                        child: GestureDetector(
                          key: Key('card-reactions-${post.id}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: onReactors,
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: BvCardReactSpec.groupGap,
                            children: [
                              for (final g in groups)
                                Row(
                                  key: Key(
                                    'card-reaction-${post.id}-${g.kind.json}',
                                  ),
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: BvCardReactSpec.kindGap,
                                  children: [
                                    Icon(
                                      reactionIcon(g.kind),
                                      size: BvCardReactSpec.kindIcon,
                                      color: reactionColor(g.kind),
                                    ),
                                    BvFaces([
                                      for (final p in g.people)
                                        (
                                          name: p.name ?? '',
                                          tint: BvAvatarTints.forId(p.id),
                                        ),
                                    ]),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          if (!post.isCheckIn)
            action(
              key: Key('card-react-${post.id}'),
              anchor: reactKey,
              icon: mine == null ? BvIcons.react : reactionIcon(mine),
              label: mine == null ? l10n.reactReact : reactionName(l10n, mine),
              color: mine == null
                  ? BvColors.textSecondary
                  : reactionColor(mine),
              onTap: onReact == null
                  ? null
                  : () {
                      final box = reactKey.currentContext;
                      onReact!(box == null ? Rect.zero : bvGlobalRect(box));
                    },
            ),
          action(
            key: Key('card-share-${post.id}'),
            icon: BvIcons.shareFile,
            label: l10n.reactShare,
            color: BvColors.textSecondary,
            onTap: onShare,
          ),
        ],
      ),
    );
  }
}

/// The React picker (RX1): Like · Heart · Bravo on a white pill over
/// [anchor]; the one I gave is marked, and a tap on it takes it off. Null
/// when closed with nothing picked.
Future<PostReaction?> showReactPicker(
  BuildContext context, {
  required Rect anchor,
  PostReaction? mine,
}) {
  final l10n = AppLocalizations.of(context);
  return showGeneralDialog<PostReaction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x00000000),
    pageBuilder: (menu, _, _) {
      final size = MediaQuery.sizeOf(menu);
      final rtl = Directionality.of(menu) == TextDirection.rtl;
      final pill = Material(
        key: const Key('react-picker'),
        color: BvColors.surfaceElevated,
        borderRadius: BvCardReactSpec.pickerRadius,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: BvCardReactSpec.pickerRadius,
            boxShadow: BvCardReactSpec.pickerShadow,
          ),
          child: Padding(
            padding: BvCardReactSpec.pickerPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in PostReaction.values)
                  Semantics(
                    button: true,
                    selected: r == mine,
                    label: reactionName(l10n, r),
                    excludeSemantics: true,
                    child: InkResponse(
                      key: Key('react-${r.json}'),
                      onTap: () => Navigator.of(menu).pop(r),
                      child: SizedBox.square(
                        dimension: BvCardReactSpec.pickerButton,
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: r == mine
                                  ? BvColors.surfaceBrandSoft
                                  : null,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.all(
                                BvSpace.s4,
                              ),
                              child: Icon(
                                reactionIcon(r),
                                size: BvCardReactSpec.pickerIcon,
                                color: reactionColor(r),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      final bottom = size.height - anchor.top + BvCardReactSpec.pickerLift;
      return Stack(
        children: [
          Positioned(
            bottom: bottom.clamp(0, size.height).toDouble(),
            // Over React, kept on the screen: its end at React's end.
            left: rtl ? anchor.left.clamp(0, size.width).toDouble() : null,
            right: rtl
                ? null
                : (size.width - anchor.right).clamp(0, size.width).toDouble(),
            child: pill,
          ),
        ],
      );
    },
  );
}

/// Who reacted (RX1): a tap on the faces shows their names, by kind. A
/// hidden or blocked person keeps a plain face and no name.
Future<void> showReactors(BuildContext context, DaybookPost post) {
  final l10n = AppLocalizations.of(context);
  final type = BvType.of(context);
  return showBvSheet<void>(
    context: context,
    title: l10n.reactWho,
    builder: (_) => Column(
      key: const Key('reactors-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in post.reactions)
          for (final p in g.people)
            Padding(
              key: Key('reactor-${g.kind.json}-${p.id}'),
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: BvSpace.s8,
              ),
              child: Row(
                spacing: BvCardReactSpec.nameRowGap,
                children: [
                  BvAvatar(
                    name: p.name ?? '',
                    size: BvAvatarSize.sm,
                    tint: p.name == null
                        ? BvAvatarTints.plain
                        : BvAvatarTints.forId(p.id),
                  ),
                  Expanded(
                    child: Text(
                      inOwnDirection(personName(l10n, p.name)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                    ),
                  ),
                  Icon(
                    reactionIcon(g.kind),
                    size: BvCardReactSpec.kindIcon,
                    color: reactionColor(g.kind),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

/// Opens the picker over React and calls [react] with the choice.
Future<void> pickReaction(
  BuildContext context,
  DaybookPost post,
  Rect anchor,
  Future<void> Function(PostReaction) react,
) async {
  final picked = await showReactPicker(
    context,
    anchor: anchor,
    mine: post.myReaction,
  );
  if (picked == null) return;
  unawaited(react(picked));
}
