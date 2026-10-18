// The daybook pages on the rows daybook_page returns, not on the entries
// this version draws (migration 24 deploy order): a page full of a kind
// the app doesn't know never ends paging early.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/features/work/daybook_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';

void main() {
  const space = DaybookSamples.space;
  final s = DaybookSamples('en');

  /// [n] updates, a minute apart, newest at 12:00.
  List<DaybookRecord> updates(int n, {int from = 0}) => [
    for (var i = from; i < from + n; i++)
      DaybookUpdate(
        id: 'u-${i.toString().padLeft(3, '0')}',
        at: DateTime(2026, 10, 15, 12).subtract(Duration(minutes: i)),
        postId: 'post-sleeves',
        title: s.sleeves,
      ),
  ];

  test('a first page of unknown kinds still has older pages; loading them '
      'reaches the drawn entries', () async {
    final rows = updates(DaybookPages.pageSize + 5);
    final fake = FakeDaybookRepository()
      ..posts[space] = rows
      ..unknown.addAll([
        for (final r in rows.take(DaybookPages.pageSize)) r.id,
      ]);
    final container = ProviderContainer(
      overrides: [daybookRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(daybookPageProvider(space), (_, _) {});
    addTearDown(sub.close);

    final first = await container.read(daybookPageProvider(space).future);
    final pages = container.read(daybookPageProvider(space).notifier);
    expect(first, isEmpty);
    expect(pages.hasOlder, isTrue);

    expect(await pages.loadOlder(), isTrue);
    expect(container.read(daybookPageProvider(space)).value, hasLength(5));
    expect(pages.hasOlder, isFalse);
    // The second page started after the last row sent, drawn or not.
    expect(
      fake.pageCalls.last,
      '$space ${rows[DaybookPages.pageSize - 1].at.toIso8601String()}',
    );
  });

  test(
    'a short page of rows ends paging even when all of them are drawn',
    () async {
      final fake = FakeDaybookRepository()..posts[space] = updates(3);
      final container = ProviderContainer(
        overrides: [daybookRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(daybookPageProvider(space), (_, _) {});
      addTearDown(sub.close);
      await container.read(daybookPageProvider(space).future);
      expect(
        container.read(daybookPageProvider(space).notifier).hasOlder,
        isFalse,
      );
    },
  );

  test('sent_back rows parse as their own entry, with the owner\'s clip', () {
    final r = DaybookRecord.fromRow({
      'id': 'e1',
      'created_at': '2026-10-15T07:12:00Z',
      'kind': 'sent_back',
      'entry': {
        'id': 'e1',
        'post_id': 'p1',
        'ref': 'KCT-021',
        'title': 'Sleeves',
        'post_status': 'open',
        'item_status': 'open',
        'actor_id': 'u1',
        'actor_name': 'Islam Ahmed',
        'reason': 'not_as_asked',
        'note': 'One sleeve is short.',
        'at': '2026-10-15T07:12:00Z',
        'needs_me': true,
      },
    });
    expect(r, isA<DaybookSentBack>());
    final b = r! as DaybookSentBack;
    expect(b.postId, 'p1');
    expect(b.actorName, 'Islam Ahmed');
    expect(b.note, 'One sleeve is short.');
    expect(b.needsMe, isTrue);
    expect(b.cancelled, isFalse);
    expect(
      DaybookRecord.fromRow({
        'kind': 'later_kind',
        'entry': <String, dynamic>{},
      }),
      isNull,
    );
  });
}
