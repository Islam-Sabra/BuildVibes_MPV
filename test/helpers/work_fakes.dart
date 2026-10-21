import 'dart:io';

import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';

/// Work items with no network: the chat cards' items, sign-offs, checks,
/// send-backs, updates and give-to, recorded in [calls].
class FakeWorkRepository implements WorkRepository {
  final itemsBySpace = <String, List<WorkItem>>{};
  final uploads = <String>[];
  final calls = <String>[];

  /// The next calls fail as if the signal dropped.
  int failNext = 0;

  /// The next sign-offs fail as if the signal dropped (uploads
  /// still work).
  int failSendNext = 0;

  /// The server says no to sign-offs, checks and send-backs with this
  /// (not a lost signal).
  SpaceException? refuse;

  void _maybeRefuse() {
    final e = refuse;
    if (e != null) throw e;
  }

  /// Uploads the server cleaned up: sending them is refused as bad input.
  final cleanedUp = <String>{};

  void _maybeFail() {
    if (failNext > 0) {
      failNext--;
      throw const SpaceException(SpaceFailure.network);
    }
  }

  void _maybeFailSend(Iterable<String> paths) {
    _maybeFail();
    if (failSendNext > 0) {
      failSendNext--;
      throw const SpaceException(SpaceFailure.network);
    }
    if (paths.any(cleanedUp.contains)) {
      throw const SpaceException(SpaceFailure.badInput);
    }
  }

  @override
  Future<List<WorkItem>> items(String spaceId) async =>
      List.of(itemsBySpace[spaceId] ?? const []);

  /// No network in tests: cards show the photo placeholder.
  @override
  Future<String> photoUrl(String path) async =>
      throw const SpaceException(SpaceFailure.network);

  @override
  Future<String> uploadPhoto(String spaceId, String itemId, File file) async {
    _maybeFail();
    final path = '$spaceId/$itemId/photo-${uploads.length + 1}.jpg';
    uploads.add(path);
    return path;
  }

  @override
  Future<void> addComment(String itemId, String text) async {
    calls.add('comment $itemId $text');
  }

  @override
  Future<void> reassign(String itemId, String ownerId) async {
    calls.add('reassign $itemId $ownerId');
  }

  final delivered = <DeliveredWork>[];
  final shownBy = <String, List<DeliveredWork>>{};

  @override
  Future<void> signDone(
    String itemId, {
    String? note,
    List<WorkPhoto> photos = const [],
  }) async {
    _maybeFailSend(photos.map((p) => p.path));
    _maybeRefuse();
    calls.add('done $itemId ${note ?? ''} ${photos.length}');
  }

  @override
  Future<void> checkItem(String itemId) async {
    _maybeFail();
    _maybeRefuse();
    calls.add('check $itemId');
  }

  @override
  Future<void> sendBack(
    String itemId,
    SendBackReason reason, {
    String? note,
    SendBackDue? due,
  }) async {
    _maybeFail();
    _maybeRefuse();
    final day = due?.day;
    calls.add(
      'back $itemId ${reason.json} ${note ?? ''}'
      '${due == null
          ? ''
          : day == null
          ? ' due none'
          : ' due ${day.year}-${day.month}-${day.day}${due.at == null ? '' : ' at'}'}',
    );
  }

  @override
  Future<void> setShown(String itemId, bool shown) async {
    calls.add('shown $itemId $shown');
    for (var i = 0; i < delivered.length; i++) {
      final w = delivered[i];
      if (w.id == itemId) {
        delivered[i] = DeliveredWork(
          id: w.id,
          title: w.title,
          place: w.place,
          projectName: w.projectName,
          checkedByName: w.checkedByName,
          checkedAt: w.checkedAt,
          shown: shown,
          photoPath: w.photoPath,
        );
      }
    }
  }

  @override
  Future<List<DeliveredWork>> myDeliveredWork() async => List.of(delivered);

  @override
  Future<List<DeliveredWork>> shownWorkOf(String profileId) async =>
      List.of(shownBy[profileId] ?? const []);
}
