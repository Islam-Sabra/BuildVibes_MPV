import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import 'bv_stamp.dart';

enum BvPassKind { lead, crew, viewer }

/// Spec §16: a Space pass (Lead / Crew / Viewer) with a colour band at the
/// start edge. One choice in a single-choice set, so it reads as a radio.
class BvPassCard extends StatelessWidget {
  const BvPassCard({
    super.key,
    required this.kind,
    required this.opens,
    required this.forWho,
    this.selected = false,
    this.onTap,
  });

  final BvPassKind kind;

  /// The "Opens: …" line.
  final String opens;

  /// Who the pass is for.
  final String forWho;
  final bool selected;
  final VoidCallback? onTap;

  static Color bandColor(BvPassKind kind) => switch (kind) {
    BvPassKind.lead => BvColors.brandInk,
    BvPassKind.crew => BvColors.actionPrimary,
    BvPassKind.viewer => BvColors.borderInput,
  };

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final l10n = AppLocalizations.of(context);
    final name = switch (kind) {
      BvPassKind.lead => l10n.passLead,
      BvPassKind.crew => l10n.passCrew,
      BvPassKind.viewer => l10n.passViewer,
    };

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: selected ? BvColors.brandEnergySoft : BvColors.surfaceElevated,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BvPassCardSpec.radius,
          side: selected
              ? const BorderSide(
                  color: BvColors.actionPrimary,
                  width: BvStroke.thick,
                )
              : const BorderSide(
                  color: BvColors.borderDefault,
                  width: BvStroke.thin,
                ),
        ),
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const Key('pass-band'),
                  width: BvPassCardSpec.bandWidth,
                  color: bandColor(kind),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: BvPassCardSpec.paddingHorizontal,
                      vertical: BvPassCardSpec.paddingVertical,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: BvPassCardSpec.gap,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: type.overline.copyWith(
                                  color: BvColors.textPrimary,
                                ),
                              ),
                            ),
                            if (selected)
                              BvStamp(label: l10n.stampSelected, tilted: true),
                          ],
                        ),
                        Text(
                          opens,
                          style: type.bodySm.copyWith(
                            color: BvColors.textPrimary,
                          ),
                        ),
                        Text(
                          forWho,
                          style: type.metadata.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
