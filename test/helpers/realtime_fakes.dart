import 'package:supabase_flutter/supabase_flutter.dart';

/// A Realtime channel in memory: it keeps what the app asked of it (its
/// topic, whether it is private, the broadcast it listens for) and its
/// subscribe callback, so a test can say what the server would.
class FakeRealtimeChannel implements RealtimeChannel {
  FakeRealtimeChannel(this.name, this.opts);

  final String name;
  final RealtimeChannelConfig opts;

  /// The broadcast event listened for, and its callback.
  String? broadcastEvent;
  void Function(Map<String, dynamic> message)? _onBroadcast;

  void Function(RealtimeSubscribeStatus status, Object? error)? _onStatus;

  /// How many times subscribe was called.
  int subscribes = 0;

  /// Removed with the client's removeChannel.
  bool removed = false;

  @override
  RealtimeChannel onBroadcast({
    required String event,
    required void Function(Map<String, dynamic> payload) callback,
  }) {
    broadcastEvent = event;
    _onBroadcast = callback;
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) {
    subscribes++;
    _onStatus = callback;
    return this;
  }

  /// The server says the channel is [status] (with [error], if any).
  void status(RealtimeSubscribeStatus status, [Object? error]) =>
      _onStatus?.call(status, error);

  /// The server broadcasts [message], the whole `{event, type, payload}`.
  void broadcast(Map<String, dynamic> message) => _onBroadcast?.call(message);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A Supabase client that only makes and removes [FakeRealtimeChannel]s,
/// in the order the app asked for them ([channels]).
class FakeRealtimeClient implements SupabaseClient {
  final channels = <FakeRealtimeChannel>[];

  /// The channels the app asked for and hasn't removed.
  Iterable<FakeRealtimeChannel> get open => channels.where((c) => !c.removed);

  FakeRealtimeChannel get last => channels.last;

  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) {
    final c = FakeRealtimeChannel(name, opts);
    channels.add(c);
    return c;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    (channel as FakeRealtimeChannel).removed = true;
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
