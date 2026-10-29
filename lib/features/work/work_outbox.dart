import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/signal_state.dart';
import '../../core/photo_privacy.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/sound/sent_chime.dart';
import '../../data/models/daybook.dart' show DaybookQuote;
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../entry/entry_state.dart';
import '../notebook/notebook_state.dart';
import 'daybook_draft.dart';
import 'daybook_marks.dart' show daybookExtrasProvider;
import 'daybook_state.dart';

/// A photo waiting to be sent: a copy kept on the phone ([local]) and,
/// once uploaded, its path in the Space ([remote]).
@immutable
class PendingPhoto {
  const PendingPhoto({
    required this.local,
    required this.takenAt,
    this.remote,
    this.place,
  });

  factory PendingPhoto.fromJson(Map<String, dynamic> json) => PendingPhoto(
    local: json['local'] as String,
    takenAt: DateTime.parse(json['taken_at'] as String),
    remote: json['remote'] as String?,
    place: json['place'] as String?,
  );

  final String local;
  final DateTime takenAt;
  final String? remote;
  final String? place;

  PendingPhoto uploaded(String path) =>
      PendingPhoto(local: local, takenAt: takenAt, remote: path, place: place);

  /// Back to the phone copy only, to upload again.
  PendingPhoto get notUploaded =>
      PendingPhoto(local: local, takenAt: takenAt, place: place);

  Map<String, dynamic> toJson() => {
    'local': local,
    'taken_at': takenAt.toIso8601String(),
    'remote': remote,
    'place': place,
  };
}

/// One photo's work item in a walk (slice 6): its id, the line for it and
/// who owns it. Its photo is the walk's photo at the same place.
@immutable
class WalkLine {
  const WalkLine({
    required this.id,
    required this.line,
    required this.ownerId,
    required this.ownerName,
  });

  factory WalkLine.fromJson(Map<String, dynamic> json) => WalkLine(
    id: json['id'] as String,
    line: json['line'] as String? ?? '',
    ownerId: json['owner_id'] as String? ?? '',
    ownerName: json['owner_name'] as String? ?? '',
  );

  final String id;
  final String line;
  final String ownerId;
  final String ownerName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'line': line,
    'owner_id': ownerId,
    'owner_name': ownerName,
  };
}

/// What waits in the outbox.
enum PendingKind {
  /// The owner's sign-off of a work item, with its proof photos.
  signOff('sign_done'),

  /// A work item written in place in the Daybook, not on the server yet.
  workItem('daybook_work_item'),

  /// A checklist, an announcement, an activity or a file post written in
  /// place (slice 2), not on the server yet.
  post('daybook_post'),

  /// A check, held for the undo bar's 5 seconds first (review 44, answer
  /// 4).
  check('check_item'),

  /// Cancelling a work item, held for the undo bar's 5 seconds first.
  cancel('cancel_post'),

  /// A walk (slice 6): the walk's work item and one per photo, in one
  /// create_walk call once every photo is up.
  walk('daybook_walk'),

  /// Sending a work item back (slice 10): the reason in [PendingItem.body],
  /// the note, and the new due date and time.
  sendBack('send_back'),

  /// Giving a work item to someone else (slice 10): the new owner in
  /// [PendingItem.ownerId] and [PendingItem.ownerName].
  giveTo('give_to'),

  /// An update on a work item (slice 10): its words in [PendingItem.body].
  /// Each has its own id; [PendingItem.postId] is the item's.
  update('add_update'),

  /// Remove from Space (review 94), held for the undo bar's 5 seconds
  /// first: [PendingItem.id] is the person's.
  remove('remove_member');

  const PendingKind(this.json);
  final String json;

  /// Older versions also kept new items here as 'create' (the 0.9.0 W2
  /// form, retired in slice 1); those aren't read back.
  static PendingKind? fromJson(Object? value) =>
      values.where((k) => k.json == value).firstOrNull;
}

/// Something done on the phone that isn't on the server yet: a sign-off,
/// a new post, a check or a cancel. Kept on the phone until it is, so a
/// weak site signal never loses it, its photos or its files. The app chose
/// the post's id (and each new Library file's), so sending it again is
/// safe.
@immutable
class PendingItem {
  const PendingItem({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.ownerId,
    required this.ownerName,
    this.kind = PendingKind.signOff,
    this.photos = const [],
    this.refused = false,
    this.sent = false,
    this.note,
    this.body,
    this.place,
    this.dueDate,
    this.dueAt,
    this.madeAt,
    this.authorName,
    this.draft,
    this.files = const [],
    this.quote,
    this.sourceMessageId,
    this.walk = const [],
    this.templateId,
    this.blocks,
    this.points = const [],
    this.noteId,
    this.postId,
    this.teamId,
  });

  factory PendingItem.fromJson(Map<String, dynamic> json) => PendingItem(
    id: json['id'] as String,
    spaceId: json['space_id'] as String,
    title: json['title'] as String,
    ownerId: json['owner_id'] as String,
    ownerName: json['owner_name'] as String? ?? '',
    kind: PendingKind.fromJson(json['kind']) ?? PendingKind.signOff,
    photos: [
      for (final p in json['photos'] as List? ?? const [])
        PendingPhoto.fromJson(p as Map<String, dynamic>),
    ],
    refused: json['refused'] as bool? ?? false,
    sent: json['sent'] as bool? ?? false,
    note: json['note'] as String?,
    body: json['body'] as String?,
    place: json['place'] as String?,
    dueDate: _day(json['due_date']),
    dueAt: _time(json['due_at']),
    madeAt: _time(json['made_at']),
    authorName: json['author_name'] as String?,
    draft: json['draft'] == null
        ? null
        : DaybookPostDraft.fromJson(json['draft'] as Map<String, dynamic>),
    files: [
      for (final f in json['files'] as List? ?? const [])
        DraftFile.fromJson(f as Map<String, dynamic>),
    ],
    quote: DaybookQuote.fromJson(json['quote']),
    sourceMessageId: json['source_message_id'] as String?,
    walk: [
      for (final w in json['walk'] as List? ?? const [])
        WalkLine.fromJson(w as Map<String, dynamic>),
    ],
    templateId: json['template_id'] as String?,
    teamId: json['team_id'] as String?,
    blocks: (json['blocks'] as List?)?.cast<Map<String, dynamic>>(),
    points: [
      for (final p in json['points'] as List? ?? const [])
        (
          id: (p as Map<String, dynamic>)['id'] as String,
          text: p['text'] as String? ?? '',
        ),
    ],
    noteId: json['note_id'] as String?,
    postId: json['post_id'] as String?,
  );

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  static DateTime? _day(Object? value) {
    final d = _time(value);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  final PendingKind kind;

  /// The work item's id.
  final String id;
  final String spaceId;
  final String title;
  final String ownerId;
  final String ownerName;
  final List<PendingPhoto> photos;

  /// The server said no (not a lost signal): it isn't tried again by
  /// itself.
  final bool refused;

  /// It reached the server: its slip no longer says "Waiting to send",
  /// and it stays only until the daybook has read the server's entry
  /// (F17), so the slip never blinks.
  final bool sent;

  /// The sign-off note.
  final String? note;

  // A new work item's text and properties; the due date and time are the
  // phone's own.
  final String? body;
  final String? place;
  final DateTime? dueDate;
  final DateTime? dueAt;

  /// When it was done on the phone: the slip hangs at this time until it
  /// is sent.
  final DateTime? madeAt;

  /// The writer's or signer's own name, for the slip while it waits.
  final String? authorName;

  /// A post of another kind: the card as it was written.
  final DaybookPostDraft? draft;

  /// Library files that go with a new post: a file post's, or the files
  /// on a new work item. A new one goes to the Library first.
  final List<DraftFile> files;

  /// A new work item's quoted message, and the Space chat message it was
  /// made from (review 64).
  final DaybookQuote? quote;
  final String? sourceMessageId;

  /// A walk's work items, one per photo in [photos], in order.
  final List<WalkLine> walk;

  /// A new work item's template (slice 7), its page and the points that
  /// came with it. Other kinds keep theirs on [draft].
  final String? templateId;
  final List<Map<String, dynamic>>? blocks;
  final List<DraftPoint> points;

  /// A new work item's Team (review 105 Part 3); null is the whole Space.
  /// Other kinds keep theirs on [draft].
  final String? teamId;

  /// A new work item's note in My notebook (slice 8); other kinds keep
  /// theirs on [draft]. Marked once the server takes the post.
  final String? noteId;

  /// The note this new post was put in from, of any kind.
  String? get fromNote => noteId ?? draft?.noteId;

  /// An update's work item, when [id] is the update's own.
  final String? postId;

  /// The card this is about.
  String get cardId => postId ?? id;

  /// A change to a card already on the server: send back, give to, an
  /// update (slice 10).
  bool get isChange =>
      kind == PendingKind.sendBack ||
      kind == PendingKind.giveTo ||
      kind == PendingKind.update;

  PendingItem copyWith({
    List<PendingPhoto>? photos,
    List<DraftFile>? files,
    bool? refused,
    bool? sent,
  }) => PendingItem(
    id: id,
    spaceId: spaceId,
    title: title,
    ownerId: ownerId,
    ownerName: ownerName,
    kind: kind,
    photos: photos ?? this.photos,
    refused: refused ?? this.refused,
    sent: sent ?? this.sent,
    note: note,
    body: body,
    place: place,
    dueDate: dueDate,
    dueAt: dueAt,
    madeAt: madeAt,
    authorName: authorName,
    draft: draft,
    files: files ?? this.files,
    quote: quote,
    sourceMessageId: sourceMessageId,
    walk: walk,
    templateId: templateId,
    blocks: blocks,
    points: points,
    noteId: noteId,
    postId: postId,
    teamId: teamId,
  );

  /// The same, no longer linked to the chat message it came from (the
  /// message was deleted or reported before Post); the quote stays.
  PendingItem withoutSource() => PendingItem(
    id: id,
    spaceId: spaceId,
    title: title,
    ownerId: ownerId,
    ownerName: ownerName,
    kind: kind,
    photos: photos,
    refused: refused,
    sent: sent,
    note: note,
    body: body,
    place: place,
    dueDate: dueDate,
    dueAt: dueAt,
    madeAt: madeAt,
    authorName: authorName,
    draft: draft?.copyWith(sourceMessageId: () => null),
    files: files,
    quote: quote,
    walk: walk,
    templateId: templateId,
    blocks: blocks,
    points: points,
    noteId: noteId,
    postId: postId,
    teamId: teamId,
  );

  /// A new post, of any kind.
  bool get isNewPost =>
      kind == PendingKind.workItem ||
      kind == PendingKind.post ||
      kind == PendingKind.walk;

  /// The post [index]'s photo goes in: a walk's photo is its work item's.
  String photoPost(int index) =>
      kind == PendingKind.walk && index < walk.length ? walk[index].id : id;

  Map<String, dynamic> toJson() => {
    'id': id,
    'space_id': spaceId,
    'title': title,
    'owner_id': ownerId,
    'owner_name': ownerName,
    'photos': [for (final p in photos) p.toJson()],
    'refused': refused,
    'sent': sent,
    'kind': kind.json,
    'note': note,
    'body': body,
    'place': place,
    'due_date': dueDate?.toIso8601String(),
    'due_at': dueAt?.toUtc().toIso8601String(),
    'made_at': madeAt?.toUtc().toIso8601String(),
    'author_name': authorName,
    'draft': draft?.toJson(),
    'files': [for (final f in files) f.toJson()],
    'quote': quote?.toJson(),
    'source_message_id': sourceMessageId,
    if (walk.isNotEmpty) 'walk': [for (final w in walk) w.toJson()],
    'template_id': ?templateId,
    'team_id': ?teamId,
    'blocks': ?blocks,
    if (points.isNotEmpty)
      'points': [
        for (final p in points) {'id': p.id, 'text': p.text},
      ],
    'note_id': ?noteId,
    'post_id': ?postId,
  };

  /// Only the kinds this version knows are read back.
  static bool isKnown(Map<String, dynamic> json) =>
      PendingKind.fromJson(json['kind']) != null;

  /// The same thing waiting: a kind of one work item.
  bool same(PendingItem other) => other.id == id && other.kind == kind;
}

/// Picks up to [max] photos from the gallery (K4), compressed as
/// [pickPhotoProvider]'s and made safe to leave the phone. A provider so
/// tests can stand in for the gallery.
typedef PickPhotos =
    Future<PickedPhotos> Function({
      required int max,
      void Function(int count)? onPreparing,
    });

final pickPhotosProvider = Provider<PickPhotos>((ref) {
  final picker = ImagePicker();
  return ({required int max, onPreparing}) async {
    if (max <= 0) return (photos: const <XFile>[], refused: 0);
    if (max == 1) {
      final one = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      return cleanPicked([?one], from: 'gallery', onPreparing: onPreparing);
    }
    final picked = await picker.pickMultiImage(
      limit: max,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    return cleanPicked(
      picked.take(max).toList(),
      from: 'gallery',
      onPreparing: onPreparing,
    );
  };
});

/// Takes a photo for evidence: the camera, or the gallery as a fallback.
/// Compressed to about 1600 px on the long side, JPEG quality 80, and
/// made safe to leave the phone (cleanPhoto). A provider so tests can
/// stand in for the camera.
typedef PickPhoto =
    Future<PickedPhotos> Function({
      required bool camera,
      void Function(int count)? onPreparing,
    });

final pickPhotoProvider = Provider<PickPhoto>((ref) {
  final picker = ImagePicker();
  return ({required bool camera, onPreparing}) async {
    final photo = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    return cleanPicked(
      [?photo],
      from: camera ? 'camera' : 'gallery',
      onPreparing: onPreparing,
    );
  };
});

/// The photo the camera took just before Android closed the app behind
/// it (review 79 P1), made safe to leave the phone, or null. Only Android
/// keeps one; a provider so tests can stand in for it.
typedef LostPhoto = Future<XFile?> Function();

final lostPhotoProvider = Provider<LostPhoto>(
  (ref) => () async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    final lost = await ImagePicker().retrieveLostData();
    if (lost.isEmpty) return null;
    final files = lost.files ?? [?lost.file];
    final clean = await cleanPicked(files.take(1).toList(), from: 'camera');
    return clean.photos.firstOrNull;
  },
);

/// Copies a picked photo into the app's own folder, so it outlives the
/// camera's cache until it is sent. Returns the kept file's path.
typedef KeepPhoto = Future<String> Function(XFile photo);

final keepPhotoProvider = Provider<KeepPhoto>(
  (ref) => (photo) async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/outbox',
    );
    await dir.create(recursive: true);
    final kept = '${dir.path}/${newUuid()}.jpg';
    await File(photo.path).copy(kept);
    return kept;
  },
);

/// Waits between tries of one send. Tests make them instant.
final outboxRetryDelaysProvider = Provider<List<Duration>>(
  (ref) => const [Duration(seconds: 1), Duration(seconds: 3)],
);

/// Waits before an outbox tries again by itself after a lost signal, a
/// little longer each time, then the last one over and over until it is
/// sent (F17: the label goes within seconds of the signal coming back).
/// Tests set their own.
final outboxRetryLaterProvider = Provider<List<Duration>>(
  (ref) => const [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 10),
  ],
);

/// Tries an outbox again after a lost signal ([outboxRetryLaterProvider]).
class OutboxRetry {
  OutboxRetry(this._flush);

  final Future<void> Function() _flush;
  Timer? _timer;
  var _tries = 0;

  /// One try after the next wait, unless one is already due.
  void later(List<Duration> waits) {
    if (_timer?.isActive ?? false) return;
    final wait = waits[_tries.clamp(0, waits.length - 1)];
    _tries++;
    _timer = Timer(wait, () {
      _timer = null;
      unawaited(_flush());
    });
  }

  /// Something got through: the next lost signal starts from the first
  /// wait.
  void reached() => _tries = 0;

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

final workOutboxProvider = NotifierProvider<WorkOutbox, List<PendingItem>>(
  WorkOutbox.new,
);

/// Sign-offs, new posts, checks and cancels waiting to be sent, kept on
/// the phone between app starts.
/// Each account has its own: on a phone a crew shares, the next person
/// never sees (or sends) someone else's unsent work.
class WorkOutbox extends Notifier<List<PendingItem>> {
  /// Before accounts had their own; whose items they were is unknown.
  static const _sharedKey = 'work_outbox';

  String? _key;

  /// Checks and cancels whose undo bar is showing: sent when it goes.
  final _held = <(PendingKind, String), Timer>{};

  late final _retry = OutboxRetry(flushAll);

  @override
  List<PendingItem> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authUserIdProvider).value;
    ref.onDispose(() {
      for (final t in _held.values) {
        t.cancel();
      }
      _held.clear();
      _retry.cancel();
    });
    if (prefs.containsKey(_sharedKey)) unawaited(prefs.remove(_sharedKey));
    _key = userId == null ? null : 'work_outbox:$userId';
    final raw = _key == null ? null : prefs.getString(_key!);
    if (raw == null) return const [];
    try {
      return [
        for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          if (PendingItem.isKnown(j)) PendingItem.fromJson(j),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _save(List<PendingItem> items) async {
    state = items;
    final key = _key;
    if (key == null) return;
    await ref
        .read(sharedPreferencesProvider)
        .setString(key, jsonEncode([for (final i in items) i.toJson()]));
  }

  Future<void> _put(PendingItem item) => _save([
    for (final i in state)
      if (!i.same(item)) i,
    item,
  ]);

  Future<void> _drop(PendingItem item) => _save([
    for (final i in state)
      if (!i.same(item)) i,
  ]);

  /// The ones in flight now, so a flush never sends one twice at once.
  final _sending = <(PendingKind, String)>{};

  /// Whether [kind] of [id] is still held for its undo bar.
  bool isHeld(PendingKind kind, String id) => _held.containsKey((kind, id));

  /// Keeps [item] (a check or a cancel) on the phone for [hold], the undo
  /// bar's time, then sends it. If the app closes meanwhile, it is sent on
  /// the next open ([flushAll]). [undo] takes it back before anything
  /// reaches the server.
  Future<void> hold(PendingItem item, Duration hold) async {
    final key = (item.kind, item.id);
    _held.remove(key)?.cancel();
    await _put(item);
    _held[key] = Timer(hold, () {
      _held.remove(key);
      unawaited(send(item));
    });
  }

  /// Undo: the held [kind] of [id] never leaves the phone. False when it
  /// is no longer held (already on its way: the Space or the app was left
  /// while its bar showed), and then nothing changes.
  Future<bool> undo(PendingKind kind, String id) async {
    final held = _held.remove((kind, id));
    if (held == null) return false;
    held.cancel();
    await _save([
      for (final i in state)
        if (i.kind != kind || i.id != id) i,
    ]);
    return true;
  }

  /// Leaving the Space ([spaceId]) or the app while an undo bar shows
  /// (review 94): what it holds was confirmed, so it goes now. True when
  /// something was held.
  bool releaseHeld({String? spaceId}) {
    final going = [
      for (final i in state)
        if (_held.containsKey((i.kind, i.id)) &&
            (spaceId == null || i.spaceId == spaceId))
          i,
    ];
    for (final i in going) {
      _held.remove((i.kind, i.id))?.cancel();
      // Just after: a screen being taken down can't change the outbox.
      unawaited(Future.microtask(() => send(i)));
    }
    return going.isNotEmpty;
  }

  /// Sends everything of [spaceId] still waiting for a signal (not what
  /// the server refused, nor what an undo bar still holds). Called when
  /// the daybook opens, comes back to the front, and every little while.
  Future<void> flush(String spaceId) async {
    for (final item in state.where((i) => i.spaceId == spaceId).toList()) {
      if (_due(item)) await send(item);
    }
  }

  /// [flush] for every Space, on opening the app: a check whose undo bar
  /// was cut short by closing the app is sent now.
  Future<void> flushAll() async {
    for (final item in state.toList()) {
      if (_due(item)) await send(item);
    }
  }

  bool _due(PendingItem item) =>
      !item.refused &&
      !_sending.contains((item.kind, item.id)) &&
      !_held.containsKey((item.kind, item.id));

  /// Keeps [item], uploads its photos and sends it, trying again on a weak
  /// signal. True when it reached the server; otherwise it stays here
  /// ("Waiting to send" on the daybook), unless the server refused it.
  /// While it goes, the daybook says "Sending" (F73).
  Future<bool> send(PendingItem item) async {
    final key = (item.kind, item.id);
    if (!_sending.add(key)) return false;
    final shown = ref.read(outboxSendingProvider.notifier)..start(item.id);
    try {
      return await _send(item);
    } finally {
      _sending.remove(key);
      shown.stop(item.id);
    }
  }

  Future<bool> _send(PendingItem item) async {
    // On the server already: only the page has to catch up.
    if (item.sent) return _settle(item);
    final repo = ref.read(workRepositoryProvider);
    final daybook = ref.read(daybookRepositoryProvider);
    final delays = ref.read(outboxRetryDelaysProvider);
    var current = item.copyWith(refused: false);
    await _put(current);

    Future<T> withRetries<T>(Future<T> Function() run) async {
      for (var attempt = 0; ; attempt++) {
        try {
          return await run();
        } on SpaceException catch (e) {
          // Only a lost connection is worth another try.
          if (e.failure != SpaceFailure.network || attempt >= delays.length) {
            rethrow;
          }
          await Future<void>.delayed(delays[attempt]);
        }
      }
    }

    // Photos uploaded by an earlier try. After a long wait the server may
    // have cleaned them up; the phone copies are still here.
    var reused = current.photos.any((p) => p.remote != null);
    for (;;) {
      try {
        final photos = <PendingPhoto>[];
        for (final (i, p) in current.photos.indexed) {
          if (p.remote != null) {
            photos.add(p);
            continue;
          }
          // A new name on every try: nothing is ever overwritten.
          final path = await withRetries(
            () => item.isNewPost
                ? daybook.uploadPostPhoto(
                    item.spaceId,
                    item.photoPost(i),
                    File(p.local),
                  )
                : repo.uploadPhoto(item.spaceId, item.id, File(p.local)),
          );
          photos.add(p.uploaded(path));
          current = current.copyWith(
            photos: [...photos, ...current.photos.skip(photos.length)],
          );
          await _put(current);
        }
        // New files go to the Library first, under the ids the app chose.
        final files = <DraftFile>[];
        for (final f in current.files) {
          if (!f.isNew || f.added) {
            files.add(f);
            continue;
          }
          await withRetries(() => _addToLibrary(item.spaceId, f, item.id));
          files.add(f.inLibrary);
          current = current.copyWith(
            files: [...files, ...current.files.skip(files.length)],
          );
          await _put(current);
        }
        await withRetries(() => _call(current, photos));
        break;
      } on SpaceException catch (e) {
        // Refused photos from an earlier try: upload them again, once. A
        // cleaned-up upload reads as not allowed (is_my_upload).
        if (reused &&
            (e.failure == SpaceFailure.badInput ||
                e.failure == SpaceFailure.notAllowed)) {
          reused = false;
          current = current.copyWith(
            photos: [for (final p in current.photos) p.notUploaded],
          );
          await _put(current);
          continue;
        }
        if (e.failure == SpaceFailure.network) {
          await _put(current);
          ref.read(signalProvider.notifier).lost();
          _retry.later(ref.read(outboxRetryLaterProvider));
        } else {
          await _refused(current, e);
        }
        return false;
      }
    }

    // "Waiting to send" goes at once (F17); the slip stays until the
    // daybook has the server's entry.
    _retry.reached();
    ref.read(signalProvider.notifier).back();
    // F5: a post or a sign-off the server took, not a check or a cancel.
    if (item.kind == PendingKind.signOff || item.isNewPost) {
      unawaited(ref.read(sentChimeProvider).play());
    }
    await _put(current.copyWith(sent: true));
    ref.invalidate(mySpacesProvider);
    // Put in from My notebook (slice 8): the note says so, and stays.
    if (current.fromNote case final note? when item.isNewPost) {
      unawaited(_markNotePut(note, item.id));
    }
    return _settle(current);
  }

  /// mark_note_put once the server has the post. A miss only leaves the
  /// note without its "Went into a Space" line.
  Future<void> _markNotePut(String noteId, String postId) async {
    try {
      await ref.read(notebookRepositoryProvider).markPut(noteId, postId);
    } on SpaceException {
      return;
    }
    if (ref.exists(notebookProvider)) ref.invalidate(notebookProvider);
  }

  /// A sent [item] leaves the phone once the daybook has read the server's
  /// entry for it (matched by its id), so the slip never blinks and is
  /// never there twice. With no signal for that read, it waits, without
  /// the label, and is settled on the next try.
  Future<bool> _settle(PendingItem item) async {
    if (item.kind == PendingKind.remove) {
      ref.invalidate(spacePeopleProvider(item.spaceId));
    }
    if (!await _refreshDaybook(item.spaceId)) {
      _retry.later(ref.read(outboxRetryLaterProvider));
      return true;
    }
    ref.read(signalProvider.notifier).back();
    await _drop(item);
    _deleteFiles(item);
    return true;
  }

  /// The phone's copies of [item]'s photos and new files.
  void _deleteFiles(PendingItem item) {
    for (final path in [
      for (final p in item.photos) p.local,
      for (final f in item.files) ?f.local,
    ]) {
      unawaited(_deleteKept(path));
    }
  }

  /// A file picked on the phone into the Library (add_library_file), as a
  /// new version of an older one when chosen. The server refuses an id it
  /// has already: then an earlier try got through and only its answer was
  /// lost, since the id is this phone's own.
  Future<void> _addToLibrary(String spaceId, DraftFile f, String itemId) async {
    final library = ref.read(libraryRepositoryProvider);
    final shown = ref.read(outboxSendingProvider.notifier);
    final path = await library.upload(
      spaceId,
      f.libraryId,
      PhoneFile(local: f.local!, name: f.name, mime: f.mime, bytes: f.bytes),
      // F73: "Sending · 3.1 of 8.7 MB".
      onProgress: (sent, total) => shown.progress(itemId, sent, total),
    );
    try {
      await library.add(
        id: f.libraryId,
        spaceId: spaceId,
        name: f.name,
        path: path,
        mime: f.mime,
        bytes: f.bytes,
        revLabel: f.revLabel,
        supersedesId: f.supersedesId,
      );
    } on SpaceException catch (e) {
      if (e.failure != SpaceFailure.badInput ||
          !(e.message ?? '').contains(_idTaken)) {
        rethrow;
      }
    }
  }

  static const _idTaken = 'this id is taken';

  Future<void> _call(PendingItem item, List<PendingPhoto> photos) async {
    final daybook = ref.read(daybookRepositoryProvider);
    final paths = [for (final p in photos) p.remote!];
    final fileIds = [for (final f in item.files) f.libraryId];
    switch (item.kind) {
      case PendingKind.workItem:
        await daybook.createWorkItem(
          NewWorkItem(
            id: item.id,
            spaceId: item.spaceId,
            title: item.title,
            ownerId: item.ownerId,
            body: item.body,
            place: item.place,
            dueDate: item.dueDate,
            dueAt: item.dueAt,
            photoPaths: paths,
            libraryFileIds: fileIds,
            quote: item.quote,
            sourceMessageId: item.sourceMessageId,
            templateId: item.templateId,
            blocks: item.blocks,
            points: item.points,
            teamId: item.teamId,
          ),
        );
        // The same file twice is one attachment (attach_library_file).
        for (final id in fileIds) {
          await daybook.attachFile(item.id, id);
        }
      case PendingKind.post:
        final d = item.draft!;
        await daybook.createPost(
          NewSpacePost(
            id: item.id,
            spaceId: item.spaceId,
            kind: d.kind.json,
            title: d.title,
            body: d.body,
            place: d.place,
            dueDate: d.dueDate,
            dueAt: d.dueAt,
            pinnedUntil: d.pinnedUntil,
            startsAt: d.startsAt,
            endsAt: d.endsAt,
            // A file post shares its file; the other kinds carry theirs as
            // the post's own files (F39).
            libraryFileId: d.kind == DaybookKind.file
                ? fileIds.firstOrNull
                : null,
            attachedFileIds: d.kind == DaybookKind.file ? const [] : fileIds,
            people: [for (final p in d.people) p.id],
            points: d.writtenPoints,
            photoPaths: paths,
            teamId: d.teamId,
            quote: d.quote,
            sourceMessageId: d.sourceMessageId,
            templateId: d.templateId,
            blocks: d.blocks.isEmpty ? null : d.blocks,
          ),
        );
      case PendingKind.signOff:
        await ref
            .read(workRepositoryProvider)
            .signDone(
              item.id,
              note: item.note,
              photos: [
                for (final p in photos)
                  WorkPhoto(
                    path: p.remote!,
                    takenAt: p.takenAt,
                    place: p.place,
                  ),
              ],
            );
      case PendingKind.check:
        await ref.read(workRepositoryProvider).checkItem(item.id);
      case PendingKind.cancel:
        await daybook.cancelPost(item.id);
      case PendingKind.remove:
        await ref
            .read(spaceRepositoryProvider)
            .removeMember(item.spaceId, item.id);
      case PendingKind.sendBack:
        await ref
            .read(workRepositoryProvider)
            .sendBack(
              item.id,
              SendBackReason.fromJson(item.body) ?? SendBackReason.other,
              note: item.note,
              due: (day: item.dueDate, at: item.dueAt),
            );
      case PendingKind.giveTo:
        await ref.read(workRepositoryProvider).reassign(item.id, item.ownerId);
      case PendingKind.update:
        await ref
            .read(workRepositoryProvider)
            .addComment(item.cardId, item.body ?? '');
      case PendingKind.walk:
        await daybook.createWalk(
          NewWalk(
            id: item.id,
            spaceId: item.spaceId,
            title: item.title,
            place: item.place,
            items: [
              for (final (i, w) in item.walk.indexed)
                (id: w.id, line: w.line, ownerId: w.ownerId, photo: paths[i]),
            ],
          ),
        );
    }
  }

  /// The server said no. Nothing is ever dropped silently (review 47,
  /// answer 5):
  /// - a new post goes back to a Draft in place ("Couldn't send. Tap
  ///   to fix", review 46);
  /// - a sign-off keeps its photos on the phone and shows on its proof
  ///   slip as "Couldn't send. Tap to fix"; tapping reopens the proof;
  /// - a check, a cancel, a send-back, a give-to or an update leaves the
  ///   phone, the page reads again, and a short line says why
  ///   ([refusalsProvider]).
  Future<void> _refused(PendingItem item, SpaceException e) async {
    switch (item.kind) {
      case PendingKind.workItem || PendingKind.post:
        // Its chat message is gone: it comes back without the link, so
        // the next Post can go (the words stay quoted).
        final back =
            e.failure == SpaceFailure.notAllowed &&
                (item.sourceMessageId ?? item.draft?.sourceMessageId) != null
            ? item.withoutSource()
            : item;
        if (await reopenRefused(back)) return;
        // A new card is being written: this one waits, refused, until it
        // is put down.
        await _put(back.copyWith(refused: true));
      case PendingKind.signOff || PendingKind.walk:
        await _put(item.copyWith(refused: true));
      case PendingKind.check ||
          PendingKind.cancel ||
          PendingKind.remove ||
          PendingKind.sendBack ||
          PendingKind.giveTo ||
          PendingKind.update:
        await _drop(item);
        if (item.kind == PendingKind.remove) {
          ref.invalidate(spacePeopleProvider(item.spaceId));
        }
        await _refreshDaybook(item.spaceId);
        ref
            .read(refusalsProvider.notifier)
            .add(
              DaybookRefusal(
                action: switch (item.kind) {
                  PendingKind.check => RefusedAction.check,
                  PendingKind.sendBack => RefusedAction.sendBack,
                  PendingKind.giveTo => RefusedAction.giveTo,
                  PendingKind.update => RefusedAction.update,
                  PendingKind.remove => RefusedAction.remove,
                  _ => RefusedAction.cancel,
                },
                spaceId: item.spaceId,
                postId: item.cardId,
                why: RefusalWhy.of(e),
              ),
            );
    }
  }

  /// A refused sign-off taken off the phone for good: its photos too.
  Future<void> discard(PendingItem item) async {
    await _drop(item);
    _deleteFiles(item);
  }

  /// A refused sign-off that is being sent again for another work item:
  /// its photos go with the new one, so they stay on the phone.
  Future<void> forget(PendingItem item) => _drop(item);

  /// A refused work item back into the Space's Draft, unless a card is
  /// being written there. True when it moved.
  Future<bool> reopenRefused(PendingItem item) async {
    final draft = ref.read(daybookDraftProvider(item.spaceId).notifier);
    if (!await draft.restoreRefused(item)) return false;
    await _drop(item);
    return true;
  }

  /// Reads the Space's daybook again, if it is open. False when it
  /// couldn't.
  Future<bool> _refreshDaybook(String spaceId) async {
    // A pin or an activity today sits above the page.
    ref
      ..invalidate(daybookExtrasProvider(spaceId))
      ..invalidate(daybookDueTodayProvider(spaceId))
      // A walk's work item, open on its own sheet.
      ..invalidate(daybookChildCardProvider);
    final page = daybookCardsProvider(spaceId);
    if (!ref.exists(page)) return true;
    try {
      await ref.read(page.notifier).refresh();
      return true;
    } on SpaceException {
      return false;
    }
  }

  static Future<void> _deleteKept(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

/// What the server refused on the daybook (review 47, answer 5).
enum RefusedAction {
  check,
  sendBack,
  cancel,
  giveTo,
  update,
  tick,
  ack,
  remove,
}

/// Why, when the server's message says it.
enum RefusalWhy {
  cancelled,
  checked,
  changed,
  removed,
  notAllowed,
  unknown;

  static RefusalWhy of(SpaceException e) {
    final m = (e.message ?? '').toLowerCase();
    return switch (e.failure) {
      SpaceFailure.notAllowed => notAllowed,
      SpaceFailure.rule when m.contains('checked work') => checked,
      SpaceFailure.rule when m.contains('cancelled') => cancelled,
      SpaceFailure.rule when m.contains('removed') => removed,
      SpaceFailure.rule when m.contains('only a') || m.contains('only an') =>
        changed,
      _ => unknown,
    };
  }
}

/// One refusal to say in plain words, then the page reads again.
@immutable
class DaybookRefusal {
  const DaybookRefusal({
    required this.action,
    required this.spaceId,
    required this.postId,
    required this.why,
  });

  final RefusedAction action;
  final String spaceId;
  final String postId;
  final RefusalWhy why;
}

final refusalsProvider = NotifierProvider<Refusals, DaybookRefusal?>(
  Refusals.new,
);

/// The latest refusal, for the daybook to say once.
class Refusals extends Notifier<DaybookRefusal?> {
  @override
  DaybookRefusal? build() => null;

  void add(DaybookRefusal r) => state = r;
}

/// A post on its way (F73): with a signal it says "Sending", and a file's
/// bytes while it uploads; "Waiting to send" is only for no signal.
@immutable
class OutboxSending {
  const OutboxSending({this.sent, this.total});

  final int? sent;
  final int? total;

  bool get hasBytes => sent != null && total != null && total! > 0;
}

final outboxSendingProvider =
    NotifierProvider<OutboxSendingState, Map<String, OutboxSending>>(
      OutboxSendingState.new,
    );

class OutboxSendingState extends Notifier<Map<String, OutboxSending>> {
  @override
  Map<String, OutboxSending> build() => const {};

  /// Bytes between two updates of the line (a tenth of a megabyte).
  static const _step = 100 * 1024;

  void start(String id) {
    if (!ref.mounted) return;
    state = {...state, id: const OutboxSending()};
  }

  void progress(String id, int sent, int total) {
    if (!ref.mounted || !state.containsKey(id)) return;
    final last = state[id]?.sent;
    if (last != null && sent < total && sent - last < _step) return;
    state = {...state, id: OutboxSending(sent: sent, total: total)};
  }

  void stop(String id) {
    if (!ref.mounted || !state.containsKey(id)) return;
    state = {...state}..remove(id);
  }
}
