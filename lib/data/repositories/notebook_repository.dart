import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/note.dart';
import '../models/notebook_page.dart';
import '../models/post_page.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';
import 'work_repository.dart' show newUuid;

/// My notebook and My calendar (slice 8, review 83; migration 21). Only
/// the owner reads a note, not even a Space admin; every rule is the
/// server's.
/// What share_note_to_feed takes (review 108: Post later keeps it too).
Map<String, Object?> shareToFeedParams(
  String noteId,
  String postId,
  String lang, {
  List<String>? lines,
  required bool includeLocation,
  List<Map<String, dynamic>> media = const [],
}) => {
  'p_note': noteId,
  'p_post': postId,
  'p_lang': lang,
  'p_lines': lines,
  'p_include_location': includeLocation,
  'p_media': media,
};

/// What share_note_to_space takes (review 108: Post later keeps it too).
Map<String, Object?> shareToSpaceParams(
  String noteId,
  String postId,
  String spaceId,
  String kind, {
  List<String>? lines,
  String? team,
  String? owner,
  List<String> people = const [],
  required bool includeLocation,
  List<Map<String, dynamic>> files = const [],
}) => {
  'p_note': noteId,
  'p_post': postId,
  'p_space': spaceId,
  'p_kind': kind,
  'p_lines': lines,
  'p_team': team,
  'p_owner': owner,
  'p_people': people,
  'p_include_location': includeLocation,
  'p_files': files,
};

abstract class NotebookRepository {
  /// My notes, newest first (`notes` under its owner-only policy).
  Future<List<Note>> notes();

  /// One entry as the server has it now, or null (the lead's check of
  /// r106b, K1: read again after a save, for its content key).
  Future<Note?> note(String id);

  /// save_entry (review 99A): new or mine, under the id the app chose (a
  /// retry is the same note), into its page; [newPageTitle] makes that page
  /// with it, titled from it and marked new. False when the note was
  /// deleted: the app drops its edit. [baseVersion]: the version an edit
  /// of a saved entry started from (migration 48); an older one is refused
  /// ("changed on another phone").
  Future<bool> save(Note note, {String? newPageTitle, int? baseVersion});

  /// My pages that aren't deleted (notebook_pages, owner only).
  Future<List<NotebookPage>> pages();

  /// create_notebook_page: "+ New page" or a sub-page; a retry is the same.
  Future<void> createPage(NotebookPage page);

  /// update_notebook_page: the title and icon (no longer new).
  Future<void> updatePage(String id, String title, PageIcon icon);

  /// open_notebook_page: no longer new.
  Future<void> openPage(String id);

  /// pin_notebook_pages.
  Future<void> pinPages(List<String> ids, {required bool on});

  /// move_notebook_pages: Move into… ([parent] null: the top).
  Future<void> movePages(List<String> ids, String? parent);

  /// move_notes: Move to page….
  Future<void> moveNotes(List<String> ids, String page);

  /// arrange_day (review 102 N3): one day's entries of a page, top to
  /// bottom in their new order.
  Future<void> arrangeDay(List<String> ids);

  /// set_notes_collapsed (review 106 T2): the caller's entries folded in
  /// their page, or opened.
  Future<void> setCollapsed(List<String> ids, {required bool on});

  /// merge_notebook_pages: all or nothing; [newTitle] makes [into].
  Future<void> merge(
    List<String> pages,
    List<String> notes,
    String into, {
    String? newTitle,
  });

  /// delete_notebook_pages: with every page under them.
  Future<void> deletePages(List<String> ids);

  /// search_notebook (A5): pages first, then entries, newest first. The
  /// Filter (review 100 Part 8): [kind] ('todos_open', 'photos', 'files',
  /// 'voice', 'reminders', 'archived') and [page], with its sub-pages.
  Future<List<NotebookHit>> search(String query, {String? kind, String? page});

  /// delete_entries (99B B3): my entries to Deleted items; sent again, the
  /// same.
  Future<void> deleteEntries(List<String> ids);

  /// delete_note_lines (99B B3): [lines] of my entry [noteId] (a line with
  /// the lines under it) to Deleted items as "Part of an entry", [part].
  Future<void> deleteLines(String noteId, List<String> lines, String part);

  /// archive_note or unarchive_note (review 100 Part 3b): kept, out of
  /// the page's list, its count, My calendar and the reminders.
  Future<void> archive(String id, {required bool on});

  /// set_note_done: a to-do only.
  Future<void> setDone(String id, {required bool on});

  /// pin_note.
  Future<void> pin(String id, {required bool on});

  /// mark_note_put: the post it went into, once the server took it.
  Future<void> markPut(String noteId, String postId);

  /// A recording into `notebook-files`, at `<me>/<note>/<file>`.
  Future<String> uploadRecording(String noteId, NoteRecording recording);

  /// A photo into `notebook-files`, at `<me>/<note>/<file>` (F106); made
  /// safe to leave the phone when it was picked (cleanPhoto).
  Future<String> uploadPhoto(String noteId, NotePhoto photo);

  /// A PDF into `notebook-files`, at `<me>/<note>/<file>.pdf` (F107).
  Future<String> uploadFile(String noteId, NoteFile file);

  /// A short link to play a recording or show a photo.
  Future<String> recordingUrl(String path);

  /// A file of mine from `notebook-files` (a photo going into a Space,
  /// F107 B11).
  Future<Uint8List> download(String path);

  /// Deleted items (99B B3, PG8): my_deleted_items, newest first.
  Future<List<DeletedItem>> deletedItems();

  /// How many days Deleted items are kept: 7, 30 (by default) or 90.
  Future<int> keepDays();
  Future<void> setKeepDays(int days);

  /// restore_items: back in its page, or a new page with the old title.
  Future<void> restore(List<String> ids);

  /// delete_forever, then the files it held from Storage.
  Future<void> deleteForever(List<String> ids);

  /// empty_deleted_items, then the files they held from Storage.
  Future<void> emptyDeleted();

  /// share_note_to_feed (review 100 Part 6): a public post [postId] in
  /// [lang] from the entry, or [lines] of it; the location only with
  /// [includeLocation]; [media] the copies already in post-media.
  Future<void> shareToFeed(
    String noteId,
    String postId,
    String lang, {
    List<String>? lines,
    required bool includeLocation,
    List<Map<String, dynamic>> media = const [],
  });

  /// share_note_to_space: a post, work item or checklist ([kind]: 'note',
  /// 'work_item', 'checklist') in [spaceId], for [owner] (a work item) or
  /// [people] (a checklist); [files] the copies already in the Space's
  /// bucket. The Space's rules and passes are the server's.
  Future<void> shareToSpace(
    String noteId,
    String postId,
    String spaceId,
    String kind, {
    List<String>? lines,
    String? team,
    String? owner,
    List<String> people = const [],
    required bool includeLocation,
    List<Map<String, dynamic>> files = const [],
  });

  /// share_note_to_person: a message to [personId] in [threadId] (new
  /// when they have none), with start_dm's rules; [attachments] the copies
  /// already in dm-files.
  Future<void> shareToPerson(
    String noteId,
    String messageId,
    String personId,
    String threadId, {
    List<String>? lines,
    required bool includeLocation,
    List<Map<String, dynamic>> attachments = const [],
  });

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

  static const _noteColumns =
      '*, note_files(storage_path, kind, mime, bytes, duration_ms, sort, name), '
      'note_shares(target, target_name, created_at, content_key)';

  @override
  Future<List<Note>> notes() => _guard(() async {
    final rows = await _client
        .from('notes')
        .select(_noteColumns)
        .order('created_at', ascending: false)
        .limit(_limit);
    return [for (final r in rows) Note.fromJson(r)];
  });

  @override
  Future<Note?> note(String id) => _guard(() async {
    final row = await _client
        .from('notes')
        .select(_noteColumns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Note.fromJson(row);
  });

  @override
  Future<bool> save(
    Note note, {
    String? newPageTitle,
    int? baseVersion,
  }) => _guard(() async {
    final page = {
      'p_page': note.pageId,
      'p_new_page_title': newPageTitle,
      'p_base_version': ?baseVersion,
    };
    final blocks = note.blocks;
    if (blocks != null) {
      // F107: a page, with its title, blocks, date, location, photos,
      // PDFs and voice blocks' recordings, and the phone's time.
      final id = await _client.rpc<String?>(
        'save_entry',
        params: {
          ...page,
          'p_id': note.id,
          'p_kind': NoteKind.text.json,
          'p_body': note.body.trim().isEmpty ? null : note.body.trim(),
          'p_title': note.title.trim().isEmpty ? null : note.title.trim(),
          'p_blocks': [
            for (final b in blocks) b is PageVoice ? b.toServer() : b.toJson(),
          ],
          'p_due_at': note.dueAt == null ? null : _instant(note.dueAt!),
          'p_remind_at': note.remindAt == null
              ? null
              : _instant(note.remindAt!),
          'p_pinned': note.pinned,
          'p_location': note.location?.toJson(),
          'p_created_at': _instant(note.createdAt),
          'p_files': [
            for (final p in note.photos)
              if (p.path != null) p.toServer(),
            for (final f in note.files)
              if (f.path != null) f.toServer(),
            for (final b in blocks)
              if (b case PageVoice(:final path?))
                {
                  'path': path,
                  'mime': 'audio/mp4',
                  'duration_ms': b.durationMs,
                },
          ],
        },
      );
      return id != null;
    }
    final id = await _client.rpc<String?>(
      'save_entry',
      params: {
        ...page,
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
        // A voice note sends its one recording (null keeps it until it is
        // uploaded); any other note its photos, all of them each time
        // (F106: set_note_files replaces them).
        'p_files': note.kind == NoteKind.voice
            ? (note.recording?.path == null
                  ? null
                  : [note.recording!.toServer()])
            : [
                for (final p in note.photos)
                  if (p.path != null) p.toServer(),
              ],
      },
    );
    return id != null;
  });

  @override
  Future<List<NotebookPage>> pages() => _guard(() async {
    final rows = await _client
        .from('notebook_pages')
        .select()
        .isFilter('deleted_at', null)
        .order('last_activity_at', ascending: false)
        .limit(_limit);
    return [for (final r in rows) NotebookPage.fromJson(r)];
  });

  @override
  Future<void> createPage(NotebookPage page) => _guard(
    () => _client.rpc<void>(
      'create_notebook_page',
      params: {
        'p_id': page.id,
        'p_title': page.title,
        'p_parent': page.parentId,
        'p_icon': page.icon.json,
      },
    ),
  );

  @override
  Future<void> updatePage(String id, String title, PageIcon icon) => _guard(
    () => _client.rpc<void>(
      'update_notebook_page',
      params: {'p_id': id, 'p_title': title, 'p_icon': icon.json},
    ),
  );

  @override
  Future<void> openPage(String id) => _guard(
    () => _client.rpc<void>('open_notebook_page', params: {'p_id': id}),
  );

  @override
  Future<void> pinPages(List<String> ids, {required bool on}) => _guard(
    () => _client.rpc<void>(
      'pin_notebook_pages',
      params: {'p_ids': ids, 'p_on': on},
    ),
  );

  @override
  Future<void> movePages(List<String> ids, String? parent) => _guard(
    () => _client.rpc<void>(
      'move_notebook_pages',
      params: {'p_ids': ids, 'p_parent': parent},
    ),
  );

  @override
  Future<void> moveNotes(List<String> ids, String page) => _guard(
    () =>
        _client.rpc<void>('move_notes', params: {'p_ids': ids, 'p_page': page}),
  );

  @override
  Future<void> arrangeDay(List<String> ids) =>
      _guard(() => _client.rpc<void>('arrange_day', params: {'p_ids': ids}));

  @override
  Future<void> setCollapsed(List<String> ids, {required bool on}) => _guard(
    () => _client.rpc<void>(
      'set_notes_collapsed',
      params: {'p_ids': ids, 'p_on': on},
    ),
  );

  @override
  Future<void> merge(
    List<String> pages,
    List<String> notes,
    String into, {
    String? newTitle,
  }) => _guard(
    () => _client.rpc<void>(
      'merge_notebook_pages',
      params: {
        'p_pages': pages,
        'p_notes': notes,
        'p_into': into,
        'p_new_title': newTitle,
      },
    ),
  );

  @override
  Future<void> deletePages(List<String> ids) => _guard(
    () => _client.rpc<void>('delete_notebook_pages', params: {'p_ids': ids}),
  );

  @override
  Future<List<NotebookHit>> search(
    String query, {
    String? kind,
    String? page,
  }) => _guard(() async {
    final rows =
        (await _client.rpc<List<dynamic>>(
                      'search_notebook',
                      params: {'p_q': query, 'p_kind': kind, 'p_page': page},
                    )
                    as List? ??
                const [])
            .cast<Map<String, dynamic>>();
    return [for (final r in rows) NotebookHit.fromJson(r)];
  });

  @override
  Future<void> deleteEntries(List<String> ids) =>
      _guard(() => _client.rpc<void>('delete_entries', params: {'p_ids': ids}));

  @override
  Future<void> deleteLines(String noteId, List<String> lines, String part) =>
      _guard(
        () => _client.rpc<void>(
          'delete_note_lines',
          params: {'p_note': noteId, 'p_lines': lines, 'p_part': part},
        ),
      );

  @override
  Future<void> archive(String id, {required bool on}) => _guard(
    () => _client.rpc<void>(
      on ? 'archive_note' : 'unarchive_note',
      params: {'p_id': id},
    ),
  );

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
  Future<String> uploadPhoto(String noteId, NotePhoto photo) =>
      _guard(() async {
        final me = _client.auth.currentUser!.id;
        final path = '$me/$noteId/${newUuid()}.jpg';
        await _client.storage
            .from(notebookBucket)
            .upload(
              path,
              File(photo.local!),
              fileOptions: FileOptions(contentType: photo.mime),
            );
        return path;
      });

  @override
  Future<String> uploadFile(String noteId, NoteFile file) => _guard(() async {
    final me = _client.auth.currentUser!.id;
    final path = '$me/$noteId/${newUuid()}.pdf';
    await _client.storage
        .from(notebookBucket)
        .upload(
          path,
          File(file.local!),
          fileOptions: FileOptions(contentType: file.mime),
        );
    return path;
  });

  @override
  Future<Uint8List> download(String path) =>
      _guard(() => _client.storage.from(notebookBucket).download(path));

  @override
  Future<String> recordingUrl(String path) => _guard(
    () => _client.storage
        .from(notebookBucket)
        .createSignedUrl(path, _linkSeconds),
  );

  @override
  Future<List<DeletedItem>> deletedItems() => _guard(() async {
    final rows =
        (await _client.rpc<List<dynamic>>('my_deleted_items') as List? ??
                const [])
            .cast<Map<String, dynamic>>();
    return [for (final r in rows) DeletedItem.fromJson(r)];
  });

  @override
  Future<int> keepDays() => _guard(() async {
    final row = await _client
        .from('profile_private')
        .select('notebook_keep_days')
        .eq('id', _client.auth.currentUser!.id)
        .maybeSingle();
    return row?['notebook_keep_days'] as int? ?? 30;
  });

  @override
  Future<void> setKeepDays(int days) => _guard(
    () => _client.rpc<void>('set_notebook_keep_days', params: {'p_days': days}),
  );

  @override
  Future<void> restore(List<String> ids) =>
      _guard(() => _client.rpc<void>('restore_items', params: {'p_ids': ids}));

  /// The files a delete for good freed, out of Storage (the purge job
  /// takes any left behind).
  Future<void> _removeFiles(Object? rows) async {
    final paths = [
      for (final r in (rows as List? ?? const []).cast<Map<String, dynamic>>())
        ?r['path'] as String?,
    ];
    if (paths.isEmpty) return;
    try {
      await _client.storage.from(notebookBucket).remove(paths);
    } on StorageException {
      // The purge job takes it.
    }
  }

  @override
  Future<void> deleteForever(List<String> ids) => _guard(() async {
    await _removeFiles(
      await _client.rpc<dynamic>('delete_forever', params: {'p_ids': ids}),
    );
  });

  @override
  Future<void> emptyDeleted() => _guard(() async {
    await _removeFiles(await _client.rpc<dynamic>('empty_deleted_items'));
  });

  @override
  Future<void> shareToFeed(
    String noteId,
    String postId,
    String lang, {
    List<String>? lines,
    required bool includeLocation,
    List<Map<String, dynamic>> media = const [],
  }) => _guard(
    () => _client.rpc<void>(
      'share_note_to_feed',
      params: shareToFeedParams(
        noteId,
        postId,
        lang,
        lines: lines,
        includeLocation: includeLocation,
        media: media,
      ),
    ),
  );

  @override
  Future<void> shareToSpace(
    String noteId,
    String postId,
    String spaceId,
    String kind, {
    List<String>? lines,
    String? team,
    String? owner,
    List<String> people = const [],
    required bool includeLocation,
    List<Map<String, dynamic>> files = const [],
  }) => _guard(
    () => _client.rpc<void>(
      'share_note_to_space',
      params: shareToSpaceParams(
        noteId,
        postId,
        spaceId,
        kind,
        lines: lines,
        team: team,
        owner: owner,
        people: people,
        includeLocation: includeLocation,
        files: files,
      ),
    ),
  );

  @override
  Future<void> shareToPerson(
    String noteId,
    String messageId,
    String personId,
    String threadId, {
    List<String>? lines,
    required bool includeLocation,
    List<Map<String, dynamic>> attachments = const [],
  }) => _guard(
    () => _client.rpc<void>(
      'share_note_to_person',
      params: {
        'p_note': noteId,
        'p_message': messageId,
        'p_person': personId,
        'p_thread': threadId,
        'p_lines': lines,
        'p_include_location': includeLocation,
        'p_attachments': attachments,
      },
    ),
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
