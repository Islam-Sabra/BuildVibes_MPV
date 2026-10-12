import 'dart:io';

import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';

/// Work items with no network. [needsBySpace] stands in for the server's
/// needs_you(): tests say what needs the signed-in person.
class FakeWorkRepository implements WorkRepository {
  final itemsBySpace = <String, List<WorkItem>>{};
  final needsBySpace = <String, WorkNeeds>{};
  final details = <String, WorkItemDetail>{};
  final created = <NewWorkItem>[];
  final uploads = <String>[];
  final calls = <String>[];

  /// The next calls fail as if the signal dropped.
  int failNext = 0;
  String? nextRefValue = 'KCT-006';

  void _maybeFail() {
    if (failNext > 0) {
      failNext--;
      throw const SpaceException(SpaceFailure.network);
    }
  }

  @override
  Future<List<WorkItem>> items(String spaceId) async =>
      List.of(itemsBySpace[spaceId] ?? const []);

  @override
  Future<WorkNeeds> needs(String spaceId) async =>
      needsBySpace[spaceId] ?? const WorkNeeds();

  /// No network in tests: cards show the photo placeholder.
  @override
  Future<String> photoUrl(String path) async =>
      throw const SpaceException(SpaceFailure.network);

  @override
  Future<WorkItemDetail?> detail(String itemId) async => details[itemId];

  @override
  Future<String?> nextRef(String spaceId) async => nextRefValue;

  @override
  Future<String> uploadPhoto(String spaceId, String itemId, File file) async {
    _maybeFail();
    final path = '$spaceId/$itemId/photo-${uploads.length + 1}.jpg';
    uploads.add(path);
    return path;
  }

  @override
  Future<void> createItem(NewWorkItem item) async {
    _maybeFail();
    created.add(item);
  }

  @override
  Future<void> addComment(String itemId, String text) async {
    calls.add('comment $itemId $text');
  }

  @override
  Future<void> reassign(String itemId, String ownerId) async {
    calls.add('reassign $itemId $ownerId');
  }
}
