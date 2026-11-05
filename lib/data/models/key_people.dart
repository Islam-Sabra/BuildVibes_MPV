import 'package:flutter/foundation.dart';

import 'space.dart';

/// Review 121: one person holding a key role, with their note ("Night
/// shift") and whether Call shows for them. Never their number.
@immutable
class KeyHolder {
  const KeyHolder({required this.person, this.note, this.canCall = false});

  /// A holder from space_key_people: the person embed, plus note and
  /// can_call.
  factory KeyHolder.fromJson(Map<String, dynamic> json) => KeyHolder(
    person: SpacePerson.fromJson(json),
    note: json['note'] as String?,
    canCall: json['can_call'] as bool? ?? false,
  );

  final SpacePerson person;
  final String? note;
  final bool canCall;
}

/// A key role of the Space ("Safety officer"): what to call them for, and
/// up to 2 people, in the order the Space admin set.
@immutable
class KeyRole {
  const KeyRole({
    required this.id,
    required this.name,
    this.callFor,
    this.holders = const [],
  });

  factory KeyRole.fromJson(Map<String, dynamic> json) => KeyRole(
    id: json['id'] as String,
    name: json['name'] as String,
    callFor: json['call_for'] as String?,
    holders: [
      for (final h in (json['holders'] as List? ?? const []))
        KeyHolder.fromJson(h as Map<String, dynamic>),
    ],
  );

  final String id;
  final String name;
  final String? callFor;
  final List<KeyHolder> holders;
}

/// One card of Who to call: a person in a role.
typedef KeyToCall = ({KeyRole role, KeyHolder holder});

/// Who to call in a Space (KP1, OC1, KP2): the roles in order, and whether
/// I have seen them once (KP2).
@immutable
class KeyPeople {
  const KeyPeople({this.roles = const [], this.seen = true});

  factory KeyPeople.fromJson(Map<String, dynamic> json) => KeyPeople(
    seen: json['seen'] as bool? ?? true,
    roles: [
      for (final r in (json['roles'] as List? ?? const []))
        KeyRole.fromJson(r as Map<String, dynamic>),
    ],
  );

  final List<KeyRole> roles;
  final bool seen;

  /// One card per person per role, in order; a role with no one shows no
  /// card.
  List<KeyToCall> get toCall => [
    for (final r in roles)
      for (final h in r.holders) (role: r, holder: h),
  ];

  bool get hasAnyone => roles.any((r) => r.holders.isNotEmpty);
}

/// Who sees my number (NUM1): one choice (rule 6), Nobody by default.
enum PhoneVisibility {
  nobody('nobody'),
  spaces('spaces'),
  dms('spaces_and_dms');

  const PhoneVisibility(this.json);

  final String json;

  static PhoneVisibility fromJson(Object? value) =>
      values.where((v) => v.json == value).firstOrNull ?? nobody;
}

/// My number (E.164) and who sees it.
@immutable
class MyPhone {
  const MyPhone({this.phone, this.visibility = PhoneVisibility.nobody});

  factory MyPhone.fromJson(Map<String, dynamic> json) => MyPhone(
    phone: json['phone'] as String?,
    visibility: PhoneVisibility.fromJson(json['visibility']),
  );

  final String? phone;
  final PhoneVisibility visibility;
}
