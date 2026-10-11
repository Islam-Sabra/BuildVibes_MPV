import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/market.dart';
import '../models/profile.dart';
import '../supabase/supabase_provider.dart';

/// Profile pages (R1, R5) and the edit screens (R8). What a viewer may see
/// is decided by RLS: hidden parts simply come back empty.
abstract class ProfilePageRepository {
  /// Null when the profile does not exist or is hidden by a block.
  Future<ProfileView?> fetch(String profileId);

  Future<bool> isFollowing(String me, String other);

  Future<void> saveBasics(String me, BasicsInput input);

  Future<void> saveAbout(String me, String about);

  /// Uploads a photo into the person's own folder and sets it on the
  /// profile. Returns the new photo path.
  Future<String> savePhoto(String me, Uint8List bytes, String extension);

  Future<void> removePhoto(String me, String path);

  Future<void> addExperience(String me, ExperienceInput input);

  Future<void> updateExperience(String id, ExperienceInput input);

  Future<void> deleteExperience(String id);

  Future<void> saveOpenTo(String me, OpenTo openTo);

  Future<void> setCvVisibility(String cvProjectId, bool show);

  Future<void> block(String me, String other);

  /// Places of a market, cities first, for the "City or area" select.
  Future<List<({String id, LocalizedText name, bool isCity})>> places(
    String marketId,
  );
}

class SupabaseProfilePageRepository implements ProfilePageRepository {
  const SupabaseProfilePageRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'avatars';

  static const _profile =
      'id, first_name, last_name, headline, trade_id, home_market_id, '
      'place_id, company_id, company_name_text, photo_path, about, '
      'follower_count, following_count, '
      'trade:trades(name), company:companies!profiles_company_fk(name), '
      'place:places(name)';

  static const _cv =
      'id, role_title, start_month, end_month, show_on_profile, '
      'project:projects(id, name, type:project_types(name), place:places(name)), '
      'confirmations:cv_project_confirmations(confirmed_by)';

  @override
  Future<ProfileView?> fetch(String profileId) async {
    final row = await _client
        .from('profiles')
        .select(_profile)
        .eq('id', profileId)
        .maybeSingle();
    if (row == null) return null;
    final results = await Future.wait<Object?>([
      _client
          .from('experience')
          .select('*, company:companies(name)')
          .eq('profile_id', profileId)
          .order('start_month', ascending: false),
      _client
          .from('cv_projects')
          .select(_cv)
          .eq('profile_id', profileId)
          .order('start_month', ascending: false),
      _client
          .from('profile_open_to')
          .select('options, note, visibility')
          .eq('profile_id', profileId)
          .maybeSingle(),
    ]);
    final experience = results[0]! as List<Map<String, dynamic>>;
    final cv = results[1]! as List<Map<String, dynamic>>;
    final openTo = results[2] as Map<String, dynamic>?;
    final trade = row['trade'] as Map<String, dynamic>?;
    final company = row['company'] as Map<String, dynamic>?;
    final place = row['place'] as Map<String, dynamic>?;
    final photoPath = row['photo_path'] as String?;
    return ProfileView(
      id: row['id'] as String,
      firstName: row['first_name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      followerCount: row['follower_count'] as int? ?? 0,
      followingCount: row['following_count'] as int? ?? 0,
      headline: row['headline'] as String?,
      tradeId: row['trade_id'] as String?,
      tradeName: trade == null
          ? null
          : LocalizedText.fromJson(trade['name'] as Map<String, dynamic>),
      placeId: row['place_id'] as String?,
      placeName: place == null
          ? null
          : LocalizedText.fromJson(place['name'] as Map<String, dynamic>),
      homeMarketId: row['home_market_id'] as String?,
      companyId: row['company_id'] as String?,
      companyName: company?['name'] as String?,
      companyNameText: row['company_name_text'] as String?,
      photoPath: photoPath,
      photoUrl: photoPath == null
          ? null
          : _client.storage.from(_bucket).getPublicUrl(photoPath),
      about: row['about'] as String?,
      openTo: openTo == null ? null : OpenTo.fromJson(openTo),
      experience: [for (final e in experience) ExperienceEntry.fromJson(e)],
      projects: [for (final c in cv) CvProjectEntry.fromJson(c)],
    );
  }

  @override
  Future<bool> isFollowing(String me, String other) async {
    final row = await _client
        .from('follows')
        .select('followee_id')
        .eq('follower_id', me)
        .eq('followee_id', other)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<void> saveBasics(String me, BasicsInput input) =>
      _client.from('profiles').update(input.toJson()).eq('id', me);

  @override
  Future<void> saveAbout(String me, String about) => _client
      .from('profiles')
      .update({'about': about.trim().isEmpty ? null : about.trim()})
      .eq('id', me);

  @override
  Future<String> savePhoto(String me, Uint8List bytes, String extension) async {
    final ext = extension.toLowerCase() == 'png' ? 'png' : 'jpg';
    final path = '$me/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
    await _client.from('profiles').update({'photo_path': path}).eq('id', me);
    return path;
  }

  @override
  Future<void> removePhoto(String me, String path) async {
    await _client.from('profiles').update({'photo_path': null}).eq('id', me);
    await _client.storage.from(_bucket).remove([path]);
  }

  @override
  Future<void> addExperience(String me, ExperienceInput input) =>
      _client.from('experience').insert({...input.toJson(), 'profile_id': me});

  @override
  Future<void> updateExperience(String id, ExperienceInput input) =>
      _client.from('experience').update(input.toJson()).eq('id', id);

  @override
  Future<void> deleteExperience(String id) =>
      _client.from('experience').delete().eq('id', id);

  @override
  Future<void> saveOpenTo(String me, OpenTo openTo) async {
    // Update first; insert only when there is no row yet. (An upsert would
    // also write profile_id, which the app may not update.)
    final updated = await _client
        .from('profile_open_to')
        .update(openTo.toJson())
        .eq('profile_id', me)
        .select('profile_id');
    if (updated.isEmpty) {
      await _client.from('profile_open_to').insert({
        ...openTo.toJson(),
        'profile_id': me,
      });
    }
  }

  @override
  Future<void> setCvVisibility(String cvProjectId, bool show) => _client
      .from('cv_projects')
      .update({'show_on_profile': show})
      .eq('id', cvProjectId);

  @override
  Future<void> block(String me, String other) =>
      _client.from('blocks').insert({'blocker_id': me, 'blocked_id': other});

  @override
  Future<List<({String id, LocalizedText name, bool isCity})>> places(
    String marketId,
  ) async {
    final rows = await _client
        .from('places')
        .select('id, level, name, sort, parent_id')
        .eq('market_id', marketId);
    return orderPlaces(rows);
  }
}

/// Cities in their order, each followed by its areas. An area is labelled
/// with its city ("Salmiya · Hawalli"), so two places with the same name
/// (the Jahra governorate and the Jahra area) can be told apart.
List<({String id, LocalizedText name, bool isCity})> orderPlaces(
  List<Map<String, dynamic>> rows,
) {
  int sortOf(Map<String, dynamic> r) => r['sort'] as int? ?? 0;
  LocalizedText nameOf(Map<String, dynamic> r) =>
      LocalizedText.fromJson(r['name'] as Map<String, dynamic>);
  final cities = rows.where((r) => r['level'] == 'city').toList()
    ..sort((a, b) => sortOf(a).compareTo(sortOf(b)));
  final out = <({String id, LocalizedText name, bool isCity})>[];
  for (final city in cities) {
    final cityName = nameOf(city);
    out.add((id: city['id'] as String, name: cityName, isCity: true));
    final areas = rows.where((r) => r['parent_id'] == city['id']).toList()
      ..sort((a, b) => sortOf(a).compareTo(sortOf(b)));
    for (final area in areas) {
      final n = nameOf(area);
      out.add((
        id: area['id'] as String,
        name: LocalizedText(
          en: '${n.en} · ${cityName.en}',
          ar: '${n.ar} · ${cityName.ar}',
        ),
        isCity: false,
      ));
    }
  }
  return out;
}

final profilePageRepositoryProvider = Provider<ProfilePageRepository>(
  (ref) => SupabaseProfilePageRepository(ref.watch(supabaseClientProvider)),
);

/// A profile page; refreshed after an edit with `ref.invalidate`.
final profileViewProvider = FutureProvider.autoDispose
    .family<ProfileView?, String>(
      (ref, id) => ref.watch(profilePageRepositoryProvider).fetch(id),
    );
