import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/market.dart';
import '../../data/repositories/market_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import 'entry_state.dart';
import 'widgets/entry_hero.dart';

/// The live market to name on the entry screens: the phone's region when it
/// is a live market, otherwise the first live market. Null when offline.
Market? entryMarket(WidgetRef ref) {
  final markets = ref.watch(marketsProvider).value ?? const <Market>[];
  final region = ref.watch(deviceRegionProvider)?.toLowerCase();
  final live = liveMarkets(markets);
  return live.where((m) => m.id == region).firstOrNull ?? live.firstOrNull;
}

/// E1 · Welcome.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final country = entryMarket(ref)?.name.of(Localizations.localeOf(context));

    return Scaffold(
      body: Column(
        children: [
          EntryHero(countryName: country),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.gutter,
              ),
              child: Column(
                children: [
                  Text(
                    l10n.entryWelcomeTitle,
                    textAlign: TextAlign.center,
                    style: type.titleLg,
                  ),
                  const SizedBox(height: BvSpace.s6),
                  Text(
                    l10n.entryWelcomeBody,
                    textAlign: TextAlign.center,
                    style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                  ),
                  const SizedBox(height: BvSpace.s16),
                  _AudienceCard(countryName: country),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvSpace.s12,
                BvSpace.gutter,
                BvSpace.s8,
              ),
              child: Column(
                spacing: BvSpace.s8,
                children: [
                  BvButton(
                    key: const Key('welcome-create'),
                    label: l10n.entryCreateAccount,
                    expand: true,
                    onPressed: () => context.push(AppRoutes.join),
                  ),
                  BvButton(
                    key: const Key('welcome-sign-in'),
                    label: l10n.entrySignIn,
                    style: BvButtonStyle.secondary,
                    expand: true,
                    onPressed: () => context.push(AppRoutes.join),
                  ),
                  BvButton(
                    key: const Key('welcome-skip'),
                    label: l10n.entrySkipToHome,
                    style: BvButtonStyle.tertiary,
                    onPressed: () {
                      ref.read(guestModeProvider.notifier).enter();
                      context.go(AppRoutes.home);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The rotating "who it's for" card. It stops rotating when the phone asks
/// for less motion.
class _AudienceCard extends StatefulWidget {
  const _AudienceCard({required this.countryName});

  final String? countryName;

  @override
  State<_AudienceCard> createState() => _AudienceCardState();
}

class _AudienceCardState extends State<_AudienceCard> {
  static const _icons = [
    BvIcons.ruler,
    BvIcons.explore,
    BvIcons.clipboard,
    BvIcons.hammer,
    BvIcons.truck,
    BvIcons.cube,
  ];

  final _pages = PageController();
  Timer? _timer;
  var _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _timer = Timer.periodic(BvEntrySpec.rotateEvery, (_) => _next());
    }
  }

  void _next() {
    if (!_pages.hasClients) return;
    _pages.animateToPage(
      (_index + 1) % _icons.length,
      duration: BvMotion.slow,
      curve: BvMotion.standard,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final cards = [
      (l10n.entryAudience1Title, l10n.entryAudience1Body),
      (l10n.entryAudience2Title, l10n.entryAudience2Body),
      (l10n.entryAudience3Title, l10n.entryAudience3Body),
      (l10n.entryAudience4Title, l10n.entryAudience4Body),
      (l10n.entryAudience5Title, l10n.entryAudience5Body),
      (l10n.entryAudience6Title, l10n.entryAudience6Body),
    ];

    return Container(
      key: const Key('audience-card'),
      padding: const EdgeInsetsDirectional.all(BvSpace.s16),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvRadius.cardAll,
        border: Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.countryName != null)
            Row(
              spacing: BvSpace.s8,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(color: BvColors.brandEnergy),
                  child: SizedBox(
                    width: BvEntrySpec.accentBarWidth,
                    height: BvEntrySpec.accentBarHeight,
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.entryBuiltFor(widget.countryName!),
                    style: type.labelLg,
                  ),
                ),
              ],
            ),
          SizedBox(
            height: BvEntrySpec.audienceIconTile + BvSpace.s32,
            child: PageView.builder(
              controller: _pages,
              itemCount: cards.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => Row(
                spacing: BvSpace.s16,
                children: [
                  Container(
                    width: BvEntrySpec.audienceIconTile,
                    height: BvEntrySpec.audienceIconTile,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: BvColors.surfaceSubtle,
                      borderRadius: BvRadius.cardAll,
                    ),
                    child: Icon(
                      _icons[i],
                      size: BvSize.iconLg,
                      color: BvColors.iconAction,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: BvSpace.s4,
                      children: [
                        Text(cards[i].$1, style: type.headingMd),
                        Text(
                          cards[i].$2,
                          style: type.bodyMd.copyWith(
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
          Row(
            spacing: BvSpace.s6,
            children: [
              for (var i = 0; i < cards.length; i++)
                AnimatedContainer(
                  duration: BvMotion.fast,
                  width: i == _index
                      ? BvEntrySpec.dotActiveWidth
                      : BvEntrySpec.dotSize,
                  height: BvEntrySpec.dotSize,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? BvColors.brandEnergy
                        : BvColors.borderDefault,
                    borderRadius: BvRadius.roundAll,
                  ),
                ),
            ],
          ),
          const SizedBox(height: BvSpace.s16),
          Text(
            l10n.entryBrowseFirstNote,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
