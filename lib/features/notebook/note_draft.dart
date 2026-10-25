import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../data/models/note.dart';
import '../../data/models/post_page.dart';
import '../entry/entry_state.dart';
import '../work/daybook_draft.dart' show DaybookDraft;

/// The note being written in place in My notebook (F106, review 90), or
/// left unsent as its Draft. One at a time. A new note, or an edit of
/// [editing].
///
/// F107 (review 92): a page. Its bold [title], its [blocks] (Work's page
/// format, with the notebook's own kinds), and what is attached to the
/// note itself: a date, a reminder, a location, photos and PDFs. An older
/// note opens as blocks ([Note.pageBlocks]) and is saved as a page.
@immutable
class NoteDraft {
  const NoteDraft({
    required this.id,
    required this.startedAt,
    this.editing,
    this.title = '',
    this.blocks = const [],
    this.dueAt,
    this.remindAt,
    this.photos = const [],
    this.files = const [],
    this.location,
  });

  /// An edit of [note], filled with what it says.
  factory NoteDraft.of(Note note) => NoteDraft(
    id: note.id,
    startedAt: note.createdAt,
    editing: note,
    title: note.pageTitle,
    blocks: note.pageBlocks,
    dueAt: note.dueAt,
    remindAt: note.remindAt,
    photos: note.photos,
    files: note.files,
    location: note.location,
  );

  factory NoteDraft.fromJson(Map<String, dynamic> json) => NoteDraft(
    id: json['id'] as String,
    startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
    editing: json['editing'] == null
        ? null
        : Note.fromJson(json['editing'] as Map<String, dynamic>),
    title: json['title'] as String? ?? '',
    blocks: [
      for (final b in json['blocks'] as List? ?? const [])
        PageBlock.fromJson(b as Map<String, dynamic>),
    ],
    dueAt: _time(json['due_at']),
    remindAt: _time(json['remind_at']),
    photos: [
      for (final p in json['photos'] as List? ?? const [])
        NotePhoto.fromJson(p as Map<String, dynamic>),
    ],
    files: [
      for (final f in json['files'] as List? ?? const [])
        NoteFile.fromJson(f as Map<String, dynamic>),
    ],
    location: json['location'] == null
        ? null
        : NoteLocation.fromJson(json['location'] as Map<String, dynamic>),
  );

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  /// The note's id: chosen when the slip opened, or the edited note's.
  final String id;

  /// When the slip opened; it sits there among today's notes.
  final DateTime startedAt;

  /// The note as it was, when this is an edit.
  final Note? editing;
  final String title;
  final List<PageBlock> blocks;

  /// The note's date (Date, F107; a to-do's by when before it).
  final DateTime? dueAt;
  final DateTime? remindAt;
  final List<NotePhoto> photos;
  final List<NoteFile> files;
  final NoteLocation? location;

  /// The blocks worth keeping: an empty line goes.
  List<PageBlock> get keptBlocks => [
    for (final b in blocks)
      if (!_empty(b)) b,
  ];

  static bool _empty(PageBlock b) => switch (b) {
    PageText(:final text) ||
    PageHeading(:final text) ||
    PageLine(:final text) => text.trim().isEmpty,
    PageToggle(:final text, :final children) =>
      text.trim().isEmpty && children.every(_empty),
    PageTable(:final rows) => rows.every(
      (r) => r.every((c) => c.trim().isEmpty),
    ),
    _ => false,
  };

  /// Nothing to keep: no words, no voice, no photo, no file and no typed
  /// place. An empty slip leaves no draft.
  bool get isEmpty =>
      title.trim().isEmpty &&
      keptBlocks.every((b) => b is PageDivider) &&
      photos.isEmpty &&
      files.isEmpty &&
      !(location?.hasText ?? false);

  /// Send turns on: there is something to keep.
  bool get ready => !isEmpty;

  /// The note to save: a page (kind text) with its words as the body.
  /// [now] is when it is sent (F107 B6: the server keeps the phone's
  /// time, so it reads the same before and after).
  Note toNote(DateTime now) {
    final was = editing;
    final kept = keptBlocks;
    final note =
        was ?? Note(id: id, kind: NoteKind.text, createdAt: now, blocks: kept);
    return note.copyWith(
      kind: NoteKind.text,
      title: title.trim(),
      blocks: kept,
      body: pageDigest(title, kept),
      points: const [],
      dueAt: () => dueAt,
      doneAt: () => null,
      remindAt: () => remindAt,
      photos: photos,
      files: files,
      location: () => (location?.isEmpty ?? true) ? null : location,
    );
  }

  NoteDraft copyWith({
    String? title,
    List<PageBlock>? blocks,
    DateTime? Function()? dueAt,
    DateTime? Function()? remindAt,
    List<NotePhoto>? photos,
    List<NoteFile>? files,
    NoteLocation? Function()? location,
  }) => NoteDraft(
    id: id,
    startedAt: startedAt,
    editing: editing,
    title: title ?? this.title,
    blocks: blocks ?? this.blocks,
    dueAt: dueAt == null ? this.dueAt : dueAt(),
    remindAt: remindAt == null ? this.remindAt : remindAt(),
    photos: photos ?? this.photos,
    files: files ?? this.files,
    location: location == null ? this.location : location(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'started_at': startedAt.toUtc().toIso8601String(),
    'editing': editing?.toJson(),
    'title': title,
    'blocks': [for (final b in blocks) b.toJson()],
    'due_at': dueAt?.toUtc().toIso8601String(),
    'remind_at': remindAt?.toUtc().toIso8601String(),
    'photos': [for (final p in photos) p.toJson()],
    'files': [for (final f in files) f.toJson()],
    'location': location?.toJson(),
  };
}

/// The phone's copies a draft holds that the note it edits doesn't: its
/// own photos, PDFs and recordings.
List<String> draftLocals(NoteDraft d) {
  final was = d.editing;
  final kept = <String>{
    for (final p in was?.photos ?? const <NotePhoto>[]) ?p.local,
    for (final f in was?.files ?? const <NoteFile>[]) ?f.local,
    for (final b in was?.blocks ?? const <PageBlock>[])
      if (b case PageVoice(:final local?)) local,
  };
  return [
    for (final p in d.photos)
      if (p.path == null && p.local != null && !kept.contains(p.local))
        p.local!,
    for (final f in d.files)
      if (f.path == null && f.local != null && !kept.contains(f.local))
        f.local!,
    for (final b in d.blocks)
      if (b case PageVoice(
        path: null,
        :final local?,
      ) when !kept.contains(local))
        local,
  ];
}

/// The one note being written, or its Draft, per account. Saved on the
/// phone as it changes once anything is in it, so leaving (Back, or the
/// app closing) keeps it; never sent until Send.
final noteDraftProvider = NotifierProvider<NoteDraftNotifier, NoteDraft?>(
  NoteDraftNotifier.new,
);

class NoteDraftNotifier extends Notifier<NoteDraft?> {
  String? _key;

  @override
  NoteDraft? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authUserIdProvider).value;
    _key = userId == null ? null : 'notebook_draft:$userId';
    final raw = _key == null ? null : prefs.getString(_key!);
    if (raw == null) return null;
    try {
      return NoteDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  /// Sets the slip and keeps it once anything is in it.
  Future<void> put(NoteDraft draft) async {
    state = draft;
    final key = _key;
    if (key == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    if (draft.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(draft.toJson()));
    }
  }

  /// The slip is put down: an empty one is gone; anything else stays as
  /// the Draft.
  Future<void> close() async {
    final draft = state;
    if (draft != null && draft.isEmpty) await discard();
  }

  /// Gone: sent ([keepFiles], the note has them now), or emptied.
  Future<void> discard({bool keepFiles = false}) async {
    final draft = state;
    state = null;
    final key = _key;
    if (key != null) {
      await ref.read(sharedPreferencesProvider).remove(key);
    }
    if (keepFiles || draft == null) return;
    for (final local in draftLocals(draft)) {
      unawaited(DaybookDraft.deleteKept(local));
    }
  }
}
