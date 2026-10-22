import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space_search.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('library_overview row: NEW VERSION and the receivers, in order', () {
    final o = LibraryOverview.fromJson({
      'file_id': 'f1',
      'new_for_me': true,
      'received': [
        {
          'profile_id': 'p2',
          'name': 'Omar Haddad',
          'at': '2026-10-21T08:00:00Z',
        },
        {
          'profile_id': 'p1',
          'name': 'Islam Ahmed',
          'at': '2026-10-20T08:00:00Z',
        },
      ],
    });
    expect(o.fileId, 'f1');
    expect(o.newForMe, isTrue);
    expect([for (final r in o.received) r.profileId], ['p2', 'p1']);
    expect(o.received.first.mine, isFalse);
  });

  test('library_overview row with nothing received', () {
    final o = LibraryOverview.fromJson({
      'file_id': 'f1',
      'new_for_me': false,
      'received': [],
    });
    expect(o.newForMe, isFalse);
    expect(o.received, isEmpty);
  });

  test('library_file_receipts row marks mine', () {
    final r = LibraryReceipt.fromJson({
      'profile_id': 'me',
      'name': 'Islam Ahmed',
      'at': '2026-10-21T08:00:00Z',
      'mine': true,
    });
    expect(r.mine, isTrue);
    expect(r.at, DateTime.utc(2026, 10, 21, 8));
  });

  test('search_space rows: each kind, a cancelled post, an unknown kind', () {
    Map<String, dynamic> row(String kind, {String? status}) => {
      'kind': kind,
      'id': 'id-$kind',
      'post_id': kind == 'post' || kind == 'point' ? 'post-1' : null,
      'thread_id': kind == 'message' ? 'thread-1' : null,
      'team_id': null,
      'post_kind': kind == 'post' ? 'work_item' : null,
      'post_status': status,
      'ref': kind == 'post' ? 'KCT-021' : null,
      'title': 'Sleeves at grid C7',
      'snippet': null,
      'author_name': 'Omar Haddad',
      'created_at': '2026-10-15T08:00:00Z',
    };
    final post = SpaceSearchHit.fromJson(row('post', status: 'cancelled'))!;
    expect(post.kind, SpaceSearchKind.post);
    expect(post.isWork, isTrue);
    expect(post.cancelled, isTrue);
    expect(post.withStatus(WorkStatus.done).status, WorkStatus.done);
    expect(SpaceSearchHit.fromJson(row('point'))!.isWork, isTrue);
    expect(SpaceSearchHit.fromJson(row('message'))!.threadId, 'thread-1');
    expect(SpaceSearchHit.fromJson(row('file'))!.isWork, isFalse);
    expect(SpaceSearchHit.fromJson(row('model')), isNull);
    // Review 80: the reader's own hit (an older server sends no mine).
    expect(post.mine, isFalse);
    final mine = SpaceSearchHit.fromJson({...row('message'), 'mine': true})!;
    expect(mine.mine, isTrue);
    expect(mine.withStatus(null).mine, isTrue);
  });
}
