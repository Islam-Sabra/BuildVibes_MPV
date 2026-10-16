import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';

/// The bar under the Daybook (spec §8): a notepad that starts writing in
/// place, and the camera ("hold to prove"). For a Viewer pass,
/// [BvPostBar.viewer] shows the pass and "Read only" instead.
class BvPostBar extends StatelessWidget {
  const BvPostBar({
    super.key,
    required String this.placeholder,
    this.onWrite,
    this.onCamera,
    this.onProve,
    this.cameraLabel,
  }) : passLabel = null,
       readOnly = null;

  const BvPostBar.viewer({
    super.key,
    required String this.passLabel,
    required String this.readOnly,
  }) : placeholder = null,
       onWrite = null,
       onCamera = null,
       onProve = null,
       cameraLabel = null;

  /// "Work item".
  final String? placeholder;
  final VoidCallback? onWrite;

  /// Tap the camera.
  final VoidCallback? onCamera;

  /// Hold the camera: prove.
  final VoidCallback? onProve;

  /// What a screen reader says for the camera button.
  final String? cameraLabel;

  /// Viewer form: "Viewer" and "Read only".
  final String? passLabel;
  final String? readOnly;

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
              BvPassChip(label: passLabel!),
              Flexible(
                child: Text(
                  readOnly!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
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
            Expanded(
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
            Semantics(
              button: true,
              label: cameraLabel,
              child: Material(
                key: const Key('post-bar-camera'),
                color: BvColors.actionPrimary,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onCamera,
                  onLongPress: onProve,
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
          ],
        ),
      ),
    );
  }
}

/// A small pass label, like a site pass clipped on (the Viewer post bar):
/// a thin outline, a dot and the pass name.
class BvPassChip extends StatelessWidget {
  const BvPassChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BvPassChipSpec.radius,
        border: Border.fromBorderSide(
          BorderSide(
            color: BvColors.textSecondary,
            width: BvPassChipSpec.border,
          ),
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
            const DecoratedBox(
              decoration: BoxDecoration(
                color: BvColors.textSecondary,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: BvPassChipSpec.dot),
            ),
            Text(
              label,
              style: type.labelSm.copyWith(color: BvColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
