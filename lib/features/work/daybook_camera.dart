import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_sheet.dart';

/// What the post bar's camera takes (the lead's rulings on 105A).
enum DaybookCameraMode { photo, walk }

/// The post bar's camera: one choice at the bottom, Photo · Walk (rule 6).
/// Photo writes a work item with the photo; Walk is "one photo, one work
/// item, keep walking" (Walk mode, one tap from Work). Null when closed.
Future<DaybookCameraMode?> showDaybookCameraModes(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<DaybookCameraMode>(
    context: context,
    builder: (sheet) => Row(
      key: const Key('camera-modes'),
      spacing: BvCameraModesSpec.tileGap,
      children: [
        for (final (mode, icon, label) in [
          (DaybookCameraMode.photo, BvIcons.camera, l10n.cameraPhoto),
          (DaybookCameraMode.walk, BvIcons.walk, l10n.cameraWalk),
        ])
          Expanded(
            child: _ModeTile(
              key: Key('camera-${mode.name}'),
              icon: icon,
              label: label,
              onTap: () => Navigator.of(sheet).pop(mode),
            ),
          ),
      ],
    ),
  );
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: BvColors.surfaceElevated,
      borderRadius: BvCameraModesSpec.radius,
      child: InkWell(
        borderRadius: BvCameraModesSpec.radius,
        onTap: onTap,
        child: SizedBox(
          height: BvCameraModesSpec.tileHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: BvCameraModesSpec.iconGap,
            children: [
              Icon(icon, size: BvSize.iconLg, color: BvColors.iconPrimary),
              Text(
                label,
                style: BvType.of(
                  context,
                ).labelMd.copyWith(color: BvColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
