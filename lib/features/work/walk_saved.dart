import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../entry/entry_state.dart';
import 'daybook_draft.dart' show DaybookDraft;

/// One photo of a walk in progress, as the phone keeps it: the kept
/// file, when it was taken, its line and who does it.
@immutable
class SavedShot {
  const SavedShot({
    required this.local,
    required this.at,
    this.line = '',
    this.ownerId,
    this.ownerName,
  });

  factory SavedShot.fromJson(Map<String, dynamic> json) => SavedShot(
    local: json['local'] as String,
    at: DateTime.parse(json['at'] as String),
    line: json['line'] as String? ?? '',
    ownerId: json['owner_id'] as String?,
    ownerName: json['owner_name'] as String?,
  );

  final String local;
  final DateTime at;
  final String line;
  final String? ownerId;
  final String? ownerName;

  Map<String, dynamic> toJson() => {
    'local': local,
    'at': at.toIso8601String(),
    'line': line,
    'owner_id': ?ownerId,
    'owner_name': ?ownerName,
  };

  @override
  bool operator ==(Object other) =>
      other is SavedShot &&
      other.local == local &&
      other.at == at &&
      other.line == line &&
      other.ownerId == ownerId &&
      other.ownerName == ownerName;

  @override
  int get hashCode => Object.hash(local, at, line, ownerId, ownerName);
}

/// A walk being taken (review 79 P1), kept on the phone from the moment
/// the camera first opens: Android often closes the app behind the
/// system camera, and a walk is many photos. [camera] is true while the
/// camera is open, so the photo it took before a kill is this walk's.
/// Never sent anywhere; posting or throwing it away clears it.
@immutable
class SavedWalk {
  const SavedWalk({
    required this.name,
    this.place = '',
    this.shots = const [],
    this.camera = false,
  });

  factory SavedWalk.fromJson(Map<String, dynamic> json) => SavedWalk(
    name: json['name'] as String? ?? '',
    place: json['place'] as String? ?? '',
    shots: [
      for (final s in json['shots'] as List? ?? const [])
        SavedShot.fromJson(s as Map<String, dynamic>),
    ],
    camera: json['camera'] as bool? ?? false,
  );

  final String name;
  final String place;
  final List<SavedShot> shots;
  final bool camera;

  Map<String, dynamic> toJson() => {
    'name': name,
    'place': place,
    'shots': [for (final s in shots) s.toJson()],
    'camera': camera,
  };

  @override
  bool operator ==(Object other) =>
      other is SavedWalk &&
      other.name == name &&
      other.place == place &&
      listEquals(other.shots, shots) &&
      other.camera == camera;

  @override
  int get hashCode => Object.hash(name, place, Object.hashAll(shots), camera);
}

/// The walk in progress in one Space, per account, or null.
final walkSavedProvider =
    NotifierProvider.family<WalkSaved, SavedWalk?, String>(WalkSaved.new);

class WalkSaved extends Notifier<SavedWalk?> {
  WalkSaved(this.spaceId);

  final String spaceId;
  String? _key;

  @override
  SavedWalk? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authUserIdProvider).value;
    _key = userId == null ? null : 'walk_in_progress:$userId:$spaceId';
    final raw = _key == null ? null : prefs.getString(_key!);
    if (raw == null) return null;
    try {
      return SavedWalk.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  /// Keeps [walk] on the phone, as it is now.
  Future<void> save(SavedWalk walk) async {
    state = walk;
    final key = _key;
    if (key == null) return;
    await ref
        .read(sharedPreferencesProvider)
        .setString(key, jsonEncode(walk.toJson()));
  }

  /// Gone: posted (the outbox has its photos), or thrown away with
  /// [photos] true, which deletes the kept photos too.
  Future<void> clear({bool photos = false}) async {
    final walk = state;
    state = null;
    final key = _key;
    if (key != null) await ref.read(sharedPreferencesProvider).remove(key);
    if (!photos || walk == null) return;
    await Future.wait([
      for (final s in walk.shots) DaybookDraft.deleteKept(s.local),
    ]);
  }
}
