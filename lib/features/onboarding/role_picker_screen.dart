import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_tokens.dart';
import '../../data/models/market.dart';
import '../../data/models/people.dart';
import '../../data/repositories/reference_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../entry/widgets/entry_scaffold.dart';

@immutable
class RolePickerArgs {
  const RolePickerArgs({
    required this.marketId,
    required this.countryName,
    this.initial,
  });

  final String marketId;
  final String countryName;
  final RoleChoice? initial;
}

/// E9b · Your role. Popular trades for the market as chips, then every
/// trade by group. A role that isn't listed is typed into search and saved
/// in the person's own words. Pops with the [RoleChoice].
class RolePickerScreen extends ConsumerStatefulWidget {
  const RolePickerScreen({super.key, required this.args});

  final RolePickerArgs args;

  @override
  ConsumerState<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends ConsumerState<RolePickerScreen> {
  final _query = TextEditingController();
  late RoleChoice? _choice = widget.args.initial;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  static bool _matches(Trade t, String q) {
    bool has(LocalizedText? l) =>
        l != null && (l.en.toLowerCase().contains(q) || l.ar.contains(q));
    return has(t.name) || has(t.description);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context);
    final english = locale.languageCode == 'en';
    final picker = ref.watch(rolePickerProvider(widget.args.marketId));
    final q = _query.text.trim().toLowerCase();

    bool isSelected(Trade t) =>
        _choice != null &&
        _choice!.customText == null &&
        _choice!.trade.id == t.id;

    BvListRow row(Trade t) => BvListRow(
      key: Key('role-${t.id}'),
      title: t.name.of(locale),
      subtitle: t.description?.of(locale),
      trailing: BvRowTrailing.check(selected: isSelected(t)),
      onTap: () => setState(() => _choice = RoleChoice.trade(t)),
    );

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s20,
        BvSpace.gutter,
        BvSpace.s8,
      ),
      child: Text(
        english ? text.toUpperCase() : text,
        style: type.overline.copyWith(color: BvColors.textSecondary),
      ),
    );

    final body = picker.when(
      loading: () => const Padding(
        padding: EdgeInsetsDirectional.all(BvSpace.s32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: Column(
          spacing: BvSpace.s12,
          children: [
            Text(l10n.errorGeneric, style: type.bodyMd),
            BvButton(
              label: l10n.commonRetry,
              style: BvButtonStyle.secondary,
              onPressed: () =>
                  ref.invalidate(rolePickerProvider(widget.args.marketId)),
            ),
          ],
        ),
      ),
      data: (data) {
        if (q.isNotEmpty) {
          final hits = data.allTrades.where((t) => _matches(t, q)).toList();
          final exact = hits.any(
            (t) => t.name.en.toLowerCase() == q || t.name.ar == q,
          );
          final typed = _query.text.trim();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: BvSpace.s8),
              BvListGroup(
                rows: [
                  ...hits.map(row),
                  if (!exact)
                    BvListRow(
                      key: const Key('role-custom'),
                      title: l10n.roleAddCustom(typed),
                      trailing: BvRowTrailing.check(
                        selected: _choice?.customText == typed,
                      ),
                      onTap: () => setState(
                        () => _choice = RoleChoice.custom(
                          typed,
                          trade: data.other,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.popular.isNotEmpty) ...[
              sectionLabel(l10n.rolePopularIn(widget.args.countryName)),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: BvSpace.gutter,
                ),
                child: Wrap(
                  spacing: BvSpace.s8,
                  runSpacing: BvSpace.s8,
                  children: [
                    for (final t in data.popular)
                      BvChip(
                        key: Key('popular-${t.id}'),
                        label: t.name.of(locale),
                        selected: isSelected(t),
                        onTap: () =>
                            setState(() => _choice = RoleChoice.trade(t)),
                      ),
                  ],
                ),
              ),
            ],
            for (final family in data.families)
              if (family.trades.isNotEmpty) ...[
                sectionLabel(family.name.of(locale)),
                BvListGroup(rows: family.trades.map(row).toList()),
              ],
          ],
        );
      },
    );

    return EntryScaffold(
      title: l10n.roleTitle,
      bodyPadding: EdgeInsetsDirectional.zero,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: BvSpace.s12,
        children: [
          Text(
            l10n.roleNotInList,
            textAlign: TextAlign.center,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
          BvButton(
            key: const Key('role-save'),
            label: l10n.save,
            expand: true,
            onPressed: _choice == null
                ? null
                : () => Navigator.of(context).pop(_choice),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.gutter,
              BvSpace.s16,
              BvSpace.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvSpace.s16,
              children: [
                Text(
                  l10n.roleIntro,
                  style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                ),
                BvSearchField(
                  key: const Key('role-search'),
                  placeholder: l10n.roleSearch,
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          body,
          const SizedBox(height: BvSpace.s16),
        ],
      ),
    );
  }
}
