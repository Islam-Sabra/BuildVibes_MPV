import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart' show BvStroke;
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart' show BvNotebookPagesSpec;

/// One action of the selection bar (PG5): its icon over its word. Shared
/// by My notebook and a Space's Work (review 105 SP6, H8).
@immutable
class SelectionAction {
  const SelectionAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
}

/// The bar while selecting (PG5): its actions spread across, Delete in red.
class SelectionBar extends StatelessWidget {
  const SelectionBar({super.key, required this.actions});

  final List<SelectionAction> actions;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Material(
      key: const Key('selection-bar'),
      color: BvColors.surfaceElevated,
      child: SafeArea(
        top: false,
        child: Container(
          height: BvNotebookPagesSpec.barHeight,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: BvColors.borderSubtle,
                width: BvStroke.thin,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in actions)
                Expanded(
                  child: Semantics(
                    button: true,
                    enabled: a.onTap != null,
                    child: InkWell(
                      key: a.key,
                      onTap: a.onTap,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: BvNotebookPagesSpec.barTop,
                        ),
                        child: Column(
                          spacing: BvNotebookPagesSpec.barGap,
                          children: [
                            Icon(
                              a.icon,
                              size: BvNotebookPagesSpec.barIcon,
                              color: a.onTap == null
                                  ? BvColors.actionDisabledForeground
                                  : a.destructive
                                  ? BvColors.textDestructive
                                  : BvColors.iconPrimary,
                            ),
                            Text(
                              a.label,
                              style: type.metadata.copyWith(
                                color: a.onTap == null
                                    ? BvColors.actionDisabledForeground
                                    : a.destructive
                                    ? BvColors.textDestructive
                                    : BvColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
