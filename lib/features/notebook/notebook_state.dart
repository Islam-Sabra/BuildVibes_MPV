import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/network/signal_state.dart';
import '../../data/models/note.dart';
import '../../data/models/space.dart';
import '../../data/repositories/notebook_repository.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;

/// One change to a note, kept on the phone until the server has it.
@immutable
class NoteChange {
  const NoteChange.save(Note this.note)
    : op = 'save',
      id = null,
      on = false,
      at = null;
  const NoteChange.done(String this.id, {required this.on, this.at})
    : op = 'done',
      note = null;
  const NoteChange.pin(String this.id, {required this.on})
    : op = 'pin',
      note = null,
      at = null;
  const NoteChange.delete(Note this.note)
    : op = 'delete',
      id = null,
      on = false,
      at = null;

  factory NoteChange.fromJson(Map<String, dynamic> json) {
    final note = json['note'] == null
        ? null
        : Note.fromJson(json['note'] as Map<String, dynamic>);
    final on = json['on'] as bool? ?? false;
    return switch (json['op']) {
      'done' => NoteChange.done(
        json['id'] as String,
        on: on,
        at: json['at'] == null
            ? null
            : DateTime.parse(json['at'] as String).toLocal(),
      ),
      'pin' => NoteChange.pin(json['id'] as String, on: on),
      'delete' => NoteChange.delete(note!),
      _ => NoteChange.save(note!),
    };
  }

  final String op;
  final Note? note;
  final String? id;
  final bool on;

  /// When a to-do was marked done, on the phone.
  final DateTime? at;

  String get noteId => id ?? note!.id;

  Map<String, dynamic> toJson() => {
    'op': op,
    'note': note?.toJson(),
    'id': id,
    'on': on,
    'at': at?.toUtc().toIso8601String(),
  };

  /// What [notes] look like with this change.
  List<Note> applyTo(List<Note> notes) => switch (op) {
    'save' => [
      note!.copyWith(waiting: true),
      for (final n in notes)
        if (n.id != note!.id) n,
    ],
    'delete' => [
      for (final n in notes)
        if (n.id != note!.id) n,
    ],
    _ => [
      for (final n in notes)
        n.id != id
            ? n
            : op == 'pin'
            ? n.copyWith(pinned: on, waiting: true)
            : n.copyWith(
                doneAt: () => on ? (n.doneAt ?? at) : null,
                waiting: true,
              ),
    ],
  };
}

/// My notebook (slice 8): my notes, newest first, with the changes still
/// on the phone laid over them. A change shows at once; it waits on the
/// phone with no signal and goes on the next change or when the notebook
/// opens again. The server's ids are the app's, so a retry is the same
/// note (save_note); a note deleted elsewhere drops its waiting edit.
final notebookProvider = AsyncNotifierProvider<Notebook, List<Note>>(
  Notebook.new,
);

class Notebook extends AsyncNotifier<List<Note>> {
  String? _key;
  List<NoteChange> _waiting = const [];
  bool _sending = false;

  NotebookRepository get _repo => ref.read(notebookRepositoryProvider);

  @override
  Future<List<Note>> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authUserIdProvider).value;
    _key = userId == null ? null : 'notebook_waiting:$userId';
    _waiting = _read(prefs.getString(_key ?? ''));
    List<Note> notes;
    try {
      notes = await _repo.notes();
    } on SpaceException catch (e) {
      // No signal: what the phone still holds shows.
      if (e.failure != SpaceFailure.network || _waiting.isEmpty) rethrow;
      notes = const [];
    }
    if (_waiting.isNotEmpty) unawaited(Future.microtask(_send));
    return _laid(notes);
  }

  static List<NoteChange> _read(String? raw) {
    if (raw == null) return const [];
    try {
      return [
        for (final c in jsonDecode(raw) as List)
          NoteChange.fromJson(c as Map<String, dynamic>),
      ];
    } on Object {
      return const [];
    }
  }

  List<Note> _laid(List<Note> server) {
    var notes = server;
    for (final c in _waiting) {
      notes = c.applyTo(notes);
    }
    return notes;
  }

  Future<void> _store() async {
    final key = _key;
    if (key == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    if (_waiting.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(
        key,
        jsonEncode([for (final c in _waiting) c.toJson()]),
      );
    }
  }

  Future<void> _change(NoteChange change) async {
    _waiting = [..._waiting, change];
    await _store();
    state = AsyncData(change.applyTo(state.value ?? const []));
    await _send();
  }

  /// A new note, or an edit of one.
  Future<void> save(Note note) => _change(NoteChange.save(note));

  Future<void> setDone(Note note, {required bool on}) =>
      _change(NoteChange.done(note.id, on: on, at: ref.read(clockProvider)()));

  /// A checklist's point ticked or unticked: the note is saved again.
  Future<void> tick(Note note, int index) => save(
    note.copyWith(
      points: [
        for (final (i, p) in note.points.indexed) i == index ? p.toggled() : p,
      ],
    ),
  );

  Future<void> pin(Note note, {required bool on}) =>
      _change(NoteChange.pin(note.id, on: on));

  Future<void> delete(Note note) => _change(NoteChange.delete(note));

  /// "Saved to your notebook" (a held message): a note with its words.
  Future<void> keep(String id, String words, DateTime now) => save(
    Note(id: id, kind: NoteKind.text, body: words.trim(), createdAt: now),
  );

  /// Sends what waits, in order. A lost signal stops it, to go on the next
  /// change or when the notebook opens again; a refusal drops the change
  /// and reads the notebook again.
  Future<void> _send() async {
    if (_sending) return;
    _sending = true;
    var refused = false;
    try {
      while (_waiting.isNotEmpty) {
        var change = _waiting.first;
        try {
          change = await _upload(change);
          final kept = await _call(change);
          if (!kept) refused = true;
        } on SpaceException catch (e) {
          if (e.failure == SpaceFailure.network) {
            ref.read(signalProvider.notifier).lost();
            return;
          }
          refused = true;
        }
        ref.read(signalProvider.notifier).back();
        _waiting = _waiting.skip(1).toList();
        await _store();
        _sent(change);
      }
    } finally {
      _sending = false;
      if (refused) ref.invalidateSelf();
    }
  }

  /// A voice note's recording, or a note's photos (F106), go to Storage
  /// first, once each.
  Future<NoteChange> _upload(NoteChange change) async {
    final note = change.note;
    if (change.op != 'save' || note == null) return change;
    final recording = note.recording;
    final photos = note.photos;
    final waitingRecording = recording != null && recording.path == null;
    if (!waitingRecording && photos.every((p) => p.path != null)) {
      return change;
    }
    var uploaded = note;
    if (waitingRecording) {
      final path = await _repo.uploadRecording(note.id, recording);
      uploaded = uploaded.copyWith(recording: recording.uploaded(path));
    }
    final sent = <NotePhoto>[];
    for (final p in photos) {
      sent.add(
        p.path != null ? p : p.uploaded(await _repo.uploadPhoto(note.id, p)),
      );
      // Each one kept as it goes, so a lost signal sends only the rest.
      _waiting = [
        NoteChange.save(
          uploaded.copyWith(photos: [...sent, ...photos.skip(sent.length)]),
        ),
        ..._waiting.skip(1),
      ];
      await _store();
    }
    final done = NoteChange.save(uploaded.copyWith(photos: sent));
    _waiting = [done, ..._waiting.skip(1)];
    await _store();
    return done;
  }

  /// False when the note was deleted elsewhere.
  Future<bool> _call(NoteChange change) async {
    switch (change.op) {
      case 'save':
        return _repo.save(change.note!);
      case 'done':
        await _repo.setDone(change.id!, on: change.on);
      case 'pin':
        await _repo.pin(change.id!, on: change.on);
      case 'delete':
        await _repo.delete(change.note!);
    }
    return true;
  }

  /// The note no longer waits, unless another change to it does.
  void _sent(NoteChange change) {
    final notes = state.value;
    if (notes == null) return;
    final id = change.noteId;
    if (_waiting.any((c) => c.noteId == id)) return;
    state = AsyncData([
      for (final n in notes) n.id == id ? n.copyWith(waiting: false) : n,
    ]);
  }
}

/// My calendar's rows for a week (the phone's days, both in).
final calendarProvider = FutureProvider.autoDispose
    .family<List<CalendarRow>, ({DateTime from, DateTime to})>(
      (ref, days) =>
          ref.watch(notebookRepositoryProvider).calendar(days.from, days.to),
    );
