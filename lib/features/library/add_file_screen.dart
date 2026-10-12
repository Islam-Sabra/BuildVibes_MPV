import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/chat.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_choice_card.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../chat/chat_tab.dart' show threadName;
import '../entry/widgets/entry_scaffold.dart';
import '../entry/entry_state.dart';
import '../spaces/space_errors.dart';
import 'library_parts.dart';

/// S13k "Add file", and F1 "Upload a new revision" ([supersedesId]): a PDF
/// or photo, its title, who sees it (Everyone or one Team), a revision
/// label and a note. Pops with the new file's id.
class AddFileScreen extends ConsumerStatefulWidget {
  const AddFileScreen({
    super.key,
    required this.spaceId,
    this.supersedesId,
    this.forTeam,
  });

  final String spaceId;
  final String? supersedesId;

  /// Fixes who sees it (a Team id, or [AppRoutes.forEveryone]): a file
  /// attached to a work item must fit that item.
  final String? forTeam;

  @override
  ConsumerState<AddFileScreen> createState() => _AddFileScreenState();
}

class _AddFileScreenState extends ConsumerState<AddFileScreen> {
  final _name = TextEditingController();
  final _rev = TextEditingController();
  final _note = TextEditingController();
  PhoneFile? _file;

  /// Null is Everyone.
  late String? _teamId = widget.forTeam == AppRoutes.forEveryone
      ? null
      : widget.forTeam;
  String? _error;
  var _saving = false;
  var _teamFromOlder = false;

  @override
  void dispose() {
    _name.dispose();
    _rev.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final l10n = AppLocalizations.of(context);
    final picked = await ref.read(pickDocumentProvider)();
    if (picked == null || !mounted) return;
    if ((picked.bytes ?? 0) > maxFileBytes) {
      setState(() => _error = l10n.chatFileTooBig);
      return;
    }
    setState(() {
      _file = picked;
      _error = null;
      if (_name.text.trim().isEmpty) {
        _name.text = titleFromFileName(picked.name);
      }
    });
  }

  Future<void> _save(LibraryFile? older) async {
    final l10n = AppLocalizations.of(context);
    final file = _file;
    if (file == null) {
      setState(() => _error = l10n.libraryPickFirst);
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.libraryNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(libraryRepositoryProvider);
    final navigator = Navigator.of(context);
    try {
      final id = newUuid();
      final path = await repo.upload(widget.spaceId, id, file);
      // The stored name keeps the type, so a download opens with the
      // right app.
      final ext = '.${file.extension}';
      await repo.add(
        id: id,
        spaceId: widget.spaceId,
        name: name.toLowerCase().endsWith(ext) ? name : '$name$ext',
        path: path,
        mime: file.mime,
        bytes: file.bytes,
        teamId: older?.teamId ?? _teamId,
        revLabel: _rev.text.trim().isEmpty ? null : _rev.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        supersedesId: older?.id,
      );
      ref.invalidate(libraryFilesProvider(widget.spaceId));
      if (older != null) ref.invalidate(libraryFileProvider(older.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.libraryAdded)));
      navigator.pop(id);
    } on SpaceException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSpaceError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final space = ref.watch(spaceDetailProvider(widget.spaceId)).value;
    final people = ref.watch(spacePeopleProvider(widget.spaceId)).value;
    final me = ref.watch(authUserIdProvider).value;
    final older = widget.supersedesId == null
        ? null
        : ref.watch(libraryFileProvider(widget.supersedesId!)).value?.file;
    if (older != null && !_teamFromOlder) {
      _teamFromOlder = true;
      _teamId = older.teamId;
    }

    // Teams you may add for: yours, or all of them as a Space admin.
    final teams = [
      for (final t in people?.teams ?? const <SpaceTeam>[])
        if ((space?.iAmAdmin ?? false) || t.memberIds.contains(me)) t,
    ];
    final teamName = teams.where((t) => t.id == _teamId).firstOrNull?.name;
    final file = _file;

    return EntryScaffold(
      title: older == null ? l10n.libraryAddTitle : l10n.libraryRevisionTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          if (older != null)
            Text(
              l10n.libraryRevisionOf(older.name),
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
          if (file == null)
            BvButton(
              key: const Key('add-file-pick'),
              label: l10n.libraryPickFile,
              style: BvButtonStyle.secondary,
              expand: true,
              onPressed: _pick,
            )
          else ...[
            DecoratedBox(
              decoration: const BoxDecoration(
                color: BvColors.surfaceElevated,
                borderRadius: BvRadius.cardAll,
              ),
              child: BvListRow(
                key: const Key('add-file-picked'),
                title: file.name,
                subtitle: fileSize(l10n, file.bytes),
                leading: BvRowIcon(
                  file.isPdf ? BvIcons.document : BvIcons.image,
                  ink: true,
                ),
                trailing: const BvRowTrailing.none(),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BvButton(
                key: const Key('add-file-change'),
                label: l10n.libraryChangeFile,
                style: BvButtonStyle.tertiary,
                size: BvButtonSize.medium,
                padded: false,
                onPressed: _pick,
              ),
            ),
          ],
          BvTextField(
            key: const Key('add-file-name'),
            label: l10n.libraryName,
            controller: _name,
            maxLength: 120,
          ),
          if (older == null && widget.forTeam == null && teams.isNotEmpty) ...[
            Text(l10n.libraryFor, style: type.labelMd),
            // Everyone or one Team: one single choice (rule 6).
            BvChoiceList<String>(
              value: _teamId ?? '',
              options: [
                BvChoiceOption(
                  key: const Key('add-file-everyone'),
                  value: '',
                  title: l10n.chatEveryone,
                ),
                for (final t in teams)
                  BvChoiceOption(
                    key: Key('add-file-team-${t.id}'),
                    value: t.id,
                    title: threadName(
                      l10n,
                      ChatThread(id: '', teamId: t.id, teamName: t.name),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _teamId = v.isEmpty ? null : v),
            ),
          ],
          if (teamName != null)
            Text(
              l10n.libraryTeamOnly(teamName),
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
          BvTextField(
            key: const Key('add-file-rev'),
            label: l10n.libraryRev,
            placeholder: l10n.libraryRevHint,
            controller: _rev,
            maxLength: 20,
          ),
          BvTextField(
            key: const Key('add-file-note'),
            label: l10n.workNote,
            placeholder: l10n.libraryNoteHint,
            controller: _note,
            maxLines: 3,
            maxLength: 300,
          ),
          if (_error != null)
            Text(
              _error!,
              style: type.bodySm.copyWith(color: BvColors.textDestructive),
            ),
        ],
      ),
      footer: BvButton(
        key: const Key('add-file-upload'),
        label: l10n.libraryUpload,
        expand: true,
        onPressed: _saving ? null : () => _save(older),
      ),
    );
  }
}
