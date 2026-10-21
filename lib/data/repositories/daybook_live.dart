import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_provider.dart';

/// A Space's daybook kept live (review 50 F47): when someone posts, ticks,
/// acknowledges, edits or cancels, their app says "this post changed" on
/// the Space's channel, and every open daybook of that Space reads the
/// page again through daybook_cards, under the server's own rules.
///
/// The channel is a Realtime broadcast: it carries only the post's id,
/// never what changed, so it needs no table in the realtime publication.
/// Whoever reads the page again sees only what they may see. It is a
/// private channel (migration 29, review 62 N1): only a member of the
/// Space may join it or send on it.
abstract class DaybookLive {
  /// The ids of posts others changed in [spaceId], while listened to.
  Stream<String> changes(String spaceId);

  /// Tells the Space's open daybooks that [postId] changed. Never fails:
  /// the others catch up on their next read anyway.
  Future<void> changed(String spaceId, String postId);
}

class SupabaseDaybookLive implements DaybookLive {
  SupabaseDaybookLive(this._client);

  final SupabaseClient _client;

  /// One channel per Space while a daybook of it is open.
  final _open = <String, RealtimeChannel>{};

  static String _topic(String spaceId) => 'daybook:$spaceId';
  static const _private = RealtimeChannelConfig(private: true);
  static const _event = 'changed';
  static const _postKey = 'post_id';

  @override
  Stream<String> changes(String spaceId) {
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onCancel: () {
        final channel = _open.remove(spaceId);
        if (channel != null) unawaited(_client.removeChannel(channel));
      },
    );
    _open[spaceId] = _client
        .channel(_topic(spaceId), opts: _private)
        .onBroadcast(
          event: _event,
          callback: (payload) {
            final id = payload[_postKey];
            if (id is String && !controller.isClosed) controller.add(id);
          },
        )
        .subscribe();
    return controller.stream;
  }

  @override
  Future<void> changed(String spaceId, String postId) async {
    final open = _open[spaceId];
    // With no daybook of the Space open here, a channel just to send (the
    // REST path); it is let go after.
    final channel = open ?? _client.channel(_topic(spaceId), opts: _private);
    try {
      await channel.sendBroadcastMessage(
        event: _event,
        payload: {_postKey: postId},
      );
    } on Exception catch (e) {
      debugPrint('daybook live: $e');
    } finally {
      if (open == null) unawaited(_client.removeChannel(channel));
    }
  }
}

final daybookLiveProvider = Provider<DaybookLive>(
  (ref) => SupabaseDaybookLive(ref.watch(supabaseClientProvider)),
);
