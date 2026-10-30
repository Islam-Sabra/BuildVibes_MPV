import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';
import 'bv_tap_target.dart';
import 'bv_tip.dart';

/// The bar under the Daybook (spec §8): a notepad that starts writing in
/// place, and the camera (a tap only: a signature is never on a hold, the
/// lead's check of 105A, H1). For a Viewer pass,
/// [BvPostBar.viewer] shows the pass and "Read only" instead.
class BvPostBar extends StatelessWidget {
  const BvPostBar({
    super.key,
    required String this.placeholder,
    this.onWrite,
    this.onCamera,
    this.cameraLabel,
    this.cameraAnchor,
    this.field,
    this.end,
  }) : passLabel = null,
       readOnly = null,
       passTone = BvPassTone.viewer;

  const BvPostBar.viewer({
    super.key,
    required String this.passLabel,
    this.readOnly,
    this.passTone = BvPassTone.viewer,
  }) : placeholder = null,
       onWrite = null,
       onCamera = null,
       cameraLabel = null,
       cameraAnchor = null,
       field = null,
       end = null;

  /// "Work item".
  final String? placeholder;
  final VoidCallback? onWrite;

  /// Tap the camera.
  final VoidCallback? onCamera;

  /// What a screen reader says for the camera button.
  final String? cameraLabel;

  /// The camera as a first-run tip's anchor, by this id ([BvTipAnchor]).
  final Object? cameraAnchor;

  /// In place of the notepad (My notebook's recording bar, slice 8).
  final Widget? field;

  /// In place of the camera (My notebook's mic, slice 8).
  final Widget? end;

  /// Viewer form: "Viewer" and "Read only". Someone else who may not post
  /// (a Crew pass with posting locked) sees only their pass (review 67).
  final String? passLabel;
  final String? readOnly;
  final BvPassTone passTone;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    const border = Border(
      top: BorderSide(
        color: BvColors.borderSubtle,
        width: BvPostBarSpec.border,
      ),
    );

    if (passLabel != null) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          color: BvColors.surfaceApp,
          border: border,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvPostBarSpec.viewerPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: BvPostBarSpec.viewerGap,
            children: [
              BvPassChip(label: passLabel!, tone: passTone),
              if (readOnly != null)
                Flexible(
                  child: Text(
                    readOnly!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.metadata.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BvColors.surfaceApp,
        border: border,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvPostBarSpec.paddingHorizontal,
          vertical: BvPostBarSpec.paddingVertical,
        ),
        child: Row(
          spacing: BvPostBarSpec.gap,
          children: [
            // The 44 notepad's touch area reaches 48 into the bar's padding.
            Expanded(
              child:
                  field ??
                  BvTapTarget(
                    child: Material(
                      key: const Key('post-bar-notepad'),
                      color: BvColors.surfaceSubtle,
                      borderRadius: BvPostBarSpec.notepadRadius,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onWrite,
                        child: SizedBox(
                          height: BvPostBarSpec.notepadHeight,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: BvPostBarSpec.notepadPadding,
                            ),
                            child: Row(
                              spacing: BvPostBarSpec.notepadGap,
                              children: [
                                const Icon(
                                  BvIcons.workItems,
                                  size: BvPostBarSpec.notepadIcon,
                                  color: BvColors.iconPrimary,
                                ),
                                Expanded(
                                  child: Text(
                                    placeholder!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: type.bodyMd.copyWith(
                                      color: BvColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
            end ??
                BvTipAnchor(
                  id: cameraAnchor,
                  child: Semantics(
                    button: true,
                    label: cameraLabel,
                    child: Material(
                      key: const Key('post-bar-camera'),
                      color: BvColors.actionPrimary,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onCamera,
                        child: const SizedBox.square(
                          dimension: BvPostBarSpec.cameraSize,
                          child: Icon(
                            BvIcons.camera,
                            size: BvPostBarSpec.cameraIcon,
                            color: BvColors.iconInverse,
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

/// A pass tag's colour: Lead orange, Crew green, Viewer grey (P1).
enum BvPassTone { lead, crew, viewer }

/// A small pass label, like a site pass clipped on: the Viewer post bar
/// and the People list (P1). One widget for every pass tag.
class BvPassChip extends StatelessWidget {
  const BvPassChip({
    super.key,
    required this.label,
    this.tone = BvPassTone.viewer,
  });

  final String label;
  final BvPassTone tone;

  static Color colorOf(BvPassTone tone) => switch (tone) {
    BvPassTone.lead => BvColors.textAction,
    BvPassTone.crew => BvColors.textPositive,
    BvPassTone.viewer => BvColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final color = colorOf(tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BvPassChipSpec.radius,
        border: Border.fromBorderSide(
          BorderSide(color: color, width: BvPassChipSpec.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvPassChipSpec.paddingHorizontal,
          vertical: BvPassChipSpec.paddingVertical,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: BvPassChipSpec.gap,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: BvPassChipSpec.dot),
            ),
            Text(label, style: type.labelSm.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
