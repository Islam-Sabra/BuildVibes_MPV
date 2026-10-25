// Review 93: how a note's lines sit together: levels, numbering by level,
// Continue and Restart, folding, and moving, turning and deleting with
// the children kept.
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_outline.dart';
import 'package:flutter_test/flutter_test.dart';

String _id(int n) => 'a0000000-0000-4000-8000-${'$n'.padLeft(12, '0')}';

PageNumbered _n(int id, {int indent = 0, int? start}) =>
    PageNumbered(_id(id), 'n$id', indent: indent, start: start);

PageText _t(int id, {int indent = 0}) =>
    PageText(_id(id), 't$id', indent: indent);

/// The labels the numbered lines show, in order ('' for the others).
List<String> _labels(List<PageBlock> blocks) => [
  for (final (i, b) in blocks.indexed)
    b is PageNumbered ? numberLabel(numberAt(blocks, i), b.indent) : '',
];

List<int> _levels(List<PageBlock> blocks) => [for (final b in blocks) b.indent];

void main() {
  group("the founder's case", () {
    test('1, 2, a callout, then a numbered line starts again at 1; Continue '
        'numbering (3) gives 3', () {
      final blocks = <PageBlock>[
        _n(1),
        _n(2),
        PageCallout(_id(3), 'Rain expected'),
        _n(4),
      ];
      expect(_labels(blocks), ['1.', '2.', '', '1.']);
      expect(continueAt(blocks, 3), 3);
      final goneOn = [...blocks]..[3] = continued(blocks, 3, 3);
      expect((goneOn[3] as PageNumbered).start, 3);
      expect(_labels(goneOn), ['1.', '2.', '', '3.']);
      // Already going on: offered no more.
      expect(continueAt(goneOn, 3), isNull);
    });

    test('the callout under 2 is its child: the next item is 3 by itself, '
        'and Continue is not offered', () {
      final blocks = <PageBlock>[
        _n(1),
        _n(2),
        PageCallout(_id(3), 'Rain expected', indent: 1),
        _n(4),
      ];
      expect(_labels(blocks), ['1.', '2.', '', '3.']);
      expect(continueAt(blocks, 3), isNull);
    });

    test('Restart at 1 starts a new count mid-list; Continue then puts it '
        'back', () {
      final blocks = <PageBlock>[_n(1), _n(2), _n(3, start: 1), _n(4)];
      expect(_labels(blocks), ['1.', '2.', '1.', '2.']);
      expect(continueAt(blocks, 2), 3);
      final back = [...blocks]..[2] = continued(blocks, 2, 3);
      expect((back[2] as PageNumbered).start, isNull);
      expect(_labels(back), ['1.', '2.', '3.', '4.']);
    });

    test('a list with no earlier list is offered no Continue', () {
      expect(continueAt([_t(1), _n(2)], 1), isNull);
      expect(continueAt([_n(1), _n(2)], 1), isNull);
    });
  });

  group('numbering by level', () {
    test('1. → a. → i. → 1., children never break the count', () {
      final blocks = <PageBlock>[
        _n(1),
        _n(2, indent: 1),
        _n(3, indent: 1),
        _n(4, indent: 2),
        _n(5, indent: 3),
        _n(6, indent: 1),
        _n(7),
      ];
      expect(_labels(blocks), ['1.', 'a.', 'b.', 'i.', '1.', 'c.', '2.']);
    });

    test('a count under another parent starts again', () {
      final blocks = <PageBlock>[
        _n(1),
        _n(2, indent: 1),
        _n(3),
        _n(4, indent: 1),
      ];
      expect(_labels(blocks), ['1.', 'a.', '2.', 'a.']);
    });

    test('the labels: letters after z go on as aa; roman numerals', () {
      expect(numberLabel(3, 0), '3.');
      expect(numberLabel(1, 1), 'a.');
      expect(numberLabel(26, 1), 'z.');
      expect(numberLabel(27, 1), 'aa.');
      expect(numberLabel(4, 2), 'iv.');
      expect(numberLabel(14, 2), 'xiv.');
      expect(numberLabel(2, 3), '2.');
    });
  });

  group('levels', () {
    test('every line where it may be: the first at 0, none more than one '
        'deeper, none under a line that cannot hold children', () {
      final blocks = normalized([
        _t(1, indent: 2),
        _t(2, indent: 3),
        PageHeading(_id(3), 'H', indent: 1),
        _t(4, indent: 2),
        _t(5, indent: 3),
      ]);
      expect(_levels(blocks), [0, 1, 1, 1, 2]);
    });

    test('⇥ needs a line before it at its level that holds children; ⇤ '
        'needs a level to come out of', () {
      final blocks = <PageBlock>[_n(1), _n(2), PageHeading(_id(3), 'H'), _t(4)];
      expect(canIndent(blocks, 0), isFalse);
      expect(canIndent(blocks, 1), isTrue);
      expect(canIndent(blocks, 3), isFalse, reason: 'a heading holds none');
      expect(canOutdent(blocks, 1), isFalse);
      final deeper = indented(blocks, 1);
      expect(_levels(deeper), [0, 1, 0, 0]);
      expect(canOutdent(deeper, 1), isTrue);
      expect(canIndent(deeper, 1), isFalse, reason: 'the first child');
      expect(_levels(outdented(deeper, 1)), [0, 0, 0, 0]);
    });

    test('⇥ and ⇤ take the children; nothing goes past level 3', () {
      final blocks = <PageBlock>[
        _n(1),
        _n(2),
        _n(3, indent: 1),
        _n(4, indent: 2),
        _n(5, indent: 3),
      ];
      expect(canIndent(blocks, 1), isFalse, reason: 'level 4 under it');
      expect(_levels(indented(blocks, 1)), _levels(blocks));
      expect(_levels(indented([_n(1), _n(2), _n(3, indent: 1)], 1)), [0, 1, 2]);
      final out = outdented([_n(1), _n(2, indent: 1), _n(3, indent: 2)], 1);
      expect(_levels(out), [0, 0, 1]);
    });
  });

  group('turn, move and delete keep the children', () {
    test('turned into a heading, the children come out one level, right '
        'below it, and nothing is lost', () {
      final blocks = <PageBlock>[
        _n(1),
        _n(2, indent: 1),
        _n(3, indent: 2),
        _t(4),
      ];
      final turned = normalized([...blocks]..[0] = PageHeading(_id(1), 'n1'));
      expect([for (final b in turned) b.id], [for (final b in blocks) b.id]);
      expect(_levels(turned), [0, 0, 1, 0]);
    });

    test('a line moves with its children, to the level it lands at, and '
        'both lists count again', () {
      final blocks = <PageBlock>[
        _n(1),
        _n(2, indent: 1),
        _n(3),
        _n(4),
        _t(5),
        _n(6),
      ];
      final after = moved(blocks, 0, _id(6))!;
      expect(
        [for (final b in after) b.id],
        [_id(3), _id(4), _id(5), _id(1), _id(2), _id(6)],
      );
      expect(_labels(after), ['1.', '2.', '', '1.', 'a.', '2.']);
      // Into the middle of a sub-list: at that level.
      final inner = moved([_n(1), _n(2, indent: 1), _n(3)], 2, _id(2))!;
      expect([for (final b in inner) b.id], [_id(1), _id(3), _id(2)]);
      expect(_levels(inner), [0, 1, 1]);
      // Never into itself.
      expect(moved(blocks, 0, _id(2)), isNull);
    });

    test('a deleted line lifts its children one level; a whole subtree '
        'goes only when asked', () {
      final blocks = <PageBlock>[
        _n(1),
        _n(2, indent: 1),
        _n(3, indent: 2),
        _n(4),
      ];
      final lifted = withoutLifting(blocks, 0);
      expect([for (final b in lifted) b.id], [_id(2), _id(3), _id(4)]);
      expect(_levels(lifted), [0, 1, 0]);
      expect(childCount(blocks, 0), 2);
      expect([for (final b in withoutSubtree(blocks, 0)) b.id], [_id(4)]);
    });
  });

  group('folding', () {
    test('a folded line hides its children; the count goes on unchanged', () {
      final blocks = <PageBlock>[
        _n(1),
        _n(2, indent: 1),
        _n(3, indent: 2),
        _n(4),
      ];
      expect(visibleLines(blocks, {}), [0, 1, 2, 3]);
      expect(visibleLines(blocks, {_id(1)}), [0, 3]);
      expect(visibleLines(blocks, {_id(2)}), [0, 1, 3]);
      expect(_labels(blocks).last, '2.');
      expect(folds(blocks, 0), isTrue);
      expect(folds(blocks, 3), isFalse);
      // Its siblings leave room for the arrow, so they line up.
      expect(foldSlot(blocks, 3), isTrue);
      expect(foldSlot([_n(1), _n(2)], 0), isFalse);
    });
  });

  group('kept in the note', () {
    test('level and start are kept; level 0 and no start are left out; an '
        'old note has none', () {
      final line = PageNumbered(_id(1), 'Pour', indent: 2, start: 3);
      expect(line.toJson(), {
        'id': _id(1),
        'type': 'numbered',
        'text': 'Pour',
        'indent': 2,
        'start': 3,
      });
      final back = PageBlock.fromJson(line.toJson()) as PageNumbered;
      expect((back.indent, back.start), (2, 3));
      expect(_t(2).toJson().containsKey('indent'), isFalse);
      expect(PageBlock.fromJson({'id': _id(3), 'type': 'todo'}).indent, 0);
      // Out of range from elsewhere: kept within bounds.
      final odd = PageBlock.fromJson({
        'id': _id(4),
        'type': 'numbered',
        'indent': 9,
        'start': 0,
      });
      expect((odd.indent, (odd as PageNumbered).start), (3, null));
      // A fold is kept only when folded, and on the kinds that fold.
      final shut = PageBlock.fromJson(
        PageBullet(_id(6), 'b', folded: true).toJson(),
      );
      expect(shut.folded, isTrue);
      expect(_t(7).withFolded(true).toJson()['folded'], isTrue);
      expect(_t(8).toJson().containsKey('folded'), isFalse);
      expect(PageCallout(_id(9), 'c').withFolded(true).folded, isFalse);
      expect(_n(10).withFolded(true).atIndent(1).folded, isTrue);
      // A heading's own level is its size, apart from its indent.
      final h = PageBlock.fromJson({
        'id': _id(5),
        'type': 'heading',
        'level': 2,
        'indent': 1,
      });
      expect(((h as PageHeading).level, h.indent), (2, 1));
    });
  });
}
