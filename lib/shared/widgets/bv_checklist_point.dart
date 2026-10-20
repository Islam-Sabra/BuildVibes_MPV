import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../core/l10n/bv_time.dart';
import 'bv_avatar.dart';
import 'bv_clock_text.dart';

/// Who ticked a point, and when: their face and the time at the end.
typedef BvTick = ({String name, Color? tint, BvClockParts time});

/// One point of a checklist on its card (K1 v13 2594:36130): a box, the
/// words, and once ticked the box filled green, the words struck through
/// and grey, then who ticked it and when. A whole 48-point row is the
/// target. [onTap] null: read only (a Viewer, or a point not yours to
/// untick).
class BvChecklistPoint extends StatelessWidget {
  const BvChecklistPoint({
    super.key,
    required this.text,
    this.tick,
    this.onTap,
  });

  final String text;

  /// Null while unticked.
  final BvTick? tick;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final tick = this.tick;
    final ticked = tick != null;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: BvChecklistSpec.rowMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: BvChecklistSpec.rowPaddingVertical,
        ),
        child: Row(
          spacing: BvChecklistSpec.rowGap,
          children: [
            _Box(ticked: ticked),
            Expanded(
              child: Text(
                text,
                style: type.bodyMd.copyWith(
                  color: ticked ? BvColors.textSecondary : BvColors.textPrimary,
                  decoration: ticked ? TextDecoration.lineThrough : null,
                  decorationColor: BvColors.textSecondary,
                ),
              ),
            ),
            if (tick != null) ...[
              ExcludeSemantics(
                child: BvAvatar(
                  name: tick.name,
                  size: BvAvatarSize.note,
                  tint: tick.tint,
                ),
              ),
              BvClockText(
                tick.time,
                style: type.metadata.copyWith(color: BvColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
    return Semantics(
      checked: ticked,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.ticked});

  final bool ticked;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('checklist-box'),
    width: BvChecklistSpec.box,
    height: BvChecklistSpec.box,
    decoration: BoxDecoration(
      color: ticked ? BvColors.feedbackSuccess : BvColors.surfaceElevated,
      borderRadius: BvChecklistSpec.boxRadius,
      border: ticked
          ? null
          : Border.all(
              color: BvColors.borderDefault,
              width: BvChecklistSpec.boxBorder,
            ),
    ),
    child: ticked
        ? const Icon(
            BvIcons.check,
            size: BvChecklistSpec.boxCheck,
            color: BvColors.textInverse,
          )
        : null,
  );
}

/// A checklist's progress (2594:36125): a thin green line and "2 of 5
/// ticked", the one count the Daybook shows. It counts the checklist's
/// own points, so it is progress, not a quality signal (rule 3).
class BvChecklistProgress extends StatelessWidget {
  const BvChecklistProgress({
    super.key,
    required this.ticked,
    required this.total,
    required this.label,
  });

  final int ticked;
  final int total;

  /// "2 of 5 ticked".
  final String label;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : (ticked / total).clamp(0.0, 1.0);
    return Row(
      spacing: BvChecklistSpec.progressGap,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BvChecklistSpec.progressRadius,
            child: SizedBox(
              height: BvChecklistSpec.progressHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: BvColors.borderSubtle),
                  FractionallySizedBox(
                    key: const Key('checklist-progress'),
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: share,
                    child: const ColoredBox(color: BvColors.feedbackSuccess),
                  ),
                ],
              ),
            ),
          ),
        ),
        Text(
          label,
          style: BvType.of(
            context,
          ).labelSm.copyWith(color: BvColors.textSecondary),
        ),
      ],
    );
  }
}
