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
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import '../chat/voice.dart' show VoiceNote;
import '../work/daybook_page_editor.dart' show withReadyToggles;
import '../work/page_block_editing.dart';

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

/// A line of [kind] with [words], under [id]; null for a kind that isn't
/// a line (a table, a divider, a voice note).
PageBlock? lineOf(NoteBlockKind kind, String id, String words) =>
    switch (kind) {
      NoteBlockKind.text => PageText(id, words),
      NoteBlockKind.heading => PageHeading(id, words),
      NoteBlockKind.subheading => PageHeading(id, words, level: 2),
      NoteBlockKind.todo => PageTodo(id, words),
      NoteBlockKind.bullets => PageBullet(id, words),
      NoteBlockKind.numbers => PageNumbered(id, words),
      NoteBlockKind.callout => PageCallout(id, words),
      NoteBlockKind.quote => PageQuote(id, words),
      NoteBlockKind.toggle => PageToggle(id, words, [PageText(newUuid(), '')]),
      _ => null,
    };

/// A note's page being written in its slip (F107, review 92): the bold
/// title, then the blocks on Work's page editor (PageBlockEditing): "/"
/// at the start of an empty line, ⋮⋮ on the line being written (hold to
/// move, tap to turn it into another kind or delete it), toggles and
/// tables. Enter starts the next line: a to-do, a bullet or a number goes
/// on as one, and an empty one turns back into text; Backspace on an
/// empty line takes it out. The categories grid inserts through
/// [NotePageEditorState.insertKind].
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
  /// The block menu's Delete.
  static const _delete = #delete;

  late final _title = TextEditingController(text: widget.title);

  @override
  int get blockTextMax => Note.lineMax;

  @override
  double get blockGap => BvNoteBlocksSpec.blockGap;

  @override
  bool get handleOnlyWhileWriting => true;

  @override
  void initState() {
    super.initState();
    editBlocks = withReadyToggles(
      widget.blocks.isEmpty ? [PageText(newUuid(), '')] : [...widget.blocks],
    );
  }

  @override
  void dispose() {
    _title.dispose();
    disposeBlockEditing();
    super.dispose();
  }

  @override
  void blocksEdited() => widget.onChanged(_kept());

  /// Toggles' ready lines aren't kept.
  List<PageBlock> _kept() => [
    for (final b in collectBlocks())
      if (b case PageToggle(:final text, :final children))
        PageToggle(b.id, text, [
          for (final c in children)
            if (!(c is PageText && c.text.isEmpty)) c,
        ])
      else
        b,
  ];

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

  /// The field a block's cursor goes to.
  static String _focusKey(PageBlock b) => switch (b) {
    PageTable() => 'c:${b.id}:0:0',
    _ => 't:${b.id}',
  };

  /// The keyboard back on the line being written (the grid closed).
  void focusCurrent() {
    final b = editBlocks.isEmpty ? null : editBlocks[_current];
    if (b == null || b is PageDivider || b is PageVoice) {
      widget.titleFocus?.requestFocus();
      return;
    }
    existingNode(_focusKey(b))?.requestFocus();
  }

  /// A tile in the grid (NBX2): an empty line turns into [kind]; otherwise
  /// the new block goes after the line being written. The keyboard comes
  /// back on it.
  void insertKind(NoteBlockKind kind) {
    editBlocks = collectBlocks();
    final at = _current;
    final here = editBlocks.isEmpty ? null : editBlocks[at];
    final words = here == null ? null : lineWords(here);
    final empty =
        here != null && words != null && words.isEmpty && here is! PageToggle;
    // A new id even for the empty line it turns: a fresh field takes the
    // keyboard, with nothing of the "/" typed there.
    final id = newUuid();
    final block =
        lineOf(kind, id, '') ??
        switch (kind) {
          NoteBlockKind.table => PageTable(id, const [
            ['', ''],
            ['', ''],
          ]),
          _ => PageDivider(id),
        };
    final next = block is PageDivider ? PageText(newUuid(), '') : null;
    setState(() {
      if (empty) {
        dropField('t:${here.id}');
        editBlocks[at] = block;
      } else {
        editBlocks.insert(at + 1, block);
      }
      if (next != null) {
        editBlocks.insert(editBlocks.indexOf(block) + 1, next);
      }
    });
    final focus = next ?? block;
    currentBlockId = focus.id;
    focusBlockLater(_focusKey(focus));
    blocksEdited();
  }

  /// A voice note, recorded: a block after the line being written.
  void insertVoice(PageVoice voice) {
    editBlocks = collectBlocks();
    final at = _current;
    final here = editBlocks.isEmpty ? null : editBlocks[at];
    setState(() {
      if (here is PageText && here.text.isEmpty && editBlocks.length > 1) {
        editBlocks[at] = voice;
      } else {
        editBlocks.insert(at + 1, voice);
      }
    });
    blocksEdited();
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
    final picked = await showBvSheet<Object>(
      context: context,
      title: words == null ? null : l10n.pageTurnInto,
      builder: (sheet) => Column(
        key: const Key('page-block-menu'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (words != null)
            for (final k in NoteBlockKind.words)
              BvListRow(
                key: Key('page-turn-${k.name}'),
                leading: BvRowIcon(k.icon),
                title: k.label(l10n),
                trailing: BvRowTrailing.check(selected: k == now),
                onTap: () => Navigator.of(sheet).pop(k),
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
      deleteBlock(index);
      return;
    }
    if (words == null || picked is! NoteBlockKind || picked == now) return;
    _turn(index, picked);
  }

  /// The line at [index] becomes [kind], keeping its words and its id.
  void _turn(int index, NoteBlockKind kind) {
    editBlocks = collectBlocks();
    final b = editBlocks[index];
    final block = lineOf(kind, b.id, lineWords(b) ?? '');
    if (block == null) return;
    setState(() => editBlocks[index] = block);
    focusBlockLater('t:${b.id}');
    blocksEdited();
  }

  @override
  VoidCallback? textEnter(int index) =>
      () => _enter(index);

  @override
  VoidCallback? textBack(int index) =>
      () => _back(index);

  /// Enter: the next line. A list goes on as the same kind; an empty
  /// list line turns back into text (leaving the list).
  void _enter(int index) {
    editBlocks = collectBlocks();
    final b = editBlocks[index];
    final words = lineWords(b) ?? '';
    if (b is PageLine &&
        b is! PageCallout &&
        b is! PageQuote &&
        words.isEmpty) {
      _turn(index, NoteBlockKind.text);
      return;
    }
    final id = newUuid();
    final next = switch (b) {
      PageTodo() => PageTodo(id, ''),
      PageBullet() => PageBullet(id, ''),
      PageNumbered() => PageNumbered(id, ''),
      _ => PageText(id, ''),
    };
    setState(() => editBlocks.insert(index + 1, next));
    currentBlockId = id;
    focusBlockLater('t:$id');
    blocksEdited();
  }

  /// Backspace on an empty line: a list line turns back into text; a text
  /// line goes, and the line before takes the cursor.
  void _back(int index) {
    editBlocks = collectBlocks();
    final b = editBlocks[index];
    if (b is! PageText) {
      _turn(index, NoteBlockKind.text);
      return;
    }
    if (index == 0) return;
    final before = editBlocks[index - 1];
    dropField('t:${b.id}');
    setState(() => editBlocks.removeAt(index));
    if (lineWords(before) != null) {
      currentBlockId = before.id;
      focusBlockLater('t:${before.id}');
    }
    blocksEdited();
  }

  /// A to-do ticked or unticked while writing.
  void _tick(int index) {
    editBlocks = collectBlocks();
    final b = editBlocks[index];
    if (b is! PageTodo) return;
    setState(() => editBlocks[index] = b.ticked());
    blocksEdited();
  }

  /// The number a numbered line shows: its place in its run.
  int _number(int index) {
    var n = 1;
    for (var i = index - 1; i >= 0 && editBlocks[i] is PageNumbered; i--) {
      n++;
    }
    return n;
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
      onEmptyBack: () => _back(index),
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
            NoteNumber(_number(index)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          itemCount: editBlocks.length,
          onReorderItem: moveBlock,
          itemBuilder: (context, i) => blockRow(i),
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
  const NoteNumber(this.n, {super.key});

  final int n;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: BvNoteBlocksSpec.numberWidth,
    child: Text(
      '$n.',
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
