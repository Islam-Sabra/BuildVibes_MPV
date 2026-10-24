// A direct message thread's own channel (SupabaseDmRepository.changes,
// F100): one private `dm:` join per stream. It says when it is joined,
// hands over each broadcast's ids, and ends with DmLiveLost when the
// channel closes, errors or times out. It does not join again by itself:
// DmLiveHost opens a new stream after its waits (dm_live_f100_test).
import 'dart:async';

import 'package:buildvibes/data/repositories/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/realtime_fakes.dart';

Map<String, dynamic> _message(Object? payload) => {
  'event': 'dm',
  'type': 'broadcast',
  'payload': payload,
};

void main() {
  late FakeRealtimeClient client;
  late List<DmLiveEvent> events;
  late List<Object> errors;
  late bool done;

  setUp(() {
    client = FakeRealtimeClient();
    events = [];
    errors = [];
    done = false;
  });

  StreamSubscription<DmLiveEvent> listen({bool cancelOnError = true}) =>
      SupabaseDmRepository(client)
          .changes('t1')
          .listen(
            events.add,
            onError: errors.add,
            onDone: () => done = true,
            cancelOnError: cancelOnError,
          );

  testWidgets('joins dm:<thread> privately, for the dm broadcast', (
    tester,
  ) async {
    final sub = listen();
    expect(client.channels, hasLength(1));
    final c = client.last;
    expect(c.name, 'dm:t1');
    expect(c.opts.private, isTrue);
    expect(c.broadcastEvent, 'dm');
    expect(c.subscribes, 1);
    unawaited(sub.cancel());
  });

  testWidgets('joined, then a new and a deleted message: their ids; a '
      'message without a usable payload: nothing', (tester) async {
    final sub = listen();
    client.last
      ..status(RealtimeSubscribeStatus.subscribed)
      ..broadcast(
        _message({
          'thread_id': 't1',
          'message_id': 'm1',
          'author_id': 'p-omar',
          'op': 'insert',
        }),
      )
      ..broadcast(_message({'message_id': 'm0', 'op': 'delete'}))
      ..broadcast({'message_id': 'm2'})
      ..broadcast(_message(null))
      ..broadcast(_message({'message_id': 3}));
    await tester.pump();
    expect(events, hasLength(3));
    expect(events[0], isA<DmLiveJoined>());
    final added = events[1] as DmLiveRow;
    expect(
      (added.id, added.inserted, added.authorId, added.deleted),
      ('m1', true, 'p-omar', false),
    );
    final gone = events[2] as DmLiveRow;
    expect(
      (gone.id, gone.inserted, gone.authorId, gone.deleted),
      ('m0', false, null, true),
    );
    unawaited(sub.cancel());
  });

  for (final status in const [
    RealtimeSubscribeStatus.channelError,
    RealtimeSubscribeStatus.timedOut,
    RealtimeSubscribeStatus.closed,
  ]) {
    testWidgets('${status.name}: the stream ends with DmLiveLost, the '
        'channel is removed, and it does not join again by itself', (
      tester,
    ) async {
      listen();
      final c = client.last..status(RealtimeSubscribeStatus.subscribed);
      c.status(
        status,
        status == RealtimeSubscribeStatus.channelError ? 'no' : null,
      );
      await tester.pump();
      expect(errors, hasLength(1));
      final lost = errors.single as DmLiveLost;
      expect(lost.status, status.name);
      expect(c.removed, isTrue);
      expect(client.open, isEmpty);
      await tester.pump(const Duration(minutes: 2));
      expect(client.channels, [c], reason: 'DmLiveHost joins again');
    });
  }

  testWidgets('a listener that keeps listening after the error gets the '
      'end, and the channel is removed then', (tester) async {
    listen(cancelOnError: false);
    final c = client.last..status(RealtimeSubscribeStatus.timedOut);
    await tester.pump();
    expect(errors.single, isA<DmLiveLost>());
    expect(done, isTrue);
    expect(c.removed, isTrue);
  });

  testWidgets('after it is lost, what the channel says is ignored', (
    tester,
  ) async {
    listen(cancelOnError: false);
    final c = client.last..status(RealtimeSubscribeStatus.channelError);
    c
      ..status(RealtimeSubscribeStatus.closed)
      ..status(RealtimeSubscribeStatus.subscribed)
      ..broadcast(_message({'message_id': 'm1', 'op': 'insert'}));
    await tester.pump();
    expect(errors, hasLength(1));
    expect(events, isEmpty);
  });

  testWidgets('cancelled (sign-out, another account): the channel is '
      'removed, and what it says later is ignored', (tester) async {
    final sub = listen();
    final c = client.last..status(RealtimeSubscribeStatus.subscribed);
    await tester.pump();
    unawaited(sub.cancel());
    expect(c.removed, isTrue);
    expect(client.open, isEmpty);
    c
      ..status(RealtimeSubscribeStatus.closed)
      ..broadcast(_message({'message_id': 'm1', 'op': 'insert'}));
    await tester.pump(const Duration(minutes: 2));
    expect(events, [isA<DmLiveJoined>()]);
    expect(errors, isEmpty);
    expect(client.channels, [c]);
  });
}
