import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// The S3 switches (migration 14). Work items and requests have no switch:
/// they follow each Space's level.
@immutable
class PushSettings {
  const PushSettings({
    this.followers = true,
    this.replies = true,
    this.messageText = false,
  });

  final bool followers;
  final bool replies;

  /// "Show message text on lock screen". Off until the person turns it on.
  final bool messageText;

  PushSettings copyWith({bool? followers, bool? replies, bool? messageText}) =>
      PushSettings(
        followers: followers ?? this.followers,
        replies: replies ?? this.replies,
        messageText: messageText ?? this.messageText,
      );
}

/// This phone's push token and the S3 switches. Sending happens on the
/// server (the push Edge Function).
abstract class PushRepository {
  /// [installId] is this install's own (F81): only its old token is
  /// replaced, so a person's phone and tablet both keep theirs.
  Future<void> register(
    String token,
    String platform,
    String locale, {
    String? installId,
  });
  Future<void> unregister(String token);
  Future<PushSettings> settings();
  Future<void> setSettings(PushSettings settings);
}

class SupabasePushRepository implements PushRepository {
  const SupabasePushRepository(this._client);

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
  Future<void> register(
    String token,
    String platform,
    String locale, {
    String? installId,
  }) => _guard(
    () => _client.rpc(
      'register_push_token',
      params: {
        'p_token': token,
        'p_platform': platform,
        'p_locale': locale,
        'p_install': ?installId,
      },
    ),
  );

  @override
  Future<void> unregister(String token) => _guard(
    () => _client.rpc('unregister_push_token', params: {'p_token': token}),
  );

  @override
  Future<PushSettings> settings() => _guard(() async {
    final rows = (await _client.rpc<List<dynamic>>(
      'my_push_settings',
    )).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return const PushSettings();
    final r = rows.first;
    return PushSettings(
      followers: r['followers'] as bool? ?? true,
      replies: r['replies'] as bool? ?? true,
      messageText: r['message_text'] as bool? ?? false,
    );
  });

  @override
  Future<void> setSettings(PushSettings s) => _guard(
    () => _client.rpc(
      'set_push_settings',
      params: {
        'p_followers': s.followers,
        'p_replies': s.replies,
        'p_message_text': s.messageText,
      },
    ),
  );
}

final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => SupabasePushRepository(ref.watch(supabaseClientProvider)),
);
