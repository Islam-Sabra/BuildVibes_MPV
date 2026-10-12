import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';

/// Work items with no network. [needsBySpace] stands in for the server's
/// needs_you(): tests say what needs the signed-in person.
class FakeWorkRepository implements WorkRepository {
  final itemsBySpace = <String, List<WorkItem>>{};
  final needsBySpace = <String, WorkNeeds>{};

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
}
