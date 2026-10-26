import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/network/signal_state.dart';
import '../../data/models/note.dart';
import '../../data/models/notebook_page.dart';
import '../../data/models/post_page.dart';
import '../../data/models/space.dart';
import '../../data/repositories/notebook_repository.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;

//// My notebook as the phone shows it (review 99A): its pages that aren't
/// deleted, and the entries in them, newest first. An entry whose page is
/// gone (deleted, or merged away) doesn't show; one from an older version
/// with no page shows in the latest page, where the server puts it.
class NotebookData {
  factory NotebookData({
    List<Note> notes = const [],
    List<NotebookPage> pages = const [],
  }) {
    final latest = pages.isEmpty
        ? null
        : pages.reduce(
            (a, b) => b.lastActivityAt.isAfter(a.lastActivityAt) ? b : a,
          );
    final ids = {for (final p in pages) p.id};
    return NotebookData._(
      [
        for (final n in notes)
          if (ids.contains(n.pageId ?? latest?.id)) n,
      ],
      notes,
      pages,
      latest,
    );
  }

  const NotebookData._(this.notes, this.all, this.pages, this.latest);

  /// The entries that show, newest first.
  final List<Note> notes;

  /// Every entry the phone has, its page gone or not.
  final List<Note> all;
  final List<NotebookPage> pages;

  /// The page with the latest activity: where "New entry" starts (A2).
  final NotebookPage? latest;

  NotebookPage? page(String? id) =>
      id == null ? null : pages.where((p) => p.id == id).firstOrNull;

  /// The page an entry shows in.
  String? pageOf(Note note) => note.pageId ?? latest?.id;

  /// The pages in [parent] (null: the top): pinned first, then by latest
  /// activity (A1).
  List<NotebookPage> children(String? parent) => [
    for (final p in pages)
      if (p.parentId == parent) p,
  ]..sort(byPinThenActivity);

  static int byPinThenActivity(NotebookPage a, NotebookPage b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.lastActivityAt.compareTo(a.lastActivityAt);
  }

  /// [id] and every page under it.
  Set<String> tree(String id) {
    final out = {id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final p in pages) {
        if (p.parentId != null && out.contains(p.parentId) && out.add(p.id)) {
          grew = true;
        }
      }
    }
    return out;
  }

  /// The entries in [id] itself, newest first.
  List<Note> entries(String id) => [
    for (final n in notes)
      if (pageOf(n) == id) n,
  ];

  /// The latest entry in [id] or a page under it.
  Note? latestIn(String id) {
    final ids = tree(id);
    return notes.where((n) => ids.contains(pageOf(n))).firstOrNull;
  }

  /// To-dos not yet ticked in [id] and the pages under it (A1).
  int openTodos(String id) {
    final ids = tree(id);
    return notes
        .where((n) => ids.contains(pageOf(n)))
        .fold(0, (sum, n) => sum + n.openTodos);
  }

  /// [id]'s pages from the top down to it, itself last (A3's path).
  List<NotebookPage> path(String id) {
    final out = <NotebookPage>[];
    final seen = <String>{};
    for (var p = page(id); p != null && seen.add(p.id); p = page(p.parentId)) {
      out.insert(0, p);
    }
    return out;
  }

  NotebookData copyWith({List<Note>? notes, List<NotebookPage>? pages}) =>
      NotebookData(notes: notes ?? all, pages: pages ?? this.pages);
}

/// One change to the notebook, kept on the phone until the server has it:
/// an entry's ([note], [id]) or pages' ([page], [ids], [noteIds],
/// [target]).
@immutable
class NoteChange {
  const NoteChange.save(Note this.note, {this.newPageTitle})
    : op = 'save',
      id = null,
      on = false,
      at = null,
      page = null,
      ids = const [],
      noteIds = const [],
      target = null;
  const NoteChange.done(String this.id, {required this.on, this.at})
    : op = 'done',
      note = null,
      newPageTitle = null,
      page = null,
      ids = const [],
      noteIds = const [],
      target = null;
  const NoteChange.pin(String this.id, {required this.on})
    : op = 'pin',
      note = null,
      at = null,
      newPageTitle = null,
      page = null,
      ids = const [],
      noteIds = const [],
      target = null;
  const NoteChange.delete(Note this.note)
    : op = 'delete',
      id = null,
      on = false,
      at = null,
      newPageTitle = null,
      page = null,
      ids = const [],
      noteIds = const [],
      target = null;

  /// "+ New page", or a sub-page.
  const NoteChange.newPage(NotebookPage this.page)
    : op = 'page',
      note = null,
      id = null,
      on = false,
      at = null,
      newPageTitle = null,
      ids = const [],
      noteIds = const [],
      target = null;

  /// The title and icon, edited in place.
  const NoteChange.editPage(NotebookPage this.page)
    : op = 'page_edit',
      note = null,
      id = null,
      on = false,
      at = null,
      newPageTitle = null,
      ids = const [],
      noteIds = const [],
      target = null;

  /// The page opened: no longer new.
  const NoteChange.openPage(String this.target)
    : op = 'page_open',
      note = null,
      id = null,
      on = false,
      at = null,
      newPageTitle = null,
      page = null,
      ids = const [],
      noteIds = const [];
  const NoteChange.pinPages(this.ids, {required this.on})
    : op = 'page_pin',
      note = null,
      id = null,
      at = null,
      newPageTitle = null,
      page = null,
      noteIds = const [],
      target = null;

  /// Move into… ([target] null: the top).
  const NoteChange.movePages(this.ids, this.target)
    : op = 'page_move',
      note = null,
      id = null,
      on = false,
      at = null,
      newPageTitle = null,
      page = null,
      noteIds = const [];

  /// Move to page….
  const NoteChange.moveNotes(this.noteIds, String this.target)
    : op = 'notes_move',
      note = null,
      id = null,
      on = false,
      at = null,
      newPageTitle = null,
      page = null,
      ids = const [];

  /// Merge [ids] and [noteIds] into [target]; [page] when it is new.
  const NoteChange.merge(
    this.ids,
    this.noteIds,
    String this.target, {
    this.page,
  }) : op = 'merge',
       note = null,
       id = null,
       on = false,
       at = null,
       newPageTitle = null;
  const NoteChange.deletePages(this.ids)
    : op = 'page_delete',
      note = null,
      id = null,
      on = false,
      at = null,
      newPageTitle = null,
      page = null,
      noteIds = const [],
      target = null;

  factory NoteChange.fromJson(Map<String, dynamic> json) {
    final note = json['note'] == null
        ? null
        : Note.fromJson(json['note'] as Map<String, dynamic>);
    final page = json['page'] == null
        ? null
        : NotebookPage.fromJson(json['page'] as Map<String, dynamic>);
    final on = json['on'] as bool? ?? false;
    final target = json['target'] as String?;
    List<String> list(String key) => [
      for (final v in json[key] as List? ?? const []) v as String,
    ];
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
      'page' => NoteChange.newPage(page!),
      'page_edit' => NoteChange.editPage(page!),
      'page_open' => NoteChange.openPage(target!),
      'page_pin' => NoteChange.pinPages(list('ids'), on: on),
      'page_move' => NoteChange.movePages(list('ids'), target),
      'notes_move' => NoteChange.moveNotes(list('note_ids'), target!),
      'merge' => NoteChange.merge(
        list('ids'),
        list('note_ids'),
        target!,
        page: page,
      ),
      'page_delete' => NoteChange.deletePages(list('ids')),
      _ => NoteChange.save(
        note!,
        newPageTitle: json['new_page_title'] as String?,
      ),
    };
  }

  final String op;
  final Note? note;
  final String? id;
  final bool on;

  /// When a to-do was marked done, on the phone.
  final DateTime? at;

  /// A save into a page made with it, titled from the entry (A2).
  final String? newPageTitle;
  final NotebookPage? page;
  final List<String> ids;
  final List<String> noteIds;
  final String? target;

  /// The entry this change is to; null for pages.
  String? get noteId => id ?? note?.id;

  Map<String, dynamic> toJson() => {
    'op': op,
    'note': note?.toJson(),
    'id': id,
    'on': on,
    'at': at?.toUtc().toIso8601String(),
    'new_page_title': ?newPageTitle,
    'page': ?page?.toJson(),
    if (ids.isNotEmpty) 'ids': ids,
    if (noteIds.isNotEmpty) 'note_ids': noteIds,
    'target': ?target,
  };

  /// What [data] looks like with this change. A saved note keeps its
  /// place, or a new one goes where its time puts it (F107 B7: an edit no
  /// longer jumps to the end of its day).
  NotebookData applyTo(NotebookData data) {
    final notes = data.all;
    final pages = data.pages;
    switch (op) {
      case 'save':
        final saved = note!.copyWith(waiting: true);
        final into = saved.pageId ?? data.latest?.id;
        final title = newPageTitle;
        final made = saved.pageId != null && title != null && data.page(into) == null;
        return NotebookData(
          notes: _placed(saved, notes),
          pages: [
            for (final p in pages)
              p.id == into && saved.createdAt.isAfter(p.lastActivityAt)
                  ? p.copyWith(lastActivityAt: saved.createdAt)
                  : p,
            if (made)
              NotebookPage(
                id: into!,
                title: title,
                isNew: true,
                createdAt: saved.createdAt,
                lastActivityAt: saved.createdAt,
              ),
          ],
        );
      case 'delete':
        return data.copyWith(
          notes: [
            for (final n in notes)
              if (n.id != note!.id) n,
          ],
        );
      case 'done' || 'pin':
        return data.copyWith(
          notes: [
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
        );
      case 'page':
        if (data.page(page!.id) != null) return data;
        return data.copyWith(pages: [...pages, page!]);
      case 'page_edit':
        return data.copyWith(
          pages: [
            for (final p in pages)
              p.id == page!.id
                  ? p.copyWith(
                      title: page!.title,
                      icon: page!.icon,
                      isNew: false,
                    )
                  : p,
          ],
        );
      case 'page_open':
        return data.copyWith(
          pages: [
            for (final p in pages)
              p.id == target ? p.copyWith(isNew: false) : p,
          ],
        );
      case 'page_pin':
        return data.copyWith(
          pages: [
            for (final p in pages)
              ids.contains(p.id) ? p.copyWith(pinned: on) : p,
          ],
        );
      case 'page_move':
        // Never a page into itself or under itself.
        final more = {for (final i in ids) ...data.tree(i)};
        if (target != null && more.contains(target)) return data;
        return data.copyWith(
          pages: [
            for (final p in pages)
              ids.contains(p.id) ? p.copyWith(parentId: () => target) : p,
          ],
        );
      case 'notes_move':
        return data.copyWith(
          notes: [
            for (final n in notes)
              noteIds.contains(n.id) ? n.copyWith(pageId: target) : n,
          ],
        );
      case 'merge':
        final into = target!;
        final gone = {
          for (final i in ids)
            if (i != into) i,
        };
        final all = [
          ...pages,
          if (page case final made? when data.page(into) == null) made,
        ];
        NotebookPage? find(String? id) =>
            all.where((p) => p.id == id).firstOrNull;
        // The page that stays climbs out of any page that goes.
        var up = find(into)?.parentId;
        while (up != null && gone.contains(up)) {
          up = find(up)?.parentId;
        }
        final stays = up;
        return NotebookData(
          notes: [
            for (final n in notes)
              gone.contains(data.pageOf(n)) || noteIds.contains(n.id)
                  ? n.copyWith(pageId: into)
                  : n,
          ],
          pages: [
            for (final p in all)
              if (p.id == into)
                p.copyWith(parentId: () => stays, isNew: false)
              else if (!gone.contains(p.id))
                gone.contains(p.parentId)
                    ? p.copyWith(parentId: () => into)
                    : p,
          ],
        );
      case 'page_delete':
        final gone = {for (final i in ids) ...data.tree(i)};
        return data.copyWith(
          pages: [
            for (final p in pages)
              if (!gone.contains(p.id)) p,
          ],
        );
    }
    return data;
  }

  static List<Note> _placed(Note saved, List<Note> notes) {
    if (notes.any((n) => n.id == saved.id)) {
      return [for (final n in notes) n.id == saved.id ? saved : n];
    }
    final at = notes.indexWhere((n) => !n.createdAt.isAfter(saved.createdAt));
    return [...notes]..insert(at < 0 ? notes.length : at, saved);
  }
}

// A note the server refused (not for want of a signal): the screen says
/// so and puts its words back as the Draft (F107 B15). Each refusal is a
/// new value.
final noteRefusedProvider = NotifierProvider<NoteRefused, Note?>(
  NoteRefused.new,
);

class NoteRefused extends Notifier<Note?> {
  @override
  Note? build() => null;

  void refused(Note note) => state = note;

  /// The screen has dealt with it.
  void seen() => state = null;
}

/// My notebook (slice 8; pages, review 99A): my pages and notes, newest
/// first, with the changes still on the phone laid over them. A change shows at once; it waits on the
/// phone with no signal and goes on the next change or when the notebook
/// opens again. The server's ids are the app's, so a retry is the same
/// note (save_note); a note deleted elsewhere drops its waiting edit.
final notebookProvider = AsyncNotifierProvider<Notebook, NotebookData>(
  Notebook.new,
);

class Notebook extends AsyncNotifier<NotebookData> {
  String? _key;
  List<NoteChange> _waiting = const [];
  bool _sending = false;

  /// Another try after a lost signal (F107 B8), sooner at first.
  Timer? _retry;
  int _tries = 0;
  static const _retryFirst = Duration(seconds: 15);
  static const _retryMost = Duration(minutes: 5);

  /// A merge or a delete shown at once but sent only after its 5 s Undo
  /// (A4), and the notebook as it was before it.
  NoteChange? _held;
  NotebookData? _beforeHeld;

  NotebookRepository get _repo => ref.read(notebookRepositoryProvider);

  @override
  Future<NotebookData> build() async {
    ref.onDispose(() => _retry?.cancel());
    // Something got through again (B8): what waits goes now.
    ref.listen(signalProvider, (was, has) {
      if (has && was == false) unawaited(_send());
    });
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authUserIdProvider).value;
    _key = userId == null ? null : 'notebook_waiting:$userId';
    _waiting = _read(prefs.getString(_key ?? ''));
    _held = null;
    _beforeHeld = null;
    NotebookData server;
    try {
      final (notes, pages) = await (_repo.notes(), _repo.pages()).wait;
      server = NotebookData(notes: notes, pages: pages);
    } on ParallelWaitError<(List<Note>?, List<NotebookPage>?),
        (AsyncError?, AsyncError?)> catch (e) {
      final error = e.errors.$1?.error ?? e.errors.$2!.error;
      // No signal: what the phone still holds shows.
      if (error is! SpaceException ||
          error.failure != SpaceFailure.network ||
          _waiting.isEmpty) {
        Error.throwWithStackTrace(
          error,
          e.errors.$1?.stackTrace ?? e.errors.$2!.stackTrace,
        );
      }
      server = NotebookData();
    }
    if (_waiting.isNotEmpty) unawaited(Future.microtask(_send));
    return _laid(server);
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

  NotebookData _laid(NotebookData server) {
    var data = server;
    for (final c in _waiting) {
      data = c.applyTo(data);
    }
    return data;
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
    await releaseHeld();
    state = AsyncData(change.applyTo(state.value ?? NotebookData()));
    await _queue(change);
  }

  Future<void> _queue(NoteChange change) async {
    _waiting = [..._waiting, change];
    await _store();
    await _send();
  }

  /// [change] shows at once but goes only on [releaseHeld] (its Undo bar
  /// closing), unless [undoHeld] takes it back first (A4: Undo for 5 s).
  Future<void> hold(NoteChange change) async {
    await releaseHeld();
    _beforeHeld = state.value ?? NotebookData();
    _held = change;
    state = AsyncData(change.applyTo(_beforeHeld!));
  }

  /// The held change goes.
  Future<void> releaseHeld() async {
    final held = _held;
    if (held == null) return;
    _held = null;
    _beforeHeld = null;
    await _queue(held);
  }

  /// The held change is taken back: false when it had already gone.
  bool undoHeld() {
    final before = _beforeHeld;
    if (_held == null || before == null) return false;
    _held = null;
    _beforeHeld = null;
    state = AsyncData(before);
    return true;
  }

  /// A new note, or an edit of one; [newPageTitle] makes its page with it
  /// (A2: "New page", titled from the entry).
  Future<void> save(Note note, {String? newPageTitle}) =>
      _change(NoteChange.save(note, newPageTitle: newPageTitle));

  /// "+ New page", or a sub-page of [NotebookPage.parentId].
  Future<void> newPage(NotebookPage page) => _change(NoteChange.newPage(page));

  /// The title and icon, edited in place.
  Future<void> editPage(NotebookPage page) =>
      _change(NoteChange.editPage(page));

  /// The page opened: no longer new (A2).
  Future<void> openPage(NotebookPage page) async {
    if (page.isNew) await _change(NoteChange.openPage(page.id));
  }

  Future<void> pinPages(List<String> ids, {required bool on}) =>
      _change(NoteChange.pinPages(ids, on: on));

  /// Move into… ([parent] null: the top of My notebook).
  Future<void> movePages(List<String> ids, String? parent) =>
      _change(NoteChange.movePages(ids, parent));

  /// Move to page….
  Future<void> moveNotes(List<String> ids, String page) =>
      _change(NoteChange.moveNotes(ids, page));

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

  /// A page's to-do ticked or unticked on its slip (F107): the note is
  /// saved again.
  Future<void> tickBlock(Note note, String blockId) => save(
    note.copyWith(
      blocks: [
        for (final b in note.blocks ?? const <PageBlock>[])
          b is PageTodo && b.id == blockId ? b.ticked() : b,
      ],
    ),
  );

  Future<void> pin(Note note, {required bool on}) =>
      _change(NoteChange.pin(note.id, on: on));

  /// What waits goes now, if it can: the notebook opened, or the app came
  /// back to the front (F107 B8).
  Future<void> retry() => _send();

  /// The waiting change for [id], if one is still on the phone.
  bool waits(String id) => _waiting.any((c) => c.noteId == id);

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
            _again();
            return;
          }
          refused = true;
          // B15: said, and its words kept as the Draft.
          final lost = change.note;
          if (change.op == 'save' && lost != null) {
            ref.read(noteRefusedProvider.notifier).refused(lost);
          }
        }
        _tries = 0;
        _retry?.cancel();
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

  /// The next try after a lost signal: 15 s, then twice as long each
  /// time, up to 5 minutes.
  void _again() {
    _retry?.cancel();
    final wait = _retryFirst * (1 << _tries.clamp(0, 5));
    _tries++;
    _retry = Timer(wait > _retryMost ? _retryMost : wait, () {
      if (_waiting.isNotEmpty) unawaited(_send());
    });
  }

  /// A voice note's recording, a note's photos (F106), its PDFs and its
  /// voice blocks' recordings (F107) go to Storage first, once each.
  Future<NoteChange> _upload(NoteChange change) async {
    var note = change.note;
    if (change.op != 'save' || note == null) return change;
    note = await _uploadPage(note);
    change = NoteChange.save(note);
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

  /// A page's PDFs and voice blocks, each kept on the phone's list as it
  /// goes, so a lost signal sends only the rest.
  Future<Note> _uploadPage(Note note) async {
    var sent = note;
    Future<void> keep() async {
      _waiting = [NoteChange.save(sent), ..._waiting.skip(1)];
      await _store();
    }

    for (final (i, f) in note.files.indexed) {
      if (f.path != null || f.local == null) continue;
      final path = await _repo.uploadFile(note.id, f);
      sent = sent.copyWith(files: [...sent.files]..[i] = f.uploaded(path));
      await keep();
    }
    final blocks = note.blocks;
    if (blocks == null) return sent;
    for (final (i, b) in blocks.indexed) {
      if (b is! PageVoice || b.path != null || b.local == null) continue;
      final path = await _repo.uploadRecording(
        note.id,
        NoteRecording(local: b.local, durationMs: b.durationMs),
      );
      sent = sent.copyWith(blocks: [...sent.blocks!]..[i] = b.uploaded(path));
      await keep();
    }
    return sent;
  }

  /// False when the note was deleted elsewhere.
  Future<bool> _call(NoteChange change) async {
    switch (change.op) {
      case 'save':
        return _repo.save(change.note!, newPageTitle: change.newPageTitle);
      case 'done':
        await _repo.setDone(change.id!, on: change.on);
      case 'pin':
        await _repo.pin(change.id!, on: change.on);
      case 'delete':
        await _repo.delete(change.note!);
      case 'page':
        await _repo.createPage(change.page!);
      case 'page_edit':
        final page = change.page!;
        await _repo.updatePage(page.id, page.title, page.icon);
      case 'page_open':
        await _repo.openPage(change.target!);
      case 'page_pin':
        await _repo.pinPages(change.ids, on: change.on);
      case 'page_move':
        await _repo.movePages(change.ids, change.target);
      case 'notes_move':
        await _repo.moveNotes(change.noteIds, change.target!);
      case 'merge':
        final made = change.page;
        if (made != null) await _repo.createPage(made);
        await _repo.merge(change.ids, change.noteIds, change.target!);
      case 'page_delete':
        await _repo.deletePages(change.ids);
    }
    return true;
  }

  /// The note no longer waits, unless another change to it does.
  void _sent(NoteChange change) {
    final data = state.value;
    final id = change.noteId;
    if (data == null || id == null) return;
    if (_waiting.any((c) => c.noteId == id)) return;
    state = AsyncData(
      data.copyWith(
        notes: [
          for (final n in data.all)
            n.id == id ? n.copyWith(waiting: false) : n,
        ],
      ),
    );
  }
}

/// My calendar's rows for a week (the phone's days, both in).
final calendarProvider = FutureProvider.autoDispose
    .family<List<CalendarRow>, ({DateTime from, DateTime to})>(
      (ref, days) =>
          ref.watch(notebookRepositoryProvider).calendar(days.from, days.to),
    );
