import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  SupabaseDaybookLive(this._client, {this.retryDelays = _waits});

  final SupabaseClient _client;

  /// The waits before a lost channel is joined again (as the `dm:`
  /// channels after F100); the last one again and again.
  final List<Duration> retryDelays;

  static const _waits = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  static String _topic(String spaceId) => 'daybook:$spaceId';
  static const _private = RealtimeChannelConfig(private: true);
  static const _event = 'changed';
  static const _postKey = 'post_id';

  /// The post id in a broadcast as the Realtime client hands it over: the
  /// whole message (`{event, type, payload}`), with what was sent inside
  /// `payload` (F100: reading it at the top level never found it).
  @visibleForTesting
  static String? postIdFromBroadcast(Map<String, dynamic> message) {
    final payload = message['payload'];
    if (payload is! Map) return null;
    final id = payload[_postKey];
    return id is String ? id : null;
  }

  @override
  Stream<String> changes(String spaceId) {
    RealtimeChannel? channel;
    Timer? again;
    var tries = 0;
    var cancelled = false;
    late final StreamController<String> controller;

    void join() {
      final mine = _client
          .channel(_topic(spaceId), opts: _private)
          .onBroadcast(
            event: _event,
            callback: (message) {
              final id = postIdFromBroadcast(message);
              // One line per broadcast, for adb (F47 reopened).
              debugPrint('BV-LIVE daybook:$spaceId broadcast post=$id');
              if (id != null && !controller.isClosed) controller.add(id);
            },
          );
      channel = mine;
      mine.subscribe((status, [error]) {
        // One line per status change, for adb.
        debugPrint(
          'BV-LIVE daybook:$spaceId ${status.name}'
          '${error == null ? '' : ' error=$error'}',
        );
        // A channel let go (left, or replaced) says nothing more.
        if (cancelled || !identical(channel, mine)) return;
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            tries = 0;
          case RealtimeSubscribeStatus.channelError ||
              RealtimeSubscribeStatus.timedOut ||
              RealtimeSubscribeStatus.closed:
            // Joined again a little later, waiting longer each time it
            // fails in a row.
            channel = null;
            unawaited(_client.removeChannel(mine));
            final wait = retryDelays[tries.clamp(0, retryDelays.length - 1)];
            tries++;
            again?.cancel();
            again = Timer(wait, () {
              again = null;
              if (!cancelled) join();
            });
        }
      });
    }

    controller = StreamController<String>(
      onListen: join,
      onCancel: () {
        cancelled = true;
        again?.cancel();
        final open = channel;
        channel = null;
        if (open != null) unawaited(_client.removeChannel(open));
      },
    );
    return controller.stream;
  }
}

final daybookLiveProvider = Provider<DaybookLive>(
  (ref) => SupabaseDaybookLive(ref.watch(supabaseClientProvider)),
);
