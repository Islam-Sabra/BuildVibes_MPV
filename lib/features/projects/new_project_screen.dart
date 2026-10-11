import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/months.dart';
import '../../data/models/project.dart';
import '../../data/repositories/project_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_month_sheet.dart';
import '../../shared/widgets/bv_title_block.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/entry_scaffold.dart';
import '../profile/edit/basics_screen.dart';
import '../profile/edit/edit_common.dart';
import '../profile/edit/experience_screens.dart';
import 'widgets/project_sheets.dart';

/// P14 · New project: the record's title block, filled in by the person,
/// then "Add to my CV" creates the record and the CV entry.
class NewProjectScreen extends ConsumerStatefulWidget {
  const NewProjectScreen({super.key, this.initialName});

  /// What was typed in "Is it already here?".
  final String? initialName;

  @override
  ConsumerState<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends ConsumerState<NewProjectScreen> {
  late String _name = widget.initialName ?? '';
  String? _typeId;
  String? _placeId;
  DateTime? _start;
  DateTime? _end;
  String? _role;
  var _showErrors = false;
  var _saving = false;

  Future<void> _create(String marketId) async {
    if (_name.trim().length < 2 || _typeId == null || (_role ?? '').isEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(projectRepositoryProvider);
    try {
      final id = await repo.create(
        NewProjectInput(
          name: _name,
          typeId: _typeId!,
          marketId: marketId,
          placeId: _placeId,
          start: _start,
          end: _end,
        ),
        now: ref.read(clockProvider)(),
      );
      await repo.addToCv(
        id,
        CvEntryInput(role: _role!, start: _start, end: _end),
      );
      if (!mounted) return;
      afterSave(context, ref);
      context.pushReplacement('/projects/$id');
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorGeneric)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final tag = locale.toLanguageTag();
    final marketId = ref.watch(myProfileProvider).value?.homeMarketId;
    final types = ref.watch(projectTypesProvider).value ?? const <RefOption>[];
    final places = marketId == null
        ? null
        : ref.watch(placesProvider(marketId)).value;
    final placeOptions = [
      for (final p in places ?? const []) RefOption(id: p.id, name: p.name),
    ];
    final now = ref.read(clockProvider)();
    String? labelOf(List<RefOption> list, String? id) =>
        list.where((o) => o.id == id).firstOrNull?.name.of(locale);

    return EntryScaffold(
      title: l10n.newProjectTitle,
      footer: Align(
        alignment: AlignmentDirectional.centerStart,
        child: BvButton(
          key: const Key('new-project-add'),
          label: l10n.addToCv,
          onPressed: _saving || marketId == null
              ? null
              : () => _create(marketId),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          BvTitleBlock(
            label: l10n.projectRecordLabel,
            stamp: l10n.draftStamp,
            rows: [
              [
                BvTitleCell(
                  key: const Key('cell-name'),
                  label: l10n.cellProjectName,
                  value: _name,
                  placeholder: l10n.projectNameHint,
                  error: _showErrors && _name.trim().length < 2,
                  onTap: () async {
                    final v = await showTextSheet(
                      context,
                      title: l10n.cellProjectName,
                      initial: _name,
                      hint: l10n.projectNameHint,
                    );
                    if (v != null && mounted) setState(() => _name = v);
                  },
                ),
              ],
              [
                BvTitleCell(
                  key: const Key('cell-type'),
                  label: l10n.cellType,
                  value: labelOf(types, _typeId),
                  placeholder: l10n.choose,
                  icon: BvIcons.caretDown,
                  error: _showErrors && _typeId == null,
                  onTap: () async {
                    final v = await showOptionSheet(
                      context,
                      title: l10n.wrongType,
                      options: types,
                      value: _typeId,
                    );
                    if (v != null && mounted) setState(() => _typeId = v);
                  },
                ),
                BvTitleCell(
                  key: const Key('cell-location'),
                  label: l10n.cellLocation,
                  value: labelOf(placeOptions, _placeId),
                  placeholder: l10n.choose,
                  icon: BvIcons.caretDown,
                  onTap: placeOptions.isEmpty
                      ? null
                      : () async {
                          final v = await showOptionSheet(
                            context,
                            title: l10n.wrongLocation,
                            options: placeOptions,
                            value: _placeId,
                          );
                          if (v != null && mounted) {
                            setState(() => _placeId = v);
                          }
                        },
                ),
              ],
              [
                BvTitleCell(
                  key: const Key('cell-started'),
                  label: l10n.cellStarted,
                  value: _start == null ? null : formatMonth(_start!, tag),
                  placeholder: l10n.choose,
                  icon: BvIcons.month,
                  onTap: () async {
                    final c = await showBvMonthSheet(
                      context,
                      title: l10n.startedLabel,
                      initial: _start,
                      now: now,
                    );
                    if (c is PickedMonth && mounted) {
                      setState(() => _start = c.month);
                    }
                  },
                ),
                BvTitleCell(
                  key: const Key('cell-ended'),
                  label: l10n.cellEnded,
                  value: _end == null ? l10n.present : formatMonth(_end!, tag),
                  icon: BvIcons.month,
                  onTap: () async {
                    final c = await showBvMonthSheet(
                      context,
                      title: l10n.endedLabel,
                      initial: _end,
                      allowStillGoing: true,
                      stillGoing: _end == null,
                      now: now,
                    );
                    if (!mounted || c == null) return;
                    setState(
                      () => _end = switch (c) {
                        PickedMonth(:final month) => month,
                        StillGoing() => null,
                      },
                    );
                  },
                ),
              ],
              [
                BvTitleCell(
                  key: const Key('cell-role'),
                  label: l10n.cellYourRole,
                  value: _role,
                  placeholder: l10n.headlineHint,
                  error: _showErrors && (_role ?? '').isEmpty,
                  onTap: () async {
                    final v = await showTextSheet(
                      context,
                      title: l10n.yourRole,
                      initial:
                          _role ?? ref.read(myProfileProvider).value?.headline,
                      hint: l10n.headlineHint,
                    );
                    if (v != null && mounted) setState(() => _role = v);
                  },
                ),
              ],
            ],
          ),
          Text(
            l10n.newProjectNote,
            style: BvType.of(
              context,
            ).bodySm.copyWith(color: BvColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
