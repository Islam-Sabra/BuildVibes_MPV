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
  /// A sign-off (W4) of an existing work item.
  signOff('sign_done'),

  /// A work item written in place in the Daybook (1c), not on the server
  /// yet.
  workItem('daybook_work_item');

  const PendingKind(this.json);
  final String json;

  /// Older versions also kept new items here as 'create' (the 0.9.0 W2
  /// form, retired in slice 1); those aren't read back.
  static PendingKind? fromJson(Object? value) =>
      values.where((k) => k.json == value).firstOrNull;
}

/// Something made on the phone that isn't on the server yet: a sign-off or
/// a new work item. Kept on the phone until it is, so a weak site signal
/// never loses it or its photos. The app chose its id, so sending it again
/// is safe.
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
    this.failed = false,
    this.refused = false,
    this.note,
    this.ref,
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
    failed: json['failed'] as bool? ?? false,
    refused: json['refused'] as bool? ?? false,
    note: json['note'] as String?,
    ref: json['ref'] as String?,
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

  /// The last try didn't get through: "Not sent yet · Retry".
  final bool failed;

  /// The server said no (not a lost signal): it isn't tried again by
  /// itself. The Couldn't send screen comes in slice 10.
  final bool refused;

  /// The sign-off note.
  final String? note;

  /// The item's reference ("KCT-021").
  final String? ref;

  // A new work item's text and properties; the due date and time are the
  // phone's own.
  final String? body;
  final String? place;
  final DateTime? dueDate;
  final DateTime? dueAt;

  /// When Post was tapped: the slip hangs at this time until it is sent.
  final DateTime? madeAt;

  /// The writer's own name, for the slip's avatar while it waits.
  final String? authorName;

  PendingItem copyWith({
    List<PendingPhoto>? photos,
    bool? failed,
    bool? refused,
  }) => PendingItem(
    id: id,
    spaceId: spaceId,
    title: title,
    ownerId: ownerId,
    ownerName: ownerName,
    kind: kind,
    photos: photos ?? this.photos,
    failed: failed ?? this.failed,
    refused: refused ?? this.refused,
    note: note,
    ref: ref,
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
    'failed': failed,
    'refused': refused,
    'kind': kind.json,
    'note': note,
    'ref': ref,
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

final workOutboxProvider = NotifierProvider<WorkOutbox, List<PendingItem>>(
  WorkOutbox.new,
);

/// Sign-offs and new work items waiting to be sent, kept on the phone
/// between app starts.
/// Each account has its own: on a phone a crew shares, the next person
/// never sees (or sends) someone else's unsent work.
class WorkOutbox extends Notifier<List<PendingItem>> {
  /// Before accounts had their own; whose items they were is unknown.
  static const _sharedKey = 'work_outbox';

  String? _key;

  @override
  List<PendingItem> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authUserIdProvider).value;
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
      if (i.id != item.id) i,
    item,
  ]);

  List<PendingItem> forSpace(String spaceId) => [
    for (final i in state)
      if (i.spaceId == spaceId) i,
  ];

  /// The ones in flight now, so a flush never sends one twice at once.
  final _sending = <String>{};

  /// Sends every new work item of [spaceId] still waiting for a signal
  /// (not one the server refused). Called when the daybook opens, comes
  /// back to the front, and every little while it shows one waiting.
  Future<void> flush(String spaceId) async {
    for (final item in forSpace(spaceId)) {
      if (item.kind == PendingKind.workItem &&
          !item.refused &&
          !_sending.contains(item.id)) {
        await send(item);
      }
    }
  }

  /// Keeps [item], uploads its photos and sends it (signs it, or creates
  /// the work item), trying again on a weak signal. True when it reached
  /// the server; otherwise it stays here as "Not sent yet" ("Waiting to
  /// send" on the daybook).
  Future<bool> send(PendingItem item) async {
    if (!_sending.add(item.id)) return false;
    try {
      return await _send(item);
    } finally {
      _sending.remove(item.id);
    }
  }

  Future<bool> _send(PendingItem item) async {
    final repo = ref.read(workRepositoryProvider);
    final daybook = ref.read(daybookRepositoryProvider);
    final newItem = item.kind == PendingKind.workItem;
    final delays = ref.read(outboxRetryDelaysProvider);
    var current = item.copyWith(failed: false, refused: false);
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
            () => newItem
                ? daybook.uploadPostPhoto(item.spaceId, item.id, File(p.local))
                : repo.uploadPhoto(item.spaceId, item.id, File(p.local)),
          );
          photos.add(p.uploaded(path));
          current = current.copyWith(
            photos: [...photos, ...current.photos.skip(photos.length)],
          );
          await _put(current);
        }
        if (newItem) {
          await withRetries(
            () => daybook.createWorkItem(
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
          );
        } else {
          final sent = [
            for (final p in photos)
              WorkPhoto(path: p.remote!, takenAt: p.takenAt, place: p.place),
          ];
          await withRetries(
            () => repo.signDone(item.id, note: item.note, photos: sent),
          );
        }
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
        await _put(
          current.copyWith(
            failed: true,
            refused: e.failure != SpaceFailure.network,
          ),
        );
        return false;
      }
    }

    // On the daybook before it leaves the outbox, so the slip never
    // blinks out.
    final page = daybookPageProvider(item.spaceId);
    if (newItem && ref.exists(page)) {
      try {
        await ref.read(page.notifier).refreshNewest();
      } on SpaceException {
        // It is on the server; the page catches up on its next read.
      }
    }

    // Sent: drop the kept copies.
    await _save([
      for (final i in state)
        if (i.id != item.id) i,
    ]);
    for (final p in item.photos) {
      unawaited(_deleteKept(p.local));
    }
    ref
      ..invalidate(workItemDetailProvider(item.id))
      ..invalidate(workItemsProvider(item.spaceId))
      ..invalidate(workNeedsProvider(item.spaceId))
      ..invalidate(mySpacesProvider);
    return true;
  }

  static Future<void> _deleteKept(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  Future<bool> retry(String id) async {
    final item = state.where((i) => i.id == id).firstOrNull;
    return item == null ? false : send(item);
  }
}
