import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/text/fold_for_search.dart';
import '../../data/models/key_people.dart';
import '../../data/models/market.dart';
import '../../data/models/space.dart';
import '../../data/repositories/key_people_repository.dart';
import '../../data/repositories/market_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_section_scaffold.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import 'key_people.dart';
import 'space_errors.dart';
import 'widgets/space_person_row.dart';

/// Review 121 KP3: Space settings → Key people, for the Space admin. Each
/// role with its people and what to call them for, in the order the admin
/// sets (hold and drag); Add a role up to 6. The server checks it all.
class KeyPeopleScreen extends ConsumerStatefulWidget {
  const KeyPeopleScreen({super.key, required this.spaceId});

  final String spaceId;

  static const maxRoles = 6;

  @override
  ConsumerState<KeyPeopleScreen> createState() => _KeyPeopleScreenState();
}

class _KeyPeopleScreenState extends ConsumerState<KeyPeopleScreen> {
  /// The order just set here, until the server's comes back.
  List<KeyRole>? _moved;

  String get _spaceId => widget.spaceId;

  Future<void> _edit(KeyRole? role) async {
    final saved = await showKeyRoleSheet(
      context,
      spaceId: _spaceId,
      role: role,
    );
    if (saved && mounted) ref.invalidate(spaceKeyPeopleProvider(_spaceId));
  }

  Future<void> _reorder(List<KeyRole> roles, int from, int to) async {
    final moved = [...roles];
    moved.insert(to, moved.removeAt(from));
    setState(() => _moved = moved);
    try {
      await ref.read(keyPeopleRepositoryProvider).reorderRoles(_spaceId, [
        for (final r in moved) r.id,
      ]);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
    if (!mounted) return;
    ref.invalidate(spaceKeyPeopleProvider(_spaceId));
    await ref.read(spaceKeyPeopleProvider(_spaceId).future);
    if (mounted) setState(() => _moved = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final space = ref.watch(spaceDetailProvider(_spaceId)).value;
    final people = ref.watch(spaceKeyPeopleProvider(_spaceId));
    final roles = _moved ?? people.value?.roles;

    return BvSectionScaffold(
      title: l10n.keyPeopleTitle,
      subtitle: space?.name,
      body: roles == null
          ? (people.hasError
                ? Padding(
                    padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                    child: EmptyNote(l10n.errorGeneric),
                  )
                : const Center(child: CircularProgressIndicator()))
          : ReorderableListView(
              key: const Key('key-people-screen'),
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(horizontal: BvSpace.gutter),
              onReorderItem: (from, to) => unawaited(_reorder(roles, from, to)),
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (roles.length < KeyPeopleScreen.maxRoles)
                    InkWell(
                      key: const Key('key-people-add'),
                      onTap: () => _edit(null),
                      splashFactory: NoSplash.splashFactory,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          vertical: BvKeyPeopleSpec.rowPaddingVertical,
                        ),
                        child: Row(
                          spacing: BvSpace.s8,
                          children: [
                            const Icon(
                              BvIcons.add,
                              size: BvSize.iconMd,
                              color: BvColors.iconAction,
                            ),
                            Text(
                              l10n.keyPeopleAddRole,
                              style: type.emphasis.copyWith(
                                color: BvColors.textAction,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              children: [
                for (final (i, r) in roles.indexed)
                  ReorderableDelayedDragStartListener(
                    key: Key('key-role-${r.id}'),
                    index: i,
                    child: _RoleRow(role: r, onEdit: () => _edit(r)),
                  ),
              ],
            ),
    );
  }
}

/// A role on KP3: its tag, who holds it, what to call them for, and the
/// pencil.
class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.role, required this.onEdit});

  final KeyRole role;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final callFor = role.callFor;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BvColors.surfaceApp,
        border: Border(
          bottom: BorderSide(
            color: BvColors.borderDefault,
            width: BvStroke.thin,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: BvKeyPeopleSpec.rowPaddingVertical,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BvKeyPeopleSpec.lineGap,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: BvKeyPeopleSpec.tagBottom,
                    ),
                    child: KeyRoleTag(name: role.name),
                  ),
                  // Review 122 F1: what to call them for, above the people.
                  if (callFor != null)
                    Text(
                      inOwnDirection(callFor),
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  if (role.holders.isEmpty)
                    Text(
                      l10n.keyPeopleNoOne,
                      style: type.bodyMd.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  // Review 122: each holder on a line; under one who shares
                  // no number, why there is no Call.
                  for (final h in role.holders)
                    Column(
                      key: Key('key-role-holder-${role.id}-${h.person.id}'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inOwnDirection(h.person.fullName),
                          style: type.bodyMd,
                        ),
                        if (!h.canCall)
                          Text(
                            l10n.keyPeopleMessageOnly,
                            style: type.metadata.copyWith(
                              color: BvColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            IconButton(
              key: Key('key-role-edit-${role.id}'),
              tooltip: l10n.keyRoleEdit,
              onPressed: onEdit,
              icon: const Icon(
                BvIcons.edit,
                size: BvSize.iconMd,
                color: BvColors.iconSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// KP4: a new key role ([role] null) or a change to one. The name, with
/// the market pack's names to tap (rule 5); what to call them for; who
/// holds it, up to 2, members only, each with a short note. True when
/// saved or deleted.
Future<bool> showKeyRoleSheet(
  BuildContext context, {
  required String spaceId,
  KeyRole? role,
}) async {
  final l10n = AppLocalizations.of(context);
  final done = await showBvSheet<bool>(
    context: context,
    title: role == null ? l10n.keyRoleNew : l10n.keyRoleEdit,
    form: true,
    builder: (_) => _KeyRoleForm(spaceId: spaceId, role: role),
  );
  return done ?? false;
}

class _KeyRoleForm extends ConsumerStatefulWidget {
  const _KeyRoleForm({required this.spaceId, required this.role});

  final String spaceId;
  final KeyRole? role;

  static const maxHolders = 2;

  @override
  ConsumerState<_KeyRoleForm> createState() => _KeyRoleFormState();
}

typedef _Holder = ({SpacePerson person, String? note});

class _KeyRoleFormState extends ConsumerState<_KeyRoleForm> {
  late final _name = TextEditingController(text: widget.role?.name ?? '');
  late final _callFor = TextEditingController(text: widget.role?.callFor ?? '');
  late final _holders = <_Holder>[
    for (final h in widget.role?.holders ?? const <KeyHolder>[])
      (person: h.person, note: h.note),
  ];
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _callFor.dispose();
    super.dispose();
  }

  /// The Space's market pack, else my own.
  Market? _market() {
    final markets = ref.watch(marketsProvider).value ?? const <Market>[];
    final space = ref.watch(spaceDetailProvider(widget.spaceId)).value;
    final mine = ref.watch(myProfileProvider).value?.homeMarketId;
    final id = space?.marketId ?? mine;
    return markets.where((m) => m.id == id).firstOrNull;
  }

  Future<void> _addPerson() async {
    final SpacePeople people;
    try {
      people = await ref.read(spacePeopleProvider(widget.spaceId).future);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    if (!mounted) return;
    final taken = {for (final h in _holders) h.person.id};
    final picked = await showBvSheet<SpacePerson>(
      context: context,
      title: AppLocalizations.of(context).keyRoleAddPerson,
      builder: (sheet) => ClipRRect(
        borderRadius: BvRadius.cardAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in people.members)
              if (!taken.contains(m.person.id))
                SpacePersonRow(
                  key: Key('key-pick-${m.person.id}'),
                  person: m.person,
                  onTap: () => Navigator.of(sheet).pop(m.person),
                ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _holders.add((person: picked, note: null)));
    }
  }

  Future<void> _editNote(int i) async {
    final h = _holders[i];
    final note = await showBvSheet<String>(
      context: context,
      form: true,
      title: inOwnDirection(h.person.fullName),
      builder: (_) => _NoteForm(note: h.note),
    );
    if (note != null && mounted) {
      setState(() => _holders[i] = (person: h.person, note: note));
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(keyPeopleRepositoryProvider)
          .saveRole(
            widget.spaceId,
            roleId: widget.role?.id,
            name: _name.text.trim(),
            // The server keeps an empty line as none.
            callFor: _callFor.text,
            holders: [
              for (final h in _holders) (profileId: h.person.id, note: h.note),
            ],
          );
      if (mounted) Navigator.of(context).pop(true);
    } on SpaceException catch (e) {
      if (!mounted) return;
      switch (e.failure) {
        case SpaceFailure.limit:
          showSpaceMessage(context, l10n.keyRoleTooMany);
        case SpaceFailure.badInput:
          showSpaceMessage(context, l10n.keyRoleGone);
          ref.invalidate(spacePeopleProvider(widget.spaceId));
        default:
          showSpaceError(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final role = widget.role!;
    final l10n = AppLocalizations.of(context);
    final yes = await showBvDialog(
      context: context,
      title: l10n.keyRoleDeleteAsk(inOwnDirection(role.name)),
      body: l10n.keyRoleDeleteBody,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!yes || !mounted) return;
    try {
      await ref.read(keyPeopleRepositoryProvider).deleteRole(role.id);
      if (mounted) Navigator.of(context).pop(true);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final label = type.metadata.copyWith(color: BvColors.textSecondary);
    final name = _name.text.trim();
    // Review 122b: the name is free; the market pack's examples narrow to
    // what is typed, in either language.
    final typed = foldForSearch(name);
    final suggestions = [
      for (final s in _market()?.keyRoleSuggestions ?? const <LocalizedText>[])
        if (foldForSearch(s.en).contains(typed) ||
            foldForSearch(s.ar).contains(typed))
          lang == 'ar' && s.ar.isNotEmpty ? s.ar : s.en,
    ];

    final fields = Column(
      key: const Key('key-role-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        BvTextField(
          key: const Key('key-role-name'),
          controller: _name,
          placeholder: l10n.keyRoleNameHint,
          autofocus: widget.role == null,
          maxLength: 40,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
        ),
        if (suggestions.isNotEmpty)
          Wrap(
            spacing: BvPeopleSpec.chipGap,
            runSpacing: BvPeopleSpec.chipGap,
            children: [
              for (final s in suggestions)
                BvChip(
                  label: s,
                  selected: s == name,
                  icon: s == name ? BvIcons.check : null,
                  onTap: () => _name.text = s,
                ),
            ],
          ),
        Text(l10n.keyRoleCallFor, style: label),
        BvTextField(
          key: const Key('key-role-call-for'),
          controller: _callFor,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
        ),
        Text(l10n.keyRoleHolders, style: label),
        Material(
          color: BvColors.surfaceApp,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, h) in _holders.indexed)
                _HolderRow(
                  key: Key('key-holder-${h.person.id}'),
                  person: h.person,
                  line: _holderLine(h, lang),
                  onTap: () => _editNote(i),
                  remove: IconButton(
                    key: Key('key-holder-remove-${h.person.id}'),
                    tooltip: l10n.keyRoleRemovePerson,
                    onPressed: () => setState(() => _holders.removeAt(i)),
                    icon: const Icon(
                      BvIcons.close,
                      size: BvSize.iconMd,
                      color: BvColors.iconSecondary,
                    ),
                  ),
                ),
              if (_holders.length < _KeyRoleForm.maxHolders)
                BvListRow(
                  key: const Key('key-role-add-person'),
                  leading: const BvRowIcon(BvIcons.add),
                  title: l10n.keyRoleAddPerson,
                  trailing: const BvRowTrailing.none(),
                  onTap: _addPerson,
                ),
            ],
          ),
        ),
      ],
    );
    return BvSheetForm(
      gap: BvSpace.s24,
      body: fields,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s8,
        children: [
          BvButton(
            key: const Key('key-role-save'),
            label: l10n.save,
            expand: true,
            onPressed: name.isEmpty || _saving ? null : _save,
          ),
          if (widget.role != null)
            BvButton(
              key: const Key('key-role-delete'),
              label: l10n.keyRoleDelete,
              style: BvButtonStyle.destructive,
              expand: true,
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
    );
  }

  /// "Day shift · Safety · NBKCH": the note, then title · company.
  String _holderLine(_Holder h, String lang) => joinMeta([
    if ((h.note ?? '').isNotEmpty) inOwnDirection(h.note!),
    ?h.person.roleLabel(lang),
    ?h.person.companyLabel,
  ]);
}

/// KP4: a holder, on the page: face, name, and "Day shift · Safety ·
/// NBKCH"; a tap changes the note.
class _HolderRow extends StatelessWidget {
  const _HolderRow({
    super.key,
    required this.person,
    required this.line,
    required this.onTap,
    required this.remove,
  });

  final SpacePerson person;
  final String line;
  final VoidCallback onTap;
  final Widget remove;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: BvColors.borderDefault,
              width: BvStroke.thin,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: BvKeyPeopleSpec.rowPaddingVertical,
          ),
          child: Row(
            spacing: BvKeyPeopleSpec.faceGap,
            children: [
              BvAvatar(
                name: person.fullName,
                size: BvAvatarSize.xsm,
                tint: BvAvatarTints.forId(person.id),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s2,
                  children: [
                    Text(
                      inOwnDirection(person.fullName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodyMd,
                    ),
                    if (line.isNotEmpty)
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              remove,
            ],
          ),
        ),
      ),
    );
  }
}

/// A holder's short note ("Night shift"), 24 characters at most.
class _NoteForm extends StatefulWidget {
  const _NoteForm({required this.note});

  final String? note;

  @override
  State<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<_NoteForm> {
  late final _note = TextEditingController(text: widget.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(_note.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BvSheetForm(
      gap: BvSpace.s16,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          BvTextField(
            key: const Key('key-holder-note-field'),
            controller: _note,
            placeholder: l10n.keyRoleNoteHint,
            maxLength: 24,
            autofocus: true,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
      action: BvButton(
        key: const Key('key-holder-note-save'),
        label: l10n.save,
        expand: true,
        onPressed: _done,
      ),
    );
  }
}
