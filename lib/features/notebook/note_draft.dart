import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../data/models/note.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../entry/entry_state.dart';
import '../work/daybook_draft.dart' show DaybookDraft, DraftPoint;

/// The note being written in place in My notebook (F106, review 90), or
/// left unsent as its Draft. One at a time. A new note's words, or an
/// edit of [editing]'s.
///
/// The words are kept the same way whatever the kind, so changing the
/// kind keeps what was typed: [title] is a note's first line, a
/// checklist's title and a to-do's line; [body] a note's other lines; and
/// [points] a checklist's points.
@immutable
class NoteDraft {
  const NoteDraft({
    required this.id,
    required this.startedAt,
    this.kind = NoteKind.text,
    this.editing,
    this.title = '',
    this.body = '',
    this.points = const [],
    this.dueAt,
    this.remindAt,
    this.photos = const [],
  });

  /// An edit of [note], filled with what it says.
  factory NoteDraft.of(Note note) {
    final words = note.body.trim();
    final newline = words.indexOf('\n');
    final text = note.kind == NoteKind.text;
    return NoteDraft(
      id: note.id,
      startedAt: note.createdAt,
      kind: note.kind,
      editing: note,
      title: text && newline >= 0 ? words.substring(0, newline).trim() : words,
      body: text && newline >= 0 ? words.substring(newline + 1).trim() : '',
      points: [for (final p in note.points) (id: newUuid(), text: p.text)],
      dueAt: note.kind == NoteKind.todo ? note.dueAt : null,
      remindAt: note.remindAt,
      photos: note.photos,
    );
  }

  factory NoteDraft.fromJson(Map<String, dynamic> json) => NoteDraft(
    id: json['id'] as String,
    startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
    kind: NoteKind.fromJson(json['kind']),
    editing: json['editing'] == null
        ? null
        : Note.fromJson(json['editing'] as Map<String, dynamic>),
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    points: [
      for (final p in json['points'] as List? ?? const [])
        (
          id: (p as Map<String, dynamic>)['id'] as String,
          text: p['text'] as String? ?? '',
        ),
    ],
    dueAt: _time(json['due_at']),
    remindAt: _time(json['remind_at']),
    photos: [
      for (final p in json['photos'] as List? ?? const [])
        NotePhoto.fromJson(p as Map<String, dynamic>),
    ],
  );

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  /// The note's id: chosen when the slip opened, or the edited note's.
  final String id;

  /// When the slip opened; it sits there among today's notes.
  final DateTime startedAt;
  final NoteKind kind;

  /// The note as it was, when this is an edit.
  final Note? editing;
  final String title;
  final String body;
  final List<DraftPoint> points;

  /// A to-do's by when.
  final DateTime? dueAt;
  final DateTime? remindAt;
  final List<NotePhoto> photos;

  List<DraftPoint> get writtenPoints => [
    for (final p in points)
      if (p.text.trim().isNotEmpty) p,
  ];

  /// Nothing to keep: no words and no photo. An empty slip leaves no
  /// draft.
  bool get isEmpty =>
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      writtenPoints.isEmpty &&
      photos.isEmpty;

  /// Send turns on: what save_note takes for the kind.
  bool get ready => switch (kind) {
    NoteKind.checklist => writtenPoints.isNotEmpty,
    NoteKind.todo => title.trim().isNotEmpty,
    _ => title.trim().isNotEmpty || body.trim().isNotEmpty || photos.isNotEmpty,
  };

  /// Another kind, keeping what was typed (review 90 §3): a note's lines
  /// become a checklist's points, a checklist's points a note's lines, and
  /// a to-do takes the first line.
  NoteDraft asKind(NoteKind to) {
    if (to == kind) return this;
    final lines = [
      for (final l in body.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    switch (to) {
      case NoteKind.checklist:
        return _with(
          kind: to,
          body: '',
          points: [
            ...writtenPoints,
            for (final l in lines.take(Note.pointsMax - writtenPoints.length))
              (id: newUuid(), text: l),
          ],
        );
      case NoteKind.todo:
        // The first line is the to-do; the rest waits, hidden, for another
        // kind.
        if (title.trim().isNotEmpty) return _with(kind: to);
        final written = writtenPoints;
        if (lines.isNotEmpty) {
          return _with(
            kind: to,
            title: lines.first,
            body: lines.skip(1).join('\n'),
          );
        }
        if (written.isNotEmpty) {
          return _with(
            kind: to,
            title: written.first.text.trim(),
            points: written.skip(1).toList(),
          );
        }
        return _with(kind: to);
      case NoteKind.text:
      case NoteKind.voice:
        return _with(
          kind: NoteKind.text,
          body: [
            ...lines,
            for (final p in writtenPoints) p.text.trim(),
          ].join('\n'),
          points: const [],
        );
    }
  }

  /// The note to save: a note's first line and the rest, a checklist's
  /// title and points, a to-do's line and by when. [now] for a new one
  /// left from another day.
  Note toNote(DateTime now) {
    final was = editing;
    final createdAt =
        was?.createdAt ?? (_sameDay(startedAt, now) ? startedAt : now);
    final words = switch (kind) {
      NoteKind.text => [
        title.trim(),
        body.trim(),
      ].where((w) => w.isNotEmpty).join('\n'),
      _ => title.trim(),
    };
    final note = was ?? Note(id: id, kind: kind, createdAt: createdAt);
    return note.copyWith(
      kind: kind,
      body: words,
      points: kind == NoteKind.checklist
          ? [
              for (final p in writtenPoints.take(Note.pointsMax))
                NotePoint(p.text.trim(), done: _wasDone(p.text.trim())),
            ]
          : const [],
      dueAt: () => kind == NoteKind.todo ? dueAt : null,
      doneAt: () => kind == NoteKind.todo ? note.doneAt : null,
      remindAt: () => remindAt,
      photos: photos,
    );
  }

  /// An edited checklist keeps the ticks of the points still there.
  bool _wasDone(String text) =>
      editing?.points.any((p) => p.done && p.text == text) ?? false;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  NoteDraft _with({
    NoteKind? kind,
    String? title,
    String? body,
    List<DraftPoint>? points,
  }) => copyWith(kind: kind, title: title, body: body, points: points);

  NoteDraft copyWith({
    NoteKind? kind,
    String? title,
    String? body,
    List<DraftPoint>? points,
    DateTime? Function()? dueAt,
    DateTime? Function()? remindAt,
    List<NotePhoto>? photos,
  }) => NoteDraft(
    id: id,
    startedAt: startedAt,
    editing: editing,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    body: body ?? this.body,
    points: points ?? this.points,
    dueAt: dueAt == null ? this.dueAt : dueAt(),
    remindAt: remindAt == null ? this.remindAt : remindAt(),
    photos: photos ?? this.photos,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'started_at': startedAt.toUtc().toIso8601String(),
    'kind': kind.json,
    'editing': editing?.toJson(),
    'title': title,
    'body': body,
    'points': [
      for (final p in points) {'id': p.id, 'text': p.text},
    ],
    'due_at': dueAt?.toUtc().toIso8601String(),
    'remind_at': remindAt?.toUtc().toIso8601String(),
    'photos': [for (final p in photos) p.toJson()],
  };
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

  /// Gone: sent ([keepPhotos], the note has them now), or emptied.
  Future<void> discard({bool keepPhotos = false}) async {
    final draft = state;
    state = null;
    final key = _key;
    if (key != null) {
      await ref.read(sharedPreferencesProvider).remove(key);
    }
    if (keepPhotos || draft == null) return;
    final kept = draft.editing?.photos ?? const <NotePhoto>[];
    for (final p in draft.photos) {
      final local = p.local;
      if (local != null && p.path == null && !kept.contains(p)) {
        unawaited(DaybookDraft.deleteKept(local));
      }
    }
  }
}
