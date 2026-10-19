import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_paper_specs.dart';
import 'bv_avatar.dart';

/// A trace on an earlier day (v13 2581:35643): one quiet line for what
/// happened to a card that has since moved on ("Omar Haddad added an
/// update · Sleeves at grid C7"), its time and ›. A tap goes to the card.
class BvTraceRow extends StatelessWidget {
  const BvTraceRow({
    super.key,
    required this.name,
    required this.text,
    required this.time,
    this.tint,
    this.onTap,
  });

  /// The person's name, for the face's initials.
  final String name;
  final String text;
  final String time;

  /// [BvAvatarTints.forId] of the person.
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: BvTraceSpec.minHeight),
          padding: const EdgeInsetsDirectional.only(
            start: BvTraceSpec.paddingStart,
            end: BvTraceSpec.paddingEnd,
            top: BvTraceSpec.paddingVertical,
            bottom: BvTraceSpec.paddingVertical,
          ),
          decoration: const BoxDecoration(
            color: BvColors.surfaceSubtle,
            borderRadius: BvTraceSpec.radius,
          ),
          child: Row(
            spacing: BvTraceSpec.gap,
            children: [
              BvAvatar(name: name, size: BvAvatarSize.note, tint: tint),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                ),
              ),
              Text(
                time,
                style: type.metadata.copyWith(color: BvColors.textSecondary),
              ),
              const Icon(
                BvIcons.caretForward,
                size: BvTraceSpec.caret,
                color: BvColors.iconSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
