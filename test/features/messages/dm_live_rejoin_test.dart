// DmLiveHost (F100) beyond dm_live_f100_test: every `dm:` channel closes
// on sign-out and no wait to open one again fires after it; another
// account closes them all and opens them again; a new sign-in token opens
// them again at once, from the first wait.
import 'dart:async';

import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/repositories/dm_repository.dart';
import 'package:buildvibes/data/supabase/live_broadcast.dart';
import 'package:buildvibes/features/messages/dm_live.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/dm_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

final _now = DateTime(2026, 10, 15, 11);

DmRow _row(String threadId, String person) => DmRow(
  threadId: threadId,
  person: DmPerson(id: 'p-$person', name: person),
  lastMessageAt: _now,
  unread: false,
  last: DmPreview(fromMe: false, kind: ChatKind.text, at: _now, text: 'Hi'),
);

/// [FakeDmRepository], counting the streams each thread has open now (the
/// app listening and not yet cancelled).
class _CountingDm extends FakeDmRepository {
  final live = <String, int>{};

  int get liveTotal => live.values.fold(0, (a, b) => a + b);

  @override
  Stream<DmLiveEvent> changes(String threadId) {
    final inner = super.changes(threadId);
    StreamSubscription<DmLiveEvent>? sub;
    late final StreamController<DmLiveEvent> c;
    c = StreamController<DmLiveEvent>(
      onListen: () {
        live[threadId] = (live[threadId] ?? 0) + 1;
        sub = inner.listen(c.add, onError: c.addError, onDone: c.close);
      },
      onCancel: () {
        live[threadId] = live[threadId]! - 1;
        // Not returned: a cancel future would hold back the app's error
        // handler past the test's clock.
        unawaited(sub?.cancel());
      },
    );
    return c.stream;
  }
}

/// [FakeAuthRepository] whose signed-in account can change to another
/// one with no new token in between, so only the account change acts.
class _SwitchingAuth extends FakeAuthRepository {
  _SwitchingAuth() : super(userId: 'user-1', phone: '+96550000001');

  final _ids = StreamController<String?>.broadcast();

  void switchTo(String id) {
    userId = id;
    _ids.add(id);
  }

  @override
  Stream<String?> userIdChanges() => _ids.stream;
}

_CountingDm _twoThreads() => _CountingDm()
  ..inboxValue = DmInbox(
    threads: [_row('t-omar', 'Omar'), _row('t-sara', 'Sara')],
  );

void main() {
  test('the dm: channels wait as the daybook and chat ones do', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(dmLiveRetryDelaysProvider), liveRetryDelays);
  });

  testWidgets('signed out: every dm: channel closes, and a wait to open one '
      'again never fires', (tester) async {
    final dm = _twoThreads();
    final app = await pumpApp(tester, dm: dm, now: _now);
    expect(dm.live, {'t-omar': 1, 't-sara': 1});
    // Sara's channel drops: it waits 2 s to open again.
    dm.drop('t-sara');
    await tester.pump();
    expect(dm.live['t-sara'], 0);

    await app.auth.signOut();
    await tester.pumpAndSettle();
    expect(dm.liveTotal, 0);
    expect(dm.listened, isEmpty);
    final opens = Map.of(dm.opens);
    await tester.pump(const Duration(minutes: 2));
    expect(dm.opens, opens, reason: 'no channel opens while signed out');
    expect(dm.liveTotal, 0);
  });

  testWidgets('another account: every channel is closed and opened again, '
      'one each, and a wait from before does not open a second', (
    tester,
  ) async {
    final dm = _twoThreads();
    final auth = _SwitchingAuth();
    final profiles = FakeProfileRepository()
      ..profiles['user-2'] = completeProfile('user-2');
    await pumpApp(tester, dm: dm, auth: auth, profiles: profiles, now: _now);
    expect(dm.opens, {'t-omar': 1, 't-sara': 1});
    dm.drop('t-sara');
    await tester.pump();

    auth.switchTo('user-2');
    await tester.pumpAndSettle();
    expect(dm.opens['t-omar'], greaterThan(1), reason: 'opened again');
    expect(dm.opens['t-sara'], greaterThan(1));
    expect(dm.live, {'t-omar': 1, 't-sara': 1}, reason: 'the old ones closed');
    final opens = Map.of(dm.opens);
    await tester.pump(const Duration(minutes: 2));
    expect(dm.opens, opens, reason: "the old wait for Sara's channel is gone");
    expect(dm.live, {'t-omar': 1, 't-sara': 1});
  });

  testWidgets('a new sign-in token opens a channel waiting to rejoin at '
      'once, and the waits start again from 2 s', (tester) async {
    final dm = _twoThreads();
    final app = await pumpApp(tester, dm: dm, now: _now);
    // Omar's channel drops and its next two joins are refused: it is now
    // waiting 15 s.
    dm.failOpens['t-omar'] = 2;
    dm.drop('t-omar');
    await tester.pump();
    expect(dm.live['t-omar'], 0);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 5));
    expect(dm.opens['t-omar'], 3);
    expect(dm.live['t-omar'], 0);

    app.auth.renew();
    await tester.pumpAndSettle();
    expect(dm.opens['t-omar'], 4, reason: 'at once, not after 15 s');
    expect(dm.live, {'t-omar': 1, 't-sara': 1});
    await tester.pump(const Duration(seconds: 15));
    expect(dm.opens['t-omar'], 4, reason: 'the 15 s wait was dropped');

    dm.drop('t-omar');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1999));
    expect(dm.opens['t-omar'], 4);
    await tester.pump(const Duration(milliseconds: 1));
    expect(dm.opens['t-omar'], 5, reason: '2 s again');
    expect(dm.live['t-omar'], 1);
  });
}
