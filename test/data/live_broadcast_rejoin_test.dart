// The private Realtime channels of the daybook and Space chat
// (privateBroadcasts, F100/F103): joined once listened to, joined again
// after a close, an error or a timeout (2 s, 5 s, 15 s, then every 30 s),
// and let go when the screen stops listening. Fake channels; the waits
// run on the test's clock (testWidgets).
import 'dart:async';

import 'package:buildvibes/data/repositories/chat_repository.dart';
import 'package:buildvibes/data/repositories/daybook_live.dart';
import 'package:buildvibes/data/supabase/live_broadcast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/realtime_fakes.dart';

const _subscribed = RealtimeSubscribeStatus.subscribed;
const _error = RealtimeSubscribeStatus.channelError;
const _timedOut = RealtimeSubscribeStatus.timedOut;
const _closed = RealtimeSubscribeStatus.closed;

Map<String, dynamic> _message(Object? payload) => {
  'event': 'changed',
  'type': 'broadcast',
  'payload': payload,
};

void main() {
  late FakeRealtimeClient client;
  late List<Map<String, dynamic>> got;
  StreamSubscription<Map<String, dynamic>>? sub;

  void listen() {
    sub = privateBroadcasts(
      client,
      'daybook:s1',
      'changed',
      describe: (p) => 'post=${p['post_id']}',
    ).listen(got.add);
  }

  setUp(() {
    client = FakeRealtimeClient();
    got = [];
    sub = null;
  });

  Future<void> wait(WidgetTester tester, int ms) =>
      tester.pump(Duration(milliseconds: ms));

  testWidgets('joins one private channel on the topic once listened to', (
    tester,
  ) async {
    final stream = privateBroadcasts(
      client,
      'daybook:s1',
      'changed',
      describe: (_) => '',
    );
    expect(client.channels, isEmpty, reason: 'not before it is listened to');
    sub = stream.listen(got.add);
    expect(client.channels, hasLength(1));
    final c = client.last;
    expect(c.name, 'daybook:s1');
    expect(c.opts.private, isTrue);
    expect(c.broadcastEvent, 'changed');
    expect(c.subscribes, 1);
    unawaited(sub!.cancel());
  });

  testWidgets('after a close, an error and a timeout it joins again: 2 s, '
      '5 s, 15 s, then 30 s and 30 s, never before; each failed channel is '
      'removed', (tester) async {
    listen();
    final steps = [
      (_closed, 2000),
      (_error, 5000),
      (_timedOut, 15000),
      (_closed, 30000),
      (_error, 30000),
    ];
    for (final (i, (status, ms)) in steps.indexed) {
      final failed = client.last;
      failed.status(status, status == _error ? 'refused' : null);
      expect(failed.removed, isTrue, reason: 'step $i: the failed channel');
      expect(client.open, isEmpty);
      await wait(tester, ms - 1);
      expect(client.channels, hasLength(i + 1), reason: 'step $i: too soon');
      await wait(tester, 1);
      expect(client.channels, hasLength(i + 2), reason: 'step $i: on time');
      expect(client.last.name, 'daybook:s1');
      expect(client.last.opts.private, isTrue);
      expect(client.last.subscribes, 1);
      expect(client.open, [client.last]);
    }
    unawaited(sub!.cancel());
  });

  testWidgets('a join that succeeds starts the waits again from 2 s', (
    tester,
  ) async {
    listen();
    client.last.status(_error);
    await wait(tester, 2000);
    client.last.status(_timedOut);
    await wait(tester, 5000);
    expect(client.channels, hasLength(3));
    client.last.status(_subscribed);
    client.last.status(_closed);
    await wait(tester, 1999);
    expect(client.channels, hasLength(3));
    await wait(tester, 1);
    expect(client.channels, hasLength(4), reason: '2 s again, not 15 s');
    unawaited(sub!.cancel());
  });

  testWidgets('a broadcast hands over its inner payload; one without a '
      'usable payload hands over nothing', (tester) async {
    listen();
    final c = client.last..status(_subscribed);
    c.broadcast(_message({'post_id': 'p1', 'space_id': 's1'}));
    c.broadcast({'post_id': 'p2'});
    c.broadcast(_message(null));
    c.broadcast(_message('p3'));
    c.broadcast(_message([1, 2]));
    await tester.pump();
    expect(got, [
      {'post_id': 'p1', 'space_id': 's1'},
    ]);
    unawaited(sub!.cancel());
  });

  testWidgets('broadcasts on the channel joined again arrive too', (
    tester,
  ) async {
    listen();
    client.last.status(_closed);
    await wait(tester, 2000);
    client.last
      ..status(_subscribed)
      ..broadcast(_message({'post_id': 'p9'}));
    await tester.pump();
    expect(got, [
      {'post_id': 'p9'},
    ]);
    unawaited(sub!.cancel());
  });

  testWidgets('cancelled while joined (the screen closes, as on sign-out): '
      'the channel is removed and none is joined again', (tester) async {
    listen();
    final c = client.last..status(_subscribed);
    unawaited(sub!.cancel());
    expect(c.removed, isTrue);
    expect(client.open, isEmpty);
    // What the removed channel says afterwards changes nothing.
    c.status(_closed);
    await wait(tester, 120000);
    expect(client.channels, [c]);
    expect(client.open, isEmpty);
  });

  testWidgets('cancelled while waiting to join again: the wait never fires '
      'and no channel stays open', (tester) async {
    listen();
    client.last.status(_error);
    await wait(tester, 1000);
    unawaited(sub!.cancel());
    await wait(tester, 120000);
    expect(client.channels, hasLength(1));
    expect(client.open, isEmpty);
  });

  testWidgets('cancelled before the first join answers: the channel is '
      'removed', (tester) async {
    listen();
    final c = client.last;
    unawaited(sub!.cancel());
    expect(c.removed, isTrue);
    c.status(_subscribed);
    c.status(_timedOut);
    await wait(tester, 120000);
    expect(client.channels, [c]);
  });

  testWidgets('what a replaced channel says later is ignored: no second '
      'wait, no extra channel, no reset of the waits', (tester) async {
    listen();
    final first = client.last..status(_error);
    // The removed channel then reports its close, as removeChannel does.
    first.status(_closed);
    first.status(_timedOut);
    await wait(tester, 2000);
    expect(client.channels, hasLength(2), reason: 'one wait, one rejoin');
    final second = client.last;
    // The old channel's late news touches neither the new one nor its
    // waits.
    first.status(_closed);
    await wait(tester, 60000);
    expect(client.channels, hasLength(2));
    expect(second.removed, isFalse);
    first.status(_subscribed);
    second.status(_error);
    await wait(tester, 4999);
    expect(
      client.channels,
      hasLength(2),
      reason: "the old channel's subscribed did not reset the waits",
    );
    await wait(tester, 1);
    expect(client.channels, hasLength(3));
    unawaited(sub!.cancel());
  });

  testWidgets('a test may set its own waits; the last repeats', (tester) async {
    sub = privateBroadcasts(
      client,
      'thread:t1',
      'chat',
      describe: (_) => '',
      retryDelays: const [Duration(seconds: 1), Duration(seconds: 3)],
    ).listen(got.add);
    for (final (i, ms) in [1000, 3000, 3000].indexed) {
      client.last.status(_closed);
      await wait(tester, ms - 1);
      expect(client.channels, hasLength(i + 1));
      await wait(tester, 1);
      expect(client.channels, hasLength(i + 2));
    }
    unawaited(sub!.cancel());
  });

  test('the waits are 2 s, 5 s, 15 s and 30 s', () {
    expect(liveRetryDelays, const [
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
    ]);
  });

  group('the daybook and Space chat use it', () {
    testWidgets('the daybook joins daybook:<space> privately, hands over '
        'post ids and joins again after a close', (tester) async {
      final ids = <String>[];
      final s = SupabaseDaybookLive(client).changes('s1').listen(ids.add);
      final c = client.last;
      expect(c.name, 'daybook:s1');
      expect(c.opts.private, isTrue);
      expect(c.broadcastEvent, 'changed');
      c
        ..status(_subscribed)
        ..broadcast(_message({'post_id': 'p1'}))
        ..broadcast(_message({'post_id': 7}))
        ..status(_closed);
      await wait(tester, 2000);
      expect(client.channels, hasLength(2));
      expect(c.removed, isTrue);
      expect(ids, ['p1']);
      unawaited(s.cancel());
      expect(client.open, isEmpty);
    });

    testWidgets('Space chat joins thread:<id> privately, hands over message '
        'ids and joins again after an error', (tester) async {
      final ids = <String>[];
      final s = SupabaseChatRepository(client).changes('t1').listen(ids.add);
      final c = client.last;
      expect(c.name, 'thread:t1');
      expect(c.opts.private, isTrue);
      expect(c.broadcastEvent, 'chat');
      c
        ..status(_subscribed)
        ..broadcast(_message({'message_id': 'm1', 'op': 'insert'}))
        ..broadcast(_message({'op': 'insert'}))
        ..status(_error, 'refused');
      await wait(tester, 2000);
      expect(client.channels, hasLength(2));
      expect(client.last.name, 'thread:t1');
      expect(c.removed, isTrue);
      expect(ids, ['m1']);
      unawaited(s.cancel());
      expect(client.open, isEmpty);
    });
  });
}
