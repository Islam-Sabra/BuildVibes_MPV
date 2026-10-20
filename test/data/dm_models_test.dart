import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Messages list: rows, a dot not a number, the newest request', () {
    final inbox = DmInbox.fromJson({
      'threads': [
        {
          'thread': 't1',
          'person': {'id': 'p1', 'name': 'Omar Haddad', 'company': 'Al Hamra'},
          'last_message_at': '2026-10-15T09:00:00Z',
          'muted': false,
          'unread': true,
          'last': {
            'from_me': false,
            'kind': 'voice',
            'duration_ms': 12000,
            'at': '2026-10-15T09:00:00Z',
          },
        },
      ],
      'requests': {
        'has': true,
        'newest': {
          'thread': 't2',
          'person': {'id': 'p2', 'former': true},
          'last_message_at': '2026-10-15T08:00:00Z',
          'muted': false,
          'unread': true,
        },
      },
    });
    expect(inbox.threads.single.person.company, 'Al Hamra');
    expect(inbox.threads.single.unread, isTrue);
    expect(inbox.threads.single.last!.kind, ChatKind.voice);
    expect(inbox.newestRequest!.person.former, isTrue);
    expect(inbox.anyUnread, isTrue);
    expect(const DmInbox().anyUnread, isFalse);
  });

  test('a muted thread alone lights no dot', () {
    final inbox = DmInbox.fromJson({
      'threads': [
        {
          'thread': 't1',
          'person': {'id': 'p1'},
          'last_message_at': '2026-10-15T09:00:00Z',
          'muted': true,
          'unread': true,
        },
      ],
    });
    expect(inbox.anyUnread, isFalse);
  });

  test('a thread page: state, Both in, messages with replies and files', () {
    final page = DmThreadPage.fromJson({
      'thread': 't1',
      'person': {'id': 'p1', 'name': 'Omar Haddad'},
      'state': 'request',
      'muted': false,
      'shared_space': {'space_id': 's1', 'name': 'Kuwait City Tower'},
      'messages': [
        {
          'id': 'm2',
          'from_me': true,
          'kind': 'text',
          'body': 'Yes',
          'created_at': '2026-10-15T09:05:00Z',
          'reply_to': {'id': 'm1', 'from_me': false, 'text': 'At 7?'},
        },
        {
          'id': 'm1',
          'from_me': false,
          'kind': 'photo',
          'created_at': '2026-10-15T09:00:00Z',
          'tap_to_show': true,
          'files': [
            {'path': 'p1/m1/a.jpg', 'mime': 'image/jpeg', 'bytes': 1000},
          ],
        },
      ],
    });
    expect(page.state, DmState.request);
    expect(page.sharedSpaceName, 'Kuwait City Tower');
    expect(page.messages.first.replyTo!.text, 'At 7?');
    expect(page.messages.last.tapToShow, isTrue);
    expect(page.messages.last.files.single.isPhoto, isTrue);
  });

  test('start_dm paused by the spam guard', () {
    final s = DmStart.fromJson({
      'thread': null,
      'state': 'paused',
      'warning': true,
      'until': '2026-10-25',
    });
    expect(s.paused, isTrue);
    expect(s.threadId, isNull);
    expect(s.until, DateTime(2026, 10, 25));
  });
}
