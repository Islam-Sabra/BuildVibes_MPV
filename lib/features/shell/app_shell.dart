import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_bottom_bar.dart';
import '../create/create_sheet.dart';

/// The frame around the four tabs: the current tab and the bottom bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BvBottomBar(
        selectedIndex: navigationShell.currentIndex,
        // Tapping the current tab again goes back to its first screen.
        onSelect: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        createLabel: l10n.navCreate,
        onCreate: () => showCreateSheet(context),
        items: [
          BvBottomBarItem(
            key: const Key('nav-home'),
            icon: BvIcons.home,
            label: l10n.navHome,
          ),
          BvBottomBarItem(
            key: const Key('nav-explore'),
            icon: BvIcons.explore,
            label: l10n.navExplore,
          ),
          BvBottomBarItem(
            key: const Key('nav-activity'),
            icon: BvIcons.activity,
            label: l10n.navActivity,
          ),
          BvBottomBarItem(
            key: const Key('nav-profile'),
            icon: BvIcons.profile,
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
