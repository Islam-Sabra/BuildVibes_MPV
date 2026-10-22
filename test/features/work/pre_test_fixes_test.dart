// Fixes from the review of slices 3–6 before the founder's phone test.
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/daybook_samples.dart';

void main() {
  final quote = DaybookQuote(
    text: 'Pump booked until 2 pm',
    authorName: 'Omar Haddad',
    at: DateTime.utc(2026, 10, 15, 7),
  );

  test('a quote turns a card half-written as another kind into a work '
      'item, keeping its words', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authUserIdProvider.overrideWithValue(
          const AsyncData(DaybookSamples.islam),
        ),
      ],
    );
    addTearDown(c.dispose);
    final draft = c.read(daybookDraftProvider(DaybookSamples.space).notifier);
    await draft.put(
      const DaybookPostDraft(
        id: 'd1',
        kind: DaybookKind.checklist,
        title: 'Handover',
      ),
    );
    await draft.quoteMessage('d2', quote, sourceMessageId: 'm1');
    final now = c.read(daybookDraftProvider(DaybookSamples.space))!;
    expect(now.kind, DaybookKind.workItem);
    expect(now.title, 'Handover');
    expect(now.quote?.text, quote.text);
    expect(now.sourceMessageId, 'm1');
  });

  test('a post whose chat message went comes back without the link, the '
      'quote kept', () {
    final item = PendingItem(
      kind: PendingKind.workItem,
      id: 'w1',
      spaceId: DaybookSamples.space,
      title: 'Pump',
      ownerId: DaybookSamples.omar,
      ownerName: 'Omar Haddad',
      quote: quote,
      sourceMessageId: 'm1',
    );
    final back = item.withoutSource();
    expect(back.sourceMessageId, isNull);
    expect(back.quote?.text, quote.text);
    expect(back.id, 'w1');

    final post = PendingItem(
      kind: PendingKind.post,
      id: 'p1',
      spaceId: DaybookSamples.space,
      title: 'Pump',
      ownerId: DaybookSamples.omar,
      ownerName: 'Omar Haddad',
      draft: DaybookPostDraft(
        id: 'p1',
        kind: DaybookKind.workItem,
        quote: quote,
        sourceMessageId: 'm1',
      ),
    );
    final draftBack = post.withoutSource().draft!;
    expect(draftBack.sourceMessageId, isNull);
    expect(draftBack.quote?.text, quote.text);
  });
}
