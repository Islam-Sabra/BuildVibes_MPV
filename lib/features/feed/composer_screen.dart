import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/post.dart';
import '../../data/models/space.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/profile_page_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_choice_card.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../entry/entry_state.dart';
import '../spaces/space_errors.dart';
import '../work/work_outbox.dart' show keepPhotoProvider, pickPhotoProvider;
import 'feed_state.dart';

/// C1 v2 → C2 v2 · New post, or Edit post ([editId]: the text and its
/// language only).
class ComposerScreen extends ConsumerStatefulWidget {
  const ComposerScreen({super.key, this.editId});

  final String? editId;

  @override
  ConsumerState<ComposerScreen> createState() => _ComposerScreenState();
}

/// The post language: detected from the letters, or chosen (L6).
enum _Lang { auto, en, ar }

class _ComposerScreenState extends ConsumerState<ComposerScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _photos = <String>[];
  ({String id, String name})? _project;
  var _lang = _Lang.auto;
  var _loaded = false;
  var _saving = false;

  bool get _editing => widget.editId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) unawaited(_loadPost());
  }

  Future<void> _loadPost() async {
    final post = await ref.read(postProvider(widget.editId!).future);
    if (!mounted || post == null) return;
    setState(() {
      _text.text = post.body ?? '';
      _lang = post.lang == 'ar' ? _Lang.ar : _Lang.en;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _postLang => switch (_lang) {
    _Lang.en => 'en',
    _Lang.ar => 'ar',
    _Lang.auto => detectLang(_text.text),
  };

  bool get _hasContent => _text.text.trim().isNotEmpty || _photos.isNotEmpty;

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _addPhoto() async {
    _unfocus();
    final l10n = AppLocalizations.of(context);
    if (_photos.length >= BvPostSpec.maxPhotos) {
      _toast(l10n.composerPhotosMax);
      return;
    }
    final picked = await ref.read(pickPhotoProvider)(camera: false);
    if (picked == null || !mounted) return;
    final kept = await ref.read(keepPhotoProvider)(picked);
    if (mounted) setState(() => _photos.add(kept));
  }

  /// C10: projects on your CV with a confirmed role, shown on your profile.
  Future<void> _tagProject() async {
    _unfocus();
    final l10n = AppLocalizations.of(context);
    final me = ref.read(authUserIdProvider).value;
    if (me == null) return;
    final profile = await ref.read(profileViewProvider(me).future);
    if (!mounted) return;
    final mine = [
      for (final c in profile?.projects ?? const [])
        if (c.confirmed && c.showOnProfile) c,
    ];
    final picked = await showBvSheet<({String id, String name})?>(
      context: context,
      title: l10n.tagTitle,
      subtitle: l10n.tagHelp,
      builder: (sheet) => Column(
        key: const Key('composer-tag-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s12,
        children: [
          ClipRRect(
            borderRadius: BvRadius.cardAll,
            child: BvListGroup(
              rows: [
                if (mine.isEmpty)
                  BvListRow(
                    key: const Key('composer-tag-empty'),
                    leading: const BvRowIcon(BvIcons.create),
                    title: l10n.tagEmpty,
                    onTap: () {
                      Navigator.of(sheet).pop();
                      context.push(AppRoutes.projectsAdd);
                    },
                  ),
                for (final c in mine)
                  BvListRow(
                    key: Key('composer-tag-${c.projectId}'),
                    leading: const BvRowIcon(BvIcons.crane),
                    title: inOwnDirection(c.projectName),
                    subtitle: c.role,
                    trailing: BvRowTrailing.check(
                      selected: _project?.id == c.projectId,
                    ),
                    onTap: () => Navigator.of(
                      sheet,
                    ).pop((id: c.projectId, name: c.projectName)),
                  ),
                if (_project != null)
                  BvListRow(
                    key: const Key('composer-tag-none'),
                    leading: const BvRowIcon(BvIcons.close),
                    title: l10n.tagNone,
                    trailing: const BvRowTrailing.none(),
                    onTap: () => Navigator.of(sheet).pop((id: '', name: '')),
                  ),
              ],
            ),
          ),
          Row(
            spacing: BvSpace.s8,
            children: [
              const Icon(
                BvIcons.lock,
                size: BvSize.iconSm,
                color: BvColors.iconSecondary,
              ),
              Expanded(
                child: Text(
                  l10n.tagSpaceNote,
                  style: BvType.of(
                    sheet,
                  ).bodySm.copyWith(color: BvColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _project = picked.id.isEmpty ? null : picked);
  }

  /// C3 v2: one audience in the MVP.
  Future<void> _postTo() async {
    _unfocus();
    final l10n = AppLocalizations.of(context);
    final me = ref.read(myProfileProvider).value;
    await showBvSheet<void>(
      context: context,
      title: l10n.postToTitle,
      builder: (sheet) {
        final type = BvType.of(sheet);
        return Column(
          key: const Key('composer-post-to'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: BvSpace.s12,
          children: [
            Text(
              l10n.postToWho,
              style: type.overline.copyWith(color: BvColors.textSecondary),
            ),
            Row(
              spacing: BvSpace.s12,
              children: [
                BvAvatar(
                  name: me == null ? '' : '${me.firstName} ${me.lastName}',
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.composerYourNetwork, style: type.titleMd),
                      Text(
                        l10n.postToNetworkHelp,
                        style: type.bodySm.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              l10n.postToNote,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
          ],
        );
      },
    );
  }

  /// L6: one single choice.
  Future<void> _chooseLang() async {
    _unfocus();
    final l10n = AppLocalizations.of(context);
    final picked = await showBvSheet<_Lang>(
      context: context,
      title: l10n.composerLangTitle,
      subtitle: l10n.composerLangWhy,
      builder: (sheet) => BvChoiceList<_Lang>(
        key: const Key('composer-lang-sheet'),
        value: _lang,
        options: [
          if (!_editing)
            BvChoiceOption(
              key: const Key('composer-lang-auto'),
              value: _Lang.auto,
              title: l10n.langAuto,
              // The language it found, in the app's language.
              description: l10n.langName(detectLang(_text.text)),
            ),
          // Each in its own script, named again in the app's language
          // when that differs.
          BvChoiceOption(
            key: const Key('composer-lang-en'),
            value: _Lang.en,
            title: l10n.langEnglish,
            description: _otherName(l10n, 'en', l10n.langEnglish),
          ),
          BvChoiceOption(
            key: const Key('composer-lang-ar'),
            value: _Lang.ar,
            title: l10n.langArabic,
            description: _otherName(l10n, 'ar', l10n.langArabic),
          ),
        ],
        onChanged: (v) => Navigator.of(sheet).pop(v),
      ),
    );
    if (picked != null && mounted) setState(() => _lang = picked);
  }

  String? _otherName(AppLocalizations l10n, String code, String title) {
    final name = l10n.langName(code);
    return name == title ? null : name;
  }

  /// C13: closing with something written asks first.
  Future<void> _close() async {
    _unfocus();
    final l10n = AppLocalizations.of(context);
    if (_hasContent && !_editing) {
      final yes = await showBvDialog(
        context: context,
        title: l10n.discardTitle,
        body: l10n.discardBody,
        cancelLabel: l10n.discardKeep,
        confirmLabel: l10n.discardConfirm,
        destructive: true,
      );
      if (!yes || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _post() async {
    _unfocus();
    if (!_hasContent) return;
    if (_editing) {
      setState(() => _saving = true);
      try {
        await ref
            .read(postRepositoryProvider)
            .edit(widget.editId!, _text.text.trim(), _postLang);
        if (mounted) Navigator.of(context).pop();
      } on SpaceException catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        showSpaceError(context, e);
      }
      return;
    }
    final pending = PendingPost(
      id: newUuid(),
      body: _text.text.trim(),
      lang: _postLang,
      projectId: _project?.id,
      projectName: _project?.name,
      photos: [for (final p in _photos) PendingPostPhoto(local: p)],
    );
    final outbox = ref.read(postOutboxProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    // The Feed shows "Posting to your network…" while it goes up.
    Navigator.of(context).pop();
    try {
      await outbox.send(pending);
    } on SpaceException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(spaceErrorText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final text = _text.text.trim();
    final project = _project;

    return PopScope(
      canPop: !_hasContent || _editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('composer-close'),
            tooltip: l10n.commonCancel,
            icon: const Icon(BvIcons.close),
            onPressed: _close,
          ),
          centerTitle: true,
          title: Text(
            _editing ? l10n.postEdit : l10n.feedNewPost,
            style: type.titleLg,
          ),
        ),
        // The footer in the body, so it rises with the keyboard.
        body: Column(
          children: [
            Expanded(
              child: _editing && !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                      children: [
                        if (!_editing) ...[
                          _PostingTo(
                            projectName: project?.name,
                            projectId: project?.id,
                            onTap: _postTo,
                          ),
                          const SizedBox(height: BvSpace.s16),
                        ],
                        TextField(
                          key: const Key('composer-text'),
                          controller: _text,
                          focusNode: _focus,
                          autofocus: !_editing,
                          minLines: 3,
                          maxLines: null,
                          maxLength: 3000,
                          textCapitalization: TextCapitalization.sentences,
                          textDirection: text.isEmpty
                              ? null
                              : directionOf(text),
                          style: type.bodyLg,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            counterText: '',
                            // In line with the cards: no theme padding.
                            contentPadding: EdgeInsetsDirectional.zero,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: l10n.composerHint,
                            hintStyle: type.bodyLg.copyWith(
                              color: BvColors.textSecondary,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: BvSpace.s16),
                        // The "Start from" tiles hide once there is text.
                        if (text.isEmpty && !_editing)
                          _StartFrom(
                            // The first line is ready to type into.
                            onPick: (lines) {
                              setState(() {
                                _text.text = lines;
                                _text.selection = TextSelection.collapsed(
                                  offset: lines.indexOf(':') + 1,
                                );
                              });
                              _focus.requestFocus();
                            },
                          ),
                        if (_photos.isNotEmpty) ...[
                          Wrap(
                            spacing: BvSpace.s8,
                            runSpacing: BvSpace.s8,
                            children: [
                              for (final p in _photos)
                                _PhotoTile(
                                  path: p,
                                  onRemove: () =>
                                      setState(() => _photos.remove(p)),
                                ),
                            ],
                          ),
                          const SizedBox(height: BvSpace.s12),
                        ],
                        if (_hasContent && !_editing)
                          _Line(
                            key: const Key('composer-audience'),
                            icon: BvIcons.lock,
                            text: project == null
                                ? l10n.composerAudience
                                : l10n.composerAudienceProject,
                          ),
                        if (text.isNotEmpty) ...[
                          const SizedBox(height: BvSpace.s8),
                          Row(
                            key: const Key('composer-lang'),
                            spacing: BvSpace.s8,
                            children: [
                              const Icon(
                                BvIcons.postLanguage,
                                size: BvSize.iconSm,
                                color: BvColors.iconSecondary,
                              ),
                              Flexible(
                                child: Text(
                                  l10n.composerWrittenIn(_postLang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: type.bodySm.copyWith(
                                    color: BvColors.textSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                '·',
                                style: type.bodySm.copyWith(
                                  color: BvColors.textSecondary,
                                ),
                              ),
                              GestureDetector(
                                key: const Key('composer-lang-change'),
                                onTap: _chooseLang,
                                child: Text(
                                  l10n.composerChange,
                                  style: type.labelSm.copyWith(
                                    color: BvColors.textAction,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: BvColors.surfaceApp,
                border: Border(
                  top: BorderSide(
                    color: BvColors.borderDefault,
                    width: BvStroke.thin,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: BvSpace.s12,
                    children: [
                      // Media and Project only (review 16).
                      if (!_editing)
                        Row(
                          spacing: BvSpace.s16,
                          children: [
                            _Tool(
                              key: const Key('composer-media'),
                              icon: BvIcons.image,
                              label: l10n.composerMedia,
                              onTap: _addPhoto,
                            ),
                            _Tool(
                              key: const Key('composer-project'),
                              icon: BvIcons.crane,
                              label: l10n.composerProject,
                              onTap: _tagProject,
                            ),
                          ],
                        ),
                      Row(
                        spacing: BvSpace.s12,
                        children: [
                          Expanded(
                            child: Text(
                              project != null
                                  ? l10n.composerPostingToProject(project.name)
                                  : _editing
                                  ? ''
                                  : l10n.composerChooseHint,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: type.bodySm.copyWith(
                                color: BvColors.textSecondary,
                              ),
                            ),
                          ),
                          BvButton(
                            key: const Key('composer-post'),
                            label: _editing
                                ? l10n.composerSave
                                : l10n.composerPost,
                            onPressed: _hasContent && !_saving ? _post : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// C1: "POSTING TO · Your network · Everyone · tagged {project}".
class _PostingTo extends StatelessWidget {
  const _PostingTo({
    required this.projectName,
    required this.projectId,
    required this.onTap,
  });

  final String? projectName;
  final String? projectId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Material(
      color: BvColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BvRadius.cardAll,
        side: BorderSide(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: InkWell(
        key: const Key('composer-posting-to'),
        borderRadius: BvRadius.cardAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.s16),
          child: Row(
            spacing: BvSpace.s12,
            children: [
              if (projectId != null)
                BvProjectAvatar(id: projectId!, icon: BvIcons.crane)
              else
                Container(
                  key: const Key('composer-network-tile'),
                  width: BvSize.avatarMd,
                  height: BvSize.avatarMd,
                  decoration: BoxDecoration(
                    color: BvColors.surfaceSubtle,
                    borderRadius: BvAvatar.companyRadius(BvAvatarSize.md),
                  ),
                  child: const Icon(
                    BvIcons.everyone,
                    size: BvSize.iconMd,
                    color: BvColors.iconPrimary,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.composerPostingTo,
                      style: type.overline.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                    Text(l10n.composerYourNetwork, style: type.titleMd),
                    Row(
                      spacing: BvSpace.s4,
                      children: [
                        const Icon(
                          BvIcons.everyone,
                          size: BvSize.iconSm,
                          color: BvColors.iconSecondary,
                        ),
                        Flexible(
                          child: Text(
                            joinMeta([
                              l10n.composerEveryone,
                              if (projectName != null)
                                l10n.composerTagged(projectName!),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.bodySm.copyWith(
                              color: BvColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(BvIcons.caretDown, color: BvColors.iconSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// C1 "START FROM": four templates that fill in their lines.
class _StartFrom extends StatelessWidget {
  const _StartFrom({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final tiles = [
      (
        'progress',
        l10n.tplProgress,
        l10n.tplProgressHelp,
        l10n.tplProgressLines,
      ),
      (
        'milestone',
        l10n.tplMilestone,
        l10n.tplMilestoneHelp,
        l10n.tplMilestoneLines,
      ),
      ('visit', l10n.tplVisit, l10n.tplVisitHelp, l10n.tplVisitLines),
      ('ask', l10n.tplAsk, l10n.tplAskHelp, l10n.tplAskLines),
    ];
    return Column(
      key: const Key('composer-start-from'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        Text(
          l10n.composerStartFrom,
          style: type.overline.copyWith(color: BvColors.textSecondary),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: BvSpace.s8,
          crossAxisSpacing: BvSpace.s8,
          mainAxisExtent: BvPostSpec.templateHeight,
          children: [
            for (var i = 0; i < tiles.length; i++)
              Material(
                color: BvColors.surfaceElevated,
                shape: const RoundedRectangleBorder(
                  borderRadius: BvRadius.cardAll,
                  side: BorderSide(
                    color: BvColors.borderDefault,
                    width: BvStroke.thin,
                  ),
                ),
                child: InkWell(
                  key: Key('composer-template-${tiles[i].$1}'),
                  borderRadius: BvRadius.cardAll,
                  onTap: () => onPick(tiles[i].$4),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(BvSpace.s12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: BvSpace.s4,
                      children: [
                        Text(
                          '0${i + 1}',
                          style: type.headingMd.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                        Text(
                          tiles[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.labelLg,
                        ),
                        Text(
                          tiles[i].$3,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: type.bodySm.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BvRadius.controlAll,
          child: Image.file(
            File(path),
            width: BvPostSpec.composerPhoto,
            height: BvPostSpec.composerPhoto,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(
              width: BvPostSpec.composerPhoto,
              height: BvPostSpec.composerPhoto,
              child: ColoredBox(color: BvColors.surfaceSubtle),
            ),
          ),
        ),
        // A small round x in the corner, with a full-size touch area.
        PositionedDirectional(
          top: 0,
          end: 0,
          child: Semantics(
            button: true,
            label: l10n.composerRemovePhoto,
            child: GestureDetector(
              key: Key('composer-remove-$path'),
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(BvSpace.s4),
                child: Container(
                  width: BvSize.iconMd,
                  height: BvSize.iconMd,
                  decoration: const BoxDecoration(
                    color: BvColors.brandInk,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    BvIcons.close,
                    size: BvSize.iconSm,
                    color: BvColors.iconInverse,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BvSpace.s8,
      children: [
        Icon(icon, size: BvSize.iconSm, color: BvColors.iconSecondary),
        Expanded(
          child: Text(
            text,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BvRadius.cardAll,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: BvSpace.s4,
        children: [
          Container(
            width: BvSize.controlMd,
            height: BvSize.controlMd,
            decoration: const BoxDecoration(
              color: BvColors.surfaceSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: BvSize.iconMd, color: BvColors.iconPrimary),
          ),
          Text(label, style: type.labelSm),
        ],
      ),
    );
  }
}
