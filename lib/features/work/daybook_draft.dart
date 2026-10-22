import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../data/models/daybook.dart';
import '../../data/models/note.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../data/models/template.dart';
import '../entry/entry_state.dart';
import 'work_outbox.dart';

/// What a card in writing posts (E6 v14, the kind chip's one choice), in
/// the kind menu's order: the Note, the plain post, first (F58).
enum DaybookKind {
  note(DaybookPost.noteKind),
  workItem(DaybookPost.workItemKind),
  checklist(DaybookPost.checklistKind),
  announcement(DaybookPost.announcementKind),
  activity(DaybookPost.activityKind),
  file(DaybookPost.fileKind),

  /// A daily report (slice 7): started from the Space menu, never from the
  /// kind menu.
  report(DaybookPost.reportKind);

  const DaybookKind(this.json);
  final String json;

  static DaybookKind fromJson(Object? value) =>
      values.where((k) => k.json == value).firstOrNull ?? workItem;
}

/// Someone a checklist or an activity is for, kept with their name so the
/// card shows it before the Space's people load.
typedef DraftPerson = ({String id, String name});

/// A checklist point being written, with the id the app chose for it.
typedef DraftPoint = ({String id, String text});

/// A Library file on a card being written: one already in the Library
/// ([local] null), or one picked on the phone that goes to the Library
/// when the post is sent, under the id the app chose ([libraryId]), as a
/// new version of [supersedesId] when one was chosen.
@immutable
class DraftFile {
  const DraftFile({
    required this.libraryId,
    required this.name,
    required this.mime,
    this.bytes,
    this.local,
    this.revLabel,
    this.supersedesId,
    this.supersedesRev,
    this.added = false,
  });

  factory DraftFile.fromJson(Map<String, dynamic> json) => DraftFile(
    libraryId: json['library_id'] as String,
    name: json['name'] as String? ?? '',
    mime: json['mime'] as String? ?? 'application/pdf',
    bytes: (json['bytes'] as num?)?.toInt(),
    local: json['local'] as String?,
    revLabel: json['rev_label'] as String?,
    supersedesId: json['supersedes_id'] as String?,
    supersedesRev: json['supersedes_rev'] as String?,
    added: json['added'] as bool? ?? false,
  );

  final String libraryId;
  final String name;
  final String mime;
  final int? bytes;

  /// The copy on the phone, until it is in the Library.
  final String? local;
  final String? revLabel;

  /// The older version it replaces, and that one's revision ("Rev C").
  final String? supersedesId;
  final String? supersedesRev;

  /// It reached the Library (add_library_file), so a retry doesn't add it
  /// again.
  final bool added;

  bool get isNew => local != null;

  /// The same file as a new one, not a new version (F71's ✕).
  DraftFile get asNew => DraftFile(
    libraryId: libraryId,
    name: name,
    mime: mime,
    bytes: bytes,
    local: local,
    revLabel: revLabel,
    added: added,
  );

  DraftFile get inLibrary => DraftFile(
    libraryId: libraryId,
    name: name,
    mime: mime,
    bytes: bytes,
    local: local,
    revLabel: revLabel,
    supersedesId: supersedesId,
    supersedesRev: supersedesRev,
    added: true,
  );

  Map<String, dynamic> toJson() => {
    'library_id': libraryId,
    'name': name,
    'mime': mime,
    'bytes': bytes,
    'local': local,
    'rev_label': revLabel,
    'supersedes_id': supersedesId,
    'supersedes_rev': supersedesRev,
    'added': added,
  };
}

/// The post being written in place (E1–E6, K4), or a posted work item
/// being edited (X1 Edit). The app chose its [id] when the card opened, so
/// it is the same post however often it is sent. Each [kind] uses its own
/// fields: a work item its owner, due, place and files; a checklist its
/// people, points and due; an announcement its pin; an activity its
/// start, end, place and people; a file post its Library file.
@immutable
class DaybookPostDraft {
  const DaybookPostDraft({
    required this.id,
    this.kind = DaybookKind.workItem,
    this.title = '',
    this.body = '',
    this.ownerId,
    this.ownerName,
    this.place,
    this.dueDate,
    this.dueAt,
    this.photos = const [],
    this.people = const [],
    this.points = const [],
    this.pinnedUntil,
    this.startsAt,
    this.endsAt,
    this.files = const [],
    this.teamId,
    this.teamName,
    this.couldNotSend = false,
    this.quote,
    this.sourceMessageId,
    this.templateId,
    this.templateName,
    this.blocks = const [],
    this.reportDay,
    this.onSite = '',
    this.problems = '',
    this.refs = const [],
    this.notes = const [],
    this.refsOut = const [],
    this.noteId,
  });

  factory DaybookPostDraft.fromJson(Map<String, dynamic> json) =>
      DaybookPostDraft(
        id: json['id'] as String,
        kind: DaybookKind.fromJson(json['kind']),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        ownerId: json['owner_id'] as String?,
        ownerName: json['owner_name'] as String?,
        place: json['place'] as String?,
        dueDate: _day(json['due_date']),
        dueAt: _time(json['due_at']),
        // Drafts kept before slice 2 had one photo.
        photos: [
          for (final p in json['photos'] as List? ?? const []) p as String,
          if (json['photo'] case final String one) one,
        ],
        people: [
          for (final p in json['people'] as List? ?? const [])
            (
              id: (p as Map<String, dynamic>)['id'] as String,
              name: p['name'] as String? ?? '',
            ),
        ],
        points: [
          for (final p in json['points'] as List? ?? const [])
            (
              id: (p as Map<String, dynamic>)['id'] as String,
              text: p['text'] as String? ?? '',
            ),
        ],
        pinnedUntil: _time(json['pinned_until']),
        startsAt: _time(json['starts_at']),
        endsAt: _time(json['ends_at']),
        files: [
          for (final f in json['files'] as List? ?? const [])
            DraftFile.fromJson(f as Map<String, dynamic>),
        ],
        teamId: json['team_id'] as String?,
        teamName: json['team_name'] as String?,
        couldNotSend: json['could_not_send'] as bool? ?? false,
        quote: DaybookQuote.fromJson(json['quote']),
        sourceMessageId: json['source_message_id'] as String?,
        templateId: json['template_id'] as String?,
        templateName: json['template_name'] as String?,
        blocks: [
          for (final b in json['blocks'] as List? ?? const [])
            b as Map<String, dynamic>,
        ],
        reportDay: _day(json['report_day']),
        onSite: json['on_site'] as String? ?? '',
        problems: json['problems'] as String? ?? '',
        refs: [
          for (final r in json['refs'] as List? ?? const [])
            ReportRef.fromJson(r as Map<String, dynamic>),
        ],
        notes: [
          for (final r in json['notes'] as List? ?? const [])
            ReportRef.fromJson(r as Map<String, dynamic>),
        ],
        refsOut: [for (final r in json['refs_out'] as List? ?? const []) '$r'],
        noteId: json['note_id'] as String?,
      );

  /// A post the server refused, back as the Draft it was (review 46).
  factory DaybookPostDraft.refused(PendingItem item) {
    final kept = item.draft;
    final photos = [for (final p in item.photos) p.local];
    if (kept != null) {
      return kept.copyWith(photos: photos, files: item.files, refused: true);
    }
    return DaybookPostDraft(
      id: item.id,
      title: item.title,
      body: item.body ?? '',
      ownerId: item.ownerId,
      ownerName: item.ownerName,
      place: item.place,
      dueDate: item.dueDate,
      dueAt: item.dueAt,
      photos: photos,
      files: item.files,
      couldNotSend: true,
      quote: item.quote,
      sourceMessageId: item.sourceMessageId,
      noteId: item.noteId,
    );
  }

  /// A posted work item or announcement (with its pin, F44), to edit.
  factory DaybookPostDraft.of(DaybookPost post) => DaybookPostDraft(
    id: post.id,
    kind: DaybookKind.fromJson(post.kind),
    pinnedUntil: post.pinnedUntil,
    title: post.title,
    body: post.body ?? '',
    ownerId: post.item?.ownerId,
    ownerName: post.item?.ownerName,
    place: post.place,
    dueDate: post.dueDate,
    dueAt: post.dueAt,
  );

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  static DateTime? _day(Object? value) {
    final d = _time(value);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  /// The title's length on the server: a work item 2 to 140
  /// (create_work_item), the other kinds 1 to 200 (create_space_post).
  static const titleMin = 2;
  static const titleMax = 140;
  static const postTitleMax = 200;
  static const bodyMax = 5000;

  /// The place's length on the server (space_posts.place_text).
  static const placeMax = 80;

  /// At most 10 photos and files on a post (post_files).
  static const filesMax = 10;

  final String id;
  final DaybookKind kind;
  final String title;
  final String body;
  final String? ownerId;

  /// Kept with the id, so the card shows the owner before the Space's
  /// people load.
  final String? ownerName;
  final String? place;

  /// The phone's own due date, and its time when one was chosen.
  final DateTime? dueDate;
  final DateTime? dueAt;

  /// Photos: copies kept in the app's folder, so they outlive the camera's
  /// cache and the app being closed. Up to ten (K4).
  final List<String> photos;
  final List<DraftPerson> people;
  final List<DraftPoint> points;

  /// An announcement pinned until then; null: not pinned.
  final DateTime? pinnedUntil;

  /// An activity's start and its optional end (the phone's own).
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// A file post's file (the first), or a work item's attached files.
  final List<DraftFile> files;

  /// Who it goes to (F56, "To: Everyone ›"): a Team, with its name so
  /// the card shows it before the Space's people load; null, Everyone.
  final String? teamId;
  final String? teamName;

  /// The server refused it when it was posted: "Couldn't send. Tap to fix".
  final bool couldNotSend;

  /// The message a work item is made from, quoted in it (review 64:
  /// DM4–DM5, S8m). Only a Space chat message has a [sourceMessageId]; a
  /// direct message is quoted only, and never leaves its thread.
  final DaybookQuote? quote;
  final String? sourceMessageId;

  /// The template it started from (slice 7), named on the card as "From:
  /// Concrete pour check"; [blocks] its page, as the template keeps it.
  final String? templateId;
  final String? templateName;
  final List<Map<String, dynamic>> blocks;

  /// A daily report (slice 7): its day (today only), what was on site,
  /// the work checked today ([refs], from daily_report_fill), the day's
  /// notes added under On site, the work items taken out of it (so a new
  /// fill leaves them out), and the problems.
  final DateTime? reportDay;
  final String onSite;
  final String problems;
  final List<ReportRef> refs;
  final List<ReportRef> notes;
  final List<String> refsOut;

  /// The note in My notebook it was put in from (slice 8): marked once
  /// the server takes the post (mark_note_put). The note stays private.
  final String? noteId;

  /// The Done today lines that go: the day's checked work, less what was
  /// taken out.
  List<ReportRef> get refsIn => [
    for (final r in refs)
      if (!refsOut.contains(r.postId)) r,
  ];

  int get _titleMax => kind == DaybookKind.workItem ? titleMax : postTitleMax;

  /// What the title box takes.
  int get titleLimit => _titleMax;

  /// The points that have words.
  List<DraftPoint> get writtenPoints => [
    for (final p in points)
      if (p.text.trim().isNotEmpty) p,
  ];

  /// Nothing entered at all: no draft (the card just closes). A photo, an
  /// owner, a date or a place alone is kept (review 46: the photo often
  /// comes first).
  bool get isEmpty => kind == DaybookKind.report
      // A report's day and its checked work fill themselves: it is kept
      // once something is written or added.
      ? onSite.trim().isEmpty &&
            problems.trim().isEmpty &&
            notes.isEmpty &&
            photos.isEmpty &&
            files.isEmpty &&
            refsOut.isEmpty
      : title.trim().isEmpty &&
            body.trim().isEmpty &&
            ownerId == null &&
            place == null &&
            dueDate == null &&
            photos.isEmpty &&
            people.isEmpty &&
            writtenPoints.isEmpty &&
            pinnedUntil == null &&
            startsAt == null &&
            files.isEmpty &&
            quote == null &&
            noteId == null;

  /// Nothing yet but the message it quotes (review 64): just made from a
  /// message, not a Draft left from before.
  bool get onlyQuote =>
      quote != null &&
      copyWith(quote: () => null, sourceMessageId: () => null).isEmpty;

  /// A title the server takes. A file post's title is optional: the
  /// server takes the file's name.
  bool get titleFits {
    final length = title.trim().length;
    if (kind == DaybookKind.file) return length <= _titleMax;
    final min = kind == DaybookKind.workItem ? titleMin : 1;
    return length >= min && length <= _titleMax;
  }

  /// Post turns on: the words it can't go without. What it still needs
  /// (an owner, the people, a start) opens its picker first ([missing]).
  bool get readyToTry => switch (kind) {
    DaybookKind.file => files.isNotEmpty && titleFits,
    DaybookKind.checklist => titleFits && writtenPoints.isNotEmpty,
    _ => titleFits,
  };

  /// What Post asks for before it sends, or null when nothing.
  DaybookMissing? missing(DateTime now) => switch (kind) {
    DaybookKind.workItem when ownerId == null => DaybookMissing.owner,
    DaybookKind.checklist when people.isEmpty => DaybookMissing.people,
    // F56: who's coming is required, before the time.
    DaybookKind.activity when people.isEmpty => DaybookMissing.people,
    DaybookKind.activity when startsAt == null || !startsAt!.isAfter(now) =>
      DaybookMissing.start,
    _ => null,
  };

  /// Ready to send at [now].
  bool canPost(DateTime now) => readyToTry && missing(now) == null;

  DaybookPostDraft copyWith({
    DaybookKind? kind,
    String? title,
    String? body,
    String? ownerId,
    String? ownerName,
    String? Function()? place,
    DateTime? Function()? dueDate,
    DateTime? Function()? dueAt,
    List<String>? photos,
    List<DraftPerson>? people,
    List<DraftPoint>? points,
    DateTime? Function()? pinnedUntil,
    DateTime? Function()? startsAt,
    DateTime? Function()? endsAt,
    List<DraftFile>? files,
    ({String id, String name})? Function()? team,
    DaybookQuote? Function()? quote,
    String? Function()? sourceMessageId,
    ({String id, String? name, List<Map<String, dynamic>> blocks})? Function()?
    template,
    DateTime? Function()? reportDay,
    String? onSite,
    String? problems,
    List<ReportRef>? refs,
    List<ReportRef>? notes,
    List<String>? refsOut,
    List<Map<String, dynamic>>? blocks,
    String? Function()? noteId,
    bool refused = false,
  }) => DaybookPostDraft(
    noteId: noteId == null ? this.noteId : noteId(),
    templateId: template == null ? templateId : template()?.id,
    templateName: template == null ? templateName : template()?.name,
    blocks:
        blocks ??
        (template == null ? this.blocks : template()?.blocks ?? this.blocks),
    reportDay: reportDay == null ? this.reportDay : reportDay(),
    onSite: onSite ?? this.onSite,
    problems: problems ?? this.problems,
    refs: refs ?? this.refs,
    notes: notes ?? this.notes,
    refsOut: refsOut ?? this.refsOut,
    quote: quote == null ? this.quote : quote(),
    sourceMessageId: sourceMessageId == null
        ? this.sourceMessageId
        : sourceMessageId(),
    id: id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    body: body ?? this.body,
    ownerId: ownerId ?? this.ownerId,
    ownerName: ownerName ?? this.ownerName,
    place: place == null ? this.place : place(),
    dueDate: dueDate == null ? this.dueDate : dueDate(),
    dueAt: dueAt == null ? this.dueAt : dueAt(),
    photos: photos ?? this.photos,
    people: people ?? this.people,
    points: points ?? this.points,
    pinnedUntil: pinnedUntil == null ? this.pinnedUntil : pinnedUntil(),
    startsAt: startsAt == null ? this.startsAt : startsAt(),
    endsAt: endsAt == null ? this.endsAt : endsAt(),
    files: files ?? this.files,
    teamId: team == null ? teamId : team()?.id,
    teamName: team == null ? teamName : team()?.name,
    couldNotSend: refused || couldNotSend,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.json,
    'title': title,
    'body': body,
    'owner_id': ownerId,
    'owner_name': ownerName,
    'place': place,
    'due_date': dueDate?.toIso8601String(),
    'due_at': dueAt?.toUtc().toIso8601String(),
    'photos': photos,
    'people': [
      for (final p in people) {'id': p.id, 'name': p.name},
    ],
    'points': [
      for (final p in points) {'id': p.id, 'text': p.text},
    ],
    'pinned_until': pinnedUntil?.toUtc().toIso8601String(),
    'starts_at': startsAt?.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'files': [for (final f in files) f.toJson()],
    'team_id': teamId,
    'team_name': teamName,
    'could_not_send': couldNotSend,
    'quote': quote?.toJson(),
    'source_message_id': sourceMessageId,
    'template_id': templateId,
    'template_name': templateName,
    'blocks': blocks,
    'report_day': reportDay?.toIso8601String(),
    'on_site': onSite,
    'problems': problems,
    'refs': [for (final r in refs) r.toJson()],
    'notes': [for (final r in notes) r.toJson()],
    'refs_out': refsOut,
    'note_id': noteId,
  };
}

/// What Post still needs before it can send: it opens that picker.
enum DaybookMissing { owner, people, start }

/// The card in place: a new post's ([DaybookDraft]) or an edit's
/// ([DaybookEdit]).
abstract class DaybookWritingNotifier extends Notifier<DaybookPostDraft?> {
  Future<void> put(DaybookPostDraft draft);
}

/// The card being written in one Space, or null. As soon as anything is
/// entered it is saved on the phone as it changes, per account and Space,
/// so a killed app comes back to it as a Draft that only its author sees
/// (E4). Drafts never go to the server (data-model §14).
final daybookDraftProvider =
    NotifierProvider.family<DaybookDraft, DaybookPostDraft?, String>(
      DaybookDraft.new,
    );

class DaybookDraft extends DaybookWritingNotifier {
  DaybookDraft(this.spaceId);

  final String spaceId;
  String? _key;

  @override
  DaybookPostDraft? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authUserIdProvider).value;
    _key = userId == null ? null : 'daybook_draft:$userId:$spaceId';
    final raw = _key == null ? null : prefs.getString(_key!);
    if (raw == null) return null;
    try {
      return DaybookPostDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  /// Opens a new card with [id], or keeps the one being written.
  void open(String id) => state ??= DaybookPostDraft(id: id);

  /// A message to make a work item from (review 64: DM4–DM5, S8m): the card
  /// being written, or a new one with [id], now quoting it. A Space chat
  /// message also gives its [sourceMessageId] and, from a Team thread, its
  /// [team] (the server keeps it in that Team). Nothing is posted: only
  /// Post posts.
  Future<void> quoteMessage(
    String id,
    DaybookQuote quote, {
    String? sourceMessageId,
    ({String id, String name})? team,
  }) => put(
    // A quote goes on a work item (DM4–DM5, S8m): a card half-written as
    // another kind turns into one, keeping its words.
    (state ?? DaybookPostDraft(id: id)).copyWith(
      kind: DaybookKind.workItem,
      quote: () => quote,
      sourceMessageId: () => sourceMessageId,
      team: team == null ? null : () => team,
    ),
  );

  /// Put in a Space from My notebook (slice 8, review 83): a note or a
  /// to-do becomes a work item, its first line the title and the rest its
  /// words (a to-do's time its due); a checklist a checklist with its
  /// points. A card already half-written keeps its words; the note's are
  /// added under them.
  Future<void> fromNote(String id, Note note) {
    final current = state;
    if (current != null && !current.isEmpty) {
      final words = [
        note.body.trim(),
        for (final p in note.points) p.text,
      ].where((w) => w.isNotEmpty).join('\n');
      return put(
        current.copyWith(
          body: [
            current.body.trim(),
            words,
          ].where((w) => w.isNotEmpty).join('\n\n'),
          noteId: () => note.id,
        ),
      );
    }
    final fresh = DaybookPostDraft(id: id, noteId: note.id);
    if (note.kind == NoteKind.checklist) {
      return put(
        fresh.copyWith(
          kind: DaybookKind.checklist,
          title: _cut(note.body.trim(), DaybookPostDraft.postTitleMax).$1,
          points: [
            for (final p in note.points.take(Note.pointsMax))
              (id: newUuid(), text: p.text),
          ],
        ),
      );
    }
    final (title, rest) = _split(note.body.trim());
    final due = note.kind == NoteKind.todo ? note.dueAt : null;
    return put(
      fresh.copyWith(
        title: title,
        body: rest,
        dueDate: () =>
            due == null ? null : DateTime(due.year, due.month, due.day),
        dueAt: () => due,
      ),
    );
  }

  /// A work item's title from a note: its first line, cut at a word when
  /// it is longer than a title; what's left goes in the words.
  static (String, String) _split(String text) {
    final newline = text.indexOf('\n');
    final first = newline < 0 ? text : text.substring(0, newline).trim();
    final rest = newline < 0 ? '' : text.substring(newline + 1).trim();
    final (title, cut) = _cut(first, DaybookPostDraft.titleMax);
    if (!cut) return (title, rest);
    return (title, text);
  }

  /// [text] at most [max] long, cut at a space when it can be; true when
  /// it was cut.
  static (String, bool) _cut(String text, int max) {
    if (text.length <= max) return (text, false);
    final space = text.lastIndexOf(' ', max);
    return (text.substring(0, space > 0 ? space : max).trim(), true);
  }

  /// Sets the card and saves it once anything is entered.
  @override
  Future<void> put(DaybookPostDraft draft) async {
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

  /// A post the server refused comes back as the Draft, unless another
  /// card holds something. True when it did.
  Future<bool> restoreRefused(PendingItem item) async {
    final current = state;
    if (current != null && !current.isEmpty) return false;
    await put(DaybookPostDraft.refused(item));
    return true;
  }

  /// The card closes: an empty one is gone, with its photos; one with
  /// anything in it stays as the Draft.
  Future<void> close() async {
    final draft = state;
    if (draft != null && draft.isEmpty) await discard();
  }

  /// Gone for good. [keepFiles] when the photos and files went to the
  /// outbox with the post.
  Future<void> discard({bool keepFiles = false}) async {
    final draft = state;
    state = null;
    final key = _key;
    if (key != null) {
      await ref.read(sharedPreferencesProvider).remove(key);
    }
    if (keepFiles || draft == null) return;
    for (final path in [
      ...draft.photos,
      for (final f in draft.files) ?f.local,
    ]) {
      unawaited(deleteKept(path));
    }
  }

  static Future<void> deleteKept(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

/// A posted work item being edited in place (X1 Edit → 2524:33577): its
/// card at Now, filled with what it says. Only on the screen; putting it
/// down leaves the post as it was.
final daybookEditProvider =
    NotifierProvider.family<DaybookEdit, DaybookPostDraft?, String>(
      DaybookEdit.new,
    );

class DaybookEdit extends DaybookWritingNotifier {
  DaybookEdit(this.spaceId);

  final String spaceId;

  /// The post as it was, to send only what changed.
  DaybookPost? original;

  @override
  DaybookPostDraft? build() => null;

  void start(DaybookPost post) {
    original = post;
    state = DaybookPostDraft.of(post);
  }

  @override
  Future<void> put(DaybookPostDraft draft) async => state = draft;

  void stop() {
    original = null;
    state = null;
  }
}
