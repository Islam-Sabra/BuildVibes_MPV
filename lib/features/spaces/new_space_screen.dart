import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/profile.dart';
import '../../data/models/space.dart';
import '../../data/repositories/profile_page_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/entry_scaffold.dart';
import '../profile/widgets/profile_parts.dart';
import 'link_project_sheet.dart';
import 'space_screen.dart';
import 'space_errors.dart';

/// S5 v2 · New Space, straight to the form (no S3 "kind of room"). Always
/// a private work Space; Create opens it on People with the invite screen.
class NewSpaceScreen extends ConsumerStatefulWidget {
  const NewSpaceScreen({super.key});

  static const nameMin = 2;
  static const nameMax = 80;
  static const aboutMax = 300;

  @override
  ConsumerState<NewSpaceScreen> createState() => _NewSpaceScreenState();
}

class _NewSpaceScreenState extends ConsumerState<NewSpaceScreen> {
  final _name = TextEditingController();
  final _about = TextEditingController();
  final _project = TextEditingController();
  CvProjectEntry? _linked;
  var _showErrors = false;
  var _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _about, _project]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _nameOk => _name.text.trim().length >= NewSpaceScreen.nameMin;

  Future<void> _pickProject() async {
    final me = ref.read(authUserIdProvider).value;
    if (me == null) return;
    final pick = await showLinkProjectSheet(
      context,
      me: me,
      selectedProjectId: _linked?.projectId,
    );
    if (!mounted || pick == null) return;
    if (pick is LinkAddProject) {
      // P13 "Is it already here?", then back here with the new project.
      final before = {for (final p in await _myProjects(me)) p.projectId};
      if (!mounted) return;
      await context.push(AppRoutes.projectsAdd);
      ref.invalidate(profileViewProvider(me));
      final after = await _myProjects(me);
      final added = after.where((p) => !before.contains(p.projectId));
      if (mounted && added.isNotEmpty) _setLinked(added.first);
      return;
    }
    if (pick is LinkProject) _setLinked(pick.entry);
  }

  Future<List<CvProjectEntry>> _myProjects(String me) async =>
      (await ref.read(profileViewProvider(me).future))?.projects ?? const [];

  void _setLinked(CvProjectEntry? entry) => setState(() {
    _linked = entry;
    _project.text = entry?.projectName ?? '';
  });

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    if (!_nameOk) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(spaceRepositoryProvider)
          .createSpace(
            name: _name.text,
            about: _about.text,
            projectId: _linked?.projectId,
          );
      ref.invalidate(mySpacesProvider);
      if (!mounted) return;
      context.pushReplacement(AppRoutes.space(id), extra: SpaceOpen.invite);
    } on SpaceException catch (e) {
      if (!mounted) return;
      if (e.failure == SpaceFailure.rule) {
        showSpaceMessage(context, l10n.spacesTooManyToday);
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
    return EntryScaffold(
      title: l10n.spacesNewTitle,
      footer: BvButton(
        key: const Key('create-space'),
        label: l10n.spacesCreateButton,
        expand: true,
        onPressed: _saving ? null : _create,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BvSpace.s8,
            children: [
              Text(
                l10n.spacesPreviewLabel,
                style: type.overline.copyWith(color: BvColors.textSecondary),
              ),
              _Preview(
                name: _name.text.trim(),
                about: _about.text.trim(),
                projectName: _linked?.projectName,
              ),
            ],
          ),
          BvTextField(
            key: const Key('space-name'),
            label: l10n.spacesNameLabel,
            placeholder: l10n.spacesNameHint,
            controller: _name,
            maxLength: NewSpaceScreen.nameMax,
            textInputAction: TextInputAction.next,
            error: _showErrors && !_nameOk ? l10n.spacesNameRequired : null,
            onChanged: (_) => setState(() {}),
          ),
          BvTextField(
            key: const Key('space-about'),
            label: l10n.spacesAboutLabel,
            helper: l10n.spacesAboutHelp,
            controller: _about,
            maxLines: 3,
            maxLength: NewSpaceScreen.aboutMax,
            onChanged: (_) => setState(() {}),
          ),
          BvTextField(
            key: const Key('space-project'),
            label: l10n.spacesLinkLabel,
            placeholder: l10n.spacesLinkPlaceholder,
            helper: l10n.spacesLinkHelp,
            controller: _project,
            readOnly: true,
            suffixIcon: BvIcons.caretDown,
            onTap: _pickProject,
          ),
        ],
      ),
    );
  }
}

/// How the Space will look to members: "Private work", and the project
/// when linked. Never a member count (rule 3).
class _Preview extends StatelessWidget {
  const _Preview({required this.name, required this.about, this.projectName});

  final String name;
  final String about;
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return ProfileCard(
      child: Row(
        key: const Key('space-preview'),
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpace.s12,
        children: [
          BvProjectAvatar(
            id: name.isEmpty ? 'space' : name,
            icon: BvIcons.crane,
            size: BvAvatarSize.lg,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BvSpace.s4,
              children: [
                Text(
                  name.isEmpty ? l10n.spacesNewTitle : name,
                  style: type.titleMd.copyWith(
                    color: name.isEmpty
                        ? BvColors.textSecondary
                        : BvColors.textPrimary,
                  ),
                ),
                if (about.isNotEmpty)
                  UserText(
                    about,
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  ),
                Wrap(
                  spacing: BvSpace.s8,
                  runSpacing: BvSpace.s4,
                  children: [
                    BvBadge(
                      label: l10n.spacesPrivateWork,
                      tone: BvBadgeTone.brand,
                      icon: BvIcons.lock,
                    ),
                    if (projectName != null) BvBadge(label: projectName!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
