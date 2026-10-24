import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/design/planning_specs.dart';
import '../../core/photo_privacy.dart' show photosPreparingProvider;
import '../../data/models/daybook.dart' show dayOf;
import '../../data/models/note.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_tap_target.dart';
import '../../shared/widgets/bv_writing_card.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../work/daybook_photos.dart' show localPhotoProvider;
import '../work/daybook_words.dart';
import '../work/daybook_writing.dart' show DaybookPointsEditor;
import 'note_draft.dart';
import 'notebook_screen.dart' show reminderWhen, todoDue;

/// The card the notebook's photos are prepared for ("Preparing…" slots).
const notePhotosCard = 'notebook';

/// The kind chip's and the kind menu's word for [kind].
String noteKindName(AppLocalizations l10n, NoteKind kind) => switch (kind) {
  NoteKind.text => l10n.notebookNote,
  NoteKind.todo => l10n.notebookTodo,
  NoteKind.checklist => l10n.daybookKindChecklist,
  NoteKind.voice => l10n.notebookVoice,
};

/// The kind menu (NBW2 2613:36619): Note, To-do or Checklist, a tick on
/// the one it is. One choice (rule 6), in place of the old tabs.
class NoteKindMenu extends StatelessWidget {
  const NoteKindMenu({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final NoteKind selected;
  final ValueChanged<NoteKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BvPopoverMenu<NoteKind>.picker(
      key: const Key('note-kind-menu'),
      selected: selected,
      items: [
        BvMenuItem(
          value: NoteKind.text,
          label: noteKindName(l10n, NoteKind.text),
          icon: BvIcons.document,
        ),
        BvMenuItem(
          value: NoteKind.todo,
          label: noteKindName(l10n, NoteKind.todo),
          icon: BvIcons.checkbox,
        ),
        BvMenuItem(
          value: NoteKind.checklist,
          label: noteKindName(l10n, NoteKind.checklist),
          icon: BvIcons.workItems,
        ),
      ],
      onSelected: onSelected,
    );
  }
}

/// A photo on a note: the phone's copy while it has one, else a short
/// link to `notebook-files`; null while the link loads. Tests stand in.
final notePhotoProvider = Provider.autoDispose
    .family<ImageProvider?, NotePhoto>((ref, photo) {
      final local = photo.local;
      if (local != null) return ref.watch(localPhotoProvider(local));
      final path = photo.path;
      if (path == null) return null;
      final url = ref.watch(_notePhotoUrlProvider(path)).value;
      return url == null ? null : NetworkImage(url);
    });

final _notePhotoUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(notebookRepositoryProvider).recordingUrl(path),
);

/// One photo, or the plain surface while its link loads.
class NotePhotoImage extends ConsumerWidget {
  const NotePhotoImage({super.key, required this.photo});

  final NotePhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(notePhotoProvider(photo));
    if (image == null) {
      return const ColoredBox(color: BvColors.surfaceSubtle);
    }
    return Image(image: image, fit: BoxFit.cover);
  }
}

/// A saved note's photos on its slip: side by side as the writing card
/// shows them, 128 high for one and 110 for more; more than four scroll
/// sideways as squares.
class NotePhotos extends StatelessWidget {
  const NotePhotos({super.key, required this.photos});

  final List<NotePhoto> photos;

  @override
  Widget build(BuildContext context) {
    final height = photos.length > 1
        ? BvWritingCardSpec.postPhotoHeight
        : BvWritingCardSpec.coverHeight;
    Widget photo(NotePhoto p) => ClipRRect(
      borderRadius: BvWritingCardSpec.coverRadius,
      child: NotePhotoImage(photo: p),
    );
    return SizedBox(
      height: height,
      child: photos.length > BvWritingCardSpec.photosSideBySide
          ? ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (i, p) in photos.indexed)
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: i == photos.length - 1
                          ? 0
                          : BvWritingCardSpec.photoGap,
                    ),
                    child: SizedBox.square(dimension: height, child: photo(p)),
                  ),
              ],
            )
          : Row(
              spacing: BvWritingCardSpec.photoGap,
              children: [for (final p in photos) Expanded(child: photo(p))],
            ),
    );
  }
}

/// A reminder's chip while writing (NBW3): the time alone today ("3:45
/// pm"), else the day and the time, as the slip says it.
String reminderChip(
  AppLocalizations l10n,
  DaybookWords words,
  DateTime at,
  DateTime now,
) => dayOf(at) == dayOf(now)
    ? words.time.clock(at)
    : reminderWhen(l10n, words, at, now);

/// The note being written in place at the end of today (F106 NBW1–NBW4),
/// on Work's writing card: white, a dashed action-colour edge, the kind
/// chip and "Now" on its first line. A note's bold title and its words; a
/// to-do's one tick line; a checklist's title and its points, typed on
/// tick lines with Work's point editor (F40). By when and Remind me show
/// as small chips with ×. While not [writing] it is the Draft (NBW5),
/// read only, and a tap goes on writing.
class NoteWritingSlip extends ConsumerStatefulWidget {
  const NoteWritingSlip({
    super.key,
    required this.writing,
    required this.words,
    required this.onOpen,
    required this.onKindTap,
    required this.onPickDue,
    required this.onPickRemind,
  });

  final bool writing;
  final DaybookWords words;
  final VoidCallback onOpen;
  final VoidCallback onKindTap;
  final VoidCallback onPickDue;
  final VoidCallback onPickRemind;

  @override
  ConsumerState<NoteWritingSlip> createState() => _NoteWritingSlipState();
}

class _NoteWritingSlipState extends ConsumerState<NoteWritingSlip> {
  late final NoteDraft _first = ref.read(noteDraftProvider)!;
  late final _title = TextEditingController(text: _first.title);
  late final _body = TextEditingController(text: _first.body);
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();
  final _todoFocus = FocusNode();
  late NoteKind _kind = _first.kind;

  /// A new point editor each time the kind changes: it starts from the
  /// points the change made.
  int _rev = 0;

  NoteDraftNotifier get _drafts => ref.read(noteDraftProvider.notifier);

  @override
  void initState() {
    super.initState();
    if (widget.writing) _focusLater();
  }

  @override
  void didUpdateWidget(NoteWritingSlip old) {
    super.didUpdateWidget(old);
    if (widget.writing && !old.writing) _focusLater();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    _todoFocus.dispose();
    super.dispose();
  }

  /// The keyboard comes up on the first line: a to-do's line, or the
  /// title.
  void _focusLater() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !widget.writing) return;
    (_kind == NoteKind.todo ? _todoFocus : _titleFocus).requestFocus();
  });

  void _put(NoteDraft Function(NoteDraft d) change) {
    final d = ref.read(noteDraftProvider);
    if (d != null) _drafts.put(change(d));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final draft = ref.watch(noteDraftProvider);
    if (draft == null) return const SizedBox.shrink();
    // The kind changed (the chip or the Checklist tool): the words it
    // moved show, and the keyboard stays on the first line.
    if (draft.kind != _kind) {
      _kind = draft.kind;
      _rev++;
      if (_title.text != draft.title) _title.text = draft.title;
      if (_body.text != draft.body) _body.text = draft.body;
      _focusLater();
    }
    final writing = widget.writing;
    final words = widget.words;
    final now = ref.watch(clockProvider)();
    final kind = draft.kind;
    final preparing = ref.watch(photosPreparingProvider(notePhotosCard));
    final chips = [
      if (kind == NoteKind.todo && draft.dueAt != null)
        _SetChip(
          key: const Key('note-by-when'),
          icon: BvIcons.due,
          label: todoDue(words, draft.dueAt!, now),
          onTap: widget.onPickDue,
          removeLabel: l10n.notebookRemoveByWhen,
          onRemove: () => _put((d) => d.copyWith(dueAt: () => null)),
        ),
      if (draft.remindAt != null)
        _SetChip(
          key: const Key('note-remind-chip'),
          icon: BvIcons.remind,
          label: reminderChip(l10n, words, draft.remindAt!, now),
          onTap: widget.onPickRemind,
          removeLabel: l10n.notebookRemoveReminder,
          onRemove: () => _put((d) => d.copyWith(remindAt: () => null)),
        ),
    ];
    final extra = [
      if (kind == NoteKind.todo) _todoLine(l10n, type),
      if (kind == NoteKind.checklist)
        DaybookPointsEditor(
          key: ValueKey(('note-points', draft.id, _rev)),
          points: draft.points,
          writing: writing,
          onChanged: (points) => _put((d) => d.copyWith(points: points)),
        ),
      if (chips.isNotEmpty)
        Wrap(
          key: const Key('note-chips'),
          spacing: BvNoteWritingSpec.chipsGap,
          runSpacing: BvNoteWritingSpec.chipsGap,
          children: chips,
        ),
    ];
    final card = BvWritingCard(
      key: const Key('note-writing-card'),
      titleController: kind == NoteKind.todo ? null : _title,
      titlePlaceholder: l10n.daybookWritingTitle,
      bodyController: _body,
      bodyPlaceholder: l10n.notebookWriteHint,
      titleFocusNode: _titleFocus,
      bodyFocusNode: _bodyFocus,
      titleMaxLength: kind == NoteKind.checklist ? Note.pointMax : Note.bodyMax,
      bodyMaxLength: Note.bodyMax,
      onTitleChanged: (t) => _put((d) => d.copyWith(title: t)),
      onBodyChanged: (t) => _put((d) => d.copyWith(body: t)),
      kindLabel: noteKindName(l10n, kind),
      // The caret shows on the Draft too; a tap there goes on writing.
      onKindTap: writing ? widget.onKindTap : () {},
      headerEnd: writing
          ? Text(
              draft.editing == null
                  ? l10n.notebookNow
                  : words.time.clock(draft.editing!.createdAt),
              key: const Key('note-writing-now'),
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            )
          : _DraftPill(label: l10n.daybookDraft),
      padding: BvNoteWritingSpec.slipPadding,
      gap: BvNoteWritingSpec.slipGap,
      showBody: kind == NoteKind.text,
      extra: extra.isEmpty
          ? null
          : extra.length == 1
          ? extra.single
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvNoteWritingSpec.slipGap,
              children: extra,
            ),
      photos: [for (final p in draft.photos) NotePhotoImage(photo: p)],
      photoHeight: draft.photos.length + preparing > 1
          ? BvWritingCardSpec.postPhotoHeight
          : BvWritingCardSpec.coverHeight,
      preparing: preparing,
      preparingLabel: l10n.photoPreparing,
      onRemovePhoto: writing
          ? (i) => _put((d) => d.copyWith(photos: [...d.photos]..removeAt(i)))
          : null,
      removePhotoLabel: l10n.daybookRemovePhoto,
      footer: writing
          ? null
          : Text(
              l10n.notebookDraftKept,
              key: const Key('note-draft-kept'),
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
    );
    if (writing) {
      // A tap on the slip's paper stays on the slip.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: card,
      );
    }
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('note-draft'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: AbsorbPointer(child: card),
      ),
    );
  }

  /// A to-do's one tick line (NBW3): an empty box, then the words.
  Widget _todoLine(AppLocalizations l10n, BvTypeSet type) {
    final style = type.bodyMd;
    return Row(
      spacing: BvNotebookSpec.boxGap,
      children: [
        Container(
          width: BvNotebookSpec.box,
          height: BvNotebookSpec.box,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(
              Radius.circular(BvNotebookSpec.boxRadius),
            ),
            border: Border.all(
              color: BvColors.borderInput,
              width: BvNotebookSpec.boxBorder,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            key: const Key('note-todo-line'),
            controller: _title,
            focusNode: _todoFocus,
            enabled: widget.writing,
            inputFormatters: [LengthLimitingTextInputFormatter(Note.bodyMax)],
            minLines: 1,
            maxLines: null,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (t) => _put((d) => d.copyWith(title: t)),
            style: style.copyWith(color: BvColors.textPrimary),
            cursorColor: BvColors.actionPrimary,
            cursorWidth: BvWritingCardSpec.cursorWidth,
            decoration: bvBareField(hint: l10n.notebookTodo, style: style),
          ),
        ),
      ],
    );
  }
}

/// "Draft" at the end of the slip's first line (NBW5): a soft action-
/// colour pill.
class _DraftPill extends StatelessWidget {
  const _DraftPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('note-draft-pill'),
    height: BvNotebookSpec.pillHeight,
    alignment: Alignment.center,
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: BvNotebookSpec.pillPadding,
    ),
    decoration: const BoxDecoration(
      color: BvColors.surfaceBrandSoft,
      borderRadius: BvRadius.roundAll,
    ),
    child: Text(
      label,
      style: BvType.of(context).labelSm.copyWith(color: BvColors.textAction),
    ),
  );
}

/// By when or Remind me inside the slip (NBW3): a small grey pill with
/// its icon and a ×. A tap chooses again; the × takes it off.
class _SetChip extends StatelessWidget {
  const _SetChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onRemove,
    required this.removeLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BvColors.surfaceSubtle,
      borderRadius: BvRadius.roundAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: BvNotebookSpec.pillHeight,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvNotebookSpec.pillPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvNoteWritingSpec.chipGap,
            children: [
              Icon(
                icon,
                size: BvNotebookSpec.pillIcon,
                color: BvColors.iconPrimary,
              ),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BvType.of(
                    context,
                  ).labelSm.copyWith(color: BvColors.textPrimary),
                ),
              ),
              BvTapTarget(
                child: Semantics(
                  button: true,
                  label: removeLabel,
                  child: GestureDetector(
                    key: const Key('note-chip-remove'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemove,
                    child: const Icon(
                      BvIcons.close,
                      size: BvNoteWritingSpec.chipRemove,
                      color: BvColors.iconSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
