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
import 'spaces_day_tab.dart';

/// Home in Daybook (H1 v3 2555:35276): the wordmark and Search (people
/// search in Explore; the notebook and Messages icons come with slices 8
/// and 3, review 48), the small Feed and Spaces tabs, and the tab. Spaces, your day on site (H1b), gets a dot while something
/// needs you. Guests get no feed (the guest feed isn't in the MVP).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const feedTab = 0;
  static const spacesTab = 1;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _tab = HomeScreen.feedTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    final needsYou =
        !guest && (ref.watch(needsCardsProvider).value?.isNotEmpty ?? false);
    // Writing a post happens on the Feed, at Now (H2).
    ref.listen(postWritingProvider, (_, mode) {
      if (mode != PostWriting.none && _tab != HomeScreen.feedTab) {
        setState(() => _tab = HomeScreen.feedTab);
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
                        style: BvType.latin.headingLg.copyWith(
                          color: BvColors.brandInk,
                          fontSize: BvHomeSpec.wordmarkSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  icon(
                    'home-search',
                    BvIcons.search,
                    l10n.homeSearch,
                    () => context.go(AppRoutes.explore),
                  ),
                ],
              ),
            ),
            BvTabs.small(
              key: const Key('home-tabs'),
              labels: [l10n.homeFeed, l10n.homeSpaces],
              selectedIndex: _tab,
              dots: {if (needsYou) HomeScreen.spacesTab},
              onSelect: (i) => setState(() => _tab = i),
            ),
            Expanded(
              child: _tab == HomeScreen.spacesTab
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
