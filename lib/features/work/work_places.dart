import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/daybook.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;

/// A Space's places, its site tags, A to Z (review 105C, migration 52):
/// read with the Space; who may post work adds one from the Place picker,
/// a Lead renames or deletes one. The server checks each of them.
final spacePlacesProvider =
    AsyncNotifierProvider.family<SpacePlaces, List<SpacePlace>, String>(
      SpacePlaces.new,
    );

class SpacePlaces extends AsyncNotifier<List<SpacePlace>> {
  SpacePlaces(this.spaceId);

  final String spaceId;

  DaybookRepository get _repo => ref.read(daybookRepositoryProvider);

  @override
  Future<List<SpacePlace>> build() => _repo.places(spaceId);

  List<SpacePlace> get _now => state.value ?? const [];

  /// The place [name], new to this Space: its id is chosen here, so the
  /// post written with it can carry it at once.
  Future<SpacePlace> add(String name) async {
    final place = SpacePlace(id: newUuid(), name: name.trim());
    await _repo.addPlace(spaceId, place.id, place.name);
    state = AsyncData(sortedPlaces([..._now, place]));
    return place;
  }

  Future<void> rename(SpacePlace place, String name) async {
    await _repo.renamePlace(place.id, name);
    state = AsyncData(
      sortedPlaces([
        for (final p in _now)
          p.id == place.id ? SpacePlace(id: p.id, name: name.trim()) : p,
      ]),
    );
  }

  Future<void> delete(SpacePlace place) async {
    await _repo.deletePlace(place.id);
    state = AsyncData([
      for (final p in _now)
        if (p.id != place.id) p,
    ]);
  }
}

/// [id]'s name in [places], or null.
String? placeName(List<SpacePlace>? places, String? id) =>
    id == null ? null : places?.where((p) => p.id == id).firstOrNull?.name;

/// Work shown for one place (review 105C): a tap on a site tag, or a place
/// found by Search. Null shows everything; leaving the Space clears it.
final workPlaceFilterProvider = NotifierProvider.autoDispose
    .family<WorkPlaceFilter, SpacePlace?, String>(WorkPlaceFilter.new);

class WorkPlaceFilter extends Notifier<SpacePlace?> {
  WorkPlaceFilter(this.spaceId);

  final String spaceId;

  @override
  SpacePlace? build() => null;

  void show(SpacePlace place) => state = place;

  void clear() => state = null;
}
