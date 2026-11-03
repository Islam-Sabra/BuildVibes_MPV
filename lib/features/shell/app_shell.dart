import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/feature_switches.dart';
import '../spaces/need_you_phone.dart' show NeedYouHost;
import '../../core/design/bv_icons.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_bottom_bar.dart';
import '../../shared/widgets/bv_tab_swipe.dart';
import '../../data/repositories/dm_repository.dart';
import '../activity/activity_state.dart';
import '../create/create_sheet.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/join_wall.dart';
import '../feed/post_draft.dart';
import '../messages/dm_live.dart';
import '../notebook/note_reminders.dart';
import '../onboarding/late_alert_sheet.dart';
import '../settings/push_host.dart';
import '../work/check_in_phone.dart' show CheckInHost;
import '../work/outbox_host.dart';
import '../work/work_gestures.dart' show SpaceReminderHost;

/// The bottom tabs: Home (Spaces with the feed hidden), Explore, Activity
/// and Profile.
const shellTabCount = 4;
const shellActivityTab = 2;

/// Shows bottom tab [i], by a tap on the bar or a swipe (review 115, 3).
/// The current tab again goes back to its first screen.
void showShellTab(WidgetRef ref, StatefulNavigationShell shell, int i) {
  // Activity reads again each time it opens (and marks it read).
  if (i == shellActivityTab) {
    ref
      ..invalidate(activityProvider)
      ..invalidate(needsCardsProvider);
  }
  shell.goBranch(i, initialLocation: i == shell.currentIndex);
}

/// A bottom tab's main screen (review 115, 3): a sideways swipe on it shows
/// the next or the previous tab. Only there: what opens inside a tab, a
/// sheet or a dialog sits above it, and nothing swipes while a post is
/// being written on Home.
class ShellTabSwipe extends ConsumerWidget {
  const ShellTabSwipe({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = context
        .dependOnInheritedWidgetOfExactType<_ShellTabs>()
        ?.shell;
    if (shell == null) return child;
    final writing = ref.watch(postWritingProvider) != PostWriting.none;
    return BvTabSwipe(
      index: shell.currentIndex,
      count: shellTabCount,
      enabled: !writing,
      onSelect: (i) => showShellTab(ref, shell, i),
      child: child,
    );
  }
}

/// The tabs' shell, for the swipe on each tab's main screen: the current
/// tab, new on each move.
class _ShellTabs extends InheritedWidget {
  const _ShellTabs({required this.shell, required super.child});

  final StatefulNavigationShell shell;

  @override
  bool updateShouldNotify(_ShellTabs old) => old.shell != shell;
}

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
    // Review 113 (6): with the feed hidden, the first tab is Spaces.
    final feed = ref.watch(feedEnabledProvider);
    return Scaffold(
      // Push while signed in (permission, this phone's token, taps), and
      // what waits on the phone to be sent.
      // Messages, live app-wide (F81). My notebook's reminders on this
      // phone (slice 10), and a Space post's (review 105 Part 2).
      body: OutboxHost(
        child: PushHost(
          // Review 109 CI2: check-in notifications and their taps.
          child: CheckInHost(
            // Review 113 NN2: Need you now's notifications and answers.
            child: NeedYouHost(
              child: DmLiveHost(
                child: SpaceReminderHost(
                  // Review 114 PS3: an urgent alert that came late.
                  child: LateAlertHost(
                    child: ReminderHost(
                      child: _ShellTabs(
                        shell: navigationShell,
                        child: navigationShell,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BvBottomBar(
        selectedIndex: navigationShell.currentIndex,
        onSelect: (i) => showShellTab(ref, navigationShell, i),
        // Review 114: with the feed hidden there is no +; it comes back
        // with the feed.
        spaceTabs: false,
        createLabel: feed ? l10n.navCreate : null,
        // Create (F1): "Post to everyone" writes a post in place on Home,
        // at Now (H2), from every tab; "Work item in a Space" opens that
        // Space's daybook with its card open. Creating needs an account:
        // guests see the join wall.
        onCreate: !feed
            ? null
            : () {
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
            key: Key(feed ? 'nav-home' : 'nav-spaces'),
            icon: feed ? BvIcons.home : BvIcons.team,
            label: feed ? l10n.navHome : l10n.homeSpaces,
            // A direct message waits (F81): Messages is on Home (on
            // Spaces, with the feed hidden).
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
            dot: unread && navigationShell.currentIndex != shellActivityTab,
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
