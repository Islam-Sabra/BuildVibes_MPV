import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_tokens.dart';

/// A Space's small tile (Needs you 2544:35078): its first letter on the
/// subtle surface. It stands before the Space's name wherever a list is
/// sorted by Space: Needs you, Home → Spaces and Activity.
class BvSpaceTile extends StatelessWidget {
  const BvSpaceTile({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.characters.isEmpty ? '' : name.characters.first;
    return ExcludeSemantics(
      child: Container(
        key: const Key('space-tile'),
        width: BvNeedsSpec.spaceTile,
        height: BvNeedsSpec.spaceTile,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: BvColors.surfaceSubtle,
          borderRadius: BvRadius.smallAll,
        ),
        child: Text(initial.toUpperCase(), style: BvType.of(context).labelSm),
      ),
    );
  }
}
