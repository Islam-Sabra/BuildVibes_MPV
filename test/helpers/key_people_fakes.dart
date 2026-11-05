import 'package:buildvibes/data/models/key_people.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/key_people_repository.dart';

/// Who to call with no network (review 121). [spaces] holds each Space's
/// key people; [phones] the numbers person_phone would give; [callable]
/// the people dm_can_call says yes for (121b).
class FakeKeyPeopleRepository implements KeyPeopleRepository {
  final spaces = <String, KeyPeople>{};
  final phones = <String, String>{};
  final callable = <String>{};
  final seen = <String>[];
  final asked = <String>[];

  /// The Space each person_phone was asked from; null from a DM.
  final askedFrom = <String?>[];
  final saved =
      <
        ({String? roleId, String name, String? callFor, List<String> holders})
      >[];
  final deleted = <String>[];
  final reordered = <List<String>>[];
  var mine = const MyPhone();
  final setPhones = <({String? phone, PhoneVisibility? visibility})>[];

  /// The next call that writes fails this way, once.
  SpaceFailure? failure;

  void _fail() {
    final f = failure;
    if (f == null) return;
    failure = null;
    throw SpaceException(f);
  }

  @override
  Future<KeyPeople> keyPeople(String spaceId) async =>
      spaces[spaceId] ?? const KeyPeople();

  @override
  Future<String> saveRole(
    String spaceId, {
    String? roleId,
    required String name,
    String? callFor,
    required List<({String profileId, String? note})> holders,
  }) async {
    _fail();
    saved.add((
      roleId: roleId,
      name: name,
      callFor: callFor,
      holders: [for (final h in holders) h.profileId],
    ));
    return roleId ?? 'role-new';
  }

  @override
  Future<void> deleteRole(String roleId) async {
    _fail();
    deleted.add(roleId);
  }

  @override
  Future<void> reorderRoles(String spaceId, List<String> roleIds) async {
    _fail();
    reordered.add(roleIds);
  }

  @override
  Future<void> markSeen(String spaceId) async {
    seen.add(spaceId);
    final now = spaces[spaceId];
    if (now != null) spaces[spaceId] = KeyPeople(roles: now.roles);
  }

  @override
  Future<String?> personPhone(String profileId, {String? spaceId}) async {
    _fail();
    asked.add(profileId);
    askedFrom.add(spaceId);
    return phones[profileId];
  }

  @override
  Future<bool> dmCanCall(String profileId) async =>
      callable.contains(profileId);

  @override
  Future<MyPhone> myPhone() async => mine;

  @override
  Future<void> setMyPhone(String? phone, {PhoneVisibility? visibility}) async {
    _fail();
    setPhones.add((phone: phone, visibility: visibility));
    mine = MyPhone(phone: phone, visibility: visibility ?? mine.visibility);
  }
}
