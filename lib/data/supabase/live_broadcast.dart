import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The waits before a lost channel is joined again (as the `dm:` channels
/// after F100); the last one again and again.
const liveRetryDelays = [
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

/// The payload of a broadcast as the Realtime client hands it over: the
/// whole message (`{event, type, payload}`), with what the database sent
/// inside `payload` (F100: reading it at the top level never found it).
/// Null when it isn't one.
Map<String, dynamic>? broadcastPayload(Map<String, dynamic> message) {
  final payload = message['payload'];
  return payload is Map ? payload.cast<String, dynamic>() : null;
}

/// A private channel on [topic] that only listens for the database's
/// [event] broadcasts (migrations 40, 42 and 43: the app never sends), and
/// hands over each one's payload while listened to.
///
/// - One `BV-LIVE <topic> <status>` line per status change (with the
///   error, if any) and one `BV-LIVE <topic> broadcast <what>` line per
///   broadcast, for adb; [describe] says what a payload is about.
/// - Joined again by itself after a close, an error or a timeout, waiting
///   [retryDelays] (longer each time it fails in a row).
Stream<Map<String, dynamic>> privateBroadcasts(
  SupabaseClient client,
  String topic,
  String event, {
  required String Function(Map<String, dynamic> payload) describe,
  List<Duration> retryDelays = liveRetryDelays,
}) {
  RealtimeChannel? channel;
  Timer? again;
  var tries = 0;
  var cancelled = false;
  late final StreamController<Map<String, dynamic>> controller;

  void join() {
    final mine = client
        .channel(topic, opts: const RealtimeChannelConfig(private: true))
        .onBroadcast(
          event: event,
          callback: (message) {
            final payload = broadcastPayload(message);
            debugPrint(
              'BV-LIVE $topic broadcast '
              '${payload == null ? 'unreadable' : describe(payload)}',
            );
            if (payload != null && !controller.isClosed) {
              controller.add(payload);
            }
          },
        );
    channel = mine;
    mine.subscribe((status, [error]) {
      debugPrint(
        'BV-LIVE $topic ${status.name}${error == null ? '' : ' error=$error'}',
      );
      // A channel let go (left, or replaced) says nothing more.
      if (cancelled || !identical(channel, mine)) return;
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          tries = 0;
        case RealtimeSubscribeStatus.channelError ||
            RealtimeSubscribeStatus.timedOut ||
            RealtimeSubscribeStatus.closed:
          channel = null;
          unawaited(client.removeChannel(mine));
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

  controller = StreamController<Map<String, dynamic>>(
    onListen: join,
    onCancel: () {
      cancelled = true;
      again?.cancel();
      final open = channel;
      channel = null;
      if (open != null) unawaited(client.removeChannel(open));
    },
  );
  return controller.stream;
}
