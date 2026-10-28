import '../../data/models/post_page.dart';

// How a note's lines sit together (review 93): each line has a level (its
// `indent`, 0 to 3); the lines right after it that are deeper are its
// children. Numbers are worked out here, never kept.

/// Text, to-do, bulleted, numbered and toggle lines hold children; a
/// heading, callout, quote, divider, table or voice note can only be one.
bool holdsChildren(PageBlock b) => switch (b) {
  PageText() || PageTodo() || PageBullet() || PageNumbered() => true,
  PageToggle() => true,
  _ => false,
};

/// The index just after the last of [i]'s children (and theirs).
int subtreeEnd(List<PageBlock> blocks, int i) {
  final level = blocks[i].indent;
  var end = i + 1;
  while (end < blocks.length && blocks[end].indent > level) {
    end++;
  }
  return end;
}

/// How many lines are under [i], at any depth.
int childCount(List<PageBlock> blocks, int i) => subtreeEnd(blocks, i) - i - 1;

/// Every line where it may be: the first at 0; none more than one deeper
/// than the line before, nor deeper than a line that can't hold children;
/// none past [PageBlock.maxIndent]. So a line's children move out one
/// level, in order, when it turns into a kind that can't hold them.
List<PageBlock> normalized(List<PageBlock> blocks) {
  final out = <PageBlock>[];
  for (final b in blocks) {
    final before = out.lastOrNull;
    final most = before == null
        ? 0
        : before.indent + (holdsChildren(before) ? 1 : 0);
    final indent = b.indent.clamp(0, most).clamp(0, PageBlock.maxIndent);
    out.add(indent == b.indent ? b : b.atIndent(indent));
  }
  return out;
}

/// [i] and its children moved [by] levels.
List<PageBlock> _shifted(List<PageBlock> blocks, int i, int by) {
  final end = subtreeEnd(blocks, i);
  return [
    for (final (n, b) in blocks.indexed)
      n >= i && n < end ? b.atIndent(b.indent + by) : b,
  ];
}

/// ⇥: [i] can go one level deeper, under the line before it at its level,
/// when that line holds children and nothing goes past level 3.
bool canIndent(List<PageBlock> blocks, int i) {
  if (i <= 0 || i >= blocks.length) return false;
  final parent = _previousSibling(blocks, i);
  if (parent == null || !holdsChildren(blocks[parent])) return false;
  final deepest = blocks
      .sublist(i, subtreeEnd(blocks, i))
      .fold(0, (m, b) => b.indent > m ? b.indent : m);
  return deepest < PageBlock.maxIndent;
}

/// ⇤: [i] can come out a level.
bool canOutdent(List<PageBlock> blocks, int i) =>
    i >= 0 && i < blocks.length && blocks[i].indent > 0;

/// [i] one level deeper, its children with it.
List<PageBlock> indented(List<PageBlock> blocks, int i) =>
    canIndent(blocks, i) ? normalized(_shifted(blocks, i, 1)) : blocks;

/// [i] one level out, its children with it; the lines after it at its
/// old level become its own (as Notion does).
List<PageBlock> outdented(List<PageBlock> blocks, int i) =>
    canOutdent(blocks, i) ? normalized(_shifted(blocks, i, -1)) : blocks;

/// The line at [i] goes; its children move up one level and stay.
List<PageBlock> withoutLifting(List<PageBlock> blocks, int i) {
  final lifted = _shifted(blocks, i, -1)..removeAt(i);
  return normalized(lifted);
}

/// The line at [i] goes with everything under it.
List<PageBlock> withoutSubtree(List<PageBlock> blocks, int i) =>
    normalized([...blocks]..removeRange(i, subtreeEnd(blocks, i)));

/// [i] and its children moved to stand before [beforeId] (or at the end),
/// at that line's level; null when it would land inside itself.
List<PageBlock>? moved(List<PageBlock> blocks, int i, String? beforeId) {
  final end = subtreeEnd(blocks, i);
  final group = blocks.sublist(i, end);
  if (group.any((b) => b.id == beforeId)) return null;
  final rest = [...blocks]..removeRange(i, end);
  final at = beforeId == null
      ? rest.length
      : rest.indexWhere((b) => b.id == beforeId);
  if (at < 0) return null;
  final by = at < rest.length ? rest[at].indent - group.first.indent : 0;
  final placed = [
    for (final b in group)
      b.atIndent((b.indent + by).clamp(0, PageBlock.maxIndent)),
  ];
  return normalized([...rest.take(at), ...placed, ...rest.skip(at)]);
}

/// Move up (review 98): [i] can go above the line before it at its level
/// under the same parent, and that line's children.
bool canMoveUp(List<PageBlock> blocks, int i) =>
    i > 0 && i < blocks.length && _previousSibling(blocks, i) != null;

/// Move down: a line follows [i]'s group at its level, under its parent.
bool canMoveDown(List<PageBlock> blocks, int i) {
  if (i < 0 || i >= blocks.length) return false;
  final end = subtreeEnd(blocks, i);
  return end < blocks.length && blocks[end].indent == blocks[i].indent;
}

/// [i] and its children above the whole group before them (the line
/// before at its level, with its own children).
List<PageBlock> movedUp(List<PageBlock> blocks, int i) {
  if (!canMoveUp(blocks, i)) return blocks;
  final before = _previousSibling(blocks, i)!;
  return moved(blocks, i, blocks[before].id) ?? blocks;
}

/// [i] and its children below the whole group after them: that group
/// goes up over them instead.
List<PageBlock> movedDown(List<PageBlock> blocks, int i) {
  if (!canMoveDown(blocks, i)) return blocks;
  final next = subtreeEnd(blocks, i);
  return moved(blocks, next, blocks[i].id) ?? blocks;
}

/// Duplicate (review 98): a copy of [i] and its children, right after
/// them, each line (and each of a toggle's own lines) under an id from
/// [newId]. A voice note isn't copied: it is one recording.
bool canDuplicate(List<PageBlock> blocks, int i) =>
    i >= 0 && i < blocks.length && blocks[i] is! PageVoice;

List<PageBlock> duplicated(
  List<PageBlock> blocks,
  int i,
  String Function() newId,
) {
  if (!canDuplicate(blocks, i)) return blocks;
  final end = subtreeEnd(blocks, i);
  final copies = [
    for (final b in blocks.sublist(i, end))
      if (b is! PageVoice) copiedBlock(b, newId),
  ];
  return normalized([...blocks.take(end), ...copies, ...blocks.skip(end)]);
}

/// [b] with new ids, its children's too (Duplicate).
PageBlock copiedBlock(PageBlock b, String Function() newId) {
  Map<String, dynamic> fresh(Map<String, dynamic> json) => {
    ...json,
    'id': newId(),
    if (json['children'] case final List children)
      'children': [for (final c in children) fresh(c as Map<String, dynamic>)],
  };
  return PageBlock.fromJson(fresh(b.toJson()));
}

/// The lines shown while [folded] lines hide what is under them.
List<int> visibleLines(List<PageBlock> blocks, Set<String> folded) {
  final shown = <int>[];
  var i = 0;
  while (i < blocks.length) {
    shown.add(i);
    i = folded.contains(blocks[i].id) ? subtreeEnd(blocks, i) : i + 1;
  }
  return shown;
}

/// The line before [i] at its level under the same parent (children in
/// between skipped), or null when [i] is the first under its parent.
int? _previousSibling(List<PageBlock> blocks, int i) {
  final level = blocks[i].indent;
  for (var j = i - 1; j >= 0; j--) {
    if (blocks[j].indent > level) continue;
    return blocks[j].indent == level ? j : null;
  }
  return null;
}

/// The number a numbered line shows: 1, 2, 3 while numbered lines follow
/// each other at one level under one parent, whatever children stand in
/// between; any other line at that level starts the count again. A line's
/// own `start` begins a new count there.
int numberAt(List<PageBlock> blocks, int i) {
  var count = 0;
  int? j = i;
  while (j != null) {
    final b = blocks[j];
    if (b is! PageNumbered) break;
    if (b.start case final start?) return start + count;
    count++;
    j = _previousSibling(blocks, j);
  }
  return count;
}

/// "Continue numbering (N)": offered on the first line of a list when an
/// earlier list stands at its level under the same parent; N is where it
/// would go on. Null when there is none, or it already goes on there.
int? continueAt(List<PageBlock> blocks, int i) {
  final b = blocks[i];
  if (b is! PageNumbered) return null;
  final before = _previousSibling(blocks, i);
  if (before != null && blocks[before] is PageNumbered) {
    // Inside a list, a restarted line goes on by itself again.
    return b.start == null ? null : numberAt(blocks, before) + 1;
  }
  int? j = before;
  while (j != null && blocks[j] is! PageNumbered) {
    j = _previousSibling(blocks, j);
  }
  if (j == null) return null;
  final n = numberAt(blocks, j) + 1;
  return n == numberAt(blocks, i) || n > PageNumbered.startMax ? null : n;
}

/// What goes in the line's place for Continue: [n], or nothing when the
/// line before is numbered and the count simply goes on.
PageNumbered continued(List<PageBlock> blocks, int i, int n) {
  final b = blocks[i] as PageNumbered;
  final before = _previousSibling(blocks, i);
  final inList = before != null && blocks[before] is PageNumbered;
  return b.startingAt(inList ? null : n);
}

/// A number as its level shows it: 1. 2. 3. → a. b. c. → i. ii. iii. →
/// 1. 2. 3., always in Western digits and Latin letters (the app's rule
/// in Arabic too).
String numberLabel(int n, int level) => switch (level % 3) {
  1 => '${_letters(n)}.',
  2 => '${_roman(n)}.',
  _ => '$n.',
};

/// a … z, then aa, ab …
String _letters(int n) {
  var s = '';
  var k = n;
  while (k > 0) {
    k--;
    s = String.fromCharCode(0x61 + k % 26) + s;
    k ~/= 26;
  }
  return s;
}

String _roman(int n) {
  const marks = [
    (1000, 'm'),
    (900, 'cm'),
    (500, 'd'),
    (400, 'cd'),
    (100, 'c'),
    (90, 'xc'),
    (50, 'l'),
    (40, 'xl'),
    (10, 'x'),
    (9, 'ix'),
    (5, 'v'),
    (4, 'iv'),
    (1, 'i'),
  ];
  var s = '';
  var k = n;
  for (final (value, mark) in marks) {
    while (k >= value) {
      s += mark;
      k -= value;
    }
  }
  return s;
}

/// Whether [i]'s list leaves room for a fold arrow: one of the lines at
/// its level under its parent has children, so every one of them lines up.
bool foldSlot(List<PageBlock> blocks, int i) {
  final level = blocks[i].indent;
  var start = i;
  while (start > 0 && blocks[start - 1].indent >= level) {
    start--;
  }
  for (var j = start; j < blocks.length && blocks[j].indent >= level; j++) {
    if (blocks[j].indent == level && folds(blocks, j)) return true;
  }
  return false;
}

/// Whether [i] shows a fold arrow: a text, to-do, bulleted or numbered
/// line with children (a toggle has its own caret).
bool folds(List<PageBlock> blocks, int i) =>
    holdsChildren(blocks[i]) &&
    blocks[i] is! PageToggle &&
    childCount(blocks, i) > 0;
