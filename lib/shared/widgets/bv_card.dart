import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// A white card with the thin border and the card radius; tappable with
/// [onTap]. Review 121: a key person, who runs the Space, a Team, the
/// phone number's choices.
class BvCard extends StatelessWidget {
  const BvCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsetsDirectional.all(BvSpace.s12),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final inside = Padding(padding: padding, child: child);
    return Material(
      color: BvColors.surfaceElevated,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BvRadius.cardAll,
        side: const BorderSide(
          color: BvColors.borderDefault,
          width: BvStroke.thin,
        ),
      ),
      child: onTap == null
          ? inside
          : InkWell(
              onTap: onTap,
              splashFactory: NoSplash.splashFactory,
              child: inside,
            ),
    );
  }
}
