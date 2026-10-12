import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';

enum BvSignOffStepKind { raised, done, checked }

/// One step of the sign-off. It is signed when [person] is set.
class BvSignOffStep {
  const BvSignOffStep({
    required this.kind,
    this.person,
    this.when,
    this.waitingFor,
  });

  final BvSignOffStepKind kind;
  final String? person;

  /// Date and time, already formatted for the app language and market.
  final String? when;

  /// Shown in place of the dash while unsigned, for example "You check
  /// it" (W3c).
  final String? waitingFor;

  bool get signed => person != null;
}

/// Spec §14: RAISED · DONE · CHECKED, under a "SIGN-OFF" label.
class BvSignOffStrip extends StatelessWidget {
  const BvSignOffStrip({super.key, required this.steps});

  final List<BvSignOffStep> steps;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSignOffSpec.labelGap,
      children: [
        Text(
          l10n.signOffLabel,
          style: type.overline.copyWith(color: BvColors.textSecondary),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: BvColors.surfaceElevated,
            borderRadius: BvSignOffSpec.radius,
            border: Border.all(
              color: BvColors.borderDefault,
              width: BvStroke.thin,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0)
                    const VerticalDivider(
                      width: BvStroke.thin,
                      thickness: BvStroke.thin,
                      color: BvColors.borderDefault,
                    ),
                  Expanded(child: _Cell(step: steps[i])),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.step});

  final BvSignOffStep step;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final l10n = AppLocalizations.of(context);
    final signed = step.signed;
    final name = switch (step.kind) {
      BvSignOffStepKind.raised => l10n.signOffRaised,
      BvSignOffStepKind.done => l10n.signOffDone,
      BvSignOffStepKind.checked => l10n.signOffChecked,
    };

    return Container(
      key: Key('sign-off-${step.kind.name}'),
      color: signed ? BvColors.surfaceElevated : BvColors.surfaceSubtle,
      padding: const EdgeInsetsDirectional.only(
        top: BvSignOffSpec.cellPaddingTop,
        start: BvSignOffSpec.cellPaddingSide,
        end: BvSignOffSpec.cellPaddingSide,
        bottom: BvSignOffSpec.cellPaddingBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSignOffSpec.cellGap,
        children: [
          Text(
            name,
            style: type.overline.copyWith(
              color: signed ? BvColors.textAction : BvColors.textSecondary,
            ),
          ),
          Text(
            step.person ?? step.waitingFor ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.labelMd.copyWith(
              color: signed ? BvColors.textPrimary : BvColors.textSecondary,
            ),
          ),
          Divider(
            height: BvStroke.thin,
            thickness: BvStroke.thin,
            color: signed ? BvColors.borderInput : BvColors.borderDefault,
          ),
          Text(
            signed ? (step.when ?? '') : l10n.signOffWaiting,
            style: type.metadata.copyWith(color: BvColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
