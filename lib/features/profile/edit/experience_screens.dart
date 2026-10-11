import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/bv_icons.dart';
import '../../../core/design/bv_tokens.dart';
import '../../../core/l10n/months.dart';
import '../../../core/routing/app_routes.dart';
import '../../../data/models/people.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/profile_page_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_button.dart';
import '../../../shared/widgets/bv_month_sheet.dart';
import '../../../shared/widgets/bv_text_field.dart';
import '../../entry/widgets/entry_scaffold.dart';
import '../../onboarding/company_sheet.dart';
import '../widgets/profile_parts.dart';
import 'edit_common.dart';

/// Today, overridden in tests so month pickers are stable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The list of experience entries, with Add.
class ExperienceListScreen extends ConsumerWidget {
  const ExperienceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = myId(ref);
    final p = me == null ? null : ref.watch(profileViewProvider(me)).value;
    final entries = p?.experience ?? const <ExperienceEntry>[];
    return EntryScaffold(
      title: l10n.profileTabExperience,
      footer: BvButton(
        key: const Key('experience-add'),
        label: l10n.experienceAdd,
        icon: BvIcons.create,
        expand: true,
        onPressed: () => context.push(AppRoutes.profileEditExperienceForm),
      ),
      body: entries.isEmpty
          ? EmptyNote(l10n.experienceEmpty)
          : DividedColumn(
              children: [
                for (final e in entries)
                  ExperienceRow(
                    entry: e,
                    onTap: () => context.push(
                      AppRoutes.profileEditExperienceForm,
                      extra: e,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Add or edit one experience entry: title, company, dates and who sees it.
class ExperienceFormScreen extends ConsumerStatefulWidget {
  const ExperienceFormScreen({super.key, this.entry});

  /// Null to add a new entry.
  final ExperienceEntry? entry;

  @override
  ConsumerState<ExperienceFormScreen> createState() =>
      _ExperienceFormScreenState();
}

class _ExperienceFormScreenState extends ConsumerState<ExperienceFormScreen> {
  late final _title = TextEditingController(text: widget.entry?.title);
  late final _companyText = TextEditingController(
    text: widget.entry?.companyLabel,
  );
  final _startText = TextEditingController();
  final _endText = TextEditingController();
  late CompanyPick _company = widget.entry?.companyLabel == null
      ? const CompanyPick.none()
      : widget.entry!.companyId != null
      ? CompanyPick.registered(
          CompanySummary(
            id: widget.entry!.companyId!,
            name: widget.entry!.companyLabel!,
          ),
        )
      : CompanyPick.typed(widget.entry!.companyLabel!);
  late DateTime? _start = widget.entry?.start;
  late DateTime? _end = widget.entry?.end;
  late ShowTo _showTo = widget.entry?.visibility ?? ShowTo.everyone;
  var _showErrors = false;
  var _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _companyText, _startText, _endText]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStart() async {
    final choice = await showBvMonthSheet(
      context,
      title: AppLocalizations.of(context).startedLabel,
      initial: _start,
      now: ref.read(clockProvider)(),
    );
    if (choice is PickedMonth && mounted) {
      setState(() => _start = choice.month);
    }
  }

  Future<void> _pickEnd() async {
    final choice = await showBvMonthSheet(
      context,
      title: AppLocalizations.of(context).endedLabel,
      initial: _end,
      allowStillGoing: true,
      stillGoing: _end == null,
      now: ref.read(clockProvider)(),
    );
    if (!mounted || choice == null) return;
    setState(
      () => _end = switch (choice) {
        PickedMonth(:final month) => month,
        StillGoing() => null,
      },
    );
  }

  Future<void> _save() async {
    final me = myId(ref);
    if (me == null) return;
    if (_title.text.trim().isEmpty || _start == null) {
      setState(() => _showErrors = true);
      return;
    }
    final input = ExperienceInput(
      title: _title.text,
      start: _start!,
      end: _end,
      companyId: _company.companyId,
      companyNameText: _company.companyId == null ? _company.name : null,
      visibility: _showTo,
    );
    setState(() => _saving = true);
    final repo = ref.read(profilePageRepositoryProvider);
    try {
      if (widget.entry == null) {
        await repo.addExperience(me, input);
      } else {
        await repo.updateExperience(widget.entry!.id, input);
      }
      if (!mounted) return;
      afterSave(context, ref);
      context.pop();
    } on Exception {
      if (mounted) showSaveError(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    await ref
        .read(profilePageRepositoryProvider)
        .deleteExperience(widget.entry!.id);
    if (!mounted) return;
    afterSave(context, ref);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    _startText.text = _start == null ? '' : formatMonth(_start!, locale);
    _endText.text = _end == null ? l10n.present : formatMonth(_end!, locale);

    return EntryScaffold(
      title: widget.entry == null ? l10n.experienceAdd : l10n.experienceEdit,
      footer: BvButton(
        key: const Key('experience-save'),
        label: l10n.save,
        expand: true,
        onPressed: _saving ? null : _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          BvTextField(
            key: const Key('experience-title'),
            label: l10n.titleLabel,
            placeholder: l10n.headlineHint,
            controller: _title,
            error: _showErrors && _title.text.trim().isEmpty
                ? l10n.titleRequired
                : null,
          ),
          BvTextField(
            key: const Key('experience-company'),
            label: l10n.companyOptional,
            placeholder: l10n.companyPlaceholder,
            controller: _companyText,
            readOnly: true,
            suffixIcon: BvIcons.caretDown,
            onTap: () async {
              final pick = await showCompanySheet(
                context,
                marketId: null,
                initialQuery: _company.name,
              );
              if (pick == null || !mounted) return;
              setState(() {
                _company = pick;
                _companyText.text = pick.name ?? '';
              });
            },
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvSpace.s12,
            children: [
              Expanded(
                child: BvTextField(
                  key: const Key('experience-start'),
                  label: l10n.startedLabel,
                  controller: _startText,
                  readOnly: true,
                  suffixIcon: BvIcons.month,
                  onTap: _pickStart,
                  error: _showErrors && _start == null
                      ? l10n.startRequired
                      : null,
                ),
              ),
              Expanded(
                child: BvTextField(
                  key: const Key('experience-end'),
                  label: l10n.endedLabel,
                  controller: _endText,
                  readOnly: true,
                  suffixIcon: BvIcons.month,
                  onTap: _pickEnd,
                ),
              ),
            ],
          ),
          Text(l10n.whoCanSee, style: BvType.of(context).labelLg),
          ShowToChoice(
            value: _showTo,
            onChanged: (v) => setState(() => _showTo = v),
          ),
          if (widget.entry != null)
            BvButton(
              key: const Key('experience-delete'),
              label: l10n.delete,
              icon: BvIcons.delete,
              style: BvButtonStyle.destructive,
              expand: true,
              onPressed: _delete,
            ),
        ],
      ),
    );
  }
}
