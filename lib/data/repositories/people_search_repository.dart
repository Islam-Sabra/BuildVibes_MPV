import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// Finding a person (F78): by name, role or company, and the people you
/// share a Space with. Row-level security on profiles never returns
/// someone blocked either way, or a hidden account.
abstract class PeopleSearchRepository {
  /// Nothing under [minLength] characters.
  static const minLength = 2;

  /// At most this many.
  static const limit = 30;

  /// People whose name, role (headline) or company matches [query], not
  /// [me].
  Future<List<SpacePerson>> search(String query, {required String me});

  /// Everyone in the Spaces [me] is in, but [me].
  Future<List<SpacePerson>> sharedSpaces({required String me});
}

/// How a search person is selected: name, and role · company.
const _person =
    'id, first_name, last_name, headline, trade_id, company_name_text, '
    'trade:trades(name), company:companies!profiles_company_fk(name)';

/// The words PostgREST's filter syntax would read as its own.
final _unsafe = RegExp(
  r'[,()%*\\:"'
  "'"
  r'.]',
);

class SupabasePeopleSearchRepository implements PeopleSearchRepository {
  const SupabasePeopleSearchRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        '$e',
      );
    }
  }

  @override
  Future<List<SpacePerson>> search(String query, {required String me}) =>
      _guard(() async {
        final words = query
            .replaceAll(_unsafe, ' ')
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList();
        if (words.isEmpty) return const [];
        // The server looks for the longest word; every word must match
        // here ("omar had" finds Omar Haddad).
        final key = words.reduce((a, b) => b.length > a.length ? b : a);
        final like = '%$key%';
        final byWords = await _client
            .from('profiles')
            .select(_person)
            .or(
              'first_name.ilike.$like,last_name.ilike.$like,'
              'headline.ilike.$like,company_name_text.ilike.$like',
            )
            .neq('id', me)
            .limit(PeopleSearchRepository.limit);
        // A registered company's name.
        final companies = await _client
            .from('companies')
            .select('id')
            .ilike('name', like)
            .limit(PeopleSearchRepository.limit);
        final companyIds = [for (final c in companies) c['id'] as String];
        final byCompany = companyIds.isEmpty
            ? const <Map<String, dynamic>>[]
            : await _client
                  .from('profiles')
                  .select(_person)
                  .inFilter('company_id', companyIds)
                  .neq('id', me)
                  .limit(PeopleSearchRepository.limit);
        final seen = <String>{};
        return [
          for (final r in [...byWords, ...byCompany])
            if (seen.add(r['id'] as String)) SpacePerson.fromJson(r),
        ].where((p) => matchesPerson(p, words)).toList();
      });

  @override
  Future<List<SpacePerson>> sharedSpaces({required String me}) =>
      _guard(() async {
        final mine = await _client
            .from('space_members')
            .select('space_id')
            .eq('profile_id', me)
            .isFilter('left_at', null);
        final spaces = [for (final r in mine) r['space_id'] as String];
        if (spaces.isEmpty) return const [];
        final rows = await _client
            .from('space_members')
            .select('person:profiles!space_members_profile_id_fkey($_person)')
            .inFilter('space_id', spaces)
            .isFilter('left_at', null)
            .neq('profile_id', me);
        final seen = <String>{};
        return [
          for (final r in rows)
            if (r['person'] case final Map<String, dynamic> p
                when seen.add(p['id'] as String))
              SpacePerson.fromJson(p),
        ];
      });
}

/// Whether every word of a search is in [p]'s name, role or company.
bool matchesPerson(SpacePerson p, List<String> words) {
  final text = [
    p.firstName,
    p.lastName,
    p.headline ?? '',
    p.companyLabel ?? '',
  ].join(' ').toLowerCase();
  return words.every((w) => text.contains(w.toLowerCase()));
}

final peopleSearchRepositoryProvider = Provider<PeopleSearchRepository>(
  (ref) => SupabasePeopleSearchRepository(ref.watch(supabaseClientProvider)),
);
