import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/bv_icons.dart';
import '../../../core/design/bv_tokens.dart';
import '../../../core/l10n/months.dart';
import '../../../data/models/project.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_button.dart';
import '../../../shared/widgets/bv_chip.dart';
import '../../../shared/widgets/bv_choice_card.dart';
import '../../../shared/widgets/bv_month_sheet.dart';
import '../../../shared/widgets/bv_sheet.dart';
import '../../../shared/widgets/bv_text_field.dart';
import '../../profile/edit/experience_screens.dart';

/// A sheet with one text field and Save. Returns the text, or null.
Future<String?> showTextSheet(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
  int maxLength = 120,
}) {
  return showBvSheet<String>(
    context: context,
    title: title,
    builder: (_) =>
        _TextSheet(initial: initial, hint: hint, maxLength: maxLength),
  );
}

class _TextSheet extends StatefulWidget {
  const _TextSheet({this.initial, this.hint, required this.maxLength});

  final String? initial;
  final String? hint;
  final int maxLength;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s16,
      children: [
        BvTextField(
          key: const Key('text-sheet-field'),
          controller: _text,
          placeholder: widget.hint,
          autofocus: true,
          maxLength: widget.maxLength,
          onChanged: (_) => setState(() {}),
        ),
        BvButton(
          key: const Key('text-sheet-save'),
          label: l10n.save,
          expand: true,
          onPressed: _text.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_text.text.trim()),
        ),
      ],
    );
  }
}

/// A single-choice sheet over reference options (project type, place).
Future<String?> showOptionSheet(
  BuildContext context, {
  required String title,
  required List<RefOption> options,
  String? value,
}) {
  final locale = Localizations.localeOf(context);
  return showBvSheet<String>(
    context: context,
    title: title,
    builder: (sheetContext) => BvChoiceList<String>(
      value: value,
      options: [
        for (final o in options)
          BvChoiceOption(
            key: Key('option-${o.id}'),
            value: o.id,
            title: o.name.of(locale),
          ),
      ],
      onChanged: (v) => Navigator.of(sheetContext).pop(v),
    ),
  );
}

/// "Your role on {project}": role and dates, then Add to my CV.
Future<CvEntryInput?> showCvEntrySheet(
  BuildContext context, {
  required String projectName,
  String? role,
}) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<CvEntryInput>(
    context: context,
    title: l10n.cvEntryTitle(projectName),
    builder: (_) => _CvEntryForm(role: role),
  );
}

class _CvEntryForm extends ConsumerStatefulWidget {
  const _CvEntryForm({this.role});

  final String? role;

  @override
  ConsumerState<_CvEntryForm> createState() => _CvEntryFormState();
}

class _CvEntryFormState extends ConsumerState<_CvEntryForm> {
  late final _role = TextEditingController(text: widget.role);
  final _startText = TextEditingController();
  final _endText = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  var _showErrors = false;

  @override
  void dispose() {
    for (final c in [_role, _startText, _endText]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = ref.read(clockProvider)();
    _startText.text = _start == null ? '' : formatMonth(_start!, locale);
    _endText.text = _end == null ? l10n.present : formatMonth(_end!, locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s16,
      children: [
        BvTextField(
          key: const Key('cv-role'),
          label: l10n.yourRole,
          placeholder: l10n.headlineHint,
          controller: _role,
          error: _showErrors && _role.text.trim().isEmpty
              ? l10n.roleTitleRequired
              : null,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BvSpace.s12,
          children: [
            Expanded(
              child: BvTextField(
                key: const Key('cv-start'),
                label: l10n.startedLabel,
                controller: _startText,
                readOnly: true,
                suffixIcon: BvIcons.month,
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
            ),
            Expanded(
              child: BvTextField(
                key: const Key('cv-end'),
                label: l10n.endedLabel,
                controller: _endText,
                readOnly: true,
                suffixIcon: BvIcons.month,
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
            ),
          ],
        ),
        BvButton(
          key: const Key('cv-add'),
          label: l10n.addToCv,
          expand: true,
          onPressed: () {
            if (_role.text.trim().isEmpty) {
              setState(() => _showErrors = true);
              return;
            }
            Navigator.of(
              context,
            ).pop(CvEntryInput(role: _role.text, start: _start, end: _end));
          },
        ),
      ],
    );
  }
}

/// PJ1-E · Suggest an edit: what's wrong, and the correct value. It goes to
/// back-office review. Returns the field and value, or null.
Future<(EditField, String)?> showSuggestEditSheet(
  BuildContext context, {
  required String projectName,
}) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<(EditField, String)>(
    context: context,
    title: l10n.suggestTitle(projectName),
    subtitle: l10n.suggestBody,
    builder: (_) => const _SuggestForm(),
  );
}

class _SuggestForm extends StatefulWidget {
  const _SuggestForm();

  @override
  State<_SuggestForm> createState() => _SuggestFormState();
}

class _SuggestFormState extends State<_SuggestForm> {
  final _value = TextEditingController();
  var _field = EditField.name;
  var _showErrors = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final labels = {
      EditField.name: l10n.wrongName,
      EditField.type: l10n.wrongType,
      EditField.location: l10n.wrongLocation,
      EditField.dates: l10n.wrongDates,
      EditField.duplicate: l10n.wrongDuplicate,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s12,
      children: [
        Text(
          l10n.whatsWrong,
          style: type.overline.copyWith(color: BvColors.textSecondary),
        ),
        // One choice: chips that exclude each other.
        Semantics(
          container: true,
          child: Wrap(
            spacing: BvSpace.s8,
            runSpacing: BvSpace.s8,
            children: [
              for (final e in labels.entries)
                BvChip(
                  key: Key('wrong-${e.key.name}'),
                  label: e.value,
                  selected: _field == e.key,
                  onTap: () => setState(() => _field = e.key),
                ),
            ],
          ),
        ),
        BvTextField(
          key: const Key('suggest-value'),
          label: l10n.correctValue,
          controller: _value,
          helper: l10n.correctValueHelp,
          maxLength: 300,
          error: _showErrors && _value.text.trim().isEmpty
              ? l10n.correctValueRequired
              : null,
        ),
        BvButton(
          key: const Key('suggest-send'),
          label: l10n.sendForReview,
          expand: true,
          onPressed: () {
            if (_value.text.trim().isEmpty) {
              setState(() => _showErrors = true);
              return;
            }
            Navigator.of(context).pop((_field, _value.text.trim()));
          },
        ),
      ],
    );
  }
}
