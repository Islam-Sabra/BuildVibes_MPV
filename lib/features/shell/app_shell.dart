import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/routing/app_routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_bottom_bar.dart';
import '../activity/activity_state.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/join_wall.dart';

/// The frame around the four tabs: the current tab and the bottom bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    final unread = ref.watch(unreadActivityProvider).value ?? false;
    const activityTab = 2;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BvBottomBar(
        selectedIndex: navigationShell.currentIndex,
        // Tapping the current tab again goes back to its first screen.
        onSelect: (i) {
          // Activity reads again each time it opens (and marks it read).
          if (i == activityTab) {
            ref
              ..invalidate(activityProvider)
              ..invalidate(needsCardsProvider);
          }
          navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          );
        },
        createLabel: l10n.navCreate,
        // Create opens the composer (C1 v2). Creating needs an account:
        // guests see the join wall.
        onCreate: () => guest
            ? showJoinWall(context)
            : GoRouter.of(context).push(AppRoutes.postNew),
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
            // Something new: a dot, never a number.
            dot: unread && navigationShell.currentIndex != activityTab,
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
