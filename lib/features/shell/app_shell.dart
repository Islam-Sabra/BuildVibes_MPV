import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_bottom_bar.dart';
import '../../data/repositories/dm_repository.dart';
import '../activity/activity_state.dart';
import '../create/create_sheet.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/join_wall.dart';
import '../feed/post_draft.dart';
import '../messages/dm_live.dart';
import '../settings/push_host.dart';
import '../work/outbox_host.dart';

/// The frame around the four tabs: the current tab and the bottom bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    final unread = ref.watch(unreadActivityProvider).value ?? false;
    final dmUnread =
        !guest && (ref.watch(dmInboxProvider).value?.anyUnread ?? false);
    const homeTab = 0;
    const activityTab = 2;
    return Scaffold(
      // Push while signed in (permission, this phone's token, taps), and
      // what waits on the phone to be sent.
      // Messages, live app-wide (F81).
      body: OutboxHost(
        child: PushHost(child: DmLiveHost(child: navigationShell)),
      ),
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
        // Create (F1): "Post to everyone" writes a post in place on Home,
        // at Now (H2), from every tab; "Work item in a Space" opens that
        // Space's daybook with its card open. Creating needs an account:
        // guests see the join wall.
        onCreate: () {
          if (guest) {
            showJoinWall(context);
            return;
          }
          showCreateChoice(
            context,
            onPost: () {
              ref.read(postWritingProvider.notifier).write();
              navigationShell.goBranch(homeTab, initialLocation: true);
            },
          );
        },
        items: [
          BvBottomBarItem(
            key: const Key('nav-home'),
            icon: BvIcons.home,
            label: l10n.navHome,
            // A direct message waits (F81): Messages is on Home.
            dot: dmUnread && navigationShell.currentIndex != homeTab,
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
