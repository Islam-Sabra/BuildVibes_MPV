import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/market.dart';
import '../../data/models/people.dart';
import '../../data/repositories/market_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_step_progress.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/entry_scaffold.dart';

/// Suggestions for the signed-in person, with who they already follow.
final peopleSuggestionsProvider =
    FutureProvider.autoDispose<(List<PersonSuggestion>, Set<String>)>((
      ref,
    ) async {
      final me = await ref.watch(myProfileProvider.future);
      if (me == null) return (const <PersonSuggestion>[], const <String>{});
      final repo = ref.watch(profileRepositoryProvider);
      final results = await Future.wait([
        repo.suggestions(me),
        repo.following(me.id),
      ]);
      return (results[0] as List<PersonSuggestion>, results[1] as Set<String>);
    });

/// E10 · People to follow (step 2 of 2). Each suggestion says why it is
/// there. Skip and Continue both go Home.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  /// Follows changed on this screen, over what the server returned.
  final _changed = <String, bool>{};

  Future<void> _toggle(String userId, String otherId, bool follow) async {
    setState(() => _changed[otherId] = follow);
    final repo = ref.read(profileRepositoryProvider);
    try {
      follow
          ? await repo.follow(userId, otherId)
          : await repo.unfollow(userId, otherId);
    } on Exception {
      if (mounted) setState(() => _changed[otherId] = !follow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context);
    final english = locale.languageCode == 'en';
    final me = ref.watch(myProfileProvider).value;
    final markets = ref.watch(marketsProvider).value ?? const <Market>[];
    final market = markets.where((m) => m.id == me?.homeMarketId).firstOrNull;
    final country = market?.name.of(locale) ?? '';
    final role = me?.roleLabel(locale.languageCode) ?? '';
    final data = ref.watch(peopleSuggestionsProvider);
    void done() => context.go(AppRoutes.home);

    String upper(String s) => english ? s.toUpperCase() : s;

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s24,
        BvSpace.gutter,
        BvSpace.s8,
      ),
      child: Text(
        upper(text),
        style: type.overline.copyWith(color: BvColors.textSecondary),
      ),
    );

    Widget person(PersonSuggestion p, Set<String> following) {
      final isFollowing = _changed[p.id] ?? following.contains(p.id);
      final reason = switch (p.reason) {
        SuggestionReason.sameCompany => l10n.reasonCompany,
        SuggestionReason.samePlace =>
          p.placeName == null
              ? l10n.reasonSameCountry(country)
              : l10n.reasonNear(p.placeName!.of(locale)),
        SuggestionReason.sameMarket => l10n.reasonSameCountry(country),
      };
      final subtitle = joinMeta(
        [p.roleLabel(locale.languageCode), p.companyLabel].whereType<String>(),
      );
      return Container(
        key: Key('person-${p.id}'),
        color: BvColors.surfaceElevated,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.gutter,
          vertical: BvSpace.s12,
        ),
        child: Row(
          spacing: BvSpace.s12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BvSpace.s2,
                children: [
                  Text(p.fullName, style: type.titleMd),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: type.bodySm.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  Text(
                    reason,
                    style: type.labelSm.copyWith(color: BvColors.textAction),
                  ),
                ],
              ),
            ),
            BvButton(
              key: Key('follow-${p.id}'),
              label: isFollowing ? l10n.following : l10n.follow,
              style: isFollowing
                  ? BvButtonStyle.tertiary
                  : BvButtonStyle.secondary,
              size: BvButtonSize.medium,
              onPressed: me == null
                  ? null
                  : () => _toggle(me.id, p.id, !isFollowing),
            ),
          ],
        ),
      );
    }

    final list = data.when(
      loading: () => const Padding(
        padding: EdgeInsetsDirectional.all(BvSpace.s32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: BvButton(
          label: l10n.commonRetry,
          style: BvButtonStyle.secondary,
          onPressed: () => ref.invalidate(peopleSuggestionsProvider),
        ),
      ),
      data: (result) {
        final (people, following) = result;
        if (people.isEmpty) {
          return Padding(
            padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
            child: Text(
              l10n.peopleEmpty,
              key: const Key('people-empty'),
              style: type.bodyMd.copyWith(color: BvColors.textSecondary),
            ),
          );
        }
        final company = people
            .where((p) => p.reason == SuggestionReason.sameCompany)
            .toList();
        final near = people
            .where((p) => p.reason != SuggestionReason.sameCompany)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (company.isNotEmpty) ...[
              sectionLabel(l10n.peopleFromCompany(me?.companyLabel ?? '')),
              for (final p in company) person(p, following),
            ],
            if (near.isNotEmpty) ...[
              sectionLabel(l10n.peopleNearYou),
              for (final p in near) person(p, following),
            ],
          ],
        );
      },
    );

    return EntryScaffold(
      title: l10n.peopleTitle,
      bodyPadding: EdgeInsetsDirectional.zero,
      actions: [
        TextButton(
          key: const Key('people-skip'),
          onPressed: done,
          child: Text(l10n.skip),
        ),
      ],
      footer: BvButton(
        key: const Key('people-continue'),
        label: l10n.continueLabel,
        expand: true,
        onPressed: done,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.gutter,
              BvSpace.s8,
              BvSpace.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BvSpace.s8,
              children: [
                const BvStepProgress(total: 2, current: 2),
                const SizedBox(height: BvSpace.s4),
                Text(
                  l10n.stepOf(2, 2),
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
                ),
                Text(l10n.peopleHeadline, style: type.headingMd),
                if (role.isNotEmpty && country.isNotEmpty)
                  Text(
                    l10n.peopleBody(role, country),
                    style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                  ),
              ],
            ),
          ),
          list,
          const SizedBox(height: BvSpace.s16),
        ],
      ),
    );
  }
}
