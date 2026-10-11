import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/months.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/project.dart';
import '../../data/repositories/project_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/entry_scaffold.dart';
import '../profile/edit/edit_common.dart';
import 'widgets/project_sheets.dart';

/// P13 · Add a project: "Is it already here?". One record per project, so
/// the person searches first, then adds the record to their CV or starts a
/// new one.
class AddProjectScreen extends ConsumerStatefulWidget {
  const AddProjectScreen({super.key});

  @override
  ConsumerState<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends ConsumerState<AddProjectScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<ProjectMatch> _matches = const [];
  Set<String> _onCv = const {};
  var _searched = false;

  @override
  void initState() {
    super.initState();
    final me = ref.read(authUserIdProvider).value;
    if (me != null) {
      ref.read(projectRepositoryProvider).myProjectIds(me).then((ids) {
        if (mounted) setState(() => _onCv = ids);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(BvAuthSpec.searchDebounce, () => _search(value));
  }

  Future<void> _search(String value) async {
    if (value.trim().length < 2) {
      setState(() {
        _matches = const [];
        _searched = false;
      });
      return;
    }
    final matches = await ref
        .read(projectRepositoryProvider)
        .findSimilar(value.trim());
    if (mounted && _query.text == value) {
      setState(() {
        _matches = matches;
        _searched = true;
      });
    }
  }

  Future<void> _addToCv(ProjectRecord project) async {
    final me = ref.read(authUserIdProvider).value;
    final headline = ref.read(myProfileProvider).value?.headline;
    final input = await showCvEntrySheet(
      context,
      projectName: project.name,
      role: headline,
    );
    if (input == null || me == null || !mounted) return;
    try {
      await ref.read(projectRepositoryProvider).addToCv(project.id, input);
    } on Exception {
      if (mounted) showSaveError(context);
      return;
    }
    if (!mounted) return;
    afterSave(context, ref);
    context.pushReplacement('/projects/${project.id}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return EntryScaffold(
      title: l10n.addProject,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          BvSearchField(
            key: const Key('project-search'),
            placeholder: l10n.projectSearchHint,
            controller: _query,
            autofocus: true,
            onChanged: _onChanged,
          ),
          Text(
            l10n.addProjectIntro,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
          for (final m in _matches)
            _MatchCard(
              match: m,
              onCv: _onCv.contains(m.project.id),
              onAdd: () => _addToCv(m.project),
            ),
          if (_searched || _query.text.trim().length >= 2)
            _NewRecordCard(
              onTap: () => context.push(
                AppRoutes.projectsNew,
                extra: _query.text.trim(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.onCv,
    required this.onAdd,
  });

  final ProjectMatch match;
  final bool onCv;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context);
    final p = match.project;
    final meta = joinMeta(
      [
        p.typeName?.of(locale),
        p.location(locale.languageCode),
        formatMonthRange(
          l10n,
          locale.toLanguageTag(),
          start: p.start,
          end: p.end,
          endExpected: p.endExpected,
        ),
      ].whereType<String>(),
    );
    return Container(
      key: Key('match-${p.id}'),
      padding: const EdgeInsetsDirectional.all(BvSpace.s16),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvRadius.cardAll,
        border: Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpace.s4,
        children: [
          Text(
            match.reason == MatchReason.sameName
                ? l10n.matchSameName
                : l10n.matchSameSite,
            style: type.overline.copyWith(color: BvColors.textAction),
          ),
          InkWell(
            onTap: () => context.push('/projects/${p.id}'),
            child: Text(p.name, style: type.titleLg),
          ),
          if (meta.isNotEmpty)
            Text(
              meta,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
          const SizedBox(height: BvSpace.s8),
          if (onCv)
            BvBadge(label: l10n.onYourCvBadge, tone: BvBadgeTone.positive)
          else
            BvButton(
              key: Key('this-is-it-${p.id}'),
              label: l10n.thisIsIt,
              size: BvButtonSize.medium,
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }
}

/// "None of these? Start a new record": an outlined card.
class _NewRecordCard extends StatelessWidget {
  const _NewRecordCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Material(
      color: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BvRadius.cardAll,
        side: BorderSide(color: BvColors.borderInput, width: BvStroke.thin),
      ),
      child: InkWell(
        key: const Key('start-new-record'),
        onTap: onTap,
        borderRadius: BvRadius.cardAll,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.s16),
          child: Row(
            spacing: BvSpace.s12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s2,
                  children: [
                    Text(l10n.startNewRecord, style: type.titleMd),
                    Text(
                      l10n.startNewRecordSub,
                      style: type.bodySm.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                BvIcons.caretForward,
                size: BvSize.iconMd,
                color: BvColors.iconSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
