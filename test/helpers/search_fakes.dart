import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/space_search.dart';
import 'package:buildvibes/data/repositories/search_repository.dart';

/// Search with no network: [hits] are matched on their title and snippet,
/// case-insensitively, as search_space does (newest first, as given).
class FakeSearchRepository implements SearchRepository {
  final hits = <SpaceSearchHit>[];
  final queries = <String>[];
  bool offline = false;

  /// Every hit for any query (the screenshots, whose words differ by
  /// language).
  bool matchAll = false;

  /// The post with each number (review 95), as search_space finds it:
  /// first, marked exact.
  final byNumber = <int, SpaceSearchHit>{};

  @override
  Future<List<SpaceSearchHit>> search(String spaceId, String query) async {
    final q = query.trim().toLowerCase();
    if (!SearchRepository.searchable(q)) return const [];
    queries.add(q);
    if (offline) throw const SpaceException(SpaceFailure.network);
    final number = RegExp(r'^(?:[a-z]{2,4}[ -]?)?0*(\d{1,9})$').firstMatch(q);
    final exact = number == null ? null : byNumber[int.parse(number[1]!)];
    return [
      ?exact,
      for (final h in hits)
        if (h != exact &&
            (matchAll ||
                '${h.title ?? ''} ${h.snippet ?? ''}'.toLowerCase().contains(
                  q,
                )))
          h,
    ];
  }
}
