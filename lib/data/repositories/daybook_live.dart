import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/live_broadcast.dart';
import '../supabase/supabase_provider.dart';

/// A Space's daybook kept live (review 50 F47, reopened): when someone
/// posts, ticks, acknowledges, edits or cancels, the database broadcasts
/// "this post changed" on the Space's channel (migration 42), and every
/// open daybook of that Space reads the page again through daybook_cards,
/// under the server's own rules. The app only listens: since migration
/// 42 nobody may send on the channel.
///
/// The broadcast carries only ids, never what changed, so it needs no
/// table in the realtime publication. It is a private channel (migration
/// 29, review 62 N1): only a member of the Space may join it.
abstract class DaybookLive {
  /// The ids of posts changed in [spaceId], while listened to. The channel
  /// is joined again by itself when it closes, errors or times out.
  Stream<String> changes(String spaceId);
}

class SupabaseDaybookLive implements DaybookLive {
  SupabaseDaybookLive(this._client);

  final SupabaseClient _client;

  static const _postKey = 'post_id';

  /// The post id in a broadcast as the Realtime client hands it over: the
  /// whole message, with what was sent inside `payload` (F100).
  @visibleForTesting
  static String? postIdFromBroadcast(Map<String, dynamic> message) {
    final id = broadcastPayload(message)?[_postKey];
    return id is String ? id : null;
  }

  @override
  Stream<String> changes(String spaceId) => privateBroadcasts(
    _client,
    'daybook:$spaceId',
    'changed',
    describe: (p) => 'post=${p[_postKey]}',
  ).map((p) => p[_postKey]).where((id) => id is String).cast<String>();
}

final daybookLiveProvider = Provider<DaybookLive>(
  (ref) => SupabaseDaybookLive(ref.watch(supabaseClientProvider)),
);
