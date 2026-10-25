import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_page_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/post_page.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import 'daybook_page.dart' show PageTableView;

/// One choice in a page's block menu ("/" or +): its value, words and
/// icon.
typedef PageMenuItem<T> = ({T value, String label, IconData icon});

/// The block menu (N3): a sheet of rows, each with its icon on a small
/// tile. Work's page and My notebook's note (F107: "/" opens the same
/// list) both use it.
Future<T?> showPageBlockMenu<T>(
  BuildContext context, {
  required String title,
  required List<PageMenuItem<T>> items,
  required String Function(T value) keyOf,
}) => showBvSheet<T>(
  context: context,
  title: title,
  builder: (sheet) => Column(
    key: const Key('page-add-menu'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final a in items)
        BvListRow(
          key: Key('page-add-${keyOf(a.value)}'),
          leading: Container(
            width: BvPageSpec.menuTile,
            height: BvPageSpec.menuTile,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: BvColors.surfaceSubtle,
              borderRadius: BvRadius.smallAll,
            ),
            child: Icon(
              a.icon,
              size: BvSize.iconSm,
              color: BvColors.iconPrimary,
            ),
          ),
          title: a.label,
          trailing: const BvRowTrailing.none(),
          onTap: () => Navigator.of(sheet).pop(a.value),
        ),
    ],
  ),
);

/// The page editor's own part, shared by Work's page (N2–N4,
/// [DaybookPageEditor]) and a note in My notebook (F107, review 92): the
/// blocks with their fields, each on a row with its ⋮⋮ (hold to move, tap
/// for its menu), "/" at the start of an empty line, toggles, tables, and
/// Delete with Undo. Each field keeps its controller and focus node, by
/// key, for the life of the editor, so typing never rebuilds the list.
///
/// The host keeps [editBlocks] and says what its own blocks look like
/// ([hostBlock]) and what a block's ⋮⋮ offers ([blockMenu]).
mixin PageBlockEditing<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  /// The blocks as they are being edited; [collectBlocks] puts the fields'
  /// words back on them.
  List<PageBlock> editBlocks = [];

  final _fields = <String, TextEditingController>{};
  final _focus = <String, FocusNode>{};
  final _keyNodes = <String, FocusNode>{};

  /// Each "/" field's text before its latest change.
  final _lastText = <String, String>{};

  /// The block whose field the cursor was in last (F107: + inserts after
  /// it, and its kind is outlined in the grid).
  String? currentBlockId;

  /// A block's text, at most (Work: validate_blocks' 2,000; a note's 5,000).
  int get blockTextMax;

  /// Something was typed or changed (a note keeps its Draft, F106).
  void blocksEdited() {}

  /// The cursor moved to another block (a note's ⋮⋮ follows it, and the
  /// grid outlines its kind).
  void currentBlockChanged() {}

  /// The block's ⋮⋮ was tapped.
  Future<void> blockMenu(int index);

  /// A block the shared part doesn't draw (Work's points, photos, files
  /// and work items; a note's lines and voice).
  Widget hostBlock(int index, PageBlock block);

  /// "/" at the start of an empty line: [filter] is what follows it; the
  /// line is [replace] (a block's index) or one inside a toggle.
  void slashAt(String filter, {int? replace, (int, String)? intoToggle});

  /// The field under [key]: `t:<id>` a block's words, `c:<id>:<row>:<col>`
  /// a table's cell, `p:<id>` a photo's caption, `pt:<id>` a point.
  TextEditingController blockField(String key, String text) =>
      _fields.putIfAbsent(key, () => TextEditingController(text: text));

  TextEditingController? existingField(String key) => _fields[key];

  /// Takes the field of [key] away (its block went).
  void dropField(String key) => _fields.remove(key)?.dispose();

  /// Every field whose key starts with [prefix].
  Iterable<MapEntry<String, TextEditingController>> fieldsStartingWith(
    String prefix,
  ) => _fields.entries.where((e) => e.key.startsWith(prefix));

  FocusNode blockNode(String key) => _focus.putIfAbsent(key, () {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus) return;
      final id = blockIdOfKey(key);
      if (id == null || id == currentBlockId) return;
      currentBlockId = id;
      currentBlockChanged();
    });
    return node;
  });

  FocusNode? existingNode(String key) => _focus[key];

  /// The block a field's [key] belongs to: a toggle's line is its own.
  static String? blockIdOfKey(String key) {
    final parts = key.split(':');
    return parts.length < 2 ? null : parts[1];
  }

  void focusBlockLater(String key) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => focusBlock(key));

  /// The cursor at the end of [key]'s words, then the focus: a field
  /// focused with no cursor of its own would show its selection handle,
  /// as after a tap.
  void focusBlock(String key) {
    final c = _fields[key];
    if (c != null && !c.selection.isValid) {
      c.selection = TextSelection.collapsed(offset: c.text.length);
    }
    _focus[key]?.requestFocus();
  }

  /// One key listener's node per field, kept and disposed with the editor.
  /// It hears the keys the field's own node gets; it never takes the
  /// focus itself (a sheet closing gives it back to the field).
  FocusNode _keyNode(String key) => _keyNodes.putIfAbsent(
    key,
    () => FocusNode(skipTraversal: true, canRequestFocus: false),
  );

  /// Every field read again from [editBlocks] (the page was read again).
  void resetBlockFields() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _fields.clear();
  }

  void disposeBlockEditing() {
    for (final c in _fields.values) {
      c.dispose();
    }
    for (final f in [..._focus.values, ..._keyNodes.values]) {
      f.dispose();
    }
  }

  /// [b] with the words in its fields.
  PageBlock collectBlock(PageBlock b) {
    String words(String fallback) => _fields['t:${b.id}']?.text ?? fallback;
    return switch (b) {
      PageText(:final text) => PageText(b.id, words(text), indent: b.indent),
      PageHeading(:final text, :final level) => PageHeading(
        b.id,
        words(text),
        level: level,
        indent: b.indent,
      ),
      PageToggle(:final text, :final children) => PageToggle(
        b.id,
        words(text),
        [for (final c in children) collectBlock(c)],
        indent: b.indent,
      ),
      PageTable(:final rows) => PageTable(b.id, [
        for (final (r, row) in rows.indexed)
          [
            for (final (c, text) in row.indexed)
              _fields['c:${b.id}:$r:$c']?.text ?? text,
          ],
      ], indent: b.indent),
      PagePhoto(:final path, :final caption) => PagePhoto(
        b.id,
        path,
        caption: _fields['p:${b.id}']?.text ?? caption,
      ),
      PageLine(:final text) => b.withText(words(text)),
      _ => b,
    };
  }

  /// The words in the fields, back on the blocks.
  List<PageBlock> collectBlocks() => [
    for (final b in editBlocks) collectBlock(b),
  ];

  /// A block's field: bare, growing with its words, in their own
  /// direction. [onSlash]: "/" typed on a line that was empty. [onEnter]:
  /// Enter is a new line of its own (a toggle's, a note's). [onStartBack]:
  /// Backspace with the cursor at the very start (an empty line too).
  Widget blockText(
    String key,
    String text, {
    required TextStyle style,
    required String hint,
    int? maxLength,
    ValueChanged<String>? onSlash,
    VoidCallback? onEnter,
    VoidCallback? onStartBack,
    bool readOnly = false,
  }) {
    final c = blockField(key, text);
    Widget field = TextField(
      key: Key('page-field-$key'),
      controller: c,
      focusNode: blockNode(key),
      readOnly: readOnly,
      maxLines: null,
      // F90: inside a toggle, Enter is a new line of its own.
      textInputAction: onEnter == null ? null : TextInputAction.next,
      onSubmitted: onEnter == null ? null : (_) => onEnter(),
      maxLength: maxLength,
      style: style,
      cursorColor: BvColors.actionPrimary,
      textDirection: c.text.isEmpty ? null : directionOf(c.text),
      decoration: bvBareField(
        hint: hint,
        style: style,
      ).copyWith(counterText: ''),
      onChanged: (v) {
        if (onSlash != null) {
          // Only on a line that was empty: "/" typed before existing
          // words is just a character.
          final was = _lastText[key] ?? text;
          _lastText[key] = v;
          if (v.startsWith('/') && was.isEmpty) {
            onSlash(v.substring(1));
            return;
          }
        }
        blocksEdited();
      },
    );
    if (onStartBack != null) {
      field = KeyboardListener(
        focusNode: _keyNode(key),
        onKeyEvent: (e) {
          final at = c.selection;
          if (e is KeyDownEvent &&
              e.logicalKey == LogicalKeyboardKey.backspace &&
              (c.text.isEmpty || (at.isCollapsed && at.baseOffset == 0))) {
            onStartBack();
          }
        },
        child: field,
      );
    }
    return field;
  }

  /// "/" opened the menu from this line: its "/" goes.
  void clearSlash(String key) {
    _fields[key]?.text = '';
    _lastText[key] = '';
  }

  /// Above each block (Work's page: 12).
  double get blockGap => BvPageSpec.blockGap;

  /// Where the ⋮⋮ is: at the start of every block (Work's page, N2), or
  /// at the end of the block being written only (a note's slip, F107:
  /// its lines start where its title does, as NBX1–NBX4 draw them).
  bool get handleOnlyWhileWriting => false;

  /// The ⋮⋮ shows at all (a note's Draft, read only, has none).
  bool get handlesShown => true;

  /// The ⋮⋮'s height (Work's page: a 44 row; a note's lines are lower).
  double get handleHeight => BvSize.controlMd;

  /// The block at [index] as its row shows it (a note: at its level, with
  /// room for a fold arrow, review 93).
  Widget decorateBlock(int index, PageBlock block, Widget child) => child;

  /// A block on its row: ⋮⋮ (hold to move, tap for its menu), and the
  /// block. [listIndex]: its place among the rows shown, when some are
  /// folded away (a note).
  Widget blockRow(int i, {int? listIndex}) {
    final l10n = AppLocalizations.of(context);
    final b = editBlocks[i];
    final handle = ReorderableDelayedDragStartListener(
      index: listIndex ?? i,
      child: Semantics(
        button: true,
        label: l10n.pageMove,
        hint: l10n.pageBlockMenu,
        child: GestureDetector(
          key: Key('page-handle-${b.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(blockMenu(i)),
          child: SizedBox(
            width: BvPageSpec.handleWidth,
            height: handleHeight,
            child: const Icon(
              BvIcons.dragHandle,
              size: BvPageSpec.handleIcon,
              color: BvColors.iconSecondary,
            ),
          ),
        ),
      ),
    );
    final at = handleOnlyWhileWriting;
    return Padding(
      key: ValueKey('page-edit-${b.id}'),
      padding: EdgeInsetsDirectional.only(top: i == 0 && at ? 0 : blockGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpace.s8,
        children: [
          if (!at && handlesShown) handle,
          Expanded(child: decorateBlock(i, b, blockEditor(i, b))),
          if (at && handlesShown && currentBlockId == b.id) handle,
        ],
      ),
    );
  }

  /// Moves the block at [from] to [to] (a drag on ⋮⋮).
  void moveBlock(int from, int to) {
    editBlocks = collectBlocks();
    setState(() => editBlocks.insert(to, editBlocks.removeAt(from)));
    blocksEdited();
  }

  /// The block at [i], being edited.
  Widget blockEditor(int i, PageBlock b) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    switch (b) {
      case PageText(:final text):
        return blockText(
          't:${b.id}',
          text,
          style: type.bodyMd,
          hint: l10n.pageAddBlock,
          maxLength: blockTextMax,
          // "/" at the start of an empty line: this line becomes the block.
          onSlash: (f) {
            clearSlash('t:${b.id}');
            slashAt(f, replace: i);
          },
          onEnter: textEnter(i),
          onStartBack: textBack(i),
        );
      case PageHeading(:final text, :final level):
        return blockText(
          't:${b.id}',
          text,
          style: level == 1 ? type.titleMd : type.emphasis,
          hint: level == 1 ? l10n.pageHeading : l10n.notebookSubheading,
          maxLength: PageHeading.max,
          onEnter: textEnter(i),
          onStartBack: textBack(i),
        );
      case PageToggle(:final text, :final children):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: BvPageSpec.caretGap,
              children: [
                const Icon(
                  BvIcons.caretDown,
                  size: BvPageSpec.caret,
                  color: BvColors.iconPrimary,
                ),
                Expanded(
                  child: blockText(
                    't:${b.id}',
                    text,
                    style: type.bodyMd,
                    hint: l10n.pageToggle,
                    maxLength: PageToggle.max,
                  ),
                ),
              ],
            ),
            for (final (n, c) in children.indexed)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: BvPageSpec.toggleIndent,
                  top: BvSpace.s8,
                ),
                child: c is PageText
                    ? blockText(
                        't:${c.id}',
                        c.text,
                        style: type.bodyMd,
                        // The last, empty line is ready to type inside.
                        hint: n == children.length - 1 && c.text.isEmpty
                            ? l10n.pageTypeInside
                            : l10n.pageText,
                        maxLength: blockTextMax,
                        onEnter: () => enterInToggle(i, c.id),
                        onSlash: (f) {
                          clearSlash('t:${c.id}');
                          slashAt(f, intoToggle: (i, c.id));
                        },
                      )
                    : hostBlock(i, c),
              ),
          ],
        );
      case PageTable():
        return tableEditor(i, b);
      default:
        return hostBlock(i, b);
    }
  }

  /// Enter on a text line or a heading: Work's page keeps it a new line in
  /// the same block (null); a note starts a block of its own.
  VoidCallback? textEnter(int index) => null;

  /// Backspace on an empty text line or heading: Work's page does nothing
  /// (null); a note takes it out.
  VoidCallback? textBack(int index) => null;

  /// F90: Enter inside a toggle starts a new line after this one; on the
  /// empty last line it leaves the toggle and starts a line after it.
  void enterInToggle(int index, String childId) {
    editBlocks = collectBlocks();
    final t = editBlocks[index] as PageToggle;
    final at = t.children.indexWhere((c) => c.id == childId);
    if (at < 0) return;
    final child = t.children[at];
    final id = newUuid();
    final leave =
        at == t.children.length - 1 &&
        child is PageText &&
        child.text.trim().isEmpty;
    setState(() {
      if (leave) {
        editBlocks.insert(index + 1, PageText(id, ''));
      } else {
        editBlocks[index] = PageToggle(t.id, t.text, [
          ...t.children.take(at + 1),
          PageText(id, ''),
          ...t.children.skip(at + 1),
        ]);
      }
    });
    focusBlockLater('t:$id');
    blocksEdited();
  }

  /// The block at [index] goes, with Undo.
  void deleteBlock(int index) {
    final l10n = AppLocalizations.of(context);
    editBlocks = collectBlocks();
    final gone = editBlocks[index];
    setState(() => editBlocks.removeAt(index));
    blocksEdited();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.pageDeleted),
          action: SnackBarAction(
            key: const Key('page-undo'),
            label: l10n.spacesUndo,
            onPressed: () {
              if (!mounted) return;
              setState(
                () =>
                    editBlocks.insert(index.clamp(0, editBlocks.length), gone),
              );
              blocksEdited();
            },
          ),
        ),
      );
  }

  // Tables --------------------------------------------------------------------

  void editTable(int index, PageTable Function(PageTable t) change) {
    editBlocks = collectBlocks();
    final t = editBlocks[index] as PageTable;
    for (final k in [..._fields.keys]) {
      if (k.startsWith('c:${t.id}:')) _fields.remove(k)?.dispose();
    }
    setState(() => editBlocks[index] = change(t));
    blocksEdited();
  }

  Future<void> _cellMenu(int index, int row, int column) async {
    final l10n = AppLocalizations.of(context);
    final t = collectBlocks()[index] as PageTable;
    final picked = await showBvSheet<int>(
      context: context,
      builder: (sheet) => Column(
        key: const Key('page-cell-menu'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (t.rows.length > 1)
            BvListRow(
              key: const Key('page-delete-row'),
              title: l10n.pageDeleteRow,
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(0),
            ),
          if (t.columns > 1)
            BvListRow(
              key: const Key('page-delete-column'),
              title: l10n.pageDeleteColumn,
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(1),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    editTable(
      index,
      (t) => PageTable(t.id, [
        for (final (r, cells) in t.rows.indexed)
          if (picked != 0 || r != row)
            [
              for (final (c, text) in cells.indexed)
                if (picked != 1 || c != column) text,
            ],
      ]),
    );
  }

  Widget tableEditor(int i, PageTable t) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s4,
      children: [
        PageTableView(
          rows: t.rows,
          cell: (r, c) => GestureDetector(
            onLongPress: () => unawaited(_cellMenu(i, r, c)),
            child: blockText(
              'c:${t.id}:$r:$c',
              t.rows[r][c],
              style: r == 0 ? type.metadata : type.bodySm,
              hint: '',
              maxLength: PageTable.cellMax,
            ),
          ),
        ),
        Wrap(
          children: [
            if (t.rows.length < PageTable.maxRows)
              TextButton.icon(
                key: Key('page-add-row-${t.id}'),
                onPressed: () => editTable(
                  i,
                  (t) =>
                      PageTable(t.id, [...t.rows, List.filled(t.columns, '')]),
                ),
                icon: const Icon(BvIcons.create, size: BvSize.iconSm),
                label: Text(l10n.pageAddRow),
              ),
            if (t.columns < PageTable.maxColumns)
              TextButton.icon(
                key: Key('page-add-column-${t.id}'),
                onPressed: () => editTable(
                  i,
                  (t) => PageTable(t.id, [
                    for (final row in t.rows) [...row, ''],
                  ]),
                ),
                icon: const Icon(BvIcons.create, size: BvSize.iconSm),
                label: Text(l10n.pageAddColumn),
              ),
          ],
        ),
      ],
    );
  }
}
