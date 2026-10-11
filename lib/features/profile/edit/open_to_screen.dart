import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/bv_tokens.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/profile_page_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_button.dart';
import '../../../shared/widgets/bv_chip.dart';
import '../../../shared/widgets/bv_text_field.dart';
import '../../entry/widgets/entry_scaffold.dart';
import '../widgets/profile_parts.dart';
import 'edit_common.dart';

/// Open to: options (any number), a short note and who sees it.
class OpenToScreen extends ConsumerStatefulWidget {
  const OpenToScreen({super.key});

  @override
  ConsumerState<OpenToScreen> createState() => _OpenToScreenState();
}

class _OpenToScreenState extends ConsumerState<OpenToScreen> {
  final _note = TextEditingController();
  final _options = <String>{};
  var _showTo = ShowTo.everyone;
  var _filled = false;
  var _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final me = myId(ref);
    if (me == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profilePageRepositoryProvider)
          .saveOpenTo(
            me,
            OpenTo(
              // Keep the listed order.
              options: [
                for (final o in OpenTo.allOptions)
                  if (_options.contains(o)) o,
              ],
              note: _note.text,
              visibility: _showTo,
            ),
          );
      if (!mounted) return;
      afterSave(context, ref);
      context.pop();
    } on Exception {
      if (mounted) showSaveError(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = myId(ref);
    final p = me == null ? null : ref.watch(profileViewProvider(me)).value;
    if (p != null && !_filled) {
      _filled = true;
      final current = p.openTo;
      if (current != null) {
        _options.addAll(current.options);
        _note.text = current.note ?? '';
        _showTo = current.visibility;
      }
    }
    return EntryScaffold(
      title: l10n.openToTitle,
      footer: BvButton(
        key: const Key('open-to-save'),
        label: l10n.save,
        expand: true,
        onPressed: _saving ? null : _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          Wrap(
            spacing: BvSpace.s8,
            runSpacing: BvSpace.s8,
            children: [
              for (final o in OpenTo.allOptions)
                BvChip(
                  key: Key('open-to-$o'),
                  label: openToLabel(l10n, o),
                  selected: _options.contains(o),
                  onTap: () => setState(
                    () => _options.contains(o)
                        ? _options.remove(o)
                        : _options.add(o),
                  ),
                ),
            ],
          ),
          BvTextField(
            key: const Key('open-to-note'),
            label: l10n.openToNote,
            placeholder: l10n.openToNoteHint,
            controller: _note,
            maxLength: 200,
          ),
          Text(l10n.whoCanSee, style: BvType.of(context).labelLg),
          ShowToChoice(
            value: _showTo,
            onChanged: (v) => setState(() => _showTo = v),
          ),
        ],
      ),
    );
  }
}
