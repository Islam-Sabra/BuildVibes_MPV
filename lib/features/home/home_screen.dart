import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_tabs.dart';
import '../activity/activity_state.dart';
import '../entry/entry_state.dart';
import '../feed/feed_tab.dart';
import '../feed/post_draft.dart';
import '../profile/widgets/profile_parts.dart';
import '../settings/push_fix.dart';
import '../../core/design/messages_specs.dart';
import '../../data/repositories/dm_repository.dart';
import 'spaces_day_tab.dart';

/// Home (H1 v4 2587:35849): the wordmark, Search (people search in
/// Explore) and Messages, with a dot while something is unread (never a
/// number; the notebook icon comes with slice 8, review 48), the small
/// Feed and Spaces tabs, and the tab. Spaces, your
/// day on site (H1b), gets a dot while something needs you. Guests get no
/// feed (the guest feed isn't in the MVP).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const feedTab = 0;
  static const spacesTab = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeTabProvider);
    void select(int i) => ref.read(homeTabProvider.notifier).show(i);
    final l10n = AppLocalizations.of(context);
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    final needsYou =
        !guest && (ref.watch(needsCardsProvider).value?.isNotEmpty ?? false);
    // Writing a post happens on the Feed, at Now (H2).
    ref.listen(postWritingProvider, (_, mode) {
      if (mode != PostWriting.none && tab != HomeScreen.feedTab) {
        select(HomeScreen.feedTab);
      }
    });
    Widget icon(String key, IconData glyph, String label, VoidCallback onTap) =>
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            key: Key(key),
            radius: BvSize.touchMin / 2,
            onTap: onTap,
            child: SizedBox.square(
              dimension: BvHomeSpec.barButton,
              child: Icon(
                glyph,
                size: BvSize.iconLg,
                color: BvColors.iconPrimary,
              ),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvHomeSpec.barPaddingStart,
                BvHomeSpec.barPaddingVertical,
                BvHomeSpec.barPaddingEnd,
                BvHomeSpec.barPaddingVertical,
              ),
              child: Row(
                spacing: BvHomeSpec.barGap,
                children: [
                  Expanded(
                    // The wordmark stays in Latin letters in both languages,
                    // at the start of the bar.
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l10n.appTitle,
                        textDirection: TextDirection.ltr,
                        // A logo: it keeps its own size (review 53, F30).
                        style: BvType.latin.headingMd.copyWith(
                          color: BvColors.brandInk,
                          fontSize: BvHomeSpec.wordmarkSize,
                          height:
                              BvHomeSpec.wordmarkLineHeight /
                              BvHomeSpec.wordmarkSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  icon(
                    'home-search',
                    BvIcons.search,
                    l10n.homeSearch,
                    // F78: people search; a tap opens the profile.
                    () => context.push(AppRoutes.peopleSearch),
                  ),
                  if (!guest)
                    Stack(
                      children: [
                        icon(
                          'home-messages',
                          BvIcons.chat,
                          l10n.messagesTitle,
                          () => context.push(AppRoutes.messages),
                        ),
                        if (ref.watch(dmInboxProvider).value?.anyUnread ??
                            false)
                          const PositionedDirectional(
                            top: BvHomeSpec.dotInset,
                            end: BvHomeSpec.dotInset,
                            child: SizedBox.square(
                              key: Key('home-messages-dot'),
                              dimension: BvMessagesSpec.dot,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: BvColors.actionPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            BvTabs.small(
              key: const Key('home-tabs'),
              labels: [l10n.homeFeed, l10n.homeSpaces],
              selectedIndex: tab,
              dots: {if (needsYou) HomeScreen.spacesTab},
              onSelect: select,
            ),
            // F9: pushes can't reach this phone; Fix it says how.
            const PushNotReachingLine(),
            Expanded(
              child: tab == HomeScreen.spacesTab
                  ? const SpacesDayTab()
                  : guest
                  ? Padding(
                      padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                      child: EmptyNote(l10n.placeholderBody),
                    )
                  : const FeedTab(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Which of Home's tabs shows: Feed or Spaces. Activity's "Needs you" line
/// opens Spaces (review 50 F32).
final homeTabProvider = NotifierProvider<HomeTab, int>(HomeTab.new);

class HomeTab extends Notifier<int> {
  @override
  int build() => HomeScreen.feedTab;

  void show(int tab) => state = tab;
}
