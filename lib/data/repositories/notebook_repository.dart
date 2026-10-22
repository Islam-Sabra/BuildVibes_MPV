import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/note.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';
import 'work_repository.dart' show newUuid;

/// My notebook and My calendar (slice 8, review 83; migration 21). Only
/// the owner reads a note, not even a Space admin; every rule is the
/// server's.
abstract class NotebookRepository {
  /// My notes, newest first (`notes` under its owner-only policy).
  Future<List<Note>> notes();

  /// save_note: new or mine, under the id the app chose (a retry is the
  /// same note). False when the note was deleted: the app drops its edit.
  Future<bool> save(Note note);

  /// delete_note, then its recording from Storage (the cleanup takes any
  /// file left behind).
  Future<void> delete(Note note);

  /// set_note_done: a to-do only.
  Future<void> setDone(String id, {required bool on});

  /// pin_note.
  Future<void> pin(String id, {required bool on});

  /// mark_note_put: the post it went into, once the server took it.
  Future<void> markPut(String noteId, String postId);

  /// A recording into `notebook-files`, at `<me>/<note>/<file>`.
  Future<String> uploadRecording(String noteId, NoteRecording recording);

  /// A short link to play a recording.
  Future<String> recordingUrl(String path);

  /// my_calendar: from [from] to [to] (the phone's days, both in; up to
  /// 62), every Space I'm in and my to-dos.
  Future<List<CalendarRow>> calendar(DateTime from, DateTime to);
}

const notebookBucket = 'notebook-files';

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _instant(DateTime t) => t.toUtc().toIso8601String();

class SupabaseNotebookRepository implements NotebookRepository {
  const SupabaseNotebookRepository(this._client);

  final SupabaseClient _client;

  /// The most a notebook reads at once.
  static const _limit = 500;

  /// How long a recording's link lasts.
  static const _linkSeconds = 600;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on StorageException catch (e) {
      throw SpaceException(SpaceFailure.unknown, e.message);
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        '$e',
      );
    }
  }

  @override
  Future<List<Note>> notes() => _guard(() async {
    final rows = await _client
        .from('notes')
        .select(
          '*, note_files(storage_path, kind, mime, bytes, duration_ms, sort)',
        )
        .order('created_at', ascending: false)
        .limit(_limit);
    return [for (final r in rows) Note.fromJson(r)];
  });

  @override
  Future<bool> save(Note note) => _guard(() async {
    final id = await _client.rpc<String?>(
      'save_note',
      params: {
        'p_id': note.id,
        'p_kind': note.kind.json,
        'p_body': note.body.trim().isEmpty ? null : note.body.trim(),
        'p_points': note.kind == NoteKind.checklist
            ? [for (final p in note.points) p.toJson()]
            : null,
        'p_due_at': note.kind == NoteKind.todo && note.dueAt != null
            ? _instant(note.dueAt!)
            : null,
        'p_remind_at': note.remindAt == null ? null : _instant(note.remindAt!),
        'p_pinned': note.pinned,
        // Null keeps the files; a voice note sends its one recording.
        'p_files': note.kind == NoteKind.voice && note.recording?.path != null
            ? [note.recording!.toServer()]
            : null,
      },
    );
    return id != null;
  });

  @override
  Future<void> delete(Note note) => _guard(() async {
    await _client.rpc<void>('delete_note', params: {'p_id': note.id});
    final path = note.recording?.path;
    if (path == null) return;
    try {
      await _client.storage.from(notebookBucket).remove([path]);
    } on StorageException {
      // The cleanup takes it.
    }
  });

  @override
  Future<void> setDone(String id, {required bool on}) => _guard(
    () => _client.rpc<void>('set_note_done', params: {'p_id': id, 'p_on': on}),
  );

  @override
  Future<void> pin(String id, {required bool on}) => _guard(
    () => _client.rpc<void>('pin_note', params: {'p_id': id, 'p_on': on}),
  );

  @override
  Future<void> markPut(String noteId, String postId) => _guard(
    () => _client.rpc<void>(
      'mark_note_put',
      params: {'p_note': noteId, 'p_post': postId},
    ),
  );

  @override
  Future<String> uploadRecording(String noteId, NoteRecording recording) =>
      _guard(() async {
        final me = _client.auth.currentUser!.id;
        final path = '$me/$noteId/${newUuid()}.m4a';
        await _client.storage
            .from(notebookBucket)
            .upload(
              path,
              File(recording.local!),
              fileOptions: FileOptions(contentType: recording.mime),
            );
        return path;
      });

  @override
  Future<String> recordingUrl(String path) => _guard(
    () => _client.storage
        .from(notebookBucket)
        .createSignedUrl(path, _linkSeconds),
  );

  @override
  Future<List<CalendarRow>> calendar(DateTime from, DateTime to) =>
      _guard(() async {
        final first = DateTime(from.year, from.month, from.day);
        final last = DateTime(to.year, to.month, to.day);
        final rows =
            (await _client.rpc<List<dynamic>>(
                          'my_calendar',
                          params: {
                            'p_from_day': _date(first),
                            'p_to_day': _date(last),
                            'p_from': _instant(first),
                            'p_to': _instant(
                              DateTime(last.year, last.month, last.day + 1),
                            ),
                          },
                        )
                        as List? ??
                    const [])
                .cast<Map<String, dynamic>>();
        return [for (final r in rows) ?CalendarRow.fromJson(r)];
      });
}

final notebookRepositoryProvider = Provider<NotebookRepository>(
  (ref) => SupabaseNotebookRepository(ref.watch(supabaseClientProvider)),
);
