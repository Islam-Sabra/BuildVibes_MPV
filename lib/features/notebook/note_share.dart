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
import '../../data/models/post.dart' show detectLang;
import '../../data/models/post_page.dart';
import '../../data/models/space.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/dm_repository.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/space_repository.dart' show spacePeopleProvider;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_line_popover.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../chat/voice.dart' show voiceTime;
import '../create/create_sheet.dart' show workItemSpacesProvider;
import '../entry/entry_state.dart' show authUserIdProvider;
import '../messages/people_search_screen.dart' show peopleSearchProvider;
import '../spaces/space_errors.dart';
import '../work/daybook_writing.dart' show newPostIdProvider;
import 'note_outline.dart' show numberAt, numberLabel;
import 'note_page_editor.dart' show NoteTick;
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

/// The most files a message carries (dm_post: at most 10), and the most
/// characters (dm_post and share_note_to_person: 3,000, J1).
const _messageFilesMax = 10;
const _messageMax = 3000;

/// What Share sends as words, as the server's note_words writes them
/// (migration 48): the title (not for [lines]), a line each, at its level,
/// to-dos as [ ] and [x], bullets as •, numbered lines counted, a toggle's
/// lines under it, a table a row a line, a divider as —; the location as
/// its last line when [location].
String shareText(Note note, List<PageBlock>? lines, {required bool location}) {
  final out = <String>[];
  final title = note.pageTitle.trim();
  if (lines == null && title.isNotEmpty) out.add(title);
  var count = 0;
  String mark(bool done) => done ? noteTodoDoneMark : noteTodoOpenMark;
  for (final b in lines ?? note.pageBlocks) {
    final pad = '  ' * b.indent;
    if (b is PageNumbered) {
      count++;
    } else if (b.indent == 0) {
      count = 0;
    }
    switch (b) {
      case PageTodo(:final text, :final done):
        out.add('$pad${mark(done)} $text');
      case PageBullet(:final text):
        out.add('$pad$noteBulletMark $text');
      case PageNumbered(:final text):
        out.add('$pad$count. $text');
      case PageToggle(:final text, :final children):
        out.add('$pad$text');
        for (final c in children) {
          final words = c is PageLine ? c.text : '';
          out.add(
            c is PageTodo ? '$pad  ${mark(c.done)} $words' : '$pad  $words',
          );
        }
      case PageTable(:final rows):
        for (final r in rows) {
          out.add('$pad${r.join(' · ')}');
        }
      case PageDivider():
        out.add('$pad—');
      case PageVoice():
        break;
      default:
        final words = blockWords(b).join(' ');
        if (words.trim().isNotEmpty) out.add('$pad$words');
    }
  }
  final place = note.location;
  if (location && place != null && (place.hasText || place.hasGps)) {
    out.add(
      '📍 ${[if (place.hasText) place.text!, if (place.hasGps) '${place.lat!.toStringAsFixed(6)}, ${place.lng!.toStringAsFixed(6)}'].join(' · ')}',
    );
  }
  return out.join('\n');
}

/// A search for a person starts from this many letters.
const _findFrom = 2;

/// Share (review 100 Part 6, BH4): on one selected entry, or on [lines] of
/// it (a line with the lines under it, BH12). The [card] over the bar
/// [anchor] turns into Feed · Space · Message; each shows its preview
/// first (BH5), and nothing leaves in one tap. What goes is what the
/// server has (H2): the entry's waiting changes go first, or, with no
/// signal, it says so and stops. [saved] gives the entry as the server has
/// it, an edit in hand saved first. A refusal is said and the preview
/// stays (H1); only what went is said to have gone. [onDone] runs once the
/// card or the preview has closed.
Future<void> shareEntry(
  BuildContext context,
  WidgetRef ref, {
  required Note note,
  List<PageBlock>? lines,
  required BvLinePopover card,
  required BuildContext? Function() anchor,
  Future<Note?> Function()? saved,
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
  final notebook = ref.read(notebookProvider.notifier);
  var entry = note;
  try {
    entry = await saved?.call() ?? note;
    final there = await notebook.flush(entry.id);
    if (!there) {
      if (context.mounted) _say(context, l10n.notebookShareOffline);
      onDone?.call();
      return;
    }
  } on SpaceException catch (e) {
    if (context.mounted) showSpaceError(context, e);
    onDone?.call();
    return;
  }
  // The entry as the server now has it.
  final now = ref
      .read(notebookProvider)
      .value
      ?.all
      .where((n) => n.id == entry.id)
      .firstOrNull;
  entry = now ?? entry;
  if (!context.mounted) return;
  final to = switch (choice) {
    final DmPerson p => _Target.person(p),
    final SpaceSummary s => _Target.space(s),
    _ => const _Target.feed(),
  };
  final went = await showBvSheet<_Target>(
    context: context,
    builder: (sheet) => _SharePreview(
      note: entry,
      lines: lines,
      target: to,
      onSend: (sent) => _send(ref, note: entry, lines: lines, sent: sent),
    ),
  );
  onDone?.call();
  if (went == null || !context.mounted) return;
  _say(context, switch (went) {
    _Target(:final person?) => l10n.notebookSentTo(person.name ?? ''),
    _Target(:final space?) => l10n.notebookSharedTo(space.name),
    _ => l10n.notebookSharedFeed,
  });
}

void _say(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

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
  const _Sent(
    this.target, {
    required this.location,
    this.kind,
    this.team,
    this.people = const {},
  });

  final _Target target;
  final bool location;
  final ShareKind? kind;

  /// A Space's Team (null: the whole Space), and who a work item or a
  /// checklist is for (H11).
  final String? team;
  final Set<String> people;
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
  var _q = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (_level) {
      case null:
        return BvPopoverMenu<_ShareTo>.line(
          key: const Key('share-menu'),
          back: l10n.notebookShare,
          onBack: widget.onPicked,
          tiles: false,
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
          tiles: false,
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
        // H14: recent conversations first; a search finds only people
        // you can already message (the server's rules), in this card.
        final q = _q.trim();
        final List<DmPerson> people;
        if (q.length >= _findFrom) {
          people = [
            for (final p
                in ref.watch(peopleSearchProvider(q)).value ??
                    const <SpacePerson>[])
              DmPerson(id: p.id, name: p.fullName),
          ];
        } else {
          people = [
            for (final r
                in ref.watch(dmInboxProvider).value?.threads ?? const <DmRow>[])
              if (!r.person.former) r.person,
          ];
        }
        return BvPopoverMenu<DmPerson>.line(
          key: const Key('share-menu'),
          back: l10n.notebookShareMessage,
          onBack: () => setState(() => _level = null),
          scrolls: true,
          tiles: false,
          field: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: BvSpace.s6,
            ),
            child: BvSearchField(
              key: const Key('share-find-field'),
              placeholder: l10n.notebookShareFind,
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          items: [
            for (final p in people)
              BvMenuItem(
                key: Key('share-person-${p.id}'),
                value: p,
                label: p.name ?? '',
                icon: BvIcons.person,
                group: q.length >= _findFrom ? null : l10n.notebookShareRecent,
              ),
          ],
          onSelected: widget.onPicked,
        );
      case _ShareTo.feed:
        return const SizedBox.shrink();
    }
  }
}

/// The preview (review 100 BH5): where it goes, then exactly what goes:
/// the title, the lines, the photos, a message's files and recordings,
/// and one location line ("Gate 2 · on the map") that a ✕ leaves out of
/// this share only. A Space asks its Team and who it is for (H11). On the
/// feed, the share check. "✕ Cancel" in grey at the start, "➤ Send" (or
/// Post) in the action colour at the end; no GPS tick, ever. Send goes
/// from here: a refusal is said under it and the preview stays (H1).
class _SharePreview extends ConsumerStatefulWidget {
  const _SharePreview({
    required this.note,
    required this.lines,
    required this.target,
    required this.onSend,
  });

  final Note note;
  final List<PageBlock>? lines;
  final _Target target;
  final Future<void> Function(_Sent sent) onSend;

  @override
  ConsumerState<_SharePreview> createState() => _SharePreviewState();
}

class _SharePreviewState extends ConsumerState<_SharePreview> {
  var _location = true;
  var _kind = ShareKind.note;
  String? _team;
  Set<String>? _people;
  var _sending = false;
  SpaceException? _refused;

  Future<void> _go(_Sent sent) async {
    setState(() {
      _sending = true;
      _refused = null;
    });
    try {
      await widget.onSend(sent);
      if (mounted) Navigator.of(context).pop(sent.target);
    } on SpaceException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _refused = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final main = type.bodyMd.copyWith(color: BvColors.textPrimary);
    final to = widget.target;
    final person = to.person;
    final space = to.space;
    final me = ref.watch(authUserIdProvider).value;
    final whole = widget.lines == null;
    final blocks = widget.lines ?? widget.note.pageBlocks;
    final title = whole ? widget.note.pageTitle.trim() : '';
    final place = widget.note.location;
    final hasPlace = place != null && !place.isEmpty;
    final voices = [if (person != null) ...blocks.whereType<PageVoice>()];
    final files = [if (person != null && whole) ...widget.note.files];
    // J1: a message holds 3,000 characters; a longer entry goes to a Space
    // or is shortened first.
    final tooLong =
        person != null &&
        shareText(
              widget.note,
              widget.lines,
              location: hasPlace && _location,
            ).length >
            _messageMax;
    String lineOf(int i, PageBlock b) => switch (b) {
      PageTodo(:final text) => text,
      PageNumbered(:final text) =>
        '${numberLabel(numberAt(blocks, i), b.indent)} $text',
      PageBullet(:final text) => '$noteBulletMark $text',
      PageVoice() => '',
      _ => blockWords(b).join(' · '),
    };
    final people = space == null
        ? null
        : ref.watch(spacePeopleProvider(space.id)).value;
    // A work item is mine by default; a checklist is for me and whoever is
    // picked.
    final forWhom = _people ?? {?me};
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
              vertical: BvSpace.s8,
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
                if (person != null)
                  BvAvatar(name: person.name ?? '', size: BvAvatarSize.sm),
                Expanded(
                  child: Text(
                    person?.name ?? space!.name,
                    style: type.emphasis.copyWith(color: BvColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        if (space != null) ...[
          Wrap(
            spacing: BvSpace.s8,
            runSpacing: BvSpace.s8,
            children: [
              for (final (k, label) in [
                (ShareKind.note, l10n.notebookShareKindPost),
                (ShareKind.workItem, l10n.notebookShareKindWork),
                (ShareKind.checklist, l10n.notebookShareKindChecklist),
              ])
                BvChip(
                  key: Key('share-kind-${k.json}'),
                  label: label,
                  selected: _kind == k,
                  onTap: () => setState(() {
                    _kind = k;
                    _people = null;
                  }),
                ),
            ],
          ),
          if (people != null && people.teams.isNotEmpty) ...[
            Text(l10n.notebookShareTeam, style: quiet),
            Wrap(
              spacing: BvSpace.s8,
              runSpacing: BvSpace.s8,
              children: [
                BvChip(
                  key: const Key('share-team-none'),
                  label: l10n.notebookShareWholeSpace,
                  selected: _team == null,
                  onTap: () => setState(() => _team = null),
                ),
                for (final t in people.teams)
                  BvChip(
                    key: Key('share-team-${t.id}'),
                    label: t.name,
                    selected: _team == t.id,
                    onTap: () => setState(() => _team = t.id),
                  ),
              ],
            ),
          ],
          if (_kind != ShareKind.note && people != null) ...[
            Text(l10n.notebookShareFor, style: quiet),
            Wrap(
              spacing: BvSpace.s8,
              runSpacing: BvSpace.s8,
              children: [
                for (final m in people.members)
                  if (m.pass != SpacePass.viewer)
                    BvChip(
                      key: Key('share-for-${m.person.id}'),
                      label: m.person.fullName,
                      selected: forWhom.contains(m.person.id),
                      onTap: () => setState(() {
                        final id = m.person.id;
                        _people = _kind == ShareKind.workItem
                            ? {id}
                            : (forWhom.contains(id)
                                  ? ({...forWhom}..remove(id))
                                  : {...forWhom, id});
                      }),
                    ),
              ],
            ),
          ],
        ],
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
                  style: type.headingMd.copyWith(color: BvColors.textPrimary),
                ),
              for (final (i, b) in blocks.indexed)
                if (lineOf(i, b).trim().isNotEmpty)
                  // A to-do as the app draws one (BH5): its box.
                  if (b case PageTodo(:final done))
                    Row(
                      spacing: BvNoteBlocksSpec.lineGap,
                      children: [
                        NoteTick(ticked: done),
                        Expanded(
                          child: Text(
                            lineOf(i, b),
                            textDirection: directionOf(lineOf(i, b)),
                            style: main,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      lineOf(i, b),
                      textDirection: directionOf(lineOf(i, b)),
                      style: main,
                    ),
              if (whole && widget.note.photos.isNotEmpty)
                NotePhotos(photos: widget.note.photos),
              for (final f in files)
                Row(
                  key: Key('share-file-${f.name}'),
                  spacing: BvSpace.s6,
                  children: [
                    const Icon(
                      BvIcons.document,
                      size: BvNotebookPagesSpec.chipIcon,
                      color: BvColors.iconSecondary,
                    ),
                    Expanded(child: Text(f.name, style: quiet)),
                  ],
                ),
              for (final v in voices)
                Row(
                  key: Key('share-voice-${v.id}'),
                  spacing: BvSpace.s6,
                  children: [
                    const Icon(
                      BvIcons.microphone,
                      size: BvNotebookPagesSpec.chipIcon,
                      color: BvColors.iconSecondary,
                    ),
                    Expanded(child: Text(voiceTime(v.duration), style: quiet)),
                  ],
                ),
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
                    Expanded(
                      child: Text(_placeLine(l10n, place), style: quiet),
                    ),
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
        if (tooLong)
          Text(
            l10n.notebookShareTooLong,
            key: const Key('share-too-long'),
            style: type.metadata.copyWith(color: BvColors.textDestructive),
          ),
        if (_refused case final e?)
          Text(
            spaceErrorText(l10n, e),
            key: const Key('share-error'),
            style: type.metadata.copyWith(color: BvColors.textDestructive),
          ),
        Row(
          children: [
            BvButton(
              key: const Key('share-cancel'),
              label: l10n.commonCancel,
              icon: BvIcons.close,
              style: BvButtonStyle.quiet,
              size: BvButtonSize.medium,
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
            ),
            const Spacer(),
            BvButton(
              key: const Key('share-send'),
              label: person != null ? l10n.chatSend : l10n.notebookPost,
              icon: BvIcons.send,
              style: BvButtonStyle.tertiary,
              size: BvButtonSize.medium,
              onPressed: _sending || tooLong
                  ? null
                  : () => unawaited(
                      _go(
                        _Sent(
                          to,
                          location: hasPlace && _location,
                          kind: space == null ? null : _kind,
                          team: _team,
                          people: space == null || _kind == ShareKind.note
                              ? const {}
                              : forWhom,
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

/// The location's one line: the typed place, "· on the map" when it has a
/// pin; "On the map" for a pin alone.
String _placeLine(AppLocalizations l10n, NoteLocation place) {
  final text = place.text?.trim() ?? '';
  if (text.isEmpty) return l10n.notebookOnMapOnly;
  return place.hasGps
      ? l10n.notebookShareLocation(text, l10n.notebookOnMap)
      : text;
}

/// Sends what the preview shows: the photos first (and, to a person, the
/// files and recordings), as copies of their own in the place they go,
/// then the share; the notebook reads again for its mark. A refusal is
/// thrown to the preview (H1).
Future<void> _send(
  WidgetRef ref, {
  required Note note,
  required List<PageBlock>? lines,
  required _Sent sent,
}) async {
  final repo = ref.read(notebookRepositoryProvider);
  final id = ref.read(newPostIdProvider)();
  final ids = lines == null ? null : [for (final b in lines) b.id];
  final photos = lines == null ? note.photos : const <NotePhoto>[];
  switch (sent.target) {
    case _Target(:final person?):
      final uploads = <Map<String, dynamic>>[];
      Future<void> add(
        String? path,
        String? local,
        String name,
        String mime, {
        int? durationMs,
      }) async {
        if (uploads.length >= _messageFilesMax) return;
        final file = await _fileOf(ref, path, local);
        if (file == null) return;
        final bytes = file.lengthSync();
        final up = await ref
            .read(dmRepositoryProvider)
            .upload(
              id,
              PhoneFile(local: file.path, name: name, mime: mime, bytes: bytes),
            );
        uploads.add(
          DmUpload(
            path: up,
            name: name,
            bytes: bytes,
            durationMs: durationMs,
          ).toJson(),
        );
      }

      for (final (i, p) in photos.indexed) {
        await add(p.path, p.local, 'photo-${i + 1}.jpg', p.mime);
      }
      if (lines == null) {
        for (final f in note.files) {
          await add(f.path, f.local, f.name, f.mime);
        }
      }
      for (final v in (lines ?? note.pageBlocks).whereType<PageVoice>()) {
        await add(
          v.path,
          v.local,
          'voice-${v.id}.m4a',
          NoteRecording.voiceMime,
          durationMs: v.durationMs,
        );
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
        final file = await _fileOf(ref, p.path, p.local);
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
        team: sent.team,
        owner: sent.kind == ShareKind.workItem ? sent.people.firstOrNull : null,
        people: sent.kind == ShareKind.checklist ? [...sent.people] : const [],
        includeLocation: sent.location,
        files: files,
      );
    default:
      final media = <Map<String, dynamic>>[];
      for (final p in photos) {
        final file = await _fileOf(ref, p.path, p.local);
        if (file == null) continue;
        media.add({
          'path': await ref.read(postRepositoryProvider).uploadPhoto(id, file),
        });
      }
      // H20: a post is in the entry's language, as the feed's composer
      // decides it from the words.
      final words = [
        note.pageTitle,
        for (final b in lines ?? note.pageBlocks) ...blockWords(b),
      ].join('\n');
      await repo.shareToFeed(
        note.id,
        id,
        detectLang(words),
        lines: ids,
        includeLocation: sent.location,
        media: media,
      );
  }
  ref.invalidate(notebookProvider);
}

/// A file of the entry on the phone: its own, or downloaded.
Future<File?> _fileOf(WidgetRef ref, String? path, String? local) async {
  if (local != null && File(local).existsSync()) return File(local);
  if (path == null) return null;
  try {
    final bytes = await ref.read(notebookRepositoryProvider).download(path);
    final name = path.split('/').last;
    final file = File(
      '${Directory.systemTemp.path}/${ref.read(newPostIdProvider)()}-$name',
    );
    await file.writeAsBytes(bytes);
    return file;
  } on Object {
    return null;
  }
}
