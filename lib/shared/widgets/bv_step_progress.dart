import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// Onboarding steps as a segmented bar (E10: step 2 of 2). Done steps are
/// ink; steps still to come are the border colour.
class BvStepProgress extends StatelessWidget {
  const BvStepProgress({super.key, required this.total, required this.current})
    : assert(current >= 1 && current <= total);

  final int total;

  /// 1-based.
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: BvStepProgressSpec.gap,
      children: [
        for (var i = 1; i <= total; i++)
          Expanded(
            child: DecoratedBox(
              key: Key('step-$i'),
              decoration: BoxDecoration(
                color: i <= current
                    ? BvColors.brandInk
                    : BvColors.borderDefault,
                borderRadius: BvStepProgressSpec.radius,
              ),
              child: const SizedBox(height: BvStepProgressSpec.height),
            ),
          ),
      ],
    );
  }
}
