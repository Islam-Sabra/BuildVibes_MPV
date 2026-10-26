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
import '../../shared/widgets/bv_line_popover.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_undo_bar.dart';
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

  /// What is typed at the start of a text line, then a space, for this
  /// kind (review 98); the "/" card and the grid show it.
  String? get shortcut => switch (this) {
    heading => '#',
    subheading => '##',
    todo => '[]',
    bullets => '-',
    numbers => '1.',
    toggle => '>',
    quote => '"',
    divider => '---',
    _ => null,
  };

  /// The kind [typed] at the start of a text line stands for, before its
  /// space: `1.` `1)` (or `١.`), `-` `*`, `[]` `[ ]`, `#` `##`, `>`, `"`
  /// (as a phone may curl it) and `---` (or the phone's dash and `-`).
  static NoteBlockKind? typed(String typed) => switch (typed) {
    '-' || '*' => bullets,
    '[]' || '[ ]' => todo,
    '#' => heading,
    '##' => subheading,
    '>' => toggle,
    '"' || '\u201C' || '\u201D' => quote,
    '---' || '\u2014-' => divider,
    _ when _numberShortcut.hasMatch(typed) => numbers,
    _ => null,
  };

  /// "1." or "1)", in Western or Arabic-Indic digits.
  static final _numberShortcut = RegExp('^[1\u0661][.)]\$');

  /// More words that find this kind in the "/" card ("num", «مهام»).
  String find(AppLocalizations l10n) => switch (this) {
    text => l10n.notebookFindText,
    heading => l10n.notebookFindHeading,
    subheading => l10n.notebookFindSubheading,
    todo => l10n.notebookFindTodo,
    bullets => l10n.notebookFindBullets,
    numbers => l10n.notebookFindNumbers,
    toggle => l10n.notebookFindToggle,
    table => l10n.notebookFindTable,
    callout => l10n.notebookFindCallout,
    quote => l10n.notebookFindQuote,
    divider => l10n.notebookFindDivider,
    voice => '',
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
    with PageBlockEditing<NotePageEditor>, TickerProviderStateMixin {
  /// The line menu's rows that aren't a kind (review 98 NBY2).
  static const _turnInto = #turnInto;
  static const _up = #up;
  static const _down = #down;
  static const _indent = #indent;
  static const _out = #outdent;
  static const _duplicate = #duplicate;
  static const _continue = #goOn;
  static const _restart = #restart;
  static const _delete = #delete;

  late final _title = TextEditingController(text: widget.title);

  /// The lines folded shut, by id (while the note is open).
  final _folded = <String>{};

  /// The line menu next to its line (review 98), the line it is for
  /// (tinted), and whether it lists the kinds (Turn into ›).
  final _menu = BvLinePopover();
  String? _marked;
  var _turning = false;

  /// Each line's row, by id: measured for Move up and Move down, and the
  /// line menu's place.
  final _rows = <String, GlobalKey>{};

  /// Move up and Move down slide the lines that moved from where they were
  /// ([_slideFrom], by id) to their place, in 180 ms (review 98).
  late final _slide = AnimationController(
    vsync: this,
    duration: BvMotion.slide,
    value: 1,
  );
  final _slideFrom = <String, double>{};

  /// A fold slides its lines shut ([_closing]) or open ([_opening]) in
  /// 180 ms, and its arrow turns.
  late final _foldMotion = AnimationController(
    vsync: this,
    duration: BvMotion.slide,
    value: 1,
  );
  String? _closing;
  String? _opening;

  @override
  int get blockTextMax => Note.lineMax;

  @override
  double get blockGap => BvNoteBlocksSpec.blockGap;

  @override
  bool get handleOnlyWhileWriting => true;

  @override
  bool get handlesShown => widget.writing && !_inTitle;

  /// The cursor is in the title: no line is being written, so no ⋮⋮ and no
  /// ⇥ ⇤ (NBY4).
  bool get _inTitle => widget.titleFocus?.hasFocus ?? false;

  void _titleFocusChanged() {
    if (!mounted) return;
    setState(() {});
    widget.onCurrentKind?.call(currentKind);
  }

  @override
  double get handleHeight => BvNoteBlocksSpec.handleHeight;

  @override
  String? get markedBlockId => _marked;

  /// Reduce motion: nothing moves.
  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    editBlocks = normalized(
      withReadyToggles(
        widget.blocks.isEmpty ? [PageText(newUuid(), '')] : [...widget.blocks],
      ),
    );
    widget.titleFocus?.addListener(_titleFocusChanged);
    // The note opens folded as it was left.
    for (final (i, b) in editBlocks.indexed) {
      if (b.folded && folds(editBlocks, i)) _folded.add(b.id);
    }
    _foldMotion.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      _endFold();
    });
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
    widget.titleFocus?.removeListener(_titleFocusChanged);
    _menu.hide();
    _slide.dispose();
    _foldMotion.dispose();
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

  int _indexOf(String id) => editBlocks.indexWhere((b) => b.id == id);

  /// ⇥ and ⇤ on the bar: the line the cursor is in can go deeper, or out.
  bool get canIndentCurrent =>
      widget.writing &&
      !_inTitle &&
      _here != null &&
      canIndent(editBlocks, _here!);
  bool get canOutdentCurrent =>
      widget.writing &&
      !_inTitle &&
      _here != null &&
      canOutdent(editBlocks, _here!);

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

  // Undo (review 98) ----------------------------------------------------------

  /// The whole note as it is: its lines, its folds and the line written in.
  ({List<PageBlock> blocks, Set<String> folded, String? current}) _snap() =>
      (blocks: collectBlocks(), folded: {..._folded}, current: currentBlockId);

  /// The Undo bar for 5 s after a line's action ("Moved · Undo"); Undo
  /// puts [before] back, children and folds and all. [mark]: the line
  /// stays tinted while it shows (NBY5).
  void _undoBar(
    String message,
    ({List<PageBlock> blocks, Set<String> folded, String? current}) before, {
    String? mark,
  }) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final bar = showBvUndoBar(
      context,
      message: message,
      actionLabel: l10n.spacesUndo,
      bottom: BvWritingToolbarSpec.height,
      onAction: () {
        if (mounted) _restore(before);
      },
    );
    if (mark == null) return;
    unawaited(
      bar.closed.then((_) {
        if (mounted && _marked == mark && !_menu.isOpen) {
          setState(() => _marked = null);
        }
      }),
    );
  }

  /// [before] back, with each field's words as they were.
  void _restore(
    ({List<PageBlock> blocks, Set<String> folded, String? current}) before,
  ) {
    void words(PageBlock b) {
      if (b case PageTable(:final rows)) {
        for (final (r, row) in rows.indexed) {
          for (final (c, cell) in row.indexed) {
            final key = 'c:${b.id}:$r:$c';
            if (existingField(key) != null) setField(key, cell, cell.length);
          }
        }
        return;
      }
      final text = switch (b) {
        PageToggle(:final text) => text,
        _ => lineWords(b),
      };
      final key = 't:${b.id}';
      if (text != null && existingField(key) != null) {
        setField(key, text, text.length);
      }
      if (b case PageToggle(:final children)) children.forEach(words);
    }

    before.blocks.forEach(words);
    _folded
      ..clear()
      ..addAll(before.folded);
    currentBlockId = before.current;
    _marked = null;
    _set(before.blocks);
    if (before.current case final id?) {
      final b = before.blocks.where((b) => b.id == id).firstOrNull;
      if (b != null && b is! PageDivider && b is! PageVoice) {
        focusBlockLater(_focusKey(b));
      }
    }
  }

  // Folds ---------------------------------------------------------------------

  /// A fold arrow tapped: the lines under [id] slide shut or open, and the
  /// note keeps it.
  void _fold(String id) {
    if (_closing != null || _opening != null) _endFold();
    final closing = !_folded.contains(id);
    if (_still) {
      setState(() => closing ? _folded.add(id) : _folded.remove(id));
      blocksEdited();
      return;
    }
    setState(() {
      if (closing) {
        _closing = id;
      } else {
        _folded.remove(id);
        _opening = id;
      }
    });
    _foldMotion.forward(from: 0);
    if (!closing) blocksEdited();
  }

  /// The fold's slide is over: a line folded shut hides its lines now.
  void _endFold() {
    final closing = _closing;
    setState(() {
      if (closing != null) _folded.add(closing);
      _closing = null;
      _opening = null;
    });
    if (closing != null) blocksEdited();
  }

  /// +1 while [index]'s line slides open under its fold, -1 while it slides
  /// shut, 0 otherwise.
  int _folding(int index) {
    for (final (id, way) in [(_closing, -1), (_opening, 1)]) {
      if (id == null) continue;
      final at = _indexOf(id);
      if (at >= 0 && index > at && index < subtreeEnd(editBlocks, at)) {
        return way;
      }
    }
    return 0;
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

  /// + on the bar (review 98): the grid is for a new line below the line
  /// being written and its children, at its level; an empty text line is
  /// turned itself.
  void lineForGrid() {
    if (!widget.writing) return;
    closeSlash();
    editBlocks = collectBlocks();
    if (editBlocks.isEmpty) return;
    final at = _current;
    final here = editBlocks[at];
    if (here is PageText && here.text.isEmpty) {
      currentBlockId = here.id;
      return;
    }
    final line = PageText(newUuid(), '', indent: here.indent);
    currentBlockId = line.id;
    _set([...editBlocks]..insert(subtreeEnd(editBlocks, at), line));
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
      if (kind != NoteBlockKind.of(here)) _changedKind();
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

  /// A light click: a line changed kind (review 98).
  void _changedKind() => unawaited(HapticFeedback.selectionClick());

  // "/" and the typed shortcuts (review 98) -----------------------------------

  /// The toggle [key]'s field is a line of, and that line's id.
  (int, String)? _toggleOf(String key) {
    final id = PageBlockEditing.blockIdOfKey(key);
    for (final (i, b) in editBlocks.indexed) {
      if (b case PageToggle(
        :final children,
      ) when b.id != id && children.any((c) => c.id == id)) {
        return (i, id!);
      }
    }
    return null;
  }

  /// "/" lists the grid's kinds (but a voice note: hold the mic), by
  /// their names in English and Arabic and a few simple words, each with
  /// its shortcut; a toggle's own line takes no toggle and no table.
  @override
  List<PageSlashItem> slashItems(String key) {
    if (!widget.writing) return const [];
    final l10n = AppLocalizations.of(context);
    final inToggle = _toggleOf(key) != null;
    return [
      for (final k in NoteBlockKind.values)
        if (k != NoteBlockKind.voice &&
            !(inToggle &&
                (k == NoteBlockKind.toggle || k == NoteBlockKind.table)))
          (
            value: k,
            key: k.name,
            label: k.label(l10n),
            icon: k.icon,
            shortcut: k.shortcut,
            words: [
              for (final w in slashLanguages) ...[k.label(w), k.find(w)],
            ],
          ),
    ];
  }

  /// A kind from "/": an empty line becomes it; a line with words turns
  /// into it keeping them, or, for a table or a divider, it goes after.
  @override
  void slashPicked(String key, Object value) {
    if (value is! NoteBlockKind) return;
    if (_toggleOf(key) case final where?) {
      _intoToggle(where, value);
      return;
    }
    editBlocks = collectBlocks();
    final index = _indexOf(PageBlockEditing.blockIdOfKey(key) ?? '');
    if (index < 0) return;
    final b = editBlocks[index];
    currentBlockId = b.id;
    final words = lineWords(b) ?? '';
    if (words.isEmpty || lineOf(value, b.id, words) == null) {
      insertKind(value);
      return;
    }
    if (value != NoteBlockKind.of(b)) _turn(index, value);
  }

  /// A kind picked on a toggle's line: that line turns into it, keeping
  /// its words.
  void _intoToggle((int, String) where, NoteBlockKind kind) {
    final (index, childId) = where;
    editBlocks = collectBlocks();
    final t = editBlocks[index] as PageToggle;
    final child = t.children.where((c) => c.id == childId).firstOrNull;
    final words = child == null ? '' : lineWords(child) ?? '';
    final block = lineOf(kind, childId, words) ?? PageDivider(childId);
    if (block is PageDivider) dropField('t:$childId');
    _changedKind();
    setState(
      () => editBlocks[index] = PageToggle(t.id, t.text, [
        for (final c in t.children) c.id == childId ? block : c,
      ], indent: t.indent),
    );
    if (block is! PageDivider) focusBlockLater('t:$childId');
    blocksEdited();
  }

  /// "1. ", "- ", "[] ", "# ", "> ", '" ' or "--- " at the start of a text
  /// line on the page turns it into that kind; the typed characters go,
  /// and Undo gives them back as text.
  @override
  bool typedShortcut(String key, String before, String after) {
    final kind = NoteBlockKind.typed(before);
    if (kind == null || !widget.writing) return false;
    final index = _indexOf(PageBlockEditing.blockIdOfKey(key) ?? '');
    if (index < 0 || editBlocks[index] is! PageText) return false;
    final undo = _snap();
    editBlocks = collectBlocks();
    final b = editBlocks[index];
    final l10n = AppLocalizations.of(context);
    _changedKind();
    if (kind == NoteBlockKind.divider) {
      // The line becomes the divider; what was after the dashes goes on a
      // new text line under it, with the cursor.
      final line = PageText(newUuid(), after, indent: b.indent);
      dropField(key);
      currentBlockId = line.id;
      _set(
        [...editBlocks]..replaceRange(index, index + 1, [
          PageDivider(b.id, indent: b.indent),
          line,
        ]),
      );
      focusBlockLater('t:${line.id}');
    } else {
      setField(key, after, 0);
      final block = lineOf(kind, b.id, after, indent: b.indent)!;
      if (!holdsChildren(block)) _folded.remove(b.id);
      _set([...editBlocks]..[index] = block);
      focusBlockLater(key);
    }
    _undoBar(l10n.notebookUndoTurned(kind.label(l10n)), undo);
    return true;
  }

  // The line menu (review 98 NBY2) --------------------------------------------

  /// ⋮⋮ tapped, or the line's marker held: the line menu next to the line,
  /// the line tinted.
  @override
  Future<void> blockMenu(int index) async {
    if (!widget.writing) return;
    closeSlash();
    editBlocks = collectBlocks();
    final id = editBlocks[index].id;
    await _roomForMenu(id);
    if (!mounted) return;
    setState(() {
      _marked = id;
      _turning = false;
    });
    _menu.show(
      context,
      anchor: () => _rows[id]?.currentContext,
      atEnd: true,
      barrier: true,
      gap: BvLineMenuSpec.menuGap,
      onDismiss: _closeMenu,
      builder: (context) => _menuCard(context, id),
    );
  }

  /// The line menu shows every row, never scrolled (lead, 26 Oct): with no
  /// room for it under the line nor over it, the note first scrolls the
  /// line the shorter way that makes room (up for room under it, down for
  /// room over it), as far as the list goes.
  Future<void> _roomForMenu(String id) async {
    final row = _rows[id]?.currentContext;
    final box = row?.findRenderObject() as RenderBox?;
    final position = Scrollable.maybeOf(context)?.position;
    if (row == null || box == null || !box.attached || position == null) {
      return;
    }
    final media = MediaQuery.of(context);
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    const need =
        BvLineMenuSpec.menuMostRows * BvLineMenuSpec.rowHeight +
        2 * BvLineMenuSpec.padding +
        BvLineMenuSpec.menuGap;
    final floor =
        media.size.height - media.padding.bottom - BvLineMenuSpec.screenMargin;
    final ceiling = media.padding.top + BvLineMenuSpec.screenMargin;
    final up = bottom + need - floor;
    final down = ceiling + need - top;
    if (up <= 0 || down <= 0) return;
    final pixels = position.pixels;
    final ways = [
      if (pixels + up <= position.maxScrollExtent) pixels + up,
      if (pixels - down >= position.minScrollExtent) pixels - down,
    ]..sort((a, b) => (a - pixels).abs().compareTo((b - pixels).abs()));
    final to = ways.isNotEmpty
        ? ways.first
        : (up < down ? position.maxScrollExtent : position.minScrollExtent);
    if (_still) {
      position.jumpTo(to);
    } else {
      await position.animateTo(
        to,
        duration: BvMotion.fast,
        curve: BvMotion.standard,
      );
    }
  }

  void _closeMenu({bool keepMark = false}) {
    _menu.hide();
    if (!mounted) return;
    setState(() {
      if (!keepMark) _marked = null;
      _turning = false;
    });
  }

  /// The menu's rows, those that can act only: Turn into ›, Move up, Move
  /// down, Indent, Outdent, Duplicate, Continue numbering or Restart at 1,
  /// Delete; or, after Turn into, the kinds the line can become.
  Widget _menuCard(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context);
    final index = _indexOf(id);
    if (index < 0) return const SizedBox.shrink();
    final b = editBlocks[index];
    final now = NoteBlockKind.of(b);
    if (_turning) {
      return BvPopoverMenu<Object>.line(
        key: const Key('page-turn-menu'),
        selected: now,
        items: [
          for (final k in NoteBlockKind.words)
            BvMenuItem(
              key: Key('page-turn-${k.name}'),
              value: k,
              label: k.label(l10n),
              icon: k.icon,
              shortcut: k.shortcut,
            ),
        ],
        onSelected: (v) => _menuPicked(id, v),
      );
    }
    final blocks = editBlocks;
    final goOn = continueAt(blocks, index);
    return BvPopoverMenu<Object>.line(
      key: const Key('page-block-menu'),
      items: [
        if (lineWords(b) != null)
          BvMenuItem(
            key: const Key('page-turn-into'),
            value: _turnInto,
            label: l10n.pageTurnInto,
            icon: BvIcons.turnInto,
            more: true,
          ),
        if (canMoveUp(blocks, index))
          BvMenuItem(
            key: const Key('page-move-up'),
            value: _up,
            label: l10n.notebookMoveUp,
            icon: BvIcons.moveUp,
          ),
        if (canMoveDown(blocks, index))
          BvMenuItem(
            key: const Key('page-move-down'),
            value: _down,
            label: l10n.notebookMoveDown,
            icon: BvIcons.moveDown,
          ),
        if (canIndent(blocks, index))
          BvMenuItem(
            key: const Key('page-indent'),
            value: _indent,
            label: l10n.notebookLineIndent,
            icon: BvIcons.indent,
          ),
        if (canOutdent(blocks, index))
          BvMenuItem(
            key: const Key('page-outdent'),
            value: _out,
            label: l10n.notebookOutdent,
            icon: BvIcons.outdent,
          ),
        if (canDuplicate(blocks, index))
          BvMenuItem(
            key: const Key('page-duplicate'),
            value: _duplicate,
            label: l10n.notebookDuplicate,
            icon: BvIcons.duplicate,
          ),
        if (goOn != null)
          BvMenuItem(
            key: const Key('page-continue-numbering'),
            value: _continue,
            label: l10n.notebookContinueNumbering(goOn),
            icon: BvIcons.numberList,
          ),
        // Any numbered line, as review 93 has it.
        if (b is PageNumbered)
          BvMenuItem(
            key: const Key('page-restart-numbering'),
            value: _restart,
            label: l10n.notebookLineRestart,
            icon: BvIcons.restartNumbering,
          ),
        BvMenuItem(
          key: const Key('page-block-delete'),
          value: _delete,
          label: l10n.pageMenuDelete,
          icon: BvIcons.delete,
          destructive: true,
        ),
      ],
      onSelected: (v) => _menuPicked(id, v),
    );
  }

  void _menuPicked(String id, Object picked) {
    final l10n = AppLocalizations.of(context);
    editBlocks = collectBlocks();
    final index = _indexOf(id);
    if (index < 0) {
      _closeMenu();
      return;
    }
    if (picked == _turnInto) {
      setState(() => _turning = true);
      _menu.rebuild();
      return;
    }
    final before = _snap();
    switch (picked) {
      case NoteBlockKind kind:
        _closeMenu();
        if (kind == NoteBlockKind.of(editBlocks[index])) return;
        _turn(index, kind);
        _undoBar(l10n.notebookUndoTurned(kind.label(l10n)), before);
      case _up || _down:
        _closeMenu(keepMark: true);
        _move(index, up: picked == _up);
        _undoBar(l10n.notebookUndoMoved, before, mark: id);
      case _indent:
        _closeMenu();
        _set(indented(editBlocks, index));
        _undoBar(l10n.notebookUndoIndented, before);
      case _out:
        _closeMenu();
        _set(outdented(editBlocks, index));
        _undoBar(l10n.notebookUndoOutdented, before);
      case _duplicate:
        _closeMenu();
        _set(duplicated(editBlocks, index, newUuid));
        _undoBar(l10n.notebookUndoDuplicated, before);
      case _continue || _restart:
        _closeMenu();
        final line = editBlocks[index];
        final goOn = continueAt(editBlocks, index);
        if (line is! PageNumbered || (picked == _continue && goOn == null)) {
          return;
        }
        _set([
          ...editBlocks.take(index),
          picked == _restart
              ? line.startingAt(1)
              : continued(editBlocks, index, goOn!),
          ...editBlocks.skip(index + 1),
        ]);
      case _delete:
        _closeMenu();
        unawaited(_deleteLine(index));
    }
    focusCurrent();
  }

  /// Move up or Move down: the line and its children over the whole group
  /// next to them at their level; both slide to their place (review 98).
  void _move(int index, {required bool up}) {
    final blocks = editBlocks;
    final end = subtreeEnd(blocks, index);
    final (from, to) = up
        ? (
            blocks.lastIndexWhere(
              (b) => b.indent == blocks[index].indent,
              index - 1,
            ),
            index,
          )
        : (end, subtreeEnd(blocks, end));
    final shown = visibleLines(blocks, _folded).toSet();
    double tall(int start, int stop) => [
      for (var i = start; i < stop; i++)
        if (shown.contains(i))
          (_rows[blocks[i].id]?.currentContext?.size?.height ?? 0),
    ].fold(0, (a, b) => a + b);
    final group = tall(index, end);
    final other = tall(from, to);
    _slideFrom.clear();
    if (!_still) {
      for (var i = index; i < end; i++) {
        _slideFrom[blocks[i].id] = up ? other : -other;
      }
      for (var i = from; i < to; i++) {
        _slideFrom[blocks[i].id] = up ? -group : group;
      }
    }
    _set(up ? movedUp(blocks, index) : movedDown(blocks, index));
    if (_slideFrom.isNotEmpty) _slide.forward(from: 0);
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
    if (kind != NoteBlockKind.of(b)) _changedKind();
    _set([...editBlocks]..[index] = block);
    focusBlockLater('t:${b.id}');
  }

  /// Delete: the line goes and its children move up a level; a folded line
  /// asks first, then goes with the lines under it. Undo puts it all back.
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
    final before = _snap();
    final gone = editBlocks[index].id;
    if (currentBlockId == gone) {
      final shown = visibleLines(editBlocks, _folded);
      final at = shown.indexOf(index);
      currentBlockId = at > 0 ? editBlocks[shown[at - 1]].id : null;
    }
    _set(
      whole
          ? withoutSubtree(editBlocks, index)
          : withoutLifting(editBlocks, index),
    );
    _undoBar(l10n.notebookUndoDeleted, before);
  }

  /// A drag on ⋮⋮ (a tablet; [from] and [to] count the lines shown): the
  /// line moves with its children, to the level of the line it lands
  /// before.
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
  /// its list has children (review 93); the arrow turns as its lines slide
  /// shut or open (review 98).
  @override
  Widget decorateBlock(int index, PageBlock b, Widget child) {
    final l10n = AppLocalizations.of(context);
    final arrow = folds(editBlocks, index);
    final open = !_folded.contains(b.id) && _closing != b.id;
    final rtl = Directionality.of(context) == TextDirection.rtl;
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
                            // The caret points down while open and, shut,
                            // forward (a quarter turn to the reading side).
                            child: AnimatedRotation(
                              turns: open
                                  ? 0
                                  : rtl
                                  ? BvNoteBlocksSpec.foldTurn
                                  : -BvNoteBlocksSpec.foldTurn,
                              duration: _still ? Duration.zero : BvMotion.slide,
                              curve: BvMotion.standard,
                              child: const Icon(
                                BvIcons.caretDown,
                                size: BvNoteBlocksSpec.foldIcon,
                                color: BvColors.iconSecondary,
                              ),
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

  /// A list line's marker (number, bullet or box): held, it opens the line
  /// menu (review 98); holding the words still selects them.
  Widget _marker(int index, PageBlock b, Widget marker) =>
      !widget.writing || editBlocks[index].id != b.id
      ? marker
      : GestureDetector(
          key: Key('note-marker-${b.id}'),
          behavior: HitTestBehavior.opaque,
          onLongPress: () {
            currentBlockId = b.id;
            unawaited(blockMenu(index));
          },
          child: marker,
        );

  @override
  Widget hostBlock(int index, PageBlock b) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final style = type.bodyMd.copyWith(color: BvColors.textPrimary);
    // A toggle's own lines take no "/" here: the toggle's field does.
    final onPage = index < editBlocks.length && editBlocks[index].id == b.id;
    Widget line(PageLine b, String hint, {TextStyle? textStyle}) => blockText(
      't:${b.id}',
      b.text,
      style: textStyle ?? style,
      hint: hint,
      maxLength: Note.lineMax,
      readOnly: !widget.writing,
      slash: onPage,
      onEnter: () => _enter(index),
      onStartBack: () => _back(index),
    );
    switch (b) {
      case PageTodo(:final done):
        return Row(
          key: Key('note-todo-${b.id}'),
          spacing: BvNoteBlocksSpec.lineGap,
          children: [
            _marker(
              index,
              b,
              NoteTick(
                key: Key('note-tick-${b.id}'),
                ticked: done,
                onTap: () => _tick(index),
              ),
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
            _marker(index, b, const NoteBullet()),
            Expanded(child: line(b, l10n.notebookListHint)),
          ],
        );
      case PageNumbered():
        return Row(
          spacing: BvNoteBlocksSpec.lineGap,
          children: [
            _marker(index, b, NoteNumber(_label(index, b))),
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
          itemBuilder: (context, i) {
            final id = editBlocks[shown[i]].id;
            return _LineMotion(
              key: _rows.putIfAbsent(id, GlobalKey.new),
              slide: _slide,
              from: _slideFrom[id] ?? 0,
              fold: _foldMotion,
              folding: _folding(shown[i]),
              child: blockRow(shown[i], listIndex: i),
            );
          },
        ),
      ],
    );
  }
}

/// A line's row as it moves (review 98): slid from [from] to its place as
/// [slide] runs (Move up, Move down), and shut or opened as [fold] runs
/// ([folding] -1 or +1) under a fold. Always the same widgets, so a line's
/// field keeps its keyboard while it moves.
class _LineMotion extends StatelessWidget {
  const _LineMotion({
    super.key,
    required this.slide,
    required this.from,
    required this.fold,
    required this.folding,
    required this.child,
  });

  final Animation<double> slide;
  final double from;
  final Animation<double> fold;
  final int folding;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([slide, fold]),
    builder: (context, child) {
      final shut = BvMotion.standard.transform(fold.value);
      final slid = BvMotion.standard.transform(slide.value);
      return ClipRect(
        clipBehavior: folding == 0 ? Clip.none : Clip.hardEdge,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: switch (folding) {
            > 0 => shut,
            < 0 => 1 - shut,
            _ => 1,
          },
          child: Transform.translate(
            offset: Offset(0, from * (1 - slid)),
            child: child,
          ),
        ),
      );
    },
    child: child,
  );
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
