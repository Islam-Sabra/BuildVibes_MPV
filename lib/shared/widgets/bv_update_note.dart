import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_loop_specs.dart';
import 'bv_avatar.dart';

/// An update hanging under its work item (Y2 2530:34124): a small note on
/// the subtle surface. The first line quotes the item (an orange bar and
/// its title); the second has the writer's face and the words.
class BvUpdateNote extends StatelessWidget {
  const BvUpdateNote({
    super.key,
    required this.quote,
    required this.name,
    required this.text,
    this.tint,
    this.photo,
  });

  /// The work item's title.
  final String quote;

  /// Who wrote it; the face's initials come from it.
  final String name;
  final String text;

  /// [BvAvatarTints.forId] of the writer.
  final Color? tint;

  /// A photo that came with the update, under the words.
  final Widget? photo;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvUpdateNoteSpec.paddingHorizontal,
        vertical: BvUpdateNoteSpec.paddingVertical,
      ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvUpdateNoteSpec.radius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvUpdateNoteSpec.gap,
        children: [
          Row(
            spacing: BvUpdateNoteSpec.quoteGap,
            children: [
              const SizedBox(
                key: Key('update-quote-bar'),
                width: BvUpdateNoteSpec.quoteBarWidth,
                height: BvUpdateNoteSpec.quoteBarHeight,
                child: ColoredBox(color: BvColors.actionPrimary),
              ),
              Expanded(
                child: Text(
                  quote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.labelSm.copyWith(color: BvColors.textSecondary),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvUpdateNoteSpec.rowGap,
            children: [
              BvAvatar(name: name, size: BvAvatarSize.note, tint: tint),
              Expanded(
                child: Text(
                  text,
                  style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                ),
              ),
            ],
          ),
          ?photo,
        ],
      ),
    );
  }
}
