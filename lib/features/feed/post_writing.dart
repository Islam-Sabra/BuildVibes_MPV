import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/profile_page_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_project_tag.dart';
import '../../shared/widgets/bv_writing_card.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../work/daybook_entry.dart' show localPhotoProvider;
import '../work/work_outbox.dart' show keepPhotoProvider, pickPhotoProvider;
import 'feed_state.dart';
import 'post_card.dart' show postPhotoProvider;
import 'post_draft.dart';
import 'post_list.dart' show postListProvider;

/// What opens over the feed while writing: the More menu, the project
/// picker or the language picker.
enum PostWritingMenu { more, project, language }

/// Writing on Home: the card's changes, its photos, project and language,
/// and Post. With [editing], the card is a posted one's, and Save sends
/// its text and language (edit_post: photos and the tag stay).
class PostWriter {
  PostWriter(this.ref, {this.editing = false});

  final WidgetRef ref;
  final bool editing;

  PostCardState get _notifier => editing
      ? ref.read(postEditProvider.notifier)
      : ref.read(postDraftProvider.notifier);
  PostDraft? get draft =>
      editing ? ref.read(postEditProvider) : ref.read(postDraftProvider);

  Future<void> _put(PostDraft Function(PostDraft d) change) async {
    final d = draft;
    if (d != null) await _notifier.put(change(d));
  }

  Future<void> setBody(String text) => _put((d) => d.copyWith(body: text));
  Future<void> setLang(PostLang lang) => _put((d) => d.copyWith(lang: lang));
  Future<void> setProject(PostProject? project) =>
      _put((d) => d.copyWith(project: () => project));

  /// Whether another photo fits (create_post takes four).
  bool get roomForPhoto => (draft?.photos.length ?? 0) < PostDraft.photosMax;

  /// A photo from the camera or the phone, kept in the app's folder.
  Future<void> addPhoto({required bool camera}) async {
    if (!roomForPhoto) return;
    final picked = await ref.read(pickPhotoProvider)(camera: camera);
    if (picked == null) return;
    final kept = await ref.read(keepPhotoProvider)(picked);
    await _put((d) => d.copyWith(photos: [...d.photos, kept]));
  }

  Future<void> removePhoto(int index) async {
    final d = draft;
    if (d == null || index >= d.photos.length) return;
    final old = d.photos[index];
    await _put((d) => d.copyWith(photos: [...d.photos]..removeAt(index)));
    unawaited(PostDrafts.deleteKept(old));
  }

  /// Post: into the outbox (it sends now, or when the signal is back), and
  /// the card is gone.
  Future<void> post() async {
    final d = draft;
    if (d == null || !d.canPost) return;
    unawaited(
      ref
          .read(postOutboxProvider.notifier)
          .send(
            PendingPost(
              id: d.id,
              body: d.body.trim(),
              lang: d.postLang,
              madeAt: ref.read(clockProvider)(),
              project: d.project,
              photos: [for (final p in d.photos) PendingPostPhoto(local: p)],
            ),
          ),
    );
    // The photos now belong to the outbox, until they are sent.
    await ref.read(postDraftProvider.notifier).discard(keepPhotos: true);
  }

  /// Save an edit: its text and language, then the card shows everywhere
  /// it is.
  Future<void> save() async {
    final d = draft;
    if (d == null) return;
    await ref
        .read(postRepositoryProvider)
        .edit(d.id, d.body.trim(), d.postLang);
    ref
      ..invalidate(postProvider(d.id))
      ..invalidate(postListProvider);
    final edited = await ref.read(postProvider(d.id).future);
    if (edited != null) ref.read(feedProvider.notifier).replace(edited);
  }
}

/// The post being written in place at Now on Home (H2 2555:35388): "You ·
/// to everyone", the text, the photos and the project tag. Its Draft when
/// it was left with anything in it (only its author sees it), or a posted
/// one being edited ([editing]). While not [writing] it is read only, and
/// a tap reopens it.
class PostWritingCard extends ConsumerStatefulWidget {
  const PostWritingCard({
    super.key,
    required this.writing,
    required this.fromBefore,
    required this.onOpen,
    this.editing = false,
  });

  final bool writing;
  final bool editing;

  /// Left from before (the app closed or the card was put down): "Draft".
  final bool fromBefore;
  final VoidCallback onOpen;

  @override
  ConsumerState<PostWritingCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostWritingCard> {
  late final PostWriter _writer = PostWriter(ref, editing: widget.editing);
  late final TextEditingController _body;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _body = TextEditingController(text: _writer.draft?.body);
  }

  @override
  void didUpdateWidget(PostWritingCard old) {
    super.didUpdateWidget(old);
    if (widget.writing && !old.writing) _focus.requestFocus();
  }

  @override
  void dispose() {
    _body.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draft = ref.watch(
      widget.editing ? postEditProvider : postDraftProvider,
    );
    if (draft == null) return const SizedBox.shrink();
    final writing = widget.writing;
    final me = ref.watch(authUserIdProvider).value ?? '';
    final profile = ref.watch(myProfileProvider).value;
    // An edit shows the post's own photos and tag; they stay as posted.
    final original = widget.editing
        ? ref.read(postEditProvider.notifier).original
        : null;
    final project = original?.project ?? draft.project;
    final locale = Localizations.localeOf(context);
    final card = BvWritingCard(
      key: const Key('post-writing-card'),
      bodyController: _body,
      bodyPlaceholder: l10n.postWritingHint,
      bodyFocusNode: _focus,
      autofocus: writing,
      bodyMaxLength: PostDraft.bodyMax,
      onBodyChanged: _writer.setBody,
      draftLabel: widget.fromBefore ? l10n.daybookDraft : null,
      author: BvWritingAuthor(
        name: profile == null ? '' : '${profile.firstName} ${profile.lastName}',
        label: l10n.postWritingAuthor,
        tint: BvAvatarTints.forId(me),
      ),
      photos: [
        if (original != null)
          for (final p in original.photos)
            _Photo(image: ref.watch(postPhotoProvider(p.path)))
        else
          for (final p in draft.photos)
            _Photo(image: ref.watch(localPhotoProvider(p))),
      ],
      photoHeight: BvWritingCardSpec.postPhotoHeight,
      onRemovePhoto: writing && !widget.editing ? _writer.removePhoto : null,
      removePhotoLabel: l10n.daybookRemovePhoto,
      footer: project == null
          ? null
          : BvProjectTag(
              key: const Key('post-writing-tag'),
              projectId: project.id,
              name: project.name,
              place: project.place(locale),
            ),
      errorLine: draft.couldNotSend && !writing
          ? l10n.daybookCouldNotSend
          : null,
    );
    if (writing) {
      // A tap on the card's paper stays on the card (a tap elsewhere puts
      // the card down).
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: card,
      );
    }
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('post-draft'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: AbsorbPointer(child: card),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.image});

  final ImageProvider? image;

  @override
  Widget build(BuildContext context) => image == null
      ? const ColoredBox(color: BvColors.surfaceSubtle)
      : Image(
          image: image!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const ColoredBox(color: BvColors.surfaceSubtle),
        );
}

/// What opens over the feed while writing: the More menu (Project and the
/// post's language; an edit can change only its language), the project
/// picker (projects on your profile with a confirmed role, C10) and the
/// language picker (one single choice, L6).
class PostWritingPopover extends ConsumerWidget {
  const PostWritingPopover({
    super.key,
    required this.menu,
    required this.onMenu,
    required this.onClose,
    this.editing = false,
  });

  final PostWritingMenu menu;
  final bool editing;
  final ValueChanged<PostWritingMenu> onMenu;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final writer = PostWriter(ref, editing: editing);
    final draft = ref.watch(editing ? postEditProvider : postDraftProvider);
    if (draft == null) return const SizedBox.shrink();
    switch (menu) {
      case PostWritingMenu.more:
        return BvPopoverMenu<PostWritingMenu>.more(
          key: const Key('post-more-menu'),
          items: [
            if (!editing)
              BvMenuItem(
                value: PostWritingMenu.project,
                label: l10n.postWritingProject,
                icon: BvIcons.crane,
              ),
            BvMenuItem(
              value: PostWritingMenu.language,
              label: l10n.postWritingLang(draft.postLang),
              icon: BvIcons.postLanguage,
            ),
          ],
          onSelected: onMenu,
        );
      case PostWritingMenu.project:
        final me = ref.watch(authUserIdProvider).value;
        final profile = me == null
            ? null
            : ref.watch(profileViewProvider(me)).value;
        if (profile == null) {
          return const SizedBox.square(
            dimension: BvSize.touchMin,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final mine = [
          for (final c in profile.projects)
            if (c.confirmed && c.showOnProfile) c,
        ];
        // Ids: a project, '' for none, null to add one on the profile.
        return BvPopoverMenu<String?>.picker(
          key: const Key('post-project-picker'),
          selected: draft.project?.id,
          items: [
            for (final c in mine)
              BvMenuItem(
                value: c.projectId,
                label: c.projectName,
                icon: BvIcons.crane,
              ),
            if (mine.isEmpty)
              BvMenuItem(
                value: null,
                label: l10n.tagEmpty,
                icon: BvIcons.create,
              ),
            if (draft.project != null)
              BvMenuItem(value: '', label: l10n.tagNone, icon: BvIcons.close),
          ],
          onSelected: (id) async {
            onClose();
            if (id == null) {
              unawaited(context.push(AppRoutes.projectsAdd));
              return;
            }
            final c = mine.where((c) => c.projectId == id).firstOrNull;
            await writer.setProject(
              c == null
                  ? null
                  : PostProject(
                      id: c.projectId,
                      name: c.projectName,
                      typeName: c.projectType,
                      placeName: c.placeName,
                    ),
            );
          },
        );
      case PostWritingMenu.language:
        return BvPopoverMenu<PostLang>.picker(
          key: const Key('post-lang-picker'),
          selected: draft.lang,
          items: [
            // An edit has a language already; there is nothing to find.
            if (!editing)
              BvMenuItem(
                value: PostLang.auto,
                label: l10n.postLangAuto(detectLang(draft.body)),
                icon: BvIcons.postLanguage,
              ),
            BvMenuItem(
              value: PostLang.en,
              label: l10n.langEnglish,
              icon: BvIcons.postLanguage,
            ),
            BvMenuItem(
              value: PostLang.ar,
              label: l10n.langArabic,
              icon: BvIcons.postLanguage,
            ),
          ],
          onSelected: (lang) async {
            onClose();
            await writer.setLang(lang);
          },
        );
    }
  }
}
