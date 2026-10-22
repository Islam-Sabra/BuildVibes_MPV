import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../data/models/note.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_segmented.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../work/daybook_words.dart';
import '../work/daybook_writing.dart' show newPostIdProvider, pickDueProvider;
import 'notebook_screen.dart' show todoDue;
import 'notebook_state.dart';

/// Writes a note, or edits [note] (review 83, question 6): one choice of
/// Note, Checklist or To-do (rule 6), the words, a checklist's points, a
/// to-do's day and time. No audience, owner or photos: it stays private.
Future<void> showNoteWriter(
  BuildContext context,
  WidgetRef ref, {
  Note? note,
}) async {
  final saved = await showBvSheet<Note>(
    context: context,
    builder: (sheet) => _NoteWriter(note: note),
  );
  if (saved == null) return;
  await ref.read(notebookProvider.notifier).save(saved);
}

class _NoteWriter extends ConsumerStatefulWidget {
  const _NoteWriter({this.note});

  final Note? note;

  @override
  ConsumerState<_NoteWriter> createState() => _NoteWriterState();
}

class _NoteWriterState extends ConsumerState<_NoteWriter> {
  late NoteKind _kind = widget.note?.kind ?? NoteKind.text;
  late final _body = TextEditingController(text: widget.note?.body);
  late DateTime? _dueAt = widget.note?.dueAt;

  /// A checklist's points, and whether each was ticked; the last box is
  /// always empty, for the next point.
  late final List<TextEditingController> _points = [
    for (final p in widget.note?.points ?? const <NotePoint>[])
      TextEditingController(text: p.text),
    TextEditingController(),
  ];
  late final List<bool> _done = [
    for (final p in widget.note?.points ?? const <NotePoint>[]) p.done,
  ];

  @override
  void dispose() {
    _body.dispose();
    for (final p in _points) {
      p.dispose();
    }
    super.dispose();
  }

  List<NotePoint> get _written => [
    for (final (i, c) in _points.indexed)
      if (c.text.trim().isNotEmpty)
        NotePoint(c.text.trim(), done: i < _done.length && _done[i]),
  ];

  bool get _ready => switch (_kind) {
    NoteKind.checklist => _written.isNotEmpty,
    _ => _body.text.trim().isNotEmpty,
  };

  void _pointChanged(int index) {
    // Typing in the last box opens the next one.
    if (index == _points.length - 1 &&
        _points[index].text.isNotEmpty &&
        _points.length < Note.pointsMax) {
      _points.add(TextEditingController());
    }
    setState(() {});
  }

  Future<void> _pickWhen() async {
    final now = ref.read(clockProvider)();
    final picked = await ref.read(pickDueProvider)(
      context,
      now: now,
      day: _dueAt == null ? null : dayOf(_dueAt!),
      at: _dueAt,
    );
    if (picked == null || !mounted) return;
    // A day with no time is kept at the day's start, and reads as the day.
    setState(
      () => _dueAt = picked.day == null ? null : picked.at ?? picked.day,
    );
  }

  void _save() {
    final now = ref.read(clockProvider)();
    final was = widget.note;
    final body = _body.text.trim();
    final note =
        was ??
        Note(id: ref.read(newPostIdProvider)(), kind: _kind, createdAt: now);
    Navigator.of(context).pop(
      note.copyWith(
        kind: _kind,
        body: body,
        points: _kind == NoteKind.checklist ? _written : const [],
        dueAt: () => _kind == NoteKind.todo ? _dueAt : null,
        doneAt: () => _kind == NoteKind.todo ? note.doneAt : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final now = ref.watch(clockProvider)();
    return Column(
      key: const Key('note-writer'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s16,
      children: [
        BvSegmented<NoteKind>(
          key: const Key('note-kind'),
          segments: [
            BvSegment(
              key: const Key('note-kind-text'),
              value: NoteKind.text,
              label: l10n.notebookNote,
            ),
            BvSegment(
              key: const Key('note-kind-checklist'),
              value: NoteKind.checklist,
              label: l10n.daybookKindChecklist,
            ),
            BvSegment(
              key: const Key('note-kind-todo'),
              value: NoteKind.todo,
              label: l10n.notebookTodo,
            ),
          ],
          value: _kind,
          onChanged: (k) => setState(() => _kind = k),
        ),
        BvTextField(
          key: const Key('note-body'),
          controller: _body,
          autofocus: widget.note == null,
          placeholder: switch (_kind) {
            NoteKind.checklist => l10n.notebookChecklistHint,
            NoteKind.todo => l10n.notebookTodoHint,
            _ => l10n.notebookWriteHint,
          },
          maxLines: _kind == NoteKind.text ? BvNotebookSpec.writerLines : 2,
          maxLength: Note.bodyMax,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        if (_kind == NoteKind.checklist)
          Column(
            spacing: BvNotebookSpec.pointGap,
            children: [
              for (final (i, c) in _points.indexed)
                BvTextField(
                  key: Key('note-point-$i'),
                  controller: c,
                  placeholder: l10n.notebookPointHint,
                  maxLength: Note.pointMax,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _pointChanged(i),
                ),
            ],
          ),
        if (_kind == NoteKind.todo)
          Material(
            color: BvColors.surfaceSubtle,
            borderRadius: BvRadius.controlAll,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('note-when'),
              onTap: _pickWhen,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BvSize.controlMd),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: BvSpace.s12,
                  ),
                  child: Row(
                    spacing: BvSpace.s8,
                    children: [
                      const Icon(
                        BvIcons.due,
                        size: BvSize.iconMd,
                        color: BvColors.iconPrimary,
                      ),
                      Text(
                        l10n.notebookWhen,
                        style: type.labelMd.copyWith(
                          color: BvColors.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _dueAt == null
                              ? l10n.notebookNoTime
                              : todoDue(words, _dueAt!, now),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.bodyMd.copyWith(
                            color: _dueAt == null
                                ? BvColors.textSecondary
                                : BvColors.textAction,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        BvButton(
          key: const Key('note-save'),
          label: l10n.save,
          expand: true,
          onPressed: _ready ? _save : null,
        ),
      ],
    );
  }
}
