import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_tabs.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/join_wall.dart';
import '../feed/feed_tab.dart';
import '../profile/widgets/profile_parts.dart';
import '../spaces/my_spaces_view.dart';

/// Home: Feed (opens first; H1 v2) and Spaces. Until week 7 part 2
/// builds the daily Spaces tab (H1b), Spaces shows My Spaces. Guests get
/// no feed (the guest feed isn't in the MVP).
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
    return Scaffold(
      appBar: AppBar(
        // The wordmark stays in Latin letters in both languages.
        title: Text(
          l10n.appTitle,
          style: BvType.latin.headingLg.copyWith(color: BvColors.brandInk),
        ),
        actions: [
          if (_tab == HomeScreen.spacesTab)
            BvButton(
              key: const Key('spaces-create'),
              label: l10n.navCreate,
              style: BvButtonStyle.tertiary,
              size: BvButtonSize.medium,
              onPressed: () => guest
                  ? showJoinWall(context)
                  : context.push(AppRoutes.spacesNew),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BvTabs(
            key: const Key('home-tabs'),
            fill: true,
            labels: [l10n.homeFeed, l10n.homeSpaces],
            selectedIndex: _tab,
            onSelect: (i) => setState(() => _tab = i),
          ),
          const Divider(
            height: BvStroke.thin,
            thickness: BvStroke.thin,
            color: BvColors.borderDefault,
          ),
          Expanded(
            child: _tab == HomeScreen.spacesTab
                ? const MySpacesView()
                : guest
                ? Padding(
                    padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                    child: EmptyNote(l10n.placeholderBody),
                  )
                : const FeedTab(),
          ),
        ],
      ),
    );
  }
}
