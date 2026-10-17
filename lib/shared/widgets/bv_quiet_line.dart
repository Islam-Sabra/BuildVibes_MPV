import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// A quiet line across the page: an icon, a short state in secondary
/// text, and one action at the end ("Notifications aren't reaching this
/// phone · Fix it", F9).
class BvQuietLine extends StatelessWidget {
  const BvQuietLine({
    super.key,
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return ColoredBox(
      color: BvColors.surfaceSubtle,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: BvQuietLineSpec.paddingStart,
          end: BvQuietLineSpec.paddingEnd,
        ),
        child: Row(
          spacing: BvQuietLineSpec.gap,
          children: [
            Icon(
              icon,
              size: BvQuietLineSpec.icon,
              color: BvColors.iconSecondary,
            ),
            Expanded(
              child: Text(
                text,
                style: type.labelSm.copyWith(color: BvColors.textSecondary),
              ),
            ),
            Semantics(
              button: true,
              child: InkWell(
                onTap: onAction,
                borderRadius: BvRadius.controlAll,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: BvSize.touchMin,
                    minWidth: BvSize.touchMin,
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: BvQuietLineSpec.actionPadding,
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        actionLabel,
                        style: type.labelMd.copyWith(
                          color: BvColors.textAction,
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
    );
  }
}
