import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/l10n/locale_controller.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../entry/entry_state.dart';
import 'daybook_draft.dart';
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

/// What waits in the outbox.
enum PendingKind {
  /// The owner's sign-off of a work item, with its proof photos.
  signOff('sign_done'),

  /// A work item written in place in the Daybook, not on the server yet.
  workItem('daybook_work_item'),

  /// A check, held for the undo bar's 5 seconds first (review 44, answer
  /// 4).
  check('check_item'),

  /// Cancelling a work item, held for the undo bar's 5 seconds first.
  cancel('cancel_post');

  const PendingKind(this.json);
  final String json;

  /// Older versions also kept new items here as 'create' (the 0.9.0 W2
  /// form, retired in slice 1); those aren't read back.
  static PendingKind? fromJson(Object? value) =>
      values.where((k) => k.json == value).firstOrNull;
}

/// Something done on the phone that isn't on the server yet: a sign-off,
/// a new work item, a check or a cancel. Kept on the phone until it is, so
/// a weak site signal never loses it or its photos. The app chose the
/// work item's id, so sending it again is safe.
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

  PendingItem copyWith({
    List<PendingPhoto>? photos,
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
  );

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
  };

  /// Only the kinds this version knows are read back.
  static bool isKnown(Map<String, dynamic> json) =>
      PendingKind.fromJson(json['kind']) != null;

  /// The same thing waiting: a kind of one work item.
  bool same(PendingItem other) => other.id == id && other.kind == kind;
}

/// Takes a photo for evidence: the camera, or the gallery as a fallback.
/// Compressed to about 1600 px on the long side, JPEG quality 80. Null when
/// the person cancels. A provider so tests can stand in for the camera.
typedef PickPhoto = Future<XFile?> Function({required bool camera});

final pickPhotoProvider = Provider<PickPhoto>((ref) {
  final picker = ImagePicker();
  return ({required bool camera}) => picker.pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
});

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

/// Sign-offs, new work items, checks and cancels waiting to be sent, kept
/// on the phone between app starts.
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

  /// Undo: the held [kind] of [id] never leaves the phone.
  Future<void> undo(PendingKind kind, String id) async {
    _held.remove((kind, id))?.cancel();
    await _save([
      for (final i in state)
        if (i.kind != kind || i.id != id) i,
    ]);
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
  Future<bool> send(PendingItem item) async {
    final key = (item.kind, item.id);
    if (!_sending.add(key)) return false;
    try {
      return await _send(item);
    } finally {
      _sending.remove(key);
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
        for (final p in current.photos) {
          if (p.remote != null) {
            photos.add(p);
            continue;
          }
          // A new name on every try: nothing is ever overwritten.
          final path = await withRetries(
            () => item.kind == PendingKind.workItem
                ? daybook.uploadPostPhoto(item.spaceId, item.id, File(p.local))
                : repo.uploadPhoto(item.spaceId, item.id, File(p.local)),
          );
          photos.add(p.uploaded(path));
          current = current.copyWith(
            photos: [...photos, ...current.photos.skip(photos.length)],
          );
          await _put(current);
        }
        await withRetries(() => _call(item, photos));
        break;
      } on SpaceException catch (e) {
        // Refused photos from an earlier try: upload them again, once.
        if (reused && e.failure == SpaceFailure.badInput) {
          reused = false;
          current = current.copyWith(
            photos: [for (final p in current.photos) p.notUploaded],
          );
          await _put(current);
          continue;
        }
        if (e.failure == SpaceFailure.network) {
          await _put(current);
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
    await _put(current.copyWith(sent: true));
    ref.invalidate(mySpacesProvider);
    return _settle(current);
  }

  /// A sent [item] leaves the phone once the daybook has read the server's
  /// entry for it (matched by its id), so the slip never blinks and is
  /// never there twice. With no signal for that read, it waits, without
  /// the label, and is settled on the next try.
  Future<bool> _settle(PendingItem item) async {
    if (!await _refreshDaybook(item.spaceId)) {
      _retry.later(ref.read(outboxRetryLaterProvider));
      return true;
    }
    await _drop(item);
    for (final p in item.photos) {
      unawaited(_deleteKept(p.local));
    }
    return true;
  }

  Future<void> _call(
    PendingItem item,
    List<PendingPhoto> photos,
  ) => switch (item.kind) {
    PendingKind.workItem =>
      ref
          .read(daybookRepositoryProvider)
          .createWorkItem(
            NewWorkItem(
              id: item.id,
              spaceId: item.spaceId,
              title: item.title,
              ownerId: item.ownerId,
              body: item.body,
              place: item.place,
              dueDate: item.dueDate,
              dueAt: item.dueAt,
              photoPaths: [for (final p in photos) p.remote!],
            ),
          ),
    PendingKind.signOff =>
      ref
          .read(workRepositoryProvider)
          .signDone(
            item.id,
            note: item.note,
            photos: [
              for (final p in photos)
                WorkPhoto(path: p.remote!, takenAt: p.takenAt, place: p.place),
            ],
          ),
    PendingKind.check => ref.read(workRepositoryProvider).checkItem(item.id),
    PendingKind.cancel =>
      ref.read(daybookRepositoryProvider).cancelPost(item.id),
  };

  /// The server said no. Nothing is ever dropped silently (review 47,
  /// answer 5):
  /// - a new work item goes back to a Draft in place ("Couldn't send. Tap
  ///   to fix", review 46);
  /// - a sign-off keeps its photos on the phone and shows on its proof
  ///   slip as "Couldn't send. Tap to fix"; tapping reopens the proof;
  /// - a check or a cancel leaves the phone, the page reads again, and a
  ///   short line says why ([refusalsProvider]).
  Future<void> _refused(PendingItem item, SpaceException e) async {
    switch (item.kind) {
      case PendingKind.workItem:
        if (await reopenRefused(item)) return;
        // A new card is being written: this one waits, refused, until it
        // is put down.
        await _put(item.copyWith(refused: true));
      case PendingKind.signOff:
        await _put(item.copyWith(refused: true));
      case PendingKind.check || PendingKind.cancel:
        await _drop(item);
        await _refreshDaybook(item.spaceId);
        ref
            .read(refusalsProvider.notifier)
            .add(
              DaybookRefusal(
                action: item.kind == PendingKind.check
                    ? RefusedAction.check
                    : RefusedAction.cancel,
                spaceId: item.spaceId,
                postId: item.id,
                why: RefusalWhy.of(e),
              ),
            );
    }
  }

  /// A refused sign-off taken off the phone for good: its photos too.
  Future<void> discard(PendingItem item) async {
    await _drop(item);
    for (final p in item.photos) {
      unawaited(_deleteKept(p.local));
    }
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
    final page = daybookPageProvider(spaceId);
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
enum RefusedAction { check, sendBack, cancel, giveTo, update }

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
