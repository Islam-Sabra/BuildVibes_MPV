import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart';
import 'who_sees_sheet.dart' show BvTeamDisc;

/// The brand card that points the Space admin to a next step: Make Teams
/// from companies (TM1) and, review 122 KP0, Set who to call. A white disc
/// with [icon], the title in the action colour, a line, and the caret.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.icon,
    required this.title,
    required this.line,
    required this.onTap,
    this.lineColor = BvColors.textSecondary,
  });

  final IconData icon;
  final String title;
  final String line;
  final VoidCallback onTap;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Material(
      color: BvColors.surfaceBrandSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BvRadius.cardAll,
        side: const BorderSide(
          color: BvColors.borderSelected,
          width: BvStroke.thin,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BvRadius.cardAll,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvTeamsSpec.cardPadding),
          child: Row(
            spacing: BvTeamsSpec.rowGap,
            children: [
              BvTeamDisc(size: BvTeamsSpec.cardDisc, icon: icon, onCard: true),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvTeamsSpec.lineGap,
                  children: [
                    Text(
                      title,
                      style: type.emphasis.copyWith(color: BvColors.textAction),
                    ),
                    Text(line, style: type.metadata.copyWith(color: lineColor)),
                  ],
                ),
              ),
              const Icon(
                BvIcons.caretForward,
                size: BvSize.iconMd,
                color: BvColors.iconAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
