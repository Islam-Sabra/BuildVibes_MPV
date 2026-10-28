import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/design/planning_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/photo_privacy.dart' show photosPreparingProvider;
import '../../data/models/daybook.dart' show dayOf;
import '../../data/models/note.dart';
import '../../data/models/post_page.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_photo_preparing.dart';
import '../../shared/widgets/bv_tap_target.dart';
import '../../shared/widgets/bv_writing_card.dart';
import '../library/library_parts.dart' show fileSize;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../work/daybook_photos.dart' show localPhotoProvider;
import '../work/daybook_words.dart';
import 'note_draft.dart';
import 'note_page_editor.dart';
import 'notebook_page_screen.dart' show reminderWhen, todoDue;

/// The card the notebook's photos are prepared for ("Preparing…" slots).
const notePhotosCard = 'notebook';

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

/// A position's accuracy in whole metres, Western digits.
String gpsMetres(double? metres) => metres == null ? '' : '${metres.round()}';

/// The location's one line (NBX3; review 100 Part 6: "GPS" is never in
/// the app's words): "Gate 2 · on the map", the place alone, or "On the
/// map" for a pin alone.
String locationLabel(AppLocalizations l10n, NoteLocation l) => l.hasText
    ? (l.hasGps
          ? l10n.notebookShareLocation(l.text!.trim(), l10n.notebookOnMap)
          : l.text!.trim())
    : l10n.notebookOnMapOnly;

/// The note being written in place at the end of today (F106 NBW1, F107
/// NBX1–NBX4), on Work's writing card: white, a dashed action-colour edge,
/// "Now" on its first line. A page: its bold title and blocks
/// ([NotePageEditor]), then what is attached to the note (NBX3): the
/// location, the photos, the PDFs, the date and the reminder, each with
/// its ×. While not [writing] it is the Draft (NBW5), read only, and a tap
/// goes on writing.
class NoteWritingSlip extends ConsumerStatefulWidget {
  const NoteWritingSlip({
    super.key,
    required this.writing,
    required this.words,
    required this.onOpen,
    required this.onPickDue,
    required this.onPickRemind,
    required this.onLocation,
    required this.editorKey,
    required this.titleFocus,
    this.onCurrentKind,
    this.chip,
    this.onMoveLine,
    this.onLinesSelected,
    this.onLinesDeleted,
    this.shown,
    this.onMenu,
  });

  final bool writing;
  final DaybookWords words;
  final VoidCallback onOpen;
  final VoidCallback onPickDue;
  final VoidCallback onPickRemind;
  final VoidCallback onLocation;
  final GlobalKey<NotePageEditorState> editorKey;
  final FocusNode titleFocus;
  final ValueChanged<NoteBlockKind>? onCurrentKind;

  /// The page chip at its foot (review 99 A2, PG2), on New entry.
  final Widget? chip;

  /// The line menu's Move to page… (review 99 A4).
  final Future<bool> Function(List<PageBlock> lines)? onMoveLine;

  /// Lines selected and deleted while writing (review 100 BH12).
  final ValueChanged<int>? onLinesSelected;
  final void Function(List<String> lines, Future<bool> kept)? onLinesDeleted;

  /// A Draft put aside, shown read only (review 100 B3); null: the one in
  /// hand.
  final NoteDraft? shown;

  /// A Draft's ⋯ (review 100 B2: Discard).
  final VoidCallback? onMenu;

  @override
  ConsumerState<NoteWritingSlip> createState() => _NoteWritingSlipState();
}

class _NoteWritingSlipState extends ConsumerState<NoteWritingSlip> {
  late final NoteDraft _first = widget.shown ?? ref.read(noteDraftProvider)!;

  /// The card takes a body field; a page has none.
  final _noBody = TextEditingController();

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
    _noBody.dispose();
    super.dispose();
  }

  /// The keyboard comes up on the title of a new note, or on the line
  /// last written in.
  void _focusLater() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !widget.writing) return;
    final editor = widget.editorKey.currentState;
    if (_first.title.isEmpty || editor == null) {
      widget.titleFocus.requestFocus();
    } else {
      editor.focusCurrent();
    }
  });

  void _put(NoteDraft Function(NoteDraft d) change) {
    final d = ref.read(noteDraftProvider);
    if (d != null) _drafts.put(change(d));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final draft = widget.shown ?? ref.watch(noteDraftProvider);
    if (draft == null) return const SizedBox.shrink();
    final writing = widget.writing;
    final words = widget.words;
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final when = draft.editing == null
        ? l10n.notebookNow
        : words.time.clock(draft.editing!.createdAt);
    final card = BvWritingCard(
      key: const Key('note-writing-card'),
      bodyController: _noBody,
      bodyPlaceholder: '',
      showBody: false,
      padding: BvNoteWritingSpec.slipPadding,
      gap: BvNoteBlocksSpec.slipGap,
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvNoteBlocksSpec.slipGap,
        children: [
          Row(
            children: [
              Text(when, key: const Key('note-writing-now'), style: quiet),
              const Spacer(),
              if (!writing) _DraftPill(label: l10n.daybookDraft),
              if (!writing && widget.onMenu != null)
                const SizedBox(width: BvSize.iconLg),
            ],
          ),
          // H15: its own line under the head, never squeezed beside it.
          if (!writing && draft.changedElsewhere)
            Text(
              l10n.notebookChangedElsewhere,
              key: const Key('note-changed-elsewhere'),
              style: quiet.copyWith(color: BvColors.textWarning),
            ),
          NotePageEditor(
            key: widget.editorKey,
            title: _first.title,
            blocks: _first.blocks,
            writing: writing,
            titleFocus: widget.titleFocus,
            onTitleChanged: (t) => _put((d) => d.copyWith(title: t)),
            onChanged: (blocks) => _put((d) => d.copyWith(blocks: blocks)),
            onCurrentKind: widget.onCurrentKind,
            onMoveLine: widget.onMoveLine,
            onLinesSelected: widget.onLinesSelected,
            onLinesDeleted: widget.onLinesDeleted,
          ),
          NoteAdditions(
            draft: draft,
            words: words,
            writing: writing,
            preparing: ref.watch(photosPreparingProvider(notePhotosCard)),
            onLocation: widget.onLocation,
            onPickDue: widget.onPickDue,
            onPickRemind: widget.onPickRemind,
            onChange: _put,
          ),
          ?widget.chip,
        ],
      ),
      footer: writing
          ? null
          : Text(
              l10n.notebookDraftKept,
              key: const Key('note-draft-kept'),
              style: quiet,
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
    final draftCard = Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('note-draft'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: AbsorbPointer(child: card),
      ),
    );
    if (widget.onMenu == null) return draftCard;
    // Its ⋯ over the card, where taps reach it (review 100 B2).
    // TEMPORARY (D13): the redesign's swipe to Discard replaces it.
    return Stack(
      children: [
        draftCard,
        PositionedDirectional(
          top: BvNoteWritingSpec.slipPadding.top,
          end: BvNoteWritingSpec.slipPadding.end,
          child: Semantics(
            button: true,
            label: l10n.daybookMore,
            excludeSemantics: true,
            child: InkResponse(
              key: Key('note-draft-menu-${draft.id}'),
              onTap: widget.onMenu,
              radius: BvSize.iconLg,
              child: const SizedBox.square(
                dimension: BvSize.iconLg,
                child: Icon(
                  BvIcons.more,
                  size: BvSize.iconSm,
                  color: BvColors.iconSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// What is attached to the note being written (F107 NBX3), at the slip's
/// end: the location chip, the photos, each PDF's row, the date chip and
/// the reminder's, each with its × while writing.
class NoteAdditions extends ConsumerWidget {
  const NoteAdditions({
    super.key,
    required this.draft,
    required this.words,
    required this.writing,
    required this.onLocation,
    required this.onPickDue,
    required this.onPickRemind,
    required this.onChange,
    this.preparing = 0,
  });

  final NoteDraft draft;
  final DaybookWords words;
  final bool writing;
  final int preparing;
  final VoidCallback onLocation;
  final VoidCallback onPickDue;
  final VoidCallback onPickRemind;
  final void Function(NoteDraft Function(NoteDraft d) change) onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final location = draft.location;
    final parts = <Widget>[
      if (location != null && !location.isEmpty)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: NoteChip(
            key: const Key('note-location-chip'),
            icon: BvIcons.place,
            label: locationLabel(l10n, location),
            onTap: onLocation,
            removeLabel: l10n.notebookRemoveLocation,
            onRemove: writing
                ? () => onChange((d) => d.copyWith(location: () => null))
                : null,
          ),
        ),
      if (draft.photos.isNotEmpty || preparing > 0)
        SizedBox(
          key: const Key('note-photo-row'),
          height: BvNoteBlocksSpec.photoHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (i, p) in draft.photos.indexed)
                _Thumb(
                  index: i,
                  removeLabel: l10n.daybookRemovePhoto,
                  onRemove: writing
                      ? () => onChange(
                          (d) => d.copyWith(photos: [...d.photos]..removeAt(i)),
                        )
                      : null,
                  child: NotePhotoImage(photo: p),
                ),
              for (var i = 0; i < preparing; i++)
                _Thumb(
                  index: draft.photos.length + i,
                  child: BvPhotoPreparing(
                    label: l10n.photoPreparing,
                    compact: true,
                  ),
                ),
            ],
          ),
        ),
      for (final (i, f) in draft.files.indexed)
        NoteFileRow(
          key: Key('note-file-$i'),
          file: f,
          removeLabel: l10n.notebookRemoveFile,
          onRemove: writing
              ? () => onChange(
                  (d) => d.copyWith(files: [...d.files]..removeAt(i)),
                )
              : null,
        ),
      if (draft.dueAt != null || draft.remindAt != null)
        Wrap(
          key: const Key('note-chips'),
          spacing: BvNoteWritingSpec.chipsGap,
          runSpacing: BvNoteWritingSpec.chipsGap,
          children: [
            if (draft.dueAt case final due?)
              NoteChip(
                key: const Key('note-date-chip'),
                icon: BvIcons.due,
                label: todoDue(words, due, now),
                onTap: onPickDue,
                removeLabel: l10n.notebookRemoveDate,
                onRemove: writing
                    ? () => onChange((d) => d.copyWith(dueAt: () => null))
                    : null,
              ),
            if (draft.remindAt case final at?)
              NoteChip(
                key: const Key('note-remind-chip'),
                icon: BvIcons.remind,
                label: reminderChip(l10n, words, at, now),
                onTap: onPickRemind,
                removeLabel: l10n.notebookRemoveReminder,
                onRemove: writing
                    ? () => onChange((d) => d.copyWith(remindAt: () => null))
                    : null,
              ),
          ],
        ),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('note-additions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvNoteBlocksSpec.slipGap,
      children: parts,
    );
  }
}

/// A photo on the slip being written (NBX3): 76 × 64, radius 8, its ×
/// at the top end.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.index,
    required this.child,
    this.onRemove,
    this.removeLabel,
  });

  final int index;
  final Widget child;
  final VoidCallback? onRemove;
  final String? removeLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: BvNoteBlocksSpec.photoGap),
    child: SizedBox(
      key: Key('note-photo-$index'),
      width: BvNoteBlocksSpec.photoWidth,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BvNoteBlocksSpec.photoRadius, child: child),
          if (onRemove != null)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: Semantics(
                button: true,
                label: removeLabel,
                child: GestureDetector(
                  key: Key('note-photo-remove-$index'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(BvSpace.s4),
                    child: Container(
                      width: BvSize.iconMd,
                      height: BvSize.iconMd,
                      decoration: BoxDecoration(
                        color: BvColors.surfaceElevated.withValues(
                          alpha: BvWritingCardSpec.removeOpacity,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        BvIcons.close,
                        size: BvNoteWritingSpec.chipRemove,
                        color: BvColors.iconPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// A PDF's row (NBX3): its icon on a soft square, the name, " · 2.3 MB",
/// and × at the end.
class NoteFileRow extends StatelessWidget {
  const NoteFileRow({
    super.key,
    required this.file,
    this.onRemove,
    this.removeLabel,
  });

  final NoteFile file;
  final VoidCallback? onRemove;
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final size = fileSize(l10n, file.bytes);
    return Row(
      spacing: BvNoteBlocksSpec.fileGap,
      children: [
        Container(
          width: BvNoteBlocksSpec.fileBox,
          height: BvNoteBlocksSpec.fileBox,
          decoration: const BoxDecoration(
            color: BvColors.surfaceBrandSoft,
            borderRadius: BvNoteBlocksSpec.photoRadius,
          ),
          child: const Icon(
            BvIcons.document,
            size: BvNoteBlocksSpec.fileIcon,
            color: BvColors.iconAction,
          ),
        ),
        Flexible(
          child: Text(
            file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: directionOf(file.name),
            style: type.labelSm.copyWith(color: BvColors.textPrimary),
          ),
        ),
        if (size.isNotEmpty)
          Text(
            '· $size',
            style: type.metadata.copyWith(color: BvColors.textSecondary),
          ),
        const Spacer(),
        if (onRemove != null)
          BvTapTarget(
            child: Semantics(
              button: true,
              label: removeLabel,
              child: GestureDetector(
                key: const Key('note-file-remove'),
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: const Icon(
                  BvIcons.close,
                  size: BvNoteBlocksSpec.remove,
                  color: BvColors.iconSecondary,
                ),
              ),
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

/// A small grey pill with its icon and a × (NBW3, NBX3): the location, the
/// date, the reminder. A tap chooses again; the × takes it off.
class NoteChip extends StatelessWidget {
  const NoteChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.onRemove,
    this.removeLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final String? removeLabel;

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
              if (onRemove != null)
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
