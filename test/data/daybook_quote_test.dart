// Review 64 (DM4–DM5, S8m): a message quoted in a work item.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a quote as space_posts.quote keeps it, and the server limits', () {
    final q = DaybookQuote.fromJson({
      'text': 'Gate 2 is blocked by the crane.',
      'author_name': 'Rakesh Nair',
      'at': '2026-10-15T07:15:00Z',
    })!;
    expect(q.text, 'Gate 2 is blocked by the crane.');
    expect(q.authorName, 'Rakesh Nair');
    expect(q.at, DateTime.utc(2026, 10, 15, 7, 15));
    expect(q.toJson()['at'], '2026-10-15T07:15:00.000Z');
    expect(DaybookQuote.fromJson({'text': '  '}), isNull);
    expect(DaybookQuote.fromJson(null), isNull);
    final long = DaybookQuote(text: 'x' * 4000, authorName: 'y' * 200);
    expect((long.toJson()['text'] as String).length, DaybookQuote.textMax);
    expect(
      (long.toJson()['author_name'] as String).length,
      DaybookQuote.authorMax,
    );
    // Across a block there's no name: the key is left out.
    expect(
      const DaybookQuote(text: 'Hi').toJson().containsKey('author_name'),
      isFalse,
    );
  });

  test('a post reads its quote', () {
    final post = DaybookPost.fromJson({
      'id': 'p1',
      'kind': 'work_item',
      'created_at': '2026-10-15T08:00:00Z',
      'title': 'Clear gate 2',
      'quote': {'text': 'Gate 2 is blocked.', 'author_name': 'Rakesh Nair'},
    });
    expect(post.quote?.text, 'Gate 2 is blocked.');
  });

  test('the draft keeps its quote and source on the phone, and isn\'t empty '
      'with only a quote', () {
    const quote = DaybookQuote(text: 'At the gate at 7?', authorName: 'Omar');
    const draft = DaybookPostDraft(
      id: 'd1',
      quote: quote,
      sourceMessageId: 'm2',
    );
    expect(draft.isEmpty, isFalse);
    final back = DaybookPostDraft.fromJson(draft.toJson());
    expect(back.quote?.text, 'At the gate at 7?');
    expect(back.sourceMessageId, 'm2');
    final cleared = back.copyWith(
      quote: () => null,
      sourceMessageId: () => null,
    );
    expect(cleared.quote, isNull);
    expect(cleared.isEmpty, isTrue);
  });

  test('a waiting work item keeps its quote and source until it is sent', () {
    const item = PendingItem(
      id: 'w1',
      spaceId: 's1',
      title: 'Clear gate 2',
      ownerId: 'o1',
      ownerName: 'Rakesh Nair',
      kind: PendingKind.workItem,
      quote: DaybookQuote(text: 'Gate 2 is blocked.'),
      sourceMessageId: 'm2',
    );
    final back = PendingItem.fromJson(item.toJson());
    expect(back.quote?.text, 'Gate 2 is blocked.');
    expect(back.sourceMessageId, 'm2');
    expect(back.copyWith(sent: true).sourceMessageId, 'm2');
    expect(
      DaybookPostDraft.refused(back.copyWith(refused: true)).quote?.text,
      'Gate 2 is blocked.',
    );
  });
}
