import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_badge.dart';

/// One choice of a [BvSegmented]; with [badge] above zero, a count after
/// its label (review 105 Part 1: Chat's unread), keyed [badgeKey].
class BvSegment<T> {
  const BvSegment({
    required this.value,
    required this.label,
    this.key,
    this.badge = 0,
    this.badgeKey,
  });

  final T value;
  final String label;
  final Key? key;
  final int badge;
  final Key? badgeKey;
}

/// One single choice as a pill track (SI1 2562:35617 Notifications, 2562:
/// 35640 Who can invite): the chosen segment is a white pill. Choices that
/// exclude each other are one control, never switches (rule 6).
class BvSegmented<T> extends StatelessWidget {
  const BvSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<BvSegment<T>> segments;
  final T value;

  /// Null: shown, not changeable.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(BvSegmentedSpec.padding),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvRadius.roundAll,
      ),
      child: Row(
        spacing: BvSegmentedSpec.gap,
        children: [
          for (final s in segments)
            Expanded(
              child: Semantics(
                inMutuallyExclusiveGroup: true,
                selected: s.value == value,
                button: true,
                child: GestureDetector(
                  key: s.key,
                  behavior: HitTestBehavior.opaque,
                  onTap: onChanged == null || s.value == value
                      ? null
                      : () => onChanged!(s.value),
                  child: AnimatedContainer(
                    duration: BvMotion.fast,
                    curve: BvMotion.standard,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: BvSegmentedSpec.segmentPaddingHorizontal,
                      vertical: BvSegmentedSpec.segmentPaddingVertical,
                    ),
                    decoration: BoxDecoration(
                      color: s.value == value
                          ? BvColors.surfaceElevated
                          : BvColors.surfaceSubtle,
                      borderRadius: BvRadius.roundAll,
                      boxShadow: s.value == value ? BvShadow.infoSlip : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: BvSegmentedSpec.badgeGap,
                      children: [
                        Flexible(
                          child: Text(
                            s.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.labelMd.copyWith(
                              color: s.value == value
                                  ? BvColors.textPrimary
                                  : BvColors.textSecondary,
                            ),
                          ),
                        ),
                        if (s.badge > 0)
                          BvBadge(
                            key: s.badgeKey,
                            label: '${s.badge}',
                            tone: BvBadgeTone.action,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
