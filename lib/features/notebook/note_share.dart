import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/dm.dart';
import '../../data/models/library.dart' show PhoneFile;
import '../../data/models/note.dart';
import '../../data/models/post_page.dart';
import '../../data/models/space.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/dm_repository.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../data/repositories/post_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_line_popover.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../create/create_sheet.dart' show workItemSpacesProvider;
import '../entry/entry_state.dart' show authUserIdProvider;
import '../messages/people_search_screen.dart' show peopleSearchProvider;
import '../spaces/space_errors.dart';
import '../work/daybook_writing.dart' show newPostIdProvider;
import 'note_outline.dart' show numberAt, numberLabel;
import 'note_writing.dart' show NotePhotos;
import 'notebook_state.dart';

/// Where Share sends an entry (review 100 Part 6).
enum _ShareTo { feed, space, message }

/// What a Space share goes in as.
enum ShareKind {
  note('note'),
  workItem('work_item'),
  checklist('checklist');

  const ShareKind(this.json);
  final String json;
}

/// Share (review 100 Part 6, BH4): on one selected entry, or on [lines] of
/// it (a line with the lines under it, BH12). The [card] over the bar
/// [anchor] turns into Feed · Space · Message; each shows its preview
/// first (BH5), and nothing leaves in one tap. The entry stays, with its
/// mark once the server has it. [onDone] runs once the card or the
/// preview has closed, whatever was chosen.
Future<void> shareEntry(
  BuildContext context,
  WidgetRef ref, {
  required Note note,
  List<PageBlock>? lines,
  required BvLinePopover card,
  required BuildContext? Function() anchor,
  VoidCallback? onDone,
}) async {
  final l10n = AppLocalizations.of(context);
  final picked = Completer<Object?>();
  void close([Object? v]) {
    card.hide();
    if (!picked.isCompleted) picked.complete(v);
  }

  card.show(
    context,
    anchor: anchor,
    above: true,
    barrier: true,
    onDismiss: close,
    builder: (_) => _ShareCard(onPicked: close),
  );
  final choice = await picked.future;
  if (!context.mounted || choice == null) {
    onDone?.call();
    return;
  }
  final to = switch (choice) {
    final DmPerson p => _Target.person(p),
    final SpaceSummary s => _Target.space(s),
    _ => const _Target.feed(),
  };
  final sent = await showBvSheet<_Sent>(
    context: context,
    builder: (sheet) => _SharePreview(note: note, lines: lines, target: to),
  );
  onDone?.call();
  if (sent == null || !context.mounted) return;
  await _send(context, ref, note: note, lines: lines, sent: sent);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(switch (sent.target) {
          _Target(:final person?) => l10n.notebookSentTo(person.name ?? ''),
          _Target(:final space?) => l10n.notebookSharedTo(space.name),
          _ => l10n.notebookSharedFeed,
        }),
      ),
    );
}

/// Feed, a Space or a person.
@immutable
class _Target {
  const _Target.feed() : space = null, person = null;
  const _Target.space(SpaceSummary this.space) : person = null;
  const _Target.person(DmPerson this.person) : space = null;

  final SpaceSummary? space;
  final DmPerson? person;
}

/// What the preview's Send carries.
@immutable
class _Sent {
  const _Sent(this.target, {required this.location, this.kind});

  final _Target target;
  final bool location;
  final ShareKind? kind;
}

/// The card's levels: the three choices, then the Space or the person.
class _ShareCard extends ConsumerStatefulWidget {
  const _ShareCard({required this.onPicked});

  final void Function([Object? picked]) onPicked;

  @override
  ConsumerState<_ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends ConsumerState<_ShareCard> {
  _ShareTo? _level;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (_level) {
      case null:
        return BvPopoverMenu<_ShareTo>.line(
          key: const Key('share-menu'),
          back: l10n.notebookShare,
          onBack: widget.onPicked,
          items: [
            BvMenuItem(
              key: const Key('share-feed'),
              value: _ShareTo.feed,
              label: l10n.notebookShareFeed,
              note: l10n.notebookShareFeedNote,
              icon: BvIcons.feed,
            ),
            BvMenuItem(
              key: const Key('share-space'),
              value: _ShareTo.space,
              label: l10n.notebookShareSpace,
              note: l10n.notebookShareSpaceNote,
              icon: BvIcons.team,
            ),
            BvMenuItem(
              key: const Key('share-message'),
              value: _ShareTo.message,
              label: l10n.notebookShareMessage,
              note: l10n.notebookShareMessageNote,
              icon: BvIcons.chat,
            ),
          ],
          onSelected: (to) => to == _ShareTo.feed
              ? widget.onPicked(_ShareTo.feed)
              : setState(() => _level = to),
        );
      case _ShareTo.space:
        final spaces = ref.watch(workItemSpacesProvider);
        final list = spaces.value ?? const <SpaceSummary>[];
        return BvPopoverMenu<SpaceSummary>.line(
          key: const Key('share-menu'),
          back: l10n.notebookShareSpace,
          onBack: () => setState(() => _level = null),
          title: spaces.hasValue && list.isEmpty
              ? l10n.notebookShareNoSpace
              : null,
          scrolls: true,
          items: [
            for (final s in list)
              BvMenuItem(
                key: Key('share-space-${s.id}'),
                value: s,
                label: s.name,
                icon: BvIcons.team,
              ),
          ],
          onSelected: widget.onPicked,
        );
      case _ShareTo.message:
        final inbox = ref.watch(dmInboxProvider);
        final recent = [
          for (final r in inbox.value?.threads ?? const <DmRow>[])
            if (!r.person.former) r.person,
        ];
        return BvPopoverMenu<Object>.line(
          key: const Key('share-menu'),
          back: l10n.notebookShareMessage,
          onBack: () => setState(() => _level = null),
          scrolls: true,
          items: [
            for (final p in recent)
              BvMenuItem(
                key: Key('share-person-${p.id}'),
                value: p,
                label: p.name ?? '',
                icon: BvIcons.person,
                group: l10n.notebookShareRecent,
              ),
            BvMenuItem(
              key: const Key('share-find'),
              value: #find,
              label: l10n.notebookShareFind,
              icon: BvIcons.search,
            ),
          ],
          onSelected: (v) async {
            if (v is DmPerson) return widget.onPicked(v);
            final found = await showBvSheet<DmPerson>(
              context: context,
              builder: (_) => const _FindPerson(),
            );
            widget.onPicked(found);
          },
        );
      case _ShareTo.feed:
        return const SizedBox.shrink();
    }
  }
}

/// Message: search among the people you can already message (the server's
/// rules leave out anyone blocked or hidden).
class _FindPerson extends ConsumerStatefulWidget {
  const _FindPerson();

  @override
  ConsumerState<_FindPerson> createState() => _FindPersonState();
}

class _FindPersonState extends ConsumerState<_FindPerson> {
  var _q = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final found = _q.trim().length < 2
        ? const AsyncData(<SpacePerson>[])
        : ref.watch(peopleSearchProvider(_q.trim()));
    return Column(
      key: const Key('share-find-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('share-find-field'),
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.notebookShareFind),
          onChanged: (q) => setState(() => _q = q),
        ),
        for (final p in found.value ?? const <SpacePerson>[])
          InkWell(
            key: Key('share-person-${p.id}'),
            onTap: () =>
                Navigator.of(context).pop(DmPerson(id: p.id, name: p.fullName)),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: BvSpace.s12,
              ),
              child: Text(
                p.fullName,
                style: type.bodyMd.copyWith(color: BvColors.textPrimary),
              ),
            ),
          ),
      ],
    );
  }
}

/// The preview (review 100 BH5): where it goes, then exactly what goes:
/// the title, the lines (to-dos as ☐ / ☑), the photos, and one location
/// line ("Gate 2 · on the map") that a ✕ leaves out of this share only. On
/// the feed, the share check. "✕ Cancel" in grey at the start, "➤ Send" (or
/// Post) in the action colour at the end; no GPS tick, ever.
class _SharePreview extends ConsumerStatefulWidget {
  const _SharePreview({
    required this.note,
    required this.lines,
    required this.target,
  });

  final Note note;
  final List<PageBlock>? lines;
  final _Target target;

  @override
  ConsumerState<_SharePreview> createState() => _SharePreviewState();
}

class _SharePreviewState extends ConsumerState<_SharePreview> {
  var _location = true;
  var _kind = ShareKind.note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final main = type.bodyMd.copyWith(color: BvColors.textPrimary);
    final to = widget.target;
    final person = to.person;
    final space = to.space;
    final whole = widget.lines == null;
    final blocks = widget.lines ?? widget.note.pageBlocks;
    final title = whole ? widget.note.pageTitle.trim() : '';
    final place = widget.note.location;
    final hasPlace = place != null && !place.isEmpty;
    final placeLine = !hasPlace
        ? ''
        : place.text?.trim().isNotEmpty ?? false
        ? (place.hasGps
              ? l10n.notebookShareLocation(
                  place.text!.trim(),
                  l10n.notebookOnMap,
                )
              : place.text!.trim())
        : l10n.notebookOnMapOnly;
    String lineOf(int i, PageBlock b) => switch (b) {
      PageTodo(:final text, :final done) => '${done ? '☑' : '☐'} $text',
      PageNumbered(:final text) =>
        '${numberLabel(numberAt(blocks, i), b.indent)} $text',
      PageBullet(:final text) => '• $text',
      _ => blockWords(b).join(' · '),
    };
    return Column(
      key: const Key('share-preview'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s12,
      children: [
        Text(
          person != null
              ? l10n.notebookShareMessageTitle
              : space != null
              ? l10n.notebookShareSpaceTitle
              : l10n.notebookShareFeedTitle,
          style: type.titleMd.copyWith(color: BvColors.textPrimary),
        ),
        if (person != null || space != null)
          Container(
            key: const Key('share-to'),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.s12,
              vertical: BvSpace.s12,
            ),
            decoration: BoxDecoration(
              color: BvColors.surfaceElevated,
              borderRadius: BvRadius.controlAll,
              border: Border.all(color: BvColors.borderSelected),
            ),
            child: Row(
              spacing: BvSpace.s12,
              children: [
                Text(l10n.notebookShareTo, style: quiet),
                Expanded(
                  child: Text(
                    person?.name ?? space!.name,
                    style: type.emphasis.copyWith(color: BvColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        if (space != null)
          Wrap(
            spacing: BvSpace.s8,
            children: [
              for (final (k, label) in [
                (ShareKind.note, l10n.notebookShareKindPost),
                (ShareKind.workItem, l10n.notebookShareKindWork),
                (ShareKind.checklist, l10n.notebookShareKindChecklist),
              ])
                ChoiceChip(
                  key: Key('share-kind-${k.json}'),
                  label: Text(label),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
        Text(
          person != null
              ? l10n.notebookShareWhatSees(
                  (person.name ?? '').trim().split(' ').first,
                )
              : l10n.notebookShareWhatOthers,
          style: quiet,
        ),
        Container(
          padding: BvNotebookPagesSpec.entryPadding,
          decoration: const BoxDecoration(
            color: BvColors.surfaceSubtle,
            borderRadius: BvNotebookPagesSpec.entryRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BvNotebookPagesSpec.entryLinesGap,
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  textDirection: directionOf(title),
                  style: type.emphasis.copyWith(color: BvColors.textPrimary),
                ),
              for (final (i, b) in blocks.indexed)
                if (lineOf(i, b).trim().isNotEmpty)
                  Text(
                    lineOf(i, b),
                    textDirection: directionOf(lineOf(i, b)),
                    style: main,
                  ),
              if (whole && widget.note.photos.isNotEmpty)
                NotePhotos(photos: widget.note.photos),
              if (hasPlace && _location)
                Row(
                  key: const Key('share-location'),
                  spacing: BvSpace.s6,
                  children: [
                    const Icon(
                      BvIcons.place,
                      size: BvNotebookPagesSpec.chipIcon,
                      color: BvColors.iconSecondary,
                    ),
                    Expanded(child: Text(placeLine, style: quiet)),
                    Semantics(
                      button: true,
                      label: l10n.notebookShareLeaveOut,
                      excludeSemantics: true,
                      child: InkResponse(
                        key: const Key('share-location-remove'),
                        onTap: () => setState(() => _location = false),
                        child: const Icon(
                          BvIcons.declined,
                          size: BvNotebookPagesSpec.chipIcon,
                          color: BvColors.iconSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (person == null && space == null)
          Text(l10n.notebookShareCheck, style: quiet),
        Row(
          children: [
            TextButton.icon(
              key: const Key('share-cancel'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(BvIcons.close, color: BvColors.iconSecondary),
              label: Text(
                l10n.commonCancel,
                style: type.labelMd.copyWith(color: BvColors.textSecondary),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              key: const Key('share-send'),
              onPressed: () => Navigator.of(context).pop(
                _Sent(
                  to,
                  location: hasPlace && _location,
                  kind: space == null ? null : _kind,
                ),
              ),
              icon: const Icon(BvIcons.send, color: BvColors.textAction),
              label: Text(
                person != null ? l10n.chatSend : l10n.notebookPost,
                style: type.labelMd.copyWith(color: BvColors.textAction),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sends what the preview shows: the photos first, as copies of their own
/// in the place they go (the server's buckets), then the share. Its mark
/// comes with the notebook read again.
Future<void> _send(
  BuildContext context,
  WidgetRef ref, {
  required Note note,
  required List<PageBlock>? lines,
  required _Sent sent,
}) async {
  final repo = ref.read(notebookRepositoryProvider);
  // A post is in the app's language.
  final lang = Localizations.localeOf(context).languageCode;
  final id = ref.read(newPostIdProvider)();
  final ids = lines == null ? null : [for (final b in lines) b.id];
  final photos = lines == null ? note.photos : const <NotePhoto>[];
  try {
    switch (sent.target) {
      case _Target(:final person?):
        final uploads = <Map<String, dynamic>>[];
        for (final (i, p) in photos.indexed) {
          final file = await _photoFile(ref, p);
          if (file == null) continue;
          final path = await ref
              .read(dmRepositoryProvider)
              .upload(
                id,
                PhoneFile(
                  local: file.path,
                  name: 'photo-${i + 1}.jpg',
                  mime: p.mime,
                  bytes: file.lengthSync(),
                ),
              );
          uploads.add(DmUpload(path: path, bytes: file.lengthSync()).toJson());
        }
        final inbox = await ref.read(dmInboxProvider.future);
        final thread =
            inbox.threads
                .where((r) => r.person.id == person.id)
                .firstOrNull
                ?.threadId ??
            ref.read(newPostIdProvider)();
        await repo.shareToPerson(
          note.id,
          id,
          person.id,
          thread,
          lines: ids,
          includeLocation: sent.location,
          attachments: uploads,
        );
      case _Target(:final space?):
        final files = <Map<String, dynamic>>[];
        for (final p in photos) {
          final file = await _photoFile(ref, p);
          if (file == null) continue;
          final path = await ref
              .read(daybookRepositoryProvider)
              .uploadPostPhoto(space.id, id, file);
          files.add({'path': path, 'mime': p.mime});
        }
        await repo.shareToSpace(
          note.id,
          id,
          space.id,
          sent.kind!.json,
          lines: ids,
          owner: sent.kind == ShareKind.workItem
              ? ref.read(authUserIdProvider).value
              : null,
          people: [
            if (sent.kind == ShareKind.checklist)
              ?ref.read(authUserIdProvider).value,
          ],
          includeLocation: sent.location,
          files: files,
        );
      default:
        final media = <Map<String, dynamic>>[];
        for (final p in photos) {
          final file = await _photoFile(ref, p);
          if (file == null) continue;
          media.add({
            'path': await ref
                .read(postRepositoryProvider)
                .uploadPhoto(id, file),
          });
        }
        await repo.shareToFeed(
          note.id,
          id,
          lang,
          lines: ids,
          includeLocation: sent.location,
          media: media,
        );
    }
    ref.invalidate(notebookProvider);
  } on SpaceException catch (e) {
    if (context.mounted) showSpaceError(context, e);
  }
}

/// A photo of the entry as a file on the phone: its own, or downloaded.
Future<File?> _photoFile(WidgetRef ref, NotePhoto p) async {
  final local = p.local;
  if (local != null && File(local).existsSync()) return File(local);
  final path = p.path;
  if (path == null) return null;
  try {
    final bytes = await ref.read(notebookRepositoryProvider).download(path);
    final file = File(
      '${Directory.systemTemp.path}/${ref.read(newPostIdProvider)()}.jpg',
    );
    await file.writeAsBytes(bytes);
    return file;
  } on Object {
    return null;
  }
}
