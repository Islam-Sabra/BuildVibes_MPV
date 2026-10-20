// The daybook's cards as the phone keeps them (daybook_cards, review 53
// Part B): paging by (last_activity_at, id), a card with new activity
// moving to the top, and "Show earlier" past a card's first lines.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/features/work/daybook_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';

void main() {
  const space = DaybookSamples.space;
  const s = DaybookSamples('en');
  final noon = DateTime(2026, 10, 15, 12);

  /// Card [i]: a work item with its last activity [i] minutes before noon
  /// (or at [at]).
  DaybookCard numbered(int i, {DateTime? at}) => s.card(
    s.item(
      id: 'post-${i.toString().padLeft(3, '0')}',
      at: at ?? noon.subtract(Duration(minutes: i)),
      title: 'Item $i',
      authorId: DaybookSamples.sara,
      ownerId: DaybookSamples.omar,
    ),
  );

  ({ProviderContainer container, FakeDaybookRepository fake}) open(
    List<DaybookCard> cards,
  ) {
    final fake = FakeDaybookRepository()..posts[space] = cards;
    final container = ProviderContainer(
      overrides: [daybookRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(daybookCardsProvider(space), (_, _) {});
    addTearDown(sub.close);
    return (container: container, fake: fake);
  }

  List<String> ids(ProviderContainer c) => [
    for (final card in c.read(daybookCardsProvider(space)).value!) card.id,
  ];

  test('pages follow the last card\'s activity and id: cards at the same '
      'moment are never skipped', () async {
    // 35 cards, all at noon: only the ids tell them apart.
    final all = [for (var i = 0; i < 35; i++) numbered(i, at: noon)];
    final (:container, :fake) = open(all);
    final first = await container.read(daybookCardsProvider(space).future);
    final cards = container.read(daybookCardsProvider(space).notifier);
    expect(first, hasLength(DaybookCards.pageSize));
    expect(cards.hasOlder, isTrue);
    expect(await cards.loadOlder(), isTrue);
    expect(ids(container).toSet(), {for (final c in all) c.id});
    expect(ids(container), hasLength(35));
    expect(cards.hasOlder, isFalse);
    expect(fake.pageCalls.last, '$space ${noon.toIso8601String()}');
  });

  test('new activity moves a card to the top, once, without a load', () async {
    final (:container, :fake) = open([for (var i = 0; i < 5; i++) numbered(i)]);
    await container.read(daybookCardsProvider(space).future);
    expect(ids(container).first, 'post-000');
    // An update on the oldest card, after noon.
    final moved = numbered(4);
    fake.put(
      space,
      moved.copyWith(
        lastActivityAt: noon.add(const Duration(minutes: 5)),
        history: [
          s.event(
            'ev-new',
            DaybookEventKind.comment,
            noon.add(const Duration(minutes: 5)),
            DaybookSamples.omar,
            note: 'On it.',
          ),
          ...moved.history,
        ],
      ),
    );
    await container.read(daybookCardsProvider(space).notifier).refresh();
    expect(ids(container), [
      'post-004',
      'post-000',
      'post-001',
      'post-002',
      'post-003',
    ]);
  });

  test('a refresh past the first hundred keeps the older pages, and a card '
      'that moved is not kept twice', () async {
    final all = [for (var i = 0; i < 130; i++) numbered(i)];
    final (:container, :fake) = open(all);
    final cards = container.read(daybookCardsProvider(space).notifier);
    await container.read(daybookCardsProvider(space).future);
    while (await cards.loadOlder()) {}
    expect(ids(container), hasLength(130));
    // The oldest card has new activity.
    fake.put(
      space,
      numbered(
        129,
      ).copyWith(lastActivityAt: noon.add(const Duration(hours: 1))),
    );
    await cards.refresh();
    final now = ids(container);
    expect(now, hasLength(130));
    expect(now.first, 'post-129');
    expect(now.where((id) => id == 'post-129'), hasLength(1));
  });

  test('Show earlier past the first 50 lines reads post_history from the '
      'card\'s last line, and keeps them while nothing new happens', () async {
    final base = s.sleevesCard();
    final card = base.copyWith(historyMore: true);
    // One more than a page: post_history says more are left.
    final older = [
      for (var i = 0; i <= DaybookRepository.historyPage; i++)
        s.event(
          'ev-old-$i',
          DaybookEventKind.comment,
          DaybookSamples.sleevesRaisedAt.subtract(Duration(minutes: i + 1)),
          DaybookSamples.omar,
          note: 'Old $i',
        ),
    ];
    final (:container, :fake) = open([card]);
    fake.earlier[card.id] = older;
    await container.read(daybookCardsProvider(space).future);
    final cards = container.read(daybookCardsProvider(space).notifier);

    await cards.loadEarlier(card.id);
    var now = container.read(daybookCardsProvider(space)).value!.single;
    expect(fake.historyCalls, [card.id]);
    const page = DaybookRepository.historyPage;
    expect(now.history, hasLength(base.history.length + page));
    expect(now.history.last.id, 'ev-old-${page - 1}');
    // post_history's more: there are older lines still.
    expect(now.historyMore, isTrue);

    await cards.refresh();
    now = container.read(daybookCardsProvider(space)).value!.single;
    expect(now.history, hasLength(base.history.length + page));

    // New activity shifts the first lines: the earlier ones are read again.
    fake.put(
      space,
      card.copyWith(lastActivityAt: noon.add(const Duration(hours: 1))),
    );
    await cards.refresh();
    now = container.read(daybookCardsProvider(space)).value!.single;
    expect(now.history, hasLength(base.history.length));
  });

  test('a short post_history page means no more', () async {
    final card = s.sleevesCard().copyWith(historyMore: true);
    final (:container, :fake) = open([card]);
    fake.earlier[card.id] = [
      s.event(
        'ev-old',
        DaybookEventKind.comment,
        DaybookSamples.sleevesRaisedAt.subtract(const Duration(minutes: 1)),
        DaybookSamples.omar,
        note: 'Old',
      ),
    ];
    await container.read(daybookCardsProvider(space).future);
    await container
        .read(daybookCardsProvider(space).notifier)
        .loadEarlier(card.id);
    final now = container.read(daybookCardsProvider(space)).value!.single;
    expect(now.history.last.id, 'ev-old');
    expect(now.historyMore, isFalse);
  });
}
