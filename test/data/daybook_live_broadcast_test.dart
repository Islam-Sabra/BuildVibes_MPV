import 'package:buildvibes/data/repositories/daybook_live.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // F100: the Realtime client hands a broadcast callback the whole message,
  // with what was sent one level down, in `payload` (realtime_client 2.13).
  test('the post id is read from inside the broadcast payload', () {
    final message = <String, dynamic>{
      'event': 'changed',
      'type': 'broadcast',
      'meta': {'id': 'm-1'},
      'payload': {'post_id': 'post-1'},
    };
    expect(SupabaseDaybookLive.postIdFromBroadcast(message), 'post-1');
  });

  test('a top-level post_id alone is not a post id', () {
    expect(
      SupabaseDaybookLive.postIdFromBroadcast({'post_id': 'post-1'}),
      isNull,
    );
  });

  test('a broadcast without a usable post id gives none', () {
    expect(SupabaseDaybookLive.postIdFromBroadcast({}), isNull);
    expect(
      SupabaseDaybookLive.postIdFromBroadcast({'payload': 'post-1'}),
      isNull,
    );
    expect(
      SupabaseDaybookLive.postIdFromBroadcast({
        'payload': {'post_id': 7},
      }),
      isNull,
    );
  });
}
