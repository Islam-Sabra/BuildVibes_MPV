import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/key_people.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart' show guardSpace;

/// Review 121: Who to call, set by the Space admin, and the phone number
/// behind Call. The number is read one person at a time, on the tap.
abstract interface class KeyPeopleRepository {
  /// Every member reads it (space_key_people); nobody outside does.
  Future<KeyPeople> keyPeople(String spaceId);

  /// A new role when [roleId] is null. [holders] in order, at most 2.
  Future<String> saveRole(
    String spaceId, {
    String? roleId,
    required String name,
    String? callFor,
    required List<({String profileId, String? note})> holders,
  });

  Future<void> deleteRole(String roleId);

  /// Every role of the Space, once, in the new order.
  Future<void> reorderRoles(String spaceId, List<String> roleIds);

  /// KP2: Got it, or the sheet closed.
  Future<void> markSeen(String spaceId);

  /// The number when its owner's choice lets me have it; otherwise null.
  /// [spaceId] null asks from a direct message.
  Future<String?> personPhone(String profileId, {String? spaceId});

  Future<MyPhone> myPhone();

  /// [phone] in E.164, or null to take it away; a null [visibility] keeps
  /// the choice.
  Future<void> setMyPhone(String? phone, {PhoneVisibility? visibility});
}

class SupabaseKeyPeopleRepository implements KeyPeopleRepository {
  const SupabaseKeyPeopleRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) => guardSpace(run);

  @override
  Future<KeyPeople> keyPeople(String spaceId) => _guard(
    () async => KeyPeople.fromJson(
      await _client.rpc<Map<String, dynamic>>(
        'space_key_people',
        params: {'p_space': spaceId},
      ),
    ),
  );

  @override
  Future<String> saveRole(
    String spaceId, {
    String? roleId,
    required String name,
    String? callFor,
    required List<({String profileId, String? note})> holders,
  }) => _guard(
    () => _client.rpc<String>(
      'save_key_role',
      params: {
        'p_space': spaceId,
        'p_id': roleId,
        'p_name': name,
        'p_call_for': callFor,
        'p_holders': [
          for (final h in holders) {'profile_id': h.profileId, 'note': h.note},
        ],
      },
    ),
  );

  @override
  Future<void> deleteRole(String roleId) => _guard(
    () => _client.rpc<void>('delete_key_role', params: {'p_id': roleId}),
  );

  @override
  Future<void> reorderRoles(String spaceId, List<String> roleIds) => _guard(
    () => _client.rpc<void>(
      'reorder_key_roles',
      params: {'p_space': spaceId, 'p_ids': roleIds},
    ),
  );

  @override
  Future<void> markSeen(String spaceId) => _guard(
    () =>
        _client.rpc<void>('mark_key_people_seen', params: {'p_space': spaceId}),
  );

  @override
  Future<String?> personPhone(String profileId, {String? spaceId}) => _guard(
    () => _client.rpc<String?>(
      'person_phone',
      params: {'p_profile': profileId, 'p_space': spaceId},
    ),
  );

  @override
  Future<MyPhone> myPhone() => _guard(
    () async => MyPhone.fromJson(
      await _client.rpc<Map<String, dynamic>?>('my_phone') ?? const {},
    ),
  );

  @override
  Future<void> setMyPhone(String? phone, {PhoneVisibility? visibility}) =>
      _guard(
        () => _client.rpc<void>(
          'set_my_phone',
          params: {'p_phone': phone, 'p_visibility': visibility?.json},
        ),
      );
}

final keyPeopleRepositoryProvider = Provider<KeyPeopleRepository>(
  (ref) => SupabaseKeyPeopleRepository(ref.watch(supabaseClientProvider)),
);

final spaceKeyPeopleProvider = FutureProvider.autoDispose
    .family<KeyPeople, String>(
      (ref, id) => ref.watch(keyPeopleRepositoryProvider).keyPeople(id),
    );

final myPhoneProvider = FutureProvider.autoDispose<MyPhone>(
  (ref) => ref.watch(keyPeopleRepositoryProvider).myPhone(),
);
