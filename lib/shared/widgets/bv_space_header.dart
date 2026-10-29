import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_space_emblem.dart';

/// The top of a Space (Figma "Space header" 2080:11849; review 105 Part 1,
/// SP1 2666:38461): back, the Space emblem, its name and line, then Search,
/// Library and People, 60 high on the app surface. Tapping the name opens
/// Space info ([onOpen]), which holds what ⋯ held; Search opens the Space's
/// search ([onSearch]); Library and People open theirs. People has a dot
/// while join requests wait ([peopleWaiting]). The name ends in "…" when
/// it must.
class BvSpaceHeader extends StatelessWidget implements PreferredSizeWidget {
  const BvSpaceHeader({
    super.key,
    required this.name,
    required this.line,
    required this.backLabel,
    required this.onOpen,
    required this.searchLabel,
    required this.onSearch,
    required this.libraryLabel,
    required this.onLibrary,
    required this.peopleLabel,
    required this.onPeople,
    this.peopleWaiting = false,
    this.waitingLabel,
    this.onBack,
  });

  final String name;

  /// "Private work · project Space".
  final String line;
  final String backLabel;
  final VoidCallback onOpen;
  final String searchLabel;
  final VoidCallback onSearch;
  final String libraryLabel;
  final VoidCallback onLibrary;
  final String peopleLabel;
  final VoidCallback onPeople;

  /// Join requests wait: People carries a dot, read as [waitingLabel].
  final bool peopleWaiting;
  final String? waitingLabel;

  /// Null: back closes the Space's route, when there is one.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(BvSpaceHeaderSpec.height);

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final back =
        onBack ??
        (Navigator.of(context).canPop()
            ? () => Navigator.of(context).maybePop()
            : null);
    return Material(
      color: BvColors.surfaceApp,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: BvSpaceHeaderSpec.height,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvSpaceHeaderSpec.paddingHorizontal,
          ),
          child: Row(
            spacing: BvSpaceHeaderSpec.gap,
            children: [
              if (back != null)
                _Square(
                  key: const Key('space-back'),
                  icon: BvIcons.arrowBack,
                  label: backLabel,
                  onTap: back,
                ),
              Expanded(
                child: Semantics(
                  button: true,
                  child: GestureDetector(
                    key: const Key('space-header'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onOpen,
                    child: Row(
                      spacing: BvSpaceHeaderSpec.gap,
                      children: [
                        const BvSpaceEmblem(),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.titleMd,
                              ),
                              Text(
                                line,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.metadata.copyWith(
                                  color: BvColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: BvSpaceHeaderSpec.iconsGap,
                children: [
                  _Square(
                    key: const Key('space-search'),
                    icon: BvIcons.search,
                    label: searchLabel,
                    onTap: onSearch,
                  ),
                  _Square(
                    key: const Key('space-library'),
                    icon: BvIcons.library,
                    label: libraryLabel,
                    onTap: onLibrary,
                  ),
                  _Square(
                    key: const Key('space-people'),
                    icon: BvIcons.team,
                    label: peopleWaiting && waitingLabel != null
                        ? '$peopleLabel, $waitingLabel'
                        : peopleLabel,
                    onTap: onPeople,
                    dot: peopleWaiting,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 48 square icon button.
class _Square extends StatelessWidget {
  const _Square({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.dot = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// A dot at the top end corner (People, join requests waiting).
  final bool dot;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      radius: BvSize.touchMin / 2,
      child: SizedBox.square(
        dimension: BvSize.touchMin,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: BvSize.iconLg, color: BvColors.iconPrimary),
            if (dot)
              const PositionedDirectional(
                top: BvSpaceHeaderSpec.dotInset,
                end: BvSpaceHeaderSpec.dotInset,
                child: DecoratedBox(
                  key: Key('space-people-dot'),
                  decoration: BoxDecoration(
                    color: BvColors.actionPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: BvSpaceHeaderSpec.dot),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
