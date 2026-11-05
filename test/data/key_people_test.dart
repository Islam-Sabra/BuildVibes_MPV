// Review 121: what space_key_people returns (each role, its people as the
// person embed, whether Call shows, never the number), the phone choice,
// and the market pack's role names.
import 'package:buildvibes/data/models/key_people.dart';
import 'package:buildvibes/data/models/market.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  test('space_key_people parses: roles in order, people, Call, seen', () {
    final people = KeyPeople.fromJson({
      'seen': false,
      'roles': [
        {
          'id': 'r1',
          'name': 'Safety officer',
          'call_for': 'Hazards, accidents, work permits',
          'holders': [
            {
              'id': 'p-khalid',
              'first_name': 'Khalid',
              'last_name': 'Al-Mansour',
              'headline': 'Safety',
              'trade_id': null,
              'company_name_text': null,
              'trade': null,
              'company': {'name': 'NBKCH'},
              'note': 'Day shift',
              'can_call': true,
            },
            {
              'id': 'p-tariq',
              'first_name': 'Tariq',
              'last_name': 'Rahman',
              'company_name_text': 'NBKCH',
              'note': null,
              'can_call': false,
            },
          ],
        },
        {'id': 'r2', 'name': 'Site nurse', 'call_for': null, 'holders': []},
      ],
    });
    expect(people.seen, isFalse);
    expect(
      [for (final r in people.roles) r.name],
      ['Safety officer', 'Site nurse'],
    );
    final khalid = people.roles.first.holders.first;
    expect(khalid.person.fullName, 'Khalid Al-Mansour');
    expect(khalid.person.companyLabel, 'NBKCH');
    expect(khalid.person.companyRegistered, isTrue);
    expect(khalid.note, 'Day shift');
    expect(khalid.canCall, isTrue);
    final tariq = people.roles.first.holders.last;
    expect(tariq.canCall, isFalse);
    expect(tariq.person.companyRegistered, isFalse);
    expect(people.roles.last.callFor, isNull);
  });

  test('Who to call lists each person once per role, roles with no one '
      'left out', () {
    final people = KeyPeople.fromJson({
      'seen': true,
      'roles': [
        {
          'id': 'r1',
          'name': 'Safety officer',
          'holders': [
            {'id': 'a', 'first_name': 'A', 'last_name': 'X', 'can_call': true},
            {'id': 'b', 'first_name': 'B', 'last_name': 'X', 'can_call': false},
          ],
        },
        {'id': 'r2', 'name': 'Site nurse', 'holders': []},
      ],
    });
    expect([for (final c in people.toCall) c.holder.person.id], ['a', 'b']);
    expect(people.toCall.first.role.name, 'Safety officer');
    expect(people.hasAnyone, isTrue);
    expect(const KeyPeople().hasAnyone, isFalse);
  });

  test('who sees my number: one of three, Nobody by default', () {
    expect(PhoneVisibility.fromJson('spaces_and_dms'), PhoneVisibility.dms);
    expect(PhoneVisibility.fromJson(null), PhoneVisibility.nobody);
    expect(PhoneVisibility.spaces.json, 'spaces');
    final mine = MyPhone.fromJson({
      'phone': '+96550001234',
      'visibility': 'spaces',
    });
    expect(mine.phone, '+96550001234');
    expect(mine.visibility, PhoneVisibility.spaces);
  });

  test('the market pack carries its role names, in both languages', () {
    final m = Market.fromJson({
      ...kuwaitJson,
      'key_role_suggestions': [
        {'en': 'Safety officer', 'ar': 'ضابط السلامة'},
        {'en': 'Storekeeper', 'ar': 'أمين المخزن'},
      ],
    });
    expect(
      [for (final s in m.keyRoleSuggestions) s.ar],
      ['ضابط السلامة', 'أمين المخزن'],
    );
    expect(kuwait.keyRoleSuggestions, isNotEmpty);
  });

  test('a typed number becomes E.164 with the market\'s dial code', () {
    expect(kuwait.nationalOf('+965 5512 3456'), '55123456');
    expect(kuwait.nationalOf('5512 3456'), '55123456');
    expect(egypt.nationalOf('010 1234 5678'), '1012345678');
    expect(kuwait.isMobileNumber(kuwait.nationalOf('5512 3456')), isTrue);
    expect(kuwait.toE164('55123456'), '+96555123456');
    expect(kuwait.grouped('+96555123456'), '+965 5512 3456');
  });
}
