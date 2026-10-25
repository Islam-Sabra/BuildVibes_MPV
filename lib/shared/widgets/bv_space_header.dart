import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_space_emblem.dart';

/// The top of a Space (Figma "Space header" 2080:11849): back, the Space
/// emblem, its name and line, Search and ⋯, 60 high on the app surface with
/// a line under it. Tapping the name opens Space info ([onOpen]); Search
/// opens the Space's search ([onSearch], review 95: no longer behind ⋯);
/// ⋯ opens the Space menu ([onMore]). The name ends in "…" when it must.
class BvSpaceHeader extends StatelessWidget implements PreferredSizeWidget {
  const BvSpaceHeader({
    super.key,
    required this.name,
    required this.line,
    required this.backLabel,
    required this.moreLabel,
    required this.onMore,
    required this.onOpen,
    required this.searchLabel,
    required this.onSearch,
    this.onBack,
  });

  final String name;

  /// "Private work · project Space".
  final String line;
  final String backLabel;
  final String moreLabel;
  final VoidCallback onMore;
  final VoidCallback onOpen;
  final String searchLabel;
  final VoidCallback onSearch;

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
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: BvColors.borderSubtle,
                width: BvStroke.thin,
              ),
            ),
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
              _Square(
                key: const Key('space-search'),
                icon: BvIcons.search,
                label: searchLabel,
                onTap: onSearch,
              ),
              _Square(
                key: const Key('space-more'),
                icon: BvIcons.more,
                label: moreLabel,
                onTap: onMore,
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

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
        child: Icon(icon, size: BvSize.iconLg, color: BvColors.iconPrimary),
      ),
    ),
  );
}
