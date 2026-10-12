import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_controls.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/widgets/entry_scaffold.dart';
import 'space_errors.dart';
import 'widgets/space_person_row.dart';

/// S12 · New Team: a name and members picked from this Space. Admins only.
class NewTeamScreen extends ConsumerStatefulWidget {
  const NewTeamScreen({super.key, required this.spaceId});

  final String spaceId;

  static const nameMax = 40;

  @override
  ConsumerState<NewTeamScreen> createState() => _NewTeamScreenState();
}

class _NewTeamScreenState extends ConsumerState<NewTeamScreen> {
  final _name = TextEditingController();
  final _members = <String>{};
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = l10n.spacesTeamNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(spaceRepositoryProvider)
          .createTeam(
            widget.spaceId,
            name: _name.text,
            memberIds: _members.toList(),
          );
      ref.invalidate(spacePeopleProvider(widget.spaceId));
      if (mounted) {
        context.pushReplacement(AppRoutes.spaceTeam(widget.spaceId, id));
      }
    } on SpaceException catch (e) {
      if (!mounted) return;
      if (e.failure == SpaceFailure.duplicate) {
        setState(() => _error = l10n.spacesTeamDuplicate);
      } else {
        showSpaceError(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final members =
        ref.watch(spacePeopleProvider(widget.spaceId)).value?.members ??
        const <SpaceMember>[];

    return EntryScaffold(
      title: l10n.spacesNewTeam,
      bodyPadding: const EdgeInsetsDirectional.symmetric(vertical: BvSpace.s16),
      footer: BvButton(
        key: const Key('create-team'),
        label: l10n.spacesCreateTeam(_members.length),
        expand: true,
        onPressed: _saving ? null : _create,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.gutter,
            ),
            child: BvTextField(
              key: const Key('team-name'),
              label: l10n.spacesTeamName,
              placeholder: l10n.spacesTeamNameHint,
              helper: l10n.spacesTeamHelp,
              error: _error,
              controller: _name,
              maxLength: NewTeamScreen.nameMax,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.gutter,
            ),
            child: Text(l10n.spacesAddMembers, style: type.titleMd),
          ),
          TeamMemberPicker(
            members: members,
            selected: _members,
            onChanged: (id, on) => setState(() {
              if (on) {
                _members.add(id);
              } else {
                _members.remove(id);
              }
            }),
          ),
        ],
      ),
    );
  }
}

/// The Space's members with a checkbox each (S12, S11k Add people).
class TeamMemberPicker extends StatelessWidget {
  const TeamMemberPicker({
    super.key,
    required this.members,
    required this.selected,
    required this.onChanged,
  });

  final List<SpaceMember> members;
  final Set<String> selected;
  final void Function(String profileId, bool on) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < members.length; i++) ...[
          if (i > 0) const SpaceRowDivider(),
          Builder(
            builder: (context) {
              final id = members[i].person.id;
              final on = selected.contains(id);
              return SpacePersonRow(
                key: Key('pick-$id'),
                person: members[i].person,
                trailing: BvCheckbox(
                  value: on,
                  onChanged: (v) => onChanged(id, v),
                ),
                onTap: () => onChanged(id, !on),
              );
            },
          ),
        ],
      ],
    );
  }
}
