import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../data/models/people.dart';
import '../../data/repositories/profile_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../../shared/widgets/bv_sheet.dart';

/// The company chosen on "About you": a registered company, or a name as
/// the person typed it (rule 4: typed text never creates a company).
@immutable
class CompanyPick {
  CompanyPick.registered(CompanySummary company)
    : companyId = company.id,
      name = company.name;
  const CompanyPick.typed(this.name) : companyId = null;
  const CompanyPick.none() : companyId = null, name = null;

  final String? companyId;
  final String? name;

  bool get isNone => name == null;
}

/// Opens the searchable company picker. Returns null when dismissed.
Future<CompanyPick?> showCompanySheet(
  BuildContext context, {
  required String? marketId,
  String? initialQuery,
}) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<CompanyPick>(
    context: context,
    title: l10n.companySheetTitle,
    builder: (_) =>
        _CompanySearch(marketId: marketId, initialQuery: initialQuery),
  );
}

class _CompanySearch extends ConsumerStatefulWidget {
  const _CompanySearch({required this.marketId, this.initialQuery});

  final String? marketId;
  final String? initialQuery;

  @override
  ConsumerState<_CompanySearch> createState() => _CompanySearchState();
}

class _CompanySearchState extends ConsumerState<_CompanySearch> {
  late final _query = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  List<CompanySummary> _results = const [];

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').isNotEmpty) _search(widget.initialQuery!);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(BvMotion.searchWait, () => _search(value));
  }

  Future<void> _search(String value) async {
    try {
      final results = await ref
          .read(profileRepositoryProvider)
          .searchCompanies(value, marketId: widget.marketId);
      if (mounted && _query.text == value) setState(() => _results = results);
    } on Exception {
      if (mounted) setState(() => _results = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typed = _query.text.trim();
    // A typed name that matches a registered company links to it.
    final exact = _results
        .where((c) => c.name.toLowerCase() == typed.toLowerCase())
        .firstOrNull;
    void pick(CompanyPick p) => Navigator.of(context).pop(p);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s12,
      children: [
        BvSearchField(
          key: const Key('company-search'),
          placeholder: l10n.companySearch,
          controller: _query,
          autofocus: true,
          onChanged: _onChanged,
        ),
        ClipRRect(
          borderRadius: BvRadius.cardAll,
          child: BvListGroup(
            rows: [
              for (final c in _results)
                BvListRow(
                  key: Key('company-${c.id}'),
                  leading: const BvRowIcon(BvIcons.company),
                  title: c.name,
                  trailing: const BvRowTrailing.none(),
                  onTap: () => pick(CompanyPick.registered(c)),
                ),
              if (typed.isNotEmpty && exact == null)
                BvListRow(
                  key: const Key('company-typed'),
                  title: l10n.companyUseTyped(typed),
                  subtitle: l10n.companyUseTypedHelp,
                  trailing: const BvRowTrailing.none(),
                  onTap: () => pick(CompanyPick.typed(typed)),
                ),
              BvListRow(
                key: const Key('company-none'),
                title: l10n.companyNone,
                trailing: const BvRowTrailing.none(),
                onTap: () => pick(const CompanyPick.none()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
