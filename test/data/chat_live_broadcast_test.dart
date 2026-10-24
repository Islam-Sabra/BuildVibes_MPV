import 'package:buildvibes/data/repositories/chat_repository.dart';
import 'package:buildvibes/data/supabase/live_broadcast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // F103: migration 43's broadcast, as the Realtime client hands it over:
  // the whole message, with the database's ids one level down.
  test('the message id is read from inside the broadcast payload', () {
    final message = <String, dynamic>{
      'event': 'chat',
      'type': 'broadcast',
      'payload': {
        'id': 'x',
        'thread_id': 't-1',
        'message_id': 'm-1',
        'author_id': 'p-1',
        'op': 'insert',
      },
    };
    final payload = broadcastPayload(message);
    expect(payload, isNotNull);
    expect(SupabaseChatRepository.messageIdFromBroadcast(payload!), 'm-1');
  });

  test('nothing usable gives nothing', () {
    expect(broadcastPayload({'message_id': 'm-1'}), isNull);
    expect(broadcastPayload({'payload': 'm-1'}), isNull);
    expect(SupabaseChatRepository.messageIdFromBroadcast({}), isNull);
    expect(
      SupabaseChatRepository.messageIdFromBroadcast({'message_id': 7}),
      isNull,
    );
  });
}
