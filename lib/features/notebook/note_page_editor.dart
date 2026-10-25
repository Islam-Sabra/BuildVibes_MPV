import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart' show BvStroke;
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/design/planning_specs.dart';
import '../../data/models/note.dart';
import '../../data/models/post_page.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import '../chat/voice.dart' show VoiceNote;
import '../work/daybook_page_editor.dart' show withReadyToggles;
import '../work/page_block_editing.dart';
import 'note_outline.dart';

/// What a note's line can be (F107 NBX2 2619:36808): the categories grid's
/// twelve tiles, in its order, and what "/" lists.
enum NoteBlockKind {
  text,
  heading,
  subheading,
  todo,
  bullets,
  numbers,
  toggle,
  table,
  callout,
  quote,
  divider,
  voice;

  /// The kinds a line's words can be turned into (⋮⋮ → Turn into).
  static const words = [
    text,
    heading,
    subheading,
    todo,
    bullets,
    numbers,
    callout,
    quote,
  ];

  String label(AppLocalizations l10n) => switch (this) {
    text => l10n.pageText,
    heading => l10n.pageHeading,
    subheading => l10n.notebookSubheading,
    todo => l10n.notebookTodoList,
    bullets => l10n.notebookBullets,
    numbers => l10n.notebookNumbers,
    toggle => l10n.pageToggle,
    table => l10n.pageTable,
    callout => l10n.notebookCallout,
    quote => l10n.notebookQuote,
    divider => l10n.notebookDivider,
    voice => l10n.notebookVoice,
  };

  IconData get icon => switch (this) {
    text => BvIcons.textBlock,
    heading => BvIcons.headingOne,
    subheading => BvIcons.headingTwo,
    todo => BvIcons.todoList,
    bullets => BvIcons.bulletList,
    numbers => BvIcons.numberList,
    toggle => BvIcons.caretForward,
    table => BvIcons.tableBlock,
    callout => BvIcons.info,
    quote => BvIcons.quote,
    divider => BvIcons.divider,
    voice => BvIcons.microphone,
  };

  /// The kind [b] is.
  static NoteBlockKind of(PageBlock b) => switch (b) {
    PageHeading(:final level) => level == 2 ? subheading : heading,
    PageTodo() => todo,
    PageBullet() => bullets,
    PageNumbered() => numbers,
    PageToggle() => toggle,
    PageTable() => table,
    PageCallout() => callout,
    PageQuote() => quote,
    PageDivider() => divider,
    PageVoice() => voice,
    _ => text,
  };
}

/// [b]'s words, when it has a line of them.
String? lineWords(PageBlock b) => switch (b) {
  PageText(:final text) ||
  PageHeading(:final text) ||
  PageLine(:final text) => text,
  _ => null,
};

/// A line of [kind] with [words], under [id], at [indent]; null for a kind
/// that isn't a line (a table, a divider, a voice note).
PageBlock? lineOf(
  NoteBlockKind kind,
  String id,
  String words, {
  int indent = 0,
}) => switch (kind) {
  NoteBlockKind.text => PageText(id, words, indent: indent),
  NoteBlockKind.heading => PageHeading(id, words, indent: indent),
  NoteBlockKind.subheading => PageHeading(id, words, level: 2, indent: indent),
  NoteBlockKind.todo => PageTodo(id, words, indent: indent),
  NoteBlockKind.bullets => PageBullet(id, words, indent: indent),
  NoteBlockKind.numbers => PageNumbered(id, words, indent: indent),
  NoteBlockKind.callout => PageCallout(id, words, indent: indent),
  NoteBlockKind.quote => PageQuote(id, words, indent: indent),
  NoteBlockKind.toggle => PageToggle(id, words, [
    PageText(newUuid(), ''),
  ], indent: indent),
  _ => null,
};

/// [b] with other [words], when it has a line of them.
PageBlock? withWords(PageBlock b, String words) => switch (b) {
  PageText() => PageText(b.id, words, indent: b.indent),
  PageHeading(:final level) => PageHeading(
    b.id,
    words,
    level: level,
    indent: b.indent,
  ),
  PageLine() => b.withText(words),
  _ => null,
};

/// A note's page being written in its slip (F107, review 92): the bold
/// title, then the blocks on Work's page editor (PageBlockEditing): "/"
/// at the start of an empty line, ⋮⋮ on the line being written (hold to
/// move, tap to turn it into another kind or delete it), toggles and
/// tables. Enter starts the next line: a to-do, a bullet or a number goes
/// on as one, and an empty one steps out a level, then turns back into
/// text; Backspace at the start of a line turns it into text, then joins
/// it to the line above. The categories grid inserts through
/// [NotePageEditorState.insertKind].
///
/// Review 93: lines sit under each other (note_outline.dart), moved with
/// ⇥ ⇤ on the bar ([NotePageEditorState.indentCurrent]); a line with
/// children folds; numbered lines count by level; moving, turning and
/// deleting keep the children.
///
/// Read only while not [writing] (the Draft, NBW5).
class NotePageEditor extends ConsumerStatefulWidget {
  const NotePageEditor({
    super.key,
    required this.title,
    required this.blocks,
    required this.writing,
    required this.onTitleChanged,
    required this.onChanged,
    this.onCurrentKind,
    this.titleFocus,
  });

  final String title;
  final List<PageBlock> blocks;
  final bool writing;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<List<PageBlock>> onChanged;

  /// The kind of the line the cursor is in, each time it changes (the
  /// grid outlines it).
  final ValueChanged<NoteBlockKind>? onCurrentKind;

  /// The title's focus: the keyboard comes up on it.
  final FocusNode? titleFocus;

  @override
  ConsumerState<NotePageEditor> createState() => NotePageEditorState();
}

class NotePageEditorState extends ConsumerState<NotePageEditor>
    with PageBlockEditing<NotePageEditor> {
  /// The block menu's Delete, Continue numbering, Restart at 1 and Turn into.
  static const _delete = #delete;
  static const _continue = #goOn;
  static const _restart = #restart;
  static const _turnInto = #turnInto;

  late final _title = TextEditingController(text: widget.title);

  /// The lines folded shut, by id (while the note is open).
  final _folded = <String>{};

  @override
  int get blockTextMax => Note.lineMax;

  @override
  double get blockGap => BvNoteBlocksSpec.blockGap;

  @override
  bool get handleOnlyWhileWriting => true;

  @override
  bool get handlesShown => widget.writing;

  @override
  double get handleHeight => BvNoteBlocksSpec.handleHeight;

  @override
  void initState() {
    super.initState();
    editBlocks = normalized(
      withReadyToggles(
        widget.blocks.isEmpty ? [PageText(newUuid(), '')] : [...widget.blocks],
      ),
    );
    // The note opens folded as it was left.
    for (final (i, b) in editBlocks.indexed) {
      if (b.folded && folds(editBlocks, i)) _folded.add(b.id);
    }
  }

  /// The page as [blocks], put where its lines may be; a fold with
  /// nothing left under it opens.
  void _set(List<PageBlock> blocks) {
    setState(() {
      editBlocks = normalized(blocks);
      _folded.removeWhere((id) {
        final at = editBlocks.indexWhere((b) => b.id == id);
        return at < 0 || !folds(editBlocks, at);
      });
    });
    blocksEdited();
    widget.onCurrentKind?.call(currentKind);
  }

  @override
  void dispose() {
    _title.dispose();
    disposeBlockEditing();
    super.dispose();
  }

  @override
  void blocksEdited() => widget.onChanged(_kept());

  /// Toggles' ready lines aren't kept; each line keeps whether it is
  /// folded (only a line with children is).
  List<PageBlock> _kept() {
    final blocks = collectBlocks();
    return [
      for (final (i, b) in blocks.indexed)
        if (b case PageToggle(:final text, :final children))
          PageToggle(b.id, text, [
            for (final c in children)
              if (!(c is PageText && c.text.isEmpty)) c,
          ], indent: b.indent)
        else
          b.withFolded(_folded.contains(b.id) && folds(blocks, i)),
    ];
  }

  @override
  void currentBlockChanged() {
    if (!mounted) return;
    setState(() {});
    widget.onCurrentKind?.call(currentKind);
  }

  /// The kind of the line the cursor is in (Text when it is in none).
  NoteBlockKind get currentKind {
    final b = editBlocks.where((b) => b.id == currentBlockId).firstOrNull;
    return b == null ? NoteBlockKind.text : NoteBlockKind.of(b);
  }

  int get _current {
    final at = editBlocks.indexWhere((b) => b.id == currentBlockId);
    return at < 0 ? editBlocks.length - 1 : at;
  }

  /// The line the cursor is in, on the page itself (not inside a toggle).
  int? get _here {
    final at = editBlocks.indexWhere((b) => b.id == currentBlockId);
    return at < 0 ? null : at;
  }

  /// ⇥ and ⇤ on the bar: the line the cursor is in can go deeper, or out.
  bool get canIndentCurrent =>
      widget.writing && _here != null && canIndent(editBlocks, _here!);
  bool get canOutdentCurrent =>
      widget.writing && _here != null && canOutdent(editBlocks, _here!);

  /// ⇥: the line the cursor is in goes under the line before it, its
  /// children with it.
  void indentCurrent() {
    final at = _here;
    if (at == null) return;
    editBlocks = collectBlocks();
    _set(indented(editBlocks, at));
    focusCurrent();
  }

  /// ⇤: the line the cursor is in comes out a level.
  void outdentCurrent() {
    final at = _here;
    if (at != null) _outdent(at);
    focusCurrent();
  }

  void _outdent(int index) {
    editBlocks = collectBlocks();
    _set(outdented(editBlocks, index));
  }

  /// A fold arrow tapped: the lines under [id] hide or show, and the note
  /// keeps it.
  void _fold(String id) {
    setState(() => _folded.contains(id) ? _folded.remove(id) : _folded.add(id));
    blocksEdited();
  }

  /// The field a block's cursor goes to.
  static String _focusKey(PageBlock b) => switch (b) {
    PageTable() => 'c:${b.id}:0:0',
    _ => 't:${b.id}',
  };

  /// The keyboard back on the line being written (the grid closed).
  void focusCurrent() {
    final b = editBlocks.isEmpty ? null : editBlocks[_current];
    if (b == null || b is PageDivider || b is PageVoice) {
      _title.selection = TextSelection.collapsed(offset: _title.text.length);
      widget.titleFocus?.requestFocus();
      return;
    }
    focusBlock(_focusKey(b));
  }

  /// A tile in the grid (NBX2): an empty line turns into [kind]; otherwise
  /// the new block goes after the line being written and the lines under
  /// it, at its level (review 93: a numbered line right under a numbered
  /// list goes on with its count). The keyboard comes back on it.
  void insertKind(NoteBlockKind kind) {
    editBlocks = collectBlocks();
    final at = _current;
    final here = editBlocks.isEmpty ? null : editBlocks[at];
    final words = here == null ? null : lineWords(here);
    final empty =
        here != null && words != null && words.isEmpty && here is! PageToggle;
    final level = here?.indent ?? 0;
    // A new id even for the empty line it turns: a fresh field takes the
    // keyboard, with nothing of the "/" typed there.
    final id = newUuid();
    final block =
        lineOf(kind, id, '', indent: level) ??
        switch (kind) {
          NoteBlockKind.table => PageTable(id, const [
            ['', ''],
            ['', ''],
          ], indent: level),
          _ => PageDivider(id, indent: level),
        };
    final next = block is PageDivider
        ? PageText(newUuid(), '', indent: level)
        : null;
    final blocks = [...editBlocks];
    if (empty) {
      dropField('t:${here.id}');
      blocks[at] = block;
    } else {
      blocks.insert(here == null ? 0 : subtreeEnd(blocks, at), block);
    }
    if (next != null) blocks.insert(blocks.indexOf(block) + 1, next);
    final focus = next ?? block;
    currentBlockId = focus.id;
    _set(blocks);
    focusBlockLater(_focusKey(focus));
  }

  /// A voice note, recorded: a block after the line being written, at its
  /// level.
  void insertVoice(PageVoice voice) {
    editBlocks = collectBlocks();
    final at = _current;
    final here = editBlocks.isEmpty ? null : editBlocks[at];
    final blocks = [...editBlocks];
    final placed = voice.atIndent(here?.indent ?? 0);
    if (here is PageText && here.text.isEmpty && blocks.length > 1) {
      blocks[at] = placed;
    } else {
      blocks.insert(here == null ? 0 : subtreeEnd(blocks, at), placed);
    }
    _set(blocks);
  }

  @override
  void slashAt(String filter, {int? replace, (int, String)? intoToggle}) =>
      unawaited(_slash(filter, replace: replace, intoToggle: intoToggle));

  /// "/" (NBX2's "or type /"): the same list as Work's page, with a
  /// note's kinds.
  Future<void> _slash(
    String filter, {
    int? replace,
    (int, String)? intoToggle,
  }) async {
    final l10n = AppLocalizations.of(context);
    final f = filter.toLowerCase();
    final kinds = [
      for (final k in NoteBlockKind.values)
        if (k != NoteBlockKind.voice &&
            (intoToggle == null ||
                (k != NoteBlockKind.toggle && k != NoteBlockKind.table)) &&
            (f.isEmpty || k.label(l10n).toLowerCase().startsWith(f)))
          k,
    ];
    if (kinds.isEmpty) return;
    final picked = await showPageBlockMenu<NoteBlockKind>(
      context,
      title: l10n.notebookCategories,
      items: [
        for (final k in kinds) (value: k, label: k.label(l10n), icon: k.icon),
      ],
      keyOf: (k) => k.name,
    );
    if (picked == null || !mounted) return;
    if (intoToggle != null) {
      _intoToggle(intoToggle, picked);
      return;
    }
    if (replace != null) currentBlockId = editBlocks[replace].id;
    insertKind(picked);
  }

  /// A kind picked on a toggle's line: that line turns into it.
  void _intoToggle((int, String) where, NoteBlockKind kind) {
    final (index, childId) = where;
    editBlocks = collectBlocks();
    final t = editBlocks[index] as PageToggle;
    final block = lineOf(kind, childId, '') ?? PageDivider(childId);
    dropField('t:$childId');
    setState(
      () => editBlocks[index] = PageToggle(t.id, t.text, [
        for (final c in t.children) c.id == childId ? block : c,
      ]),
    );
    if (block is! PageDivider) focusBlockLater('t:$childId');
    blocksEdited();
  }

  @override
  Future<void> blockMenu(int index) async {
    final l10n = AppLocalizations.of(context);
    editBlocks = collectBlocks();
    final b = editBlocks[index];
    final words = lineWords(b);
    final now = NoteBlockKind.of(b);
    // Review 93: on one screen, Continue numbering (when it applies),
    // Restart at 1 (a numbered line), Turn into › (the kinds on a sheet of
    // their own), then Delete.
    final goOn = continueAt(editBlocks, index);
    final picked = await showBvSheet<Object>(
      context: context,
      builder: (sheet) => Column(
        key: const Key('page-block-menu'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (goOn != null)
            BvListRow(
              key: const Key('page-continue-numbering'),
              leading: const BvRowIcon(BvIcons.numberList),
              title: l10n.notebookContinueNumbering(goOn),
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(_continue),
            ),
          if (b is PageNumbered)
            BvListRow(
              key: const Key('page-restart-numbering'),
              leading: const BvRowIcon(BvIcons.restartNumbering),
              title: l10n.notebookRestartNumbering,
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(_restart),
            ),
          if (words != null)
            BvListRow(
              key: const Key('page-turn-into'),
              leading: BvRowIcon(now.icon),
              title: l10n.pageTurnInto,
              trailing: const BvRowTrailing.chevron(),
              onTap: () => Navigator.of(sheet).pop(_turnInto),
            ),
          BvListRow(
            key: const Key('page-block-delete'),
            leading: const BvRowIcon(BvIcons.delete, destructive: true),
            title: l10n.pageDelete,
            destructive: true,
            trailing: const BvRowTrailing.none(),
            onTap: () => Navigator.of(sheet).pop(_delete),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    if (picked == _delete) {
      unawaited(_deleteLine(index));
      return;
    }
    if (picked == _continue || picked == _restart) {
      editBlocks = collectBlocks();
      final line = editBlocks[index];
      if (line is! PageNumbered) return;
      _set([
        ...editBlocks.take(index),
        picked == _restart
            ? line.startingAt(1)
            : continued(editBlocks, index, goOn!),
        ...editBlocks.skip(index + 1),
      ]);
      return;
    }
    if (picked != _turnInto || words == null) return;
    final kind = await showBvSheet<NoteBlockKind>(
      context: context,
      title: l10n.pageTurnInto,
      builder: (sheet) => Column(
        key: const Key('page-turn-menu'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final k in NoteBlockKind.words)
            BvListRow(
              key: Key('page-turn-${k.name}'),
              leading: BvRowIcon(k.icon),
              title: k.label(l10n),
              trailing: BvRowTrailing.check(selected: k == now),
              onTap: () => Navigator.of(sheet).pop(k),
            ),
        ],
      ),
    );
    if (kind == null || kind == now || !mounted) return;
    _turn(index, kind);
  }

  /// The line at [index] becomes [kind], keeping its words, its id, its
  /// level and its children: a kind that can't hold them lets them out one
  /// level, right below it (review 93). A to-do's tick doesn't carry over.
  void _turn(int index, NoteBlockKind kind) {
    editBlocks = collectBlocks();
    final b = editBlocks[index];
    final block = lineOf(kind, b.id, lineWords(b) ?? '', indent: b.indent);
    if (block == null) return;
    if (!holdsChildren(block)) _folded.remove(b.id);
    _set([...editBlocks]..[index] = block);
    focusBlockLater('t:${b.id}');
  }

  /// Delete on ⋮⋮: the line goes and its children move up a level; a
  /// folded line asks first, then goes with the lines under it. Undo puts
  /// it all back.
  Future<void> _deleteLine(int index) async {
    final l10n = AppLocalizations.of(context);
    editBlocks = collectBlocks();
    final under = childCount(editBlocks, index);
    final whole = under > 0 && _folded.contains(editBlocks[index].id);
    if (whole) {
      final yes = await showBvDialog(
        context: context,
        title: l10n.notebookDeleteLines(under),
        body: l10n.notebookDeleteLinesUndo,
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.pageDelete,
        destructive: true,
      );
      if (!yes || !mounted) return;
      editBlocks = collectBlocks();
    }
    final before = [...editBlocks];
    final folded = {..._folded};
    _set(
      whole
          ? withoutSubtree(editBlocks, index)
          : withoutLifting(editBlocks, index),
    );
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
              _folded.addAll(folded);
              _set(before);
            },
          ),
        ),
      );
  }

  /// A drag on ⋮⋮ ([from] and [to] count the lines shown): the line moves
  /// with its children, to the level of the line it lands before.
  @override
  void moveBlock(int from, int to) {
    editBlocks = collectBlocks();
    final shown = visibleLines(editBlocks, _folded);
    final rest = [...shown]..removeAt(from);
    final before = to < rest.length ? editBlocks[rest[to]].id : null;
    final next = moved(editBlocks, shown[from], before);
    if (next != null) _set(next);
  }

  @override
  VoidCallback? textEnter(int index) =>
      () => _enter(index);

  @override
  VoidCallback? textBack(int index) =>
      () => _back(index);

  /// Enter: the next line, at this one's level, after the lines under it.
  /// A list goes on as the same kind; an empty list line steps out a
  /// level, and at the first level turns back into text (ending the list).
  void _enter(int index) {
    editBlocks = collectBlocks();
    final b = editBlocks[index];
    final words = lineWords(b) ?? '';
    if ((b is PageTodo || b is PageBullet || b is PageNumbered) &&
        words.isEmpty) {
      if (b.indent > 0) {
        _outdent(index);
        focusBlockLater('t:${b.id}');
      } else {
        _turn(index, NoteBlockKind.text);
      }
      return;
    }
    final id = newUuid();
    final level = b.indent;
    final next = switch (b) {
      PageTodo() => PageTodo(id, '', indent: level),
      PageBullet() => PageBullet(id, '', indent: level),
      PageNumbered() => PageNumbered(id, '', indent: level),
      _ => PageText(id, '', indent: level),
    };
    currentBlockId = id;
    _set([...editBlocks]..insert(subtreeEnd(editBlocks, index), next));
    focusBlockLater('t:$id');
  }

  /// Backspace at the start of a line: any other kind turns into text,
  /// keeping its level and children; an empty text line goes; a text line
  /// with words joins the line shown above it. The line above takes the
  /// cursor.
  void _back(int index) {
    editBlocks = collectBlocks();
    final b = editBlocks[index];
    if (b is! PageText) {
      _turn(index, NoteBlockKind.text);
      return;
    }
    final shown = visibleLines(editBlocks, _folded);
    final at = shown.indexOf(index);
    if (at <= 0) return;
    final above = editBlocks[shown[at - 1]];
    final words = lineWords(above);
    // A toggle's own lines stand between it and this one.
    if (above is PageToggle) return;
    final blocks = [...editBlocks];
    final field = existingField('t:${above.id}');
    if (b.text.isNotEmpty) {
      final joined = words == null ? null : withWords(above, words + b.text);
      if (joined == null || words!.length + b.text.length > Note.lineMax) {
        return;
      }
      blocks[shown[at - 1]] = joined;
      // The cursor where the two meet.
      field?.value = TextEditingValue(
        text: words + b.text,
        selection: TextSelection.collapsed(offset: words.length),
      );
    } else if (field != null) {
      field.selection = TextSelection.collapsed(offset: field.text.length);
    }
    dropField('t:${b.id}');
    blocks.removeAt(index);
    _set(blocks);
    if (words == null) return;
    currentBlockId = above.id;
    focusBlockLater('t:${above.id}');
  }

  /// A to-do ticked or unticked while writing.
  void _tick(int index) {
    editBlocks = collectBlocks();
    final b = editBlocks[index];
    if (b is! PageTodo) return;
    setState(() => editBlocks[index] = b.ticked());
    blocksEdited();
  }

  /// What a numbered line [b] shows: its count at its level, on the page
  /// or inside the toggle at [index].
  String _label(int index, PageNumbered b) {
    final host = editBlocks[index];
    if (host case PageToggle(:final children) when host.id != b.id) {
      final at = children.indexWhere((c) => c.id == b.id);
      return numberLabel(numberAt(children, at), b.indent);
    }
    return numberLabel(numberAt(editBlocks, index), b.indent);
  }

  /// Each line at its level, with room for a fold arrow when a line of
  /// its list has children (review 93).
  @override
  Widget decorateBlock(int index, PageBlock b, Widget child) {
    final l10n = AppLocalizations.of(context);
    final arrow = folds(editBlocks, index);
    final open = !_folded.contains(b.id);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: b.indent * BvNoteBlocksSpec.indent,
      ),
      child: !foldSlot(editBlocks, index)
          ? child
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: BvNoteBlocksSpec.fold,
                  height: BvNoteBlocksSpec.handleHeight,
                  child: arrow
                      ? Semantics(
                          button: true,
                          expanded: open,
                          label: open
                              ? l10n.notebookFoldHide
                              : l10n.notebookFoldShow,
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: Key('note-fold-${b.id}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _fold(b.id),
                            child: Icon(
                              open ? BvIcons.caretDown : BvIcons.caretForward,
                              size: BvNoteBlocksSpec.foldIcon,
                              color: BvColors.iconSecondary,
                            ),
                          ),
                        )
                      : null,
                ),
                Expanded(child: child),
              ],
            ),
    );
  }

  @override
  Widget hostBlock(int index, PageBlock b) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final style = type.bodyMd.copyWith(color: BvColors.textPrimary);
    Widget line(PageLine b, String hint, {TextStyle? textStyle}) => blockText(
      't:${b.id}',
      b.text,
      style: textStyle ?? style,
      hint: hint,
      maxLength: Note.lineMax,
      readOnly: !widget.writing,
      onEnter: () => _enter(index),
      onStartBack: () => _back(index),
    );
    switch (b) {
      case PageTodo(:final done):
        return Row(
          key: Key('note-todo-${b.id}'),
          spacing: BvNoteBlocksSpec.lineGap,
          children: [
            NoteTick(
              key: Key('note-tick-${b.id}'),
              ticked: done,
              onTap: () => _tick(index),
            ),
            Expanded(
              child: line(
                b,
                l10n.notebookTodoHint,
                textStyle: done
                    ? style.copyWith(
                        color: BvColors.textSecondary,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: BvColors.textSecondary,
                      )
                    : null,
              ),
            ),
          ],
        );
      case PageBullet():
        return Row(
          spacing: BvNoteBlocksSpec.lineGap,
          children: [
            const NoteBullet(),
            Expanded(child: line(b, l10n.notebookListHint)),
          ],
        );
      case PageNumbered():
        return Row(
          spacing: BvNoteBlocksSpec.lineGap,
          children: [
            NoteNumber(_label(index, b)),
            Expanded(child: line(b, l10n.notebookListHint)),
          ],
        );
      case PageCallout():
        return NoteCallout(child: line(b, l10n.notebookCalloutHint));
      case PageQuote():
        return NoteQuote(child: line(b, l10n.notebookQuoteHint));
      case PageDivider():
        return const NoteDividerLine();
      case PageVoice(:final path, :final local, :final duration):
        return VoiceNote(
          key: Key('note-voice-${b.id}'),
          id: b.id,
          duration: duration,
          path: path,
          local: path == null ? local : null,
          linkOf: (ref, path) =>
              ref.read(notebookRepositoryProvider).recordingUrl(path),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final style = type.headingMd;
    final shown = visibleLines(editBlocks, _folded);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A Draft with no title shows none.
        if (widget.writing || _title.text.trim().isNotEmpty)
          TextField(
            key: const Key('note-title'),
            controller: _title,
            focusNode: widget.titleFocus,
            readOnly: !widget.writing,
            inputFormatters: [LengthLimitingTextInputFormatter(Note.titleMax)],
            minLines: 1,
            maxLines: null,
            // Enter goes on to the first line (F107; B1).
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              final first = editBlocks.firstOrNull;
              if (first == null || lineWords(first) == null) {
                setState(() => editBlocks.insert(0, PageText(newUuid(), '')));
              }
              focusBlockLater(_focusKey(editBlocks.first));
            },
            textCapitalization: TextCapitalization.sentences,
            onChanged: widget.onTitleChanged,
            style: style.copyWith(color: BvColors.textPrimary),
            cursorColor: BvColors.actionPrimary,
            cursorWidth: BvWritingCardSpec.cursorWidth,
            decoration: bvBareField(hint: l10n.notebookTitleHint, style: style),
          ),
        ReorderableListView.builder(
          key: const Key('note-page'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.only(top: BvNoteBlocksSpec.blockGap),
          itemCount: shown.length,
          onReorderItem: moveBlock,
          itemBuilder: (context, i) => blockRow(shown[i], listIndex: i),
        ),
      ],
    );
  }
}

/// A to-do's box (NBX3): 18, radius 4, a grey edge; ticked, filled in the
/// action colour with a white check.
class NoteTick extends StatelessWidget {
  const NoteTick({super.key, required this.ticked, this.onTap});

  final bool ticked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: ticked,
    button: onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: BvNotebookSpec.box,
        height: BvNotebookSpec.box,
        decoration: BoxDecoration(
          color: ticked ? BvColors.actionPrimary : BvColors.surfaceElevated,
          borderRadius: const BorderRadius.all(
            Radius.circular(BvNotebookSpec.boxRadius),
          ),
          border: ticked
              ? null
              : Border.all(
                  color: BvColors.textSecondary,
                  width: BvNotebookSpec.boxBorder,
                ),
        ),
        child: ticked
            ? const Icon(
                BvIcons.check,
                size: BvNotebookSpec.boxCheck,
                color: BvColors.actionPrimaryForeground,
              )
            : null,
      ),
    ),
  );
}

/// A bulleted line's dot, in the box's place.
class NoteBullet extends StatelessWidget {
  const NoteBullet({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: BvNotebookSpec.box,
    child: Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BvColors.textPrimary,
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(dimension: BvNoteBlocksSpec.bullet),
      ),
    ),
  );
}

/// A numbered line's number, in Western digits.
class NoteNumber extends StatelessWidget {
  const NoteNumber(this.label, {super.key});

  /// "1.", "a." or "i." (numberLabel); wider ones ("12.", "iii.") grow.
  final String label;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: BvNoteBlocksSpec.numberWidth),
    child: Text(
      label,
      textAlign: TextAlign.end,
      style: BvType.of(context).bodyMd.copyWith(color: BvColors.textPrimary),
    ),
  );
}

/// A callout: the subtle fill, radius 10, an info mark before its words.
class NoteCallout extends StatelessWidget {
  const NoteCallout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: BvNoteBlocksSpec.calloutPadding,
    decoration: const BoxDecoration(
      color: BvColors.surfaceSubtle,
      borderRadius: BvRadius.controlAll,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BvNoteBlocksSpec.lineGap,
      children: [
        const Icon(
          BvIcons.info,
          size: BvNoteBlocksSpec.calloutIcon,
          color: BvColors.iconAction,
        ),
        Expanded(child: child),
      ],
    ),
  );
}

/// A quote: a bar at the start, then its words.
class NoteQuote extends StatelessWidget {
  const NoteQuote({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvNoteBlocksSpec.lineGap,
      children: [
        Container(
          width: BvNoteBlocksSpec.quoteBar,
          decoration: const BoxDecoration(
            color: BvColors.textPrimary,
            borderRadius: BvRadius.roundAll,
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

/// A divider: a hairline across the slip.
class NoteDividerLine extends StatelessWidget {
  const NoteDividerLine({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsetsDirectional.symmetric(vertical: BvSpace.s8),
    child: Divider(
      height: BvStroke.thin,
      thickness: BvStroke.thin,
      color: BvColors.borderDefault,
    ),
  );
}
