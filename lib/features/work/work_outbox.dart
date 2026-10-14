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
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../entry/entry_state.dart';

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

/// What a pending entry sends: a new item (W2) or a sign-off (W4).
enum PendingKind { create, signDone }

/// A new work item (W2) or a sign-off (W4) that isn't on the server yet.
/// Kept on the phone until it is, so a weak site signal never loses it or
/// its photos.
@immutable
class PendingItem {
  const PendingItem({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.ownerId,
    required this.ownerName,
    this.due,
    this.teamId,
    this.place,
    this.photos = const [],
    this.failed = false,
    this.kind = PendingKind.create,
    this.note,
    this.ref,
    this.attachFileIds = const [],
  });

  factory PendingItem.fromJson(Map<String, dynamic> json) => PendingItem(
    id: json['id'] as String,
    spaceId: json['space_id'] as String,
    title: json['title'] as String,
    ownerId: json['owner_id'] as String,
    ownerName: json['owner_name'] as String? ?? '',
    due: json['due'] == null ? null : DateTime.parse(json['due'] as String),
    teamId: json['team_id'] as String?,
    place: json['place'] as String?,
    photos: [
      for (final p in json['photos'] as List? ?? const [])
        PendingPhoto.fromJson(p as Map<String, dynamic>),
    ],
    failed: json['failed'] as bool? ?? false,
    kind: json['kind'] == 'sign_done'
        ? PendingKind.signDone
        : PendingKind.create,
    note: json['note'] as String?,
    ref: json['ref'] as String?,
    attachFileIds: [
      for (final id in json['attach'] as List? ?? const []) id as String,
    ],
  );

  final String id;
  final String spaceId;
  final String title;
  final String ownerId;
  final String ownerName;
  final DateTime? due;
  final String? teamId;
  final String? place;
  final List<PendingPhoto> photos;

  /// The last try didn't get through: "Not sent yet · Retry".
  final bool failed;
  final PendingKind kind;

  /// The sign-off note (W4).
  final String? note;

  /// The item's reference, for a sign-off ("KCT-021").
  final String? ref;

  /// Library files to attach once the new item exists (W2-A).
  final List<String> attachFileIds;

  PendingItem copyWith({List<PendingPhoto>? photos, bool? failed}) =>
      PendingItem(
        id: id,
        spaceId: spaceId,
        title: title,
        ownerId: ownerId,
        ownerName: ownerName,
        due: due,
        teamId: teamId,
        place: place,
        photos: photos ?? this.photos,
        failed: failed ?? this.failed,
        kind: kind,
        note: note,
        ref: ref,
        attachFileIds: attachFileIds,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'space_id': spaceId,
    'title': title,
    'owner_id': ownerId,
    'owner_name': ownerName,
    'due': due?.toIso8601String(),
    'team_id': teamId,
    'place': place,
    'photos': [for (final p in photos) p.toJson()],
    'failed': failed,
    'kind': kind == PendingKind.signDone ? 'sign_done' : 'create',
    'note': note,
    'ref': ref,
    'attach': attachFileIds,
  };
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

/// New items waiting to be sent, kept on the phone between app starts.
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
        for (final j in jsonDecode(raw) as List)
          PendingItem.fromJson(j as Map<String, dynamic>),
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

  /// Keeps [item], uploads its photos and creates it, trying again on a
  /// weak signal. True when it reached the server; otherwise it stays here
  /// as "Not sent yet".
  Future<bool> send(PendingItem item) async {
    final repo = ref.read(workRepositoryProvider);
    final library = ref.read(libraryRepositoryProvider);
    final delays = ref.read(outboxRetryDelaysProvider);
    var current = item.copyWith(failed: false);
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
            () => repo.uploadPhoto(item.spaceId, item.id, File(p.local)),
          );
          photos.add(p.uploaded(path));
          current = current.copyWith(
            photos: [...photos, ...current.photos.skip(photos.length)],
          );
          await _put(current);
        }
        final sent = [
          for (final p in photos)
            WorkPhoto(path: p.remote!, takenAt: p.takenAt, place: p.place),
        ];
        await withRetries(
          () => item.kind == PendingKind.signDone
              ? repo.signDone(item.id, note: item.note, photos: sent)
              : repo.createItem(
                  NewWorkItem(
                    id: item.id,
                    spaceId: item.spaceId,
                    title: item.title,
                    ownerId: item.ownerId,
                    due: item.due,
                    teamId: item.teamId,
                    place: item.place,
                    photos: sent,
                  ),
                ),
        );
        // W2-A: files picked before the item existed. A refusal (a Team
        // file on another Team's item) leaves the item made; attach on W3.
        for (final fileId in item.attachFileIds) {
          try {
            await withRetries(() => library.attach(item.id, fileId));
          } on SpaceException catch (e) {
            if (e.failure == SpaceFailure.network) rethrow;
          }
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
        await _put(current.copyWith(failed: true));
        return false;
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
      ..invalidate(itemFilesProvider(item.id))
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
