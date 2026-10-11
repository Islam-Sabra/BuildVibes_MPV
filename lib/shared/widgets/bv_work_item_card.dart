import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

enum BvWorkStatus { open, done, checked, overdue }

/// Evidence shown on Done and Checked items.
class BvWorkEvidence {
  const BvWorkEvidence({required this.text, this.photo});

  /// Done: the quoted note. Checked: for example "Checked by Sara · 1 photo".
  final String text;
  final ImageProvider? photo;
}

/// Spec §15: a work item in a list (Work tab, Needs you). The whole card is
/// tappable.
class BvWorkItemCard extends StatelessWidget {
  const BvWorkItemCard({
    super.key,
    required this.reference,
    required this.status,
    required this.statusLine,
    required this.title,
    required this.place,
    required this.people,
    this.evidence,
    this.actionLabel,
    this.onAction,
    this.onTap,
  });

  /// For example "KCT-021 · STRUCTURE".
  final String reference;
  final BvWorkStatus status;

  /// For example "OPEN · DUE SUN 12 OCT".
  final String statusLine;
  final String title;
  final String place;

  /// For example "Owner: you · from Sara Al-Mutairi".
  final String people;

  /// Shown for Done and Checked only.
  final BvWorkEvidence? evidence;

  /// Shown only when the viewer can act, for example "Sign as done".
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  static Color statusColor(BvWorkStatus status) => switch (status) {
    BvWorkStatus.open || BvWorkStatus.done => BvColors.textAction,
    BvWorkStatus.checked => BvColors.textPositive,
    BvWorkStatus.overdue => BvColors.textDestructive,
  };

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final showEvidence =
        evidence != null &&
        (status == BvWorkStatus.done || status == BvWorkStatus.checked);

    return Material(
      color: BvColors.surfaceElevated,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BvWorkItemCardSpec.radius,
        side: BorderSide(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: BvColors.surfaceSubtle,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvWorkItemCardSpec.paddingHorizontal,
                vertical: BvWorkItemCardSpec.headerPaddingVertical,
              ),
              // Reference at the start, status at the end. When both don't
              // fit on one line (long Arabic dates), the status moves to a
              // second line instead of being cut.
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: BvWorkItemCardSpec.headerGap,
                runSpacing: BvWorkItemCardSpec.bodyGap,
                children: [
                  Text(
                    reference,
                    style: type.overline.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
                  Text(
                    statusLine,
                    key: const Key('work-status'),
                    style: type.overline.copyWith(color: statusColor(status)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvWorkItemCardSpec.paddingHorizontal,
                vertical: BvWorkItemCardSpec.bodyPaddingVertical,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BvWorkItemCardSpec.bodyGap,
                children: [
                  Text(title, style: type.titleMd),
                  Text(
                    place,
                    style: type.metadata.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
                  Text(
                    people,
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  ),
                  if (showEvidence) ...[
                    const SizedBox(height: BvWorkItemCardSpec.evidenceGap),
                    _EvidenceRow(evidence: evidence!, status: status),
                  ],
                ],
              ),
            ),
            if (actionLabel != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: BvWorkItemCardSpec.paddingHorizontal,
                  end: BvWorkItemCardSpec.paddingHorizontal,
                  bottom: BvWorkItemCardSpec.actionPaddingBottom,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: GestureDetector(
                    key: const Key('work-action'),
                    onTap: onAction ?? onTap,
                    child: Text(
                      actionLabel!,
                      style: type.labelMd.copyWith(color: BvColors.textAction),
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

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.evidence, required this.status});

  final BvWorkEvidence evidence;
  final BvWorkStatus status;

  @override
  Widget build(BuildContext context) {
    final checked = status == BvWorkStatus.checked;
    return Row(
      key: const Key('work-evidence'),
      spacing: BvWorkItemCardSpec.evidenceGap,
      children: [
        Container(
          width: BvWorkItemCardSpec.thumbSize,
          height: BvWorkItemCardSpec.thumbSize,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: BvColors.surfaceSubtle,
            borderRadius: BvWorkItemCardSpec.thumbRadius,
            image: evidence.photo == null
                ? null
                : DecorationImage(image: evidence.photo!, fit: BoxFit.cover),
          ),
          child: evidence.photo == null
              ? const Icon(
                  BvIcons.image,
                  size: BvSize.iconMd,
                  color: BvColors.iconSecondary,
                )
              : null,
        ),
        Expanded(
          child: Text(
            evidence.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: BvType.of(context).labelSm.copyWith(
              color: checked ? BvColors.textPositive : BvColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
