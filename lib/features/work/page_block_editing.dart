import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_page_specs.dart';
import '../../core/design/daybook_writing_specs.dart' show BvLineMenuSpec;
import '../../core/l10n/bidi.dart';
import '../../data/models/post_page.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_line_popover.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import 'daybook_page.dart' show PageTableView;

/// One choice in a page's block menu ("/" or +): its value, words and
/// icon.
typedef PageMenuItem<T> = ({T value, String label, IconData icon});

/// One kind in the "/" card (review 98): its value, its key's end
/// (`page-add-<key>`), words and icon, the [shortcut] typed for it, and
/// every word that finds it ([words]: its name in English and Arabic, and
/// a few simple ones such as "num", "todo", «مهام»).
typedef PageSlashItem = ({
  Object value,
  String key,
  String label,
  IconData icon,
  String? shortcut,
  List<String> words,
});

/// Whether [item] is found by [filter] (what follows the "/"): one of its
/// words, or a word inside one, starts with it; nothing typed finds all.
/// The app's words in each of its languages: "/" finds a kind by its name
/// in any of them.
final slashLanguages = [
  for (final l in AppLocalizations.supportedLocales) lookupAppLocalizations(l),
];

bool slashMatches(PageSlashItem item, String filter) {
  final f = filter.trim().toLowerCase();
  if (f.isEmpty) return true;
  for (final w in item.words) {
    final word = w.toLowerCase();
    if (word.startsWith(f)) return true;
    if (word.split(RegExp(r'\s+')).any((part) => part.startsWith(f))) {
      return true;
    }
  }
  return false;
}

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

  /// Each field's place, kept when its line changes kind (review 98: a
  /// shortcut, "/" or Turn into moves the field into another row, and it
  /// keeps the keyboard).
  final _fieldPlaces = <String, GlobalKey>{};

  /// Each "/" field's text before its latest change.
  final _lastText = <String, String>{};

  /// The "/" card (review 98): open on [_slashKey]'s field, its "/" at
  /// [_slashAt]; every kind it lists, and those found by what follows.
  final _slashCard = BvLinePopover();
  String? _slashKey;
  var _slashAt = 0;
  var _slashAll = const <PageSlashItem>[];
  var _slashShown = const <PageSlashItem>[];

  /// More than this after the "/" and it was never a kind.
  static const _slashMax = 24;

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

  /// What "/" lists on the field [key] (review 98: at the start of any
  /// line, or after a space); none, and "/" is only a character.
  List<PageSlashItem> slashItems(String key);

  /// [value] picked from "/" on [key]: the "/" and what was typed after it
  /// are already gone from the field.
  void slashPicked(String key, Object value);

  /// A space typed on [key] right after [before], with [after] still on
  /// the line (review 98: "1. " at the start of a text line); true when
  /// the line took it as a shortcut.
  bool typedShortcut(String key, String before, String after) => false;

  /// The line the open line menu is for, tinted (review 98 NBY2).
  String? get markedBlockId => null;

  /// Lines drag on ⋮⋮ only on a wide screen: never on a phone (review 98;
  /// Move up and Move down in the line's menu instead).
  bool get dragsLines =>
      MediaQuery.sizeOf(context).shortestSide >= BvPageSpec.dragMinSide;

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
      if (!node.hasFocus) {
        if (_slashKey == key) closeSlash();
        return;
      }
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

  /// The cursor to [key] now, before the page is drawn again (review 100
  /// B1): the line it leaves never lets go of the focus first, so the
  /// keyboard stays up. A line not drawn yet takes the focus as it comes.
  void focusBlockNow(String key) {
    final c = _fields[key];
    if (c != null && !c.selection.isValid) {
      c.selection = TextSelection.collapsed(offset: c.text.length);
    }
    blockNode(key).requestFocus();
  }

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
    _slashCard.hide();
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
      PageText(:final text) => PageText(
        b.id,
        words(text),
        indent: b.indent,
        folded: b.folded,
      ),
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
  /// direction. [slash]: "/" at the start or after a space opens the "/"
  /// card ([slashItems]). [shortcuts]: a space after "1." and the like at
  /// the start is offered to [typedShortcut]. [onEnter]: Enter is a new
  /// line of its own (a toggle's, a note's). [onStartBack]: Backspace with
  /// the cursor at the very start (an empty line too).
  Widget blockText(
    String key,
    String text, {
    required TextStyle style,
    required String hint,
    int? maxLength,
    bool slash = false,
    bool shortcuts = false,
    VoidCallback? onEnter,
    VoidCallback? onStartBack,
    bool readOnly = false,
  }) {
    final c = blockField(key, text);
    final field = TextField(
      key: Key('page-field-$key'),
      controller: c,
      focusNode: blockNode(key),
      readOnly: readOnly,
      maxLines: null,
      // F90: inside a toggle, Enter is a new line of its own.
      textInputAction: onEnter == null ? null : TextInputAction.next,
      // With the "/" card open, Enter picks its first kind. Enter itself
      // keeps the focus (review 100 B1): Flutter's own "next" would hand it
      // to whatever comes next for a moment, and the keyboard would drop.
      onEditingComplete: onEnter == null ? null : () {},
      onSubmitted: onEnter == null
          ? null
          : (_) => _slashKey == key ? _pickSlash() : onEnter(),
      maxLength: maxLength,
      style: style,
      cursorColor: BvColors.actionPrimary,
      textDirection: c.text.isEmpty ? null : directionOf(c.text),
      decoration: bvBareField(
        hint: hint,
        style: style,
      ).copyWith(counterText: ''),
      onChanged: (v) {
        if (!slash && !shortcuts) {
          blocksEdited();
          return;
        }
        final was = _lastText[key] ?? text;
        _lastText[key] = v;
        if (_slashKey == key) {
          _followSlash(c);
          blocksEdited();
          return;
        }
        // One character typed, just before the cursor.
        final at = c.selection.baseOffset;
        final one = v.length == was.length + 1 && at > 0 && at <= v.length;
        if (one &&
            shortcuts &&
            v[at - 1] == ' ' &&
            typedShortcut(key, v.substring(0, at - 1), v.substring(at))) {
          return;
        }
        if (one &&
            slash &&
            v[at - 1] == '/' &&
            (at == 1 || v[at - 2].trim().isEmpty)) {
          _openSlash(key, at - 1);
        }
        blocksEdited();
      },
    );
    // Always the same widgets around the field, so it can move.
    return KeyedSubtree(
      key: _fieldPlaces.putIfAbsent(key, GlobalKey.new),
      child: KeyboardListener(
        focusNode: _keyNode(key),
        onKeyEvent: (e) {
          if (e is! KeyDownEvent) return;
          // Escape closes the "/" card and leaves the "/" as typed.
          if (e.logicalKey == LogicalKeyboardKey.escape && _slashKey == key) {
            closeSlash();
            return;
          }
          final at = c.selection;
          if (onStartBack != null &&
              e.logicalKey == LogicalKeyboardKey.backspace &&
              (c.text.isEmpty || (at.isCollapsed && at.baseOffset == 0))) {
            onStartBack();
          }
        },
        child: field,
      ),
    );
  }

  /// The field under [key] holds [text], the cursor at [cursor] (a line
  /// that changed under its field, as a shortcut does).
  void setField(String key, String text, int cursor) {
    final c = _fields[key];
    _lastText[key] = text;
    c?.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  // The "/" card ---------------------------------------------------------------

  /// Whether the "/" card is open.
  bool get slashOpen => _slashKey != null;

  /// The kinds the "/" card shows now (the first is Enter's).
  List<PageSlashItem> get slashShown => _slashShown;

  void _openSlash(String key, int at) {
    final items = slashItems(key);
    if (items.isEmpty) return;
    _slashKey = key;
    _slashAt = at;
    _slashAll = items;
    _slashShown = items;
    _slashCard.show(
      context,
      anchor: () => _focus[key]?.context,
      builder: (context) {
        final shown = _slashShown;
        if (shown.isEmpty) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        return BvPopoverMenu<Object>.line(
          key: const Key('page-add-menu'),
          title: l10n.pageSlashTitle,
          hint: l10n.pageSlashEnter,
          scrolls: true,
          selected: shown.first.value,
          items: [
            for (final i in shown)
              BvMenuItem(
                key: Key('page-add-${i.key}'),
                value: i.value,
                label: i.label,
                icon: i.icon,
                shortcut: i.shortcut,
              ),
          ],
          onSelected: _pickSlash,
        );
      },
    );
  }

  /// What follows the "/" filters the card; the cursor before the "/", or
  /// the "/" gone, closes it; so does a space when nothing is found. Enter
  /// on a field that keeps its own lines picks the first kind.
  void _followSlash(TextEditingController c) {
    final v = c.text;
    final at = c.selection.baseOffset;
    if (_slashAt >= v.length || v[_slashAt] != '/' || at <= _slashAt) {
      closeSlash();
      return;
    }
    final filter = v.substring(_slashAt + 1, at);
    if (filter.endsWith('\n')) {
      setField(_slashKey!, v.substring(0, at - 1) + v.substring(at), at - 1);
      _pickSlash();
      return;
    }
    final shown = [
      for (final i in _slashAll)
        if (slashMatches(i, filter)) i,
    ];
    if (shown.isEmpty && (filter.endsWith(' ') || filter.length > _slashMax)) {
      closeSlash();
      return;
    }
    _slashShown = shown;
    _slashCard.rebuild();
  }

  /// [value] picked (the first kind found, with none given): the "/" and
  /// what follows it leave the line, then the host turns it.
  void _pickSlash([Object? value]) {
    final key = _slashKey;
    final picked = value ?? _slashShown.firstOrNull?.value;
    final c = key == null ? null : _fields[key];
    if (key == null || c == null || picked == null) {
      closeSlash();
      return;
    }
    final v = c.text;
    final end = c.selection.baseOffset.clamp(_slashAt + 1, v.length);
    final at = _slashAt;
    setField(key, v.substring(0, at) + v.substring(end), at);
    closeSlash();
    slashPicked(key, picked);
  }

  /// The "/" card closes; what was typed stays.
  void closeSlash() {
    _slashKey = null;
    _slashCard.hide();
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
    final drags = dragsLines;
    Widget handle = Semantics(
      button: true,
      label: drags ? l10n.pageMove : l10n.pageBlockMenu,
      hint: drags ? l10n.pageBlockMenu : null,
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
    );
    if (drags) {
      handle = ReorderableDelayedDragStartListener(
        index: listIndex ?? i,
        child: handle,
      );
    }
    final at = handleOnlyWhileWriting;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BvSpace.s8,
      children: [
        if (!at && handlesShown) handle,
        Expanded(child: decorateBlock(i, b, blockEditor(i, b))),
        if (at && handlesShown && currentBlockId == b.id) handle,
      ],
    );
    return Padding(
      key: ValueKey('page-edit-${b.id}'),
      padding: EdgeInsetsDirectional.only(top: i == 0 && at ? 0 : blockGap),
      child: markedBlockId == b.id
          ? DecoratedBox(
              key: Key('page-marked-${b.id}'),
              decoration: const BoxDecoration(
                color: BvColors.surfaceBrandSoft,
                borderRadius: BvLineMenuSpec.lineRadius,
              ),
              child: row,
            )
          : row,
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
          slash: true,
          shortcuts: true,
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
          slash: true,
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
                        slash: true,
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
    focusBlockNow('t:$id');
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
