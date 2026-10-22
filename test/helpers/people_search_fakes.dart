import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/people_search_repository.dart';

/// People to find, with no network: [people] everyone the server would
/// let me see, [shared] the ids I share a Space with, [blocked] the ones
/// row-level security hides from me.
class FakePeopleSearchRepository implements PeopleSearchRepository {
  FakePeopleSearchRepository({
    this.people = const [],
    this.shared = const {},
    this.blocked = const {},
  });

  final List<SpacePerson> people;
  final Set<String> shared;
  final Set<String> blocked;

  Iterable<SpacePerson> _visible(String me) =>
      people.where((p) => p.id != me && !blocked.contains(p.id));

  @override
  Future<List<SpacePerson>> search(String query, {required String me}) async {
    final words = query
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return [
      for (final p in _visible(me))
        if (matchesPerson(p, words)) p,
    ];
  }

  @override
  Future<List<SpacePerson>> sharedSpaces({required String me}) async => [
    for (final p in _visible(me))
      if (shared.contains(p.id)) p,
  ];
}
