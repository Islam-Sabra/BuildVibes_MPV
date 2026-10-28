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

/// My notebook as the phone shows it (review 99A): its pages that aren't
/// deleted, and the entries in them, newest first. An entry whose page is
/// gone (deleted, or merged away) doesn't show; one from an older version
/// with no page shows in the latest page, where the server puts it. An
/// entry in Deleted items or archived shows in no list, count or calendar
/// (99B ruling 5); the archived ones are kept for "Archived ›".
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
          if (n.shown && ids.contains(n.pageId ?? latest?.id)) n,
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

  /// The latest activity in [id] and the pages under it (review 100 Part
  /// 7: a row's "when").
  DateTime activityIn(String id) {
    final ids = tree(id);
    return pages
        .where((p) => ids.contains(p.id))
        .map((p) => p.lastActivityAt)
        .reduce((a, b) => b.isAfter(a) ? b : a);
  }

  /// How many entries [id] and the pages under it hold (review 100 Part 7).
  int entryCount(String id) {
    final ids = tree(id);
    return notes.where((n) => ids.contains(pageOf(n))).length;
  }

  /// [id]'s archived entries, newest first (review 100 Part 3b).
  List<Note> archived(String id) => [
    for (final n in all)
      if (n.archivedAt != null && n.deletedAt == null && pageOf(n) == id) n,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// The latest entry in [id] or a page under it.
  Note? latestIn(String id) {
    final ids = tree(id);
    return notes.where((n) => ids.contains(pageOf(n))).firstOrNull;
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

/// A day's entries in the page's order (review 102 N3): those arranged by
/// hand in their places; any added since, by time, where new ones come in
/// (at the day's top newest first, at its bottom oldest first). [day] is in
/// the sort's time order.
List<Note> inHandOrder(List<Note> day, {required bool oldestFirst}) {
  final placed = [
    for (final n in day)
      if (n.dayPosition != null) n,
  ]..sort((a, b) => a.dayPosition!.compareTo(b.dayPosition!));
  final rest = [
    for (final n in day)
      if (n.dayPosition == null) n,
  ];
  return oldestFirst ? [...placed, ...rest] : [...rest, ...placed];
}

/// One change to the notebook, kept on the phone until the server has it:
/// an entry's ([note], [id]) or pages' ([page], [ids], [noteIds],
/// [target]).
@immutable
class NoteChange {
  const NoteChange._(
    this.op, {
    this.note,
    this.id,
    this.on = false,
    this.at,
    this.newPageTitle,
    this.page,
    this.ids = const [],
    this.noteIds = const [],
    this.target,
    this.copies = const [],
    this.baseVersion,
  });

  /// [baseVersion]: an edit of a saved entry, from the version it started
  /// from (migration 48).
  const NoteChange.save(
    Note note, {
    String? newPageTitle,
    DateTime? at,
    int? baseVersion,
  }) : this._(
         'save',
         note: note,
         newPageTitle: newPageTitle,
         at: at,
         baseVersion: baseVersion,
       );
  const NoteChange.done(String id, {required bool on, DateTime? at})
    : this._('done', id: id, on: on, at: at);
  const NoteChange.pin(String id, {required bool on})
    : this._('pin', id: id, on: on);

  /// An older phone's delete, still in its outbox: it goes to Deleted
  /// items too (review 100 H5).
  const NoteChange.delete(Note note) : this._('delete', note: note);

  /// Entries to Deleted items (99B B3), with Undo first.
  const NoteChange.deleteEntries(List<String> ids, {DateTime? at})
    : this._('delete_entries', ids: ids, at: at);

  /// Duplicate (review 100 Part 3): each of [copies] right under the entry
  /// of [ids] it copies.
  const NoteChange.duplicate(List<String> ids, List<Note> copies)
    : this._('duplicate', ids: ids, copies: copies);

  /// [lines] of the entry [id] (a line with its children) to Deleted items
  /// as "Part of an entry", [part] (99B B3).
  const NoteChange.deleteLines(String id, List<String> lines, String part)
    : this._('delete_lines', id: id, ids: lines, target: part);

  /// Archive or Unarchive (review 100 Part 3b), with Undo first.
  const NoteChange.archive(String id, {required bool on, DateTime? at})
    : this._('archive', id: id, on: on, at: at);

  /// "+ New page", or a sub-page.
  const NoteChange.newPage(NotebookPage page) : this._('page', page: page);

  /// The title and icon, edited in place.
  const NoteChange.editPage(NotebookPage page)
    : this._('page_edit', page: page);

  /// The page opened: no longer new.
  const NoteChange.openPage(String target)
    : this._('page_open', target: target);
  const NoteChange.pinPages(List<String> ids, {required bool on})
    : this._('page_pin', ids: ids, on: on);

  /// Move into… ([target] null: the top).
  const NoteChange.movePages(List<String> ids, String? target)
    : this._('page_move', ids: ids, target: target);

  /// Move to page….
  const NoteChange.moveNotes(
    List<String> noteIds,
    String target, {
    DateTime? at,
  }) : this._('notes_move', noteIds: noteIds, target: target, at: at);

  /// Merge [ids] and [noteIds] into [target]; [page] when it is new.
  const NoteChange.merge(
    List<String> ids,
    List<String> noteIds,
    String target, {
    NotebookPage? page,
    DateTime? at,
  }) : this._(
         'merge',
         ids: ids,
         noteIds: noteIds,
         target: target,
         page: page,
         at: at,
       );
  const NoteChange.deletePages(List<String> ids)
    : this._('page_delete', ids: ids);

  /// One day's entries, top to bottom in their new order (review 102 N3).
  const NoteChange.arrangeDay(List<String> noteIds)
    : this._('day_arrange', noteIds: noteIds);

  factory NoteChange.fromJson(Map<String, dynamic> json) {
    final note = json['note'] == null
        ? null
        : Note.fromJson(json['note'] as Map<String, dynamic>);
    final page = json['page'] == null
        ? null
        : NotebookPage.fromJson(json['page'] as Map<String, dynamic>);
    final on = json['on'] as bool? ?? false;
    final target = json['target'] as String?;
    final at = json['at'] == null
        ? null
        : DateTime.parse(json['at'] as String).toLocal();
    List<String> list(String key) => [
      for (final v in json[key] as List? ?? const []) v as String,
    ];
    return switch (json['op']) {
      'done' => NoteChange.done(json['id'] as String, on: on, at: at),
      'pin' => NoteChange.pin(json['id'] as String, on: on),
      'delete' => NoteChange.delete(note!),
      'page' => NoteChange.newPage(page!),
      'page_edit' => NoteChange.editPage(page!),
      'page_open' => NoteChange.openPage(target!),
      'page_pin' => NoteChange.pinPages(list('ids'), on: on),
      'page_move' => NoteChange.movePages(list('ids'), target),
      'notes_move' => NoteChange.moveNotes(list('note_ids'), target!, at: at),
      'day_arrange' => NoteChange.arrangeDay(list('note_ids')),
      'merge' => NoteChange.merge(
        list('ids'),
        list('note_ids'),
        target!,
        page: page,
        at: at,
      ),
      'page_delete' => NoteChange.deletePages(list('ids')),
      'delete_entries' => NoteChange.deleteEntries(list('ids'), at: at),
      'archive' => NoteChange.archive(json['id'] as String, on: on, at: at),
      'duplicate' => NoteChange.duplicate(list('ids'), [
        for (final c in json['copies'] as List? ?? const [])
          Note.fromJson(c as Map<String, dynamic>),
      ]),
      'delete_lines' => NoteChange.deleteLines(
        json['id'] as String,
        list('ids'),
        target!,
      ),
      _ => NoteChange.save(
        note!,
        newPageTitle: json['new_page_title'] as String?,
        at: at,
        baseVersion: json['base_version'] as int?,
      ),
    };
  }

  final String op;
  final Note? note;
  final String? id;
  final bool on;

  /// When it was made, on the phone: a to-do marked done, an entry saved,
  /// moved or merged (a page's latest activity, as the server sets it).
  final DateTime? at;

  /// A save into a page made with it, titled from the entry (A2).
  final String? newPageTitle;
  final NotebookPage? page;
  final List<String> ids;
  final List<String> noteIds;
  final String? target;
  final List<Note> copies;
  final int? baseVersion;

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
    if (copies.isNotEmpty) 'copies': [for (final c in copies) c.toJson()],
    'base_version': ?baseVersion,
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
        final made =
            saved.pageId != null && title != null && data.page(into) == null;
        final was = notes.where((n) => n.id == saved.id).firstOrNull;
        // Activity as the server counts it: written, its words or to-dos
        // changed, or moved in; never a pin or a reminder (review 99 C4).
        final active = was == null || _wordsChanged(was, saved);
        final when = at ?? saved.createdAt;
        // The server counts the version up on each save of an entry it
        // has (save_note), so the next edit starts from the right one.
        return NotebookData(
          notes: _placed(
            saved.copyWith(version: was == null ? 1 : was.version + 1),
            notes,
          ),
          pages: [
            for (final p in pages)
              active && p.id == into ? _stamped(p, when) : p,
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
      case 'day_arrange':
        final place = {for (final (i, id) in noteIds.indexed) id: i + 1};
        return data.copyWith(
          notes: [
            for (final n in notes)
              place[n.id] == null
                  ? n
                  : n.copyWith(dayPosition: () => place[n.id]),
          ],
        );
      case 'archive':
        return data.copyWith(
          notes: [
            for (final n in notes)
              n.id == id
                  ? n.copyWith(
                      archivedAt: () =>
                          on ? (n.archivedAt ?? at ?? DateTime.now()) : null,
                    )
                  : n,
          ],
        );
      case 'delete_entries':
        return data.copyWith(
          notes: [
            for (final n in notes)
              ids.contains(n.id) && n.deletedAt == null
                  ? n.copyWith(deletedAt: () => at ?? DateTime.now())
                  : n,
          ],
        );
      case 'duplicate':
        return data.copyWith(
          notes: [
            for (final n in notes) ...[
              n,
              for (final (i, c) in copies.indexed)
                if (i < ids.length && ids[i] == n.id) c.copyWith(waiting: true),
            ],
          ],
        );
      case 'delete_lines':
        final gone = ids.toSet();
        return data.copyWith(
          notes: [
            for (final n in notes)
              n.id == id && n.blocks != null
                  ? n.copyWith(
                      blocks: [
                        for (final b in n.blocks!)
                          if (!gone.contains(b.id)) b,
                      ],
                      version: n.version + 1,
                    )
                  : n,
          ],
        );
      case 'done' || 'pin':
        final ticked = notes.where((n) => n.id == id).firstOrNull;
        final page = op == 'done' && ticked != null && at != null
            ? data.pageOf(ticked)
            : null;
        return NotebookData(
          pages: [for (final p in pages) p.id == page ? _stamped(p, at!) : p],
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
        return NotebookData(
          pages: [
            for (final p in pages)
              p.id == target && at != null ? _stamped(p, at!) : p,
          ],
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
        // The page that stays climbs out of the whole tree of every page
        // that goes (review 99 C1).
        final trees = {for (final g in gone) ...data.tree(g)};
        var up = find(into)?.parentId;
        while (up != null && trees.contains(up)) {
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
                p.copyWith(
                  parentId: () => stays,
                  // A page the merge made keeps its new mark (ruling 7).
                  isNew: page != null && data.page(into) == null,
                  lastActivityAt: at,
                )
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

  /// [page] with [at] as its latest activity, if later.
  static NotebookPage _stamped(NotebookPage page, DateTime at) =>
      at.isAfter(page.lastActivityAt)
      ? page.copyWith(lastActivityAt: at)
      : page;

  /// Its words or to-dos changed, or it moved (the server's rule).
  static bool _wordsChanged(Note was, Note now) =>
      was.title != now.title ||
      was.body != now.body ||
      was.pageId != now.pageId ||
      was.doneAt != now.doneAt ||
      jsonEncode([for (final p in was.points) p.toJson()]) !=
          jsonEncode([for (final p in now.points) p.toJson()]) ||
      jsonEncode([for (final b in was.blocks ?? const []) b.toJson()]) !=
          jsonEncode([for (final b in now.blocks ?? const []) b.toJson()]);

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
final noteRefusedProvider =
    NotifierProvider<NoteRefused, ({Note note, bool elsewhere})?>(
      NoteRefused.new,
    );

/// [elsewhere]: an edit refused because the entry changed on another phone
/// meanwhile (40001, review 100 H15).
class NoteRefused extends Notifier<({Note note, bool elsewhere})?> {
  @override
  ({Note note, bool elsewhere})? build() => null;

  void refused(Note note, {bool elsewhere = false}) =>
      state = (note: note, elsewhere: elsewhere);

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

  /// Another try after a lost signal (F107 B8), sooner at first.
  Timer? _retry;
  int _tries = 0;
  static const _retryFirst = Duration(seconds: 15);
  static const _retryMost = Duration(minutes: 5);

  /// A merge or a delete shown at once but sent only after its 5 s Undo
  /// (A4), and the notebook as it was before it. Kept on the phone too
  /// (review 99 C7): an app closed during the Undo sends it next time.
  NoteChange? _held;
  NotebookData? _beforeHeld;
  String? _heldKey;

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
    _heldKey = userId == null ? null : 'notebook_held:$userId';
    _held = null;
    _beforeHeld = null;
    // A change held when the app closed: its Undo is gone, so it goes.
    final held = _read('[${prefs.getString(_heldKey ?? '') ?? ''}]');
    if (held.isNotEmpty) {
      _waiting = [..._waiting, for (final h in held) ..._sendable(h)];
      await _store();
      await prefs.remove(_heldKey!);
    }
    NotebookData server;
    try {
      final (notes, pages) = await (_repo.notes(), _repo.pages()).wait;
      server = NotebookData(notes: notes, pages: pages);
    } on ParallelWaitError<
      (List<Note>?, List<NotebookPage>?),
      (AsyncError?, AsyncError?)
    > catch (e) {
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
    await _put(change);
    await _send();
  }

  /// [change] shown and written in the phone's outbox, after a held change
  /// (which goes first); nothing is sent yet (review 100 D2).
  Future<void> _put(NoteChange change) async {
    _releaseHeldUnsent();
    state = AsyncData(change.applyTo(state.value ?? NotebookData()));
    _waiting = [..._waiting, change];
    await _store();
    await _forgetHeld();
  }

  /// [change] shows at once but goes only on [releaseHeld] (its Undo bar
  /// closing), unless [undoHeld] takes it back first (A4: Undo for 5 s).
  Future<void> hold(NoteChange change) async {
    await releaseHeld();
    _beforeHeld = state.value ?? NotebookData();
    _held = change;
    state = AsyncData(change.applyTo(_beforeHeld!));
    final key = _heldKey;
    if (key != null) {
      await ref
          .read(sharedPreferencesProvider)
          .setString(key, jsonEncode(change.toJson()));
    }
  }

  /// The held change goes.
  Future<void> releaseHeld() async {
    if (!_releaseHeldUnsent()) return;
    await _store();
    await _forgetHeld();
    await _send();
  }

  /// The held change joins what waits, not sent yet; false with none.
  bool _releaseHeldUnsent() {
    final held = _held;
    if (held == null) return false;
    _held = null;
    _beforeHeld = null;
    _waiting = [..._waiting, ..._sendable(held)];
    return true;
  }

  /// What a held change sends: a Duplicate is a save of each copy, so its
  /// photos, files and recordings go up as any entry's do, and each copy
  /// stops waiting once it went (review 100 H3).
  static List<NoteChange> _sendable(NoteChange change) =>
      change.op == 'duplicate'
      ? [for (final c in change.copies) NoteChange.save(c)]
      : [change];

  /// The held change is taken back: false when it had already gone.
  Future<bool> undoHeld() async {
    final before = _beforeHeld;
    if (_held == null || before == null) return false;
    _held = null;
    _beforeHeld = null;
    state = AsyncData(before);
    await _forgetHeld();
    return true;
  }

  Future<void> _forgetHeld() async {
    final key = _heldKey;
    if (key != null) await ref.read(sharedPreferencesProvider).remove(key);
  }

  /// A new note, or an edit of one; [newPageTitle] makes its page with it
  /// (A2: "New page", titled from the entry).
  Future<void> save(Note note, {String? newPageTitle}) => _change(
    NoteChange.save(
      note,
      newPageTitle: newPageTitle,
      at: ref.read(clockProvider)(),
    ),
  );

  /// [note] saved (an edit left with Back, review 100 D2): the future
  /// ends once it is written in the phone's outbox, so the Draft may go;
  /// the sending goes on after.
  Future<void> saveOnPhone(Note note, {int? baseVersion}) async {
    await _put(
      NoteChange.save(
        note,
        at: ref.read(clockProvider)(),
        baseVersion: baseVersion,
      ),
    );
    unawaited(_send());
  }

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

  /// One day's entries, top to bottom in their new order (review 102 N3).
  Future<void> arrangeDay(List<String> ids) =>
      _change(NoteChange.arrangeDay(ids));

  /// Move to page….
  Future<void> moveNotes(List<String> ids, String page) =>
      _change(NoteChange.moveNotes(ids, page, at: ref.read(clockProvider)()));

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

  /// What waits goes now, and the future ends once it has (review 100 H2:
  /// Share sends what the server has); false while [id] still waits (no
  /// signal).
  Future<bool> flush(String id) async {
    await releaseHeld();
    await _send();
    return !waits(id);
  }

  /// "Saved to your notebook" (a held message): a note with its words.
  Future<void> keep(String id, String words, DateTime now) => save(
    Note(id: id, kind: NoteKind.text, body: words.trim(), createdAt: now),
  );

  /// The send going on now: a second call waits for it.
  Future<void>? _sendingNow;

  Future<void> _send() =>
      _sendingNow ??= _sendAll().whenComplete(() => _sendingNow = null);

  /// Sends what waits, in order. A lost signal stops it, to go on the next
  /// change or when the notebook opens again; a refusal drops the change
  /// and reads the notebook again.
  Future<void> _sendAll() async {
    var refused = false;
    // Said once the notebook reads again (D4: the screen then tells a
    // refused edit of a saved entry from a refused new one).
    Note? lost;
    var elsewhere = false;
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
          // B15: said, and its words kept.
          if (change.op == 'save') {
            lost = change.note ?? lost;
            elsewhere = e.failure == SpaceFailure.conflict;
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
      if (refused) ref.invalidateSelf();
      if (lost != null) {
        ref
            .read(noteRefusedProvider.notifier)
            .refused(lost, elsewhere: elsewhere);
      }
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
    // A new page made with it stays with each kept step.
    final title = change.newPageTitle;
    final base = change.baseVersion;
    note = await _uploadPage(note, title, base);
    change = NoteChange.save(note, newPageTitle: title, baseVersion: base);
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
          newPageTitle: title,
          baseVersion: base,
        ),
        ..._waiting.skip(1),
      ];
      await _store();
    }
    final done = NoteChange.save(
      uploaded.copyWith(photos: sent),
      newPageTitle: title,
      baseVersion: base,
    );
    _waiting = [done, ..._waiting.skip(1)];
    await _store();
    return done;
  }

  /// A page's PDFs and voice blocks, each kept on the phone's list as it
  /// goes, so a lost signal sends only the rest.
  Future<Note> _uploadPage(Note note, String? newPageTitle, int? base) async {
    var sent = note;
    Future<void> keep() async {
      _waiting = [
        NoteChange.save(sent, newPageTitle: newPageTitle, baseVersion: base),
        ..._waiting.skip(1),
      ];
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
        return _repo.save(
          change.note!,
          newPageTitle: change.newPageTitle,
          baseVersion: change.baseVersion,
        );
      case 'done':
        await _repo.setDone(change.id!, on: change.on);
      case 'pin':
        await _repo.pin(change.id!, on: change.on);
      case 'delete':
        await _repo.deleteEntries([change.note!.id]);
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
        // One call: a new page is made by the merge itself (C2).
        await _repo.merge(
          change.ids,
          change.noteIds,
          change.target!,
          newTitle: change.page?.title,
        );
      case 'page_delete':
        await _repo.deletePages(change.ids);
      case 'delete_entries':
        await _repo.deleteEntries(change.ids);
      case 'archive':
        await _repo.archive(change.id!, on: change.on);
      case 'day_arrange':
        await _repo.arrangeDay(change.noteIds);
      case 'delete_lines':
        await _repo.deleteLines(change.id!, change.ids, change.target!);
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
          for (final n in data.all) n.id == id ? n.copyWith(waiting: false) : n,
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
