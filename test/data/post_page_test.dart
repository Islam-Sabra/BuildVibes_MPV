import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _page({List<Object?> blocks = const []}) => {
  'id': 'post-1',
  'kind': 'work_item',
  'created_at': '2026-10-15T05:14:00Z',
  'title': 'Sleeves at grid C7 before the pour',
  'has_page': blocks.isNotEmpty,
  'blocks': blocks,
  'blocks_version': 3,
  'point_list': [
    {'id': 'pt-1', 'text': 'Sleeves sized as the drawing', 'ticked_at': null},
    {
      'id': 'pt-2',
      'text': 'Photo of each sleeve',
      'ticked_at': '2026-10-15T07:00:00Z',
    },
  ],
  'files': [
    {'id': 'f-1', 'path': 'kct/posts/post-1/a.jpg', 'mime': 'image/jpeg'},
    {
      'id': 'f-2',
      'library_file_id': 'lib-1',
      'mime': 'application/pdf',
      'name': 'M-201 Rev C.pdf',
    },
  ],
  'under': [
    {
      'id': 'c-1',
      'title': 'Core the slab at C8',
      'item_status': 'checked',
      'status': 'live',
      'owner_id': 'p-sara',
      'owner_name': 'Sara Al-Mutairi',
    },
  ],
};

void main() {
  test('every kind of block reads and writes back as it came', () {
    final blocks = [
      {'id': 'b1', 'type': 'text', 'text': 'Fix them before the pour.'},
      {'id': 'b2', 'type': 'heading', 'text': 'Sizes', 'level': 2},
      {
        'id': 'b3',
        'type': 'toggle',
        'text': 'Why the sizes matter',
        'children': [
          {'id': 'b4', 'type': 'text', 'text': 'Fire rating.'},
        ],
      },
      {
        'id': 'b5',
        'type': 'table',
        'rows': [
          ['Grid', 'Size'],
          ['C7', '100 mm'],
        ],
      },
      {
        'id': 'b6',
        'type': 'photo',
        'path': 'kct/posts/post-1/a.jpg',
        'caption': 'C7',
      },
      {'id': 'b7', 'type': 'file', 'library_file_id': 'lib-1'},
      {
        'id': 'b8',
        'type': 'checklist_ref',
        'point_ids': ['pt-1', 'pt-2'],
      },
      {'id': 'b9', 'type': 'child_item', 'post_id': 'c-1'},
      {'id': 'b10', 'type': 'item_ref', 'post_id': 'x'},
    ];
    final page = PostPage.fromJson(_page(blocks: blocks));
    expect(page.version, 3);
    expect(page.post.hasPage, isTrue);
    expect([for (final b in page.blocks) b.toJson()], blocks);
    expect(page.blocks.last, isA<PageOtherBlock>());
    expect((page.blocks[1] as PageHeading).level, 2);
    expect((page.blocks[3] as PageTable).columns, 2);
    // Everything the post holds is on a block: nothing added after them.
    expect(page.shown.length, blocks.length);
  });

  test('a post with no page shows its points, photos, files and work items '
      'under it', () {
    final page = PostPage.fromJson(_page());
    expect(page.post.hasPage, isFalse);
    final shown = page.shown;
    expect(
      [for (final b in shown) b.type],
      [PageChecklist.kind, PagePhoto.kind, PageFile.kind, PageChildItem.kind],
    );
    expect((shown.first as PageChecklist).pointIds, ['pt-1', 'pt-2']);
    expect(page.points.last.ticked, isTrue);
    expect(page.under.single.status, WorkStatus.checked);
  });

  test('a point no block shows yet comes after the blocks', () {
    final page = PostPage.fromJson(
      _page(
        blocks: [
          {
            'id': 'b8',
            'type': 'checklist_ref',
            'point_ids': ['pt-1'],
          },
        ],
      ),
    );
    final loose = page.shown.whereType<PageChecklist>().toList();
    expect(
      [for (final c in loose) c.pointIds],
      [
        ['pt-1'],
        ['pt-2'],
      ],
    );
  });

  test('a file post has no page', () {
    final json = _page()..['kind'] = 'file';
    expect(PostPage.fromJson(json).hasPage, isFalse);
  });
}
