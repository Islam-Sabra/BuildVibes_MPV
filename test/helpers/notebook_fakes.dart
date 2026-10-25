import 'dart:typed_data';

import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/notebook_repository.dart';

/// My notebook and My calendar with no network (slice 8). [offline] makes
/// every call fail as a lost signal; [deleted] are ids deleted elsewhere
/// (save_note returns null for them).
class FakeNotebookRepository implements NotebookRepository {
  FakeNotebookRepository({List<Note> notes = const [], this.rows = const []}) {
    for (final n in notes) {
      kept[n.id] = n;
    }
  }

  /// The server's notes, by id.
  final Map<String, Note> kept = {};

  /// my_calendar's rows, every day; [calendar] gives those in its days.
  List<CalendarRow> rows;
  final Set<String> deleted = {};

  /// The photos each note's last save_note sent as p_files (F106).
  final Map<String, List<String>> files = {};
  bool offline = false;

  /// Each call, in order: `save:id`, `delete:id`, `done:id:on`,
  /// `pin:id:on`, `put:note:post`, `upload:id`, `photo:id`, `calendar:month-day`.
  final List<String> calls = [];

  void _check() {
    if (offline) throw const SpaceException(SpaceFailure.network);
  }

  @override
  Future<List<Note>> notes() async {
    _check();
    return kept.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<bool> save(Note note) async {
    _check();
    calls.add('save:${note.id}');
    if (deleted.contains(note.id)) return false;
    if (note.kind != NoteKind.voice) {
      files[note.id] = [for (final p in note.photos) ?p.path];
    }
    final before = kept[note.id];
    kept[note.id] = note.copyWith(waiting: false, doneAt: () => before?.doneAt);
    return true;
  }

  @override
  Future<void> delete(Note note) async {
    _check();
    calls.add('delete:${note.id}');
    kept.remove(note.id);
    deleted.add(note.id);
  }

  @override
  Future<void> setDone(String id, {required bool on}) async {
    _check();
    calls.add('done:$id:$on');
    final n = kept[id];
    if (n == null) return;
    kept[id] = n.copyWith(doneAt: () => on ? DateTime(2026, 10, 15, 12) : null);
  }

  @override
  Future<void> pin(String id, {required bool on}) async {
    _check();
    calls.add('pin:$id:$on');
    final n = kept[id];
    if (n != null) kept[id] = n.copyWith(pinned: on);
  }

  @override
  Future<void> markPut(String noteId, String postId) async {
    _check();
    calls.add('put:$noteId:$postId');
    final n = kept[noteId];
    if (n != null) kept[noteId] = n.copyWith(putInPostId: postId);
  }

  @override
  Future<String> uploadRecording(String noteId, NoteRecording r) async {
    _check();
    calls.add('upload:$noteId');
    return 'user-1/$noteId/voice.m4a';
  }

  /// Each photo's server path, in the order they went.
  int _photos = 0;

  @override
  Future<String> uploadPhoto(String noteId, NotePhoto photo) async {
    _check();
    calls.add('photo:$noteId');
    return 'user-1/$noteId/photo-${_photos++}.jpg';
  }

  /// Each PDF's server path, in the order they went (F107).
  int _files = 0;

  @override
  Future<String> uploadFile(String noteId, NoteFile file) async {
    _check();
    calls.add('file:$noteId');
    return 'user-1/$noteId/file-${_files++}.pdf';
  }

  @override
  Future<String> recordingUrl(String path) async =>
      'https://example.test/$path';

  @override
  Future<Uint8List> download(String path) async {
    _check();
    calls.add('download:$path');
    return Uint8List(0);
  }

  /// note_for_space as the server answers it: the typed location, and the
  /// GPS only when asked (F107).
  @override
  Future<Map<String, dynamic>> forSpace(
    String noteId, {
    required bool includeGps,
  }) async {
    _check();
    calls.add('for-space:$noteId:$includeGps');
    final n = kept[noteId]!;
    final l = n.location;
    return {
      'id': n.id,
      'kind': n.kind.json,
      'title': n.title,
      'body': n.body,
      if (n.kind == NoteKind.checklist)
        'points': [for (final p in n.points) p.toJson()],
      if (n.blocks != null) 'blocks': [for (final b in n.blocks!) b.toJson()],
      'due_at': n.dueAt?.toUtc().toIso8601String(),
      'location_text': ?l?.text,
      if (includeGps && l != null && l.hasGps) ...{
        'location_lat': l.lat,
        'location_lng': l.lng,
        'location_accuracy_m': l.accuracyM,
      },
    };
  }

  @override
  Future<List<CalendarRow>> calendar(DateTime from, DateTime to) async {
    _check();
    calls.add('calendar:${from.month}-${from.day}');
    final last = DateTime(to.year, to.month, to.day + 1);
    return [
      for (final r in rows)
        if (!r.day.isBefore(from) && r.day.isBefore(last)) r,
    ];
  }
}
