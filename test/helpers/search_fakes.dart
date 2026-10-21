import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/space_search.dart';
import 'package:buildvibes/data/repositories/search_repository.dart';

/// Search with no network: [hits] are matched on their title and snippet,
/// case-insensitively, as search_space does (newest first, as given).
class FakeSearchRepository implements SearchRepository {
  final hits = <SpaceSearchHit>[];
  final queries = <String>[];
  bool offline = false;

  @override
  Future<List<SpaceSearchHit>> search(String spaceId, String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < SearchRepository.minLength) return const [];
    queries.add(q);
    if (offline) throw const SpaceException(SpaceFailure.network);
    return [
      for (final h in hits)
        if ('${h.title ?? ''} ${h.snippet ?? ''}'.toLowerCase().contains(q)) h,
    ];
  }
}
