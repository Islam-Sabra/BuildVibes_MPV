import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/work/daybook_page_editor.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = '00000000-0000-4000-8000-0000000000a1';
const _b = '00000000-0000-4000-8000-0000000000a2';
const _c = '00000000-0000-4000-8000-0000000000a3';
const _list = '00000000-0000-4000-8000-0000000000b1';

PostPage _page() => PostPage(
  post: DaybookPost(
    id: 'p',
    kind: DaybookPost.workItemKind,
    createdAt: DateTime(2026, 10, 15),
    title: 'Sleeves',
    body: 'Before the pour.',
  ),
  blocks: const [
    PageChecklist(_list, [_a, _b, _c]),
  ],
  points: [
    const DaybookPoint(id: _a, text: 'Sized'),
    DaybookPoint(id: _b, text: 'Photo', tickedAt: DateTime(2026, 10, 15)),
    const DaybookPoint(id: _c, text: 'Sealed'),
  ],
);

void main() {
  test('nothing changed: nothing to send', () {
    final plan = planPageSave(
      _page(),
      blocks: _page().blocks,
      points: {_a: 'Sized', _b: 'Photo', _c: 'Sealed'},
      title: 'Sleeves',
      body: 'Before the pour.',
    );
    expect(plan.before, isEmpty);
    expect(plan.after, isEmpty);
  });

  test('words and a new point go first; a removed point after the blocks, '
      'with the order of what is left', () {
    const added = '00000000-0000-4000-8000-0000000000a9';
    final plan = planPageSave(
      _page(),
      blocks: const [
        PageChecklist(_list, [added, _a, _b]),
      ],
      points: {_a: 'Sized as drawn', _b: 'Photo', added: ' Fire collars '},
      title: 'Sleeves at C7',
      body: 'Before the pour.',
    );
    expect(plan.before, {
      'title': 'Sleeves at C7',
      'points': {
        'add': [
          {'id': added, 'text': 'Fire collars'},
        ],
        'edit': [
          {'id': _a, 'text': 'Sized as drawn'},
        ],
      },
    });
    expect(plan.after, {
      'points': {
        'remove': [_c],
        'order': [added, _a, _b],
      },
    });
  });

  test('a ticked point is never removed and keeps its words', () {
    final plan = planPageSave(
      _page(),
      blocks: const [
        PageChecklist(_list, [_a, _c]),
      ],
      points: {_a: 'Sized', _b: 'changed', _c: 'Sealed'},
      title: 'Sleeves',
      body: 'Before the pour.',
    );
    expect(plan.before, isEmpty);
    // The ticked point keeps its place after the ones shown.
    expect(plan.after, {
      'points': {
        'order': [_a, _c, _b],
      },
    });
  });

  test('empty headings, empty toggles and empty points go; a toggle with '
      'no words gives up what it holds', () {
    const t = '00000000-0000-4000-8000-0000000000c1';
    const h = '00000000-0000-4000-8000-0000000000c2';
    const inside = '00000000-0000-4000-8000-0000000000c3';
    const empty = '00000000-0000-4000-8000-0000000000a8';
    const list2 = '00000000-0000-4000-8000-0000000000b2';
    final plan = planPageSave(
      _page(),
      blocks: const [
        PageChecklist(_list, [_a, _b, _c]),
        PageHeading(h, '  '),
        PageToggle(t, '', [PageText(inside, 'Fire rating.')]),
        PageChecklist(list2, [empty]),
      ],
      points: {_a: 'Sized', _b: 'Photo', _c: 'Sealed', empty: ''},
      title: 'Sleeves',
      body: 'Before the pour.',
    );
    expect([for (final b in plan.blocks) b.type], ['checklist_ref', 'text']);
    expect(plan.before, isEmpty);
  });

  test('review 79 P2: an empty point among others is dropped, never sent; '
      'one whose words were all erased is taken off the post', () {
    const empty = '00000000-0000-4000-8000-0000000000a9';
    final plan = planPageSave(
      _page(),
      blocks: const [
        PageChecklist(_list, [_a, empty, _b, _c]),
      ],
      points: {_a: 'Sized', empty: '  ', _b: 'Photo', _c: ' '},
      title: 'Sleeves',
      body: 'Before the pour.',
    );
    expect((plan.blocks.single as PageChecklist).pointIds, [_a, _b]);
    expect(plan.before, isEmpty);
    expect(plan.after, {
      'points': {
        'remove': [_c],
        'order': [_a, _b],
      },
    });
  });

  test('ids the page made up for what had no block get real ones', () {
    final shown = PostPage(post: _page().post, points: _page().points).shown;
    expect(shown.single.id, isNot(matches(RegExp(r'^[0-9a-f-]{36}$'))));
    final real = withRealIds(shown);
    expect(real.single.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect((real.single as PageChecklist).pointIds, [_a, _b, _c]);
  });

  test('the block menu offers points and work items only where they go', () {
    DaybookPost post(String kind) =>
        DaybookPost(id: 'p', kind: kind, createdAt: DateTime(2026), title: 't');
    expect(pageAdds(post(DaybookPost.workItemKind)), PageAdd.values);
    expect(
      pageAdds(post(DaybookPost.checklistKind)),
      isNot(contains(PageAdd.item)),
    );
    final note = pageAdds(post(DaybookPost.noteKind));
    expect(note, isNot(contains(PageAdd.checklist)));
    expect(note, isNot(contains(PageAdd.item)));
  });
  test('a photo or Library file the page no longer shows leaves the post '
      'after the blocks; a PDF the page never showed stays', () {
    final page = PostPage(
      post: _page().post,
      blocks: const [
        PagePhoto('00000000-0000-4000-8000-0000000000c1', 'kct/posts/p/1.jpg'),
        PageFile('00000000-0000-4000-8000-0000000000c2', 'lib-1'),
      ],
      files: const [
        PageFileRow(id: 'f1', mime: 'image/jpeg', path: 'kct/posts/p/1.jpg'),
        PageFileRow(id: 'f2', mime: 'application/pdf', libraryFileId: 'lib-1'),
        PageFileRow(
          id: 'f3',
          mime: 'application/pdf',
          path: 'kct/posts/p/3.pdf',
        ),
      ],
    );
    final plan = planPageSave(
      page,
      blocks: [page.blocks.last],
      points: const {},
      title: 'Sleeves',
      body: 'Before the pour.',
    );
    expect(plan.after['remove_files'], ['f1']);
    expect(plan.before, isEmpty);
  });

  test('a work item under another one offers no work item under it (one '
      'level only)', () {
    final under = DaybookPost(
      id: 'p',
      kind: DaybookPost.workItemKind,
      createdAt: DateTime(2026),
      title: 't',
      parentId: 'parent',
    );
    expect(pageAdds(under), isNot(contains(PageAdd.item)));
    expect(mayHaveItemsUnder(under), isFalse);
  });
}
