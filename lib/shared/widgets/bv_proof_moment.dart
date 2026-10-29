import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';

/// Review 105 Part 7 (SP7 2670:38787): the owner's proof moment, a dark
/// toast with the green seal: "Added to your proof of work", who checked it
/// and when, and View.
class BvProofMoment extends StatelessWidget {
  const BvProofMoment({
    super.key,
    required this.title,
    required this.by,
    required this.viewLabel,
    required this.onView,
  });

  final String title;

  /// "Checked by Islam Sabra · 11:20".
  final String by;
  final String viewLabel;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Container(
      key: const Key('proof-moment'),
      padding: BvProofMomentSpec.padding,
      decoration: const BoxDecoration(
        color: BvColors.brandInk,
        borderRadius: BvRadius.cardAll,
      ),
      child: Row(
        spacing: BvProofMomentSpec.gap,
        children: [
          Container(
            width: BvProofMomentSpec.seal,
            height: BvProofMomentSpec.seal,
            decoration: const BoxDecoration(
              color: BvColors.feedbackSuccess,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              BvIcons.confirmed,
              size: BvProofMomentSpec.icon,
              color: BvColors.textInverse,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BvProofMomentSpec.lineGap,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.emphasis.copyWith(color: BvColors.textInverse),
                ),
                Text(
                  by,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.metadata.copyWith(color: BvColors.textInverse),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            child: InkWell(
              key: const Key('proof-moment-view'),
              onTap: onView,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: BvSize.touchMin,
                  minHeight: BvSize.touchMin,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    viewLabel,
                    style: type.emphasis.copyWith(color: BvColors.textAction),
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
