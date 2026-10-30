import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/market.dart';
import '../../data/models/people.dart';
import '../../data/models/space.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/market_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/reference_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/onboarding_scaffold.dart';
import 'onboarding_state.dart';

/// OB5 · What's your work? (review 107, 2699:39043; step 2 of 3): nine big
/// tiles from the market pack (its most popular trades first), a search of
/// every trade, and "Not listed? Type it" for the person's own words.
/// Continue saves the name and the work at once ("Saving…"), with the home
/// market taken without asking. Then your Space (OB6), or with an invite,
/// the request to join that Space.
class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key});

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  final _query = TextEditingController();
  final _own = TextEditingController();
  Trade? _picked;
  var _typing = false;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    _own.dispose();
    super.dispose();
  }

  String? get _invite => onboardingInviteCode(
    ref.read(inviteCodeProvider),
    ref.read(authRepositoryProvider).signUpInviteCode,
  );

  String? _marketId(List<Market> markets) => homeMarketWithoutAsking(
    markets: markets,
    region: ref.watch(deviceRegionProvider),
    accountMarketId: ref.watch(myProfileProvider).value?.homeMarketId,
    invited: _invite != null,
  );

  static bool _matches(Trade t, String q) {
    bool has(LocalizedText? l) =>
        l != null && (l.en.toLowerCase().contains(q) || l.ar.contains(q));
    return has(t.name) || has(t.description);
  }

  /// The tiles: the market's popular trades, then the rest in their order,
  /// nine at most; with a search, the trades it finds. Never "Other".
  List<Trade> _tiles(RolePicker picker) {
    final q = _query.text.trim().toLowerCase();
    final all = picker.allTrades.where((t) => t.id != Trade.otherId);
    if (q.isNotEmpty) {
      return all.where((t) => _matches(t, q)).take(BvEntrySpec.tiles).toList();
    }
    final popular = picker.popular.where((t) => t.id != Trade.otherId);
    return [
      ...popular,
      ...all.where((t) => !popular.contains(t)),
    ].take(BvEntrySpec.tiles).toList();
  }

  Future<void> _save(RolePicker picker, String marketId) async {
    final l10n = AppLocalizations.of(context);
    final own = _own.text.trim();
    final RoleChoice? role = _typing
        ? (own.isEmpty ? null : RoleChoice.custom(own, trade: picker.other))
        : (_picked == null ? null : RoleChoice.trade(_picked!));
    if (role == null) {
      setState(() => _error = l10n.obWorkChoose);
      return;
    }
    final userId = ref.read(authUserIdProvider).value;
    final me = ref.read(myProfileProvider).value;
    final name =
        ref.read(onboardingNameProvider) ??
        (me == null ? null : (first: me.firstName, last: me.lastName));
    if (userId == null || name == null || name.first.isEmpty) {
      context.go(AppRoutes.onboardingName);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final invite = _invite;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveAboutYou(
            userId,
            AboutYouInput(
              firstName: name.first,
              lastName: name.last,
              homeMarketId: marketId,
              role: role,
              locale: Localizations.localeOf(context).languageCode,
            ),
          );
      ref.invalidate(myProfileProvider);
      await ref.read(myProfileProvider.future);
      if (invite == null) {
        router.go(AppRoutes.onboardingSpace);
        return;
      }
      // An invite: its Space, with no step 3 (review 107).
      ref.read(inviteCodeProvider.notifier).set(null);
      final result = await ref
          .read(spaceRepositoryProvider)
          .requestJoin(invite);
      ref.invalidate(myJoinRequestsProvider);
      switch (result.status) {
        case JoinStatus.member when result.spaceId != null:
          router.go(AppRoutes.space(result.spaceId!));
        case JoinStatus.requested || JoinStatus.pending:
          router.go(AppRoutes.home);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                result.status == JoinStatus.pending
                    ? l10n.spacesAlreadyWaiting
                    : l10n.spacesRequestSent,
              ),
            ),
          );
        default:
          // The code didn't work: step 3, to type another.
          router.go(AppRoutes.onboardingSpace);
      }
    } on SpaceException {
      router.go(AppRoutes.onboardingSpace);
    } on Exception {
      if (mounted) setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final markets = ref.watch(marketsProvider).value ?? const <Market>[];
    final marketId = _marketId(markets);
    final picker = marketId == null
        ? null
        : ref.watch(rolePickerProvider(marketId)).value;

    return OnboardingScaffold(
      title: l10n.obWorkTitle,
      subtitle: l10n.obWorkSub,
      step: 2,
      button: BvButton(
        key: const Key('work-continue'),
        label: _saving ? l10n.obSaving : l10n.continueLabel,
        expand: true,
        onPressed: _saving || picker == null
            ? null
            : () => _save(picker, marketId!),
      ),
      body: picker == null
          ? const Padding(
              padding: EdgeInsetsDirectional.all(BvSpace.s32),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvSpace.s12,
              children: [
                LayoutBuilder(
                  builder: (context, box) {
                    const columns = BvEntrySpec.tileColumns;
                    final width =
                        (box.maxWidth - BvEntrySpec.tileGap * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: BvEntrySpec.tileGap,
                      runSpacing: BvEntrySpec.tileGap,
                      children: [
                        for (final t in _tiles(picker))
                          SizedBox(
                            width: width,
                            child: _Tile(
                              key: Key('work-tile-${t.id}'),
                              trade: t,
                              selected: !_typing && _picked?.id == t.id,
                              onTap: () => setState(() {
                                _picked = t;
                                _typing = false;
                                _error = null;
                              }),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                BvSearchField(
                  key: const Key('work-search'),
                  placeholder: l10n.obWorkSearch,
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                ),
                if (_typing)
                  BvTextField(
                    key: const Key('work-own'),
                    label: l10n.obWorkOwn,
                    controller: _own,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() => _error = null),
                  )
                else
                  Center(
                    child: BvButton(
                      key: const Key('work-not-listed'),
                      label: l10n.obWorkNotListed,
                      style: BvButtonStyle.tertiary,
                      onPressed: () => setState(() {
                        _typing = true;
                        _picked = null;
                        _error = null;
                      }),
                    ),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    key: const Key('work-error'),
                    textAlign: TextAlign.center,
                    style: type.metadata.copyWith(
                      color: BvColors.textDestructive,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// A trade's big tile: its icon on a soft square, then its name. Picked,
/// it takes the brand's soft fill and the action colour.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.trade,
    required this.selected,
    required this.onTap,
  });

  final Trade trade;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final name = trade.name.of(Localizations.localeOf(context));
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? BvColors.surfaceBrandSoft : BvColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BvRadius.cardAll,
          side: BorderSide(
            color: selected ? BvColors.borderSelected : BvColors.borderDefault,
            width: selected ? BvStroke.thick : BvStroke.thin,
          ),
        ),
        child: InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BvRadius.cardAll,
          ),
          onTap: onTap,
          // As drawn, or taller when the name needs two lines at the
          // phone's text size.
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: BvEntrySpec.tileHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: BvSpace.s8,
              children: [
                const SizedBox(height: BvSpace.s4),
                Container(
                  width: BvEntrySpec.tileIcon,
                  height: BvEntrySpec.tileIcon,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? BvColors.surfaceElevated
                        : BvColors.surfaceSubtle,
                    borderRadius: BvRadius.controlAll,
                  ),
                  child: Icon(
                    BvIcons.forTrade(trade.id),
                    size: BvSize.iconLg,
                    color: selected
                        ? BvColors.iconAction
                        : BvColors.iconPrimary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: BvSpace.s4,
                  ),
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: type.labelMd.copyWith(
                      color: selected
                          ? BvColors.textAction
                          : BvColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: BvSpace.s4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
