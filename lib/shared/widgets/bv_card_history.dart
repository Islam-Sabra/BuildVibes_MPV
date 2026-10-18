import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_paper_specs.dart';
import 'bv_avatar.dart';
import 'bv_tap_target.dart';

/// One line of a card's history: who (their face), the bold [lead] ("Omar
/// Haddad signed as done:"), the rest in grey ([detail]) and the [time].
@immutable
class BvHistoryLine {
  const BvHistoryLine({
    required this.id,
    required this.name,
    required this.lead,
    required this.time,
    this.detail,
    this.tint,
  });

  /// The event's id: the line's key ([BvCardHistory.lineKey]).
  final String id;

  /// The person's name, for the face's initials.
  final String name;
  final String lead;
  final String? detail;
  final String time;

  /// [BvAvatarTints.forId] of the person.
  final Color? tint;
}

/// A card's history (v13 2581:35681): its [lines], oldest first, behind a
/// thin line on the leading side. [earlierLabel] ("Show earlier") sits
/// above them while older lines are left; a tap calls [onEarlier].
class BvCardHistory extends StatelessWidget {
  const BvCardHistory({
    super.key,
    required this.lines,
    this.earlierLabel,
    this.onEarlier,
    this.lineKey,
  });

  final List<BvHistoryLine> lines;
  final String? earlierLabel;
  final VoidCallback? onEarlier;

  /// Each line's key, so the screen can scroll to one.
  final Key Function(String id)? lineKey;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return DecoratedBox(
      key: const Key('card-history'),
      decoration: const BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: BvColors.borderDefault,
            width: BvCardHistorySpec.rule,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: BvCardHistorySpec.paddingStart,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BvCardHistorySpec.gap,
          children: [
            if (earlierLabel != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: BvTapTarget(
                  child: Semantics(
                    button: true,
                    child: GestureDetector(
                      key: const Key('card-history-earlier'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onEarlier,
                      child: Text(
                        earlierLabel!,
                        style: type.labelSm.copyWith(
                          color: BvColors.textAction,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            for (final line in lines)
              _Line(key: lineKey?.call(line.id), line: line),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({super.key, required this.line});

  final BvHistoryLine line;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BvCardHistorySpec.lineGap,
      children: [
        BvAvatar(name: line.name, size: BvAvatarSize.note, tint: line.tint),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: line.lead,
                  style: type.labelMd.copyWith(color: BvColors.textPrimary),
                ),
                if (line.detail != null)
                  TextSpan(
                    text: ' ${line.detail}',
                    style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        Text(
          line.time,
          style: type.metadata.copyWith(color: BvColors.textSecondary),
        ),
      ],
    );
  }
}
