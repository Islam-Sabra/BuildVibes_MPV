import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart'
    show LongPressGestureRecognizer, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart' show BvChatSpec, BvStroke;
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../core/photo_privacy.dart' show photosPreparingProvider;
import '../../core/l10n/bidi.dart';
import '../../core/network/signal_state.dart';
import '../../core/l10n/locale_controller.dart' show sharedPreferencesProvider;
import '../../core/push/reminders.dart' show phoneRemindersProvider;
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../data/models/note.dart';
import '../../data/models/notebook_page.dart';
import '../../data/models/post_page.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_back_swipe.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_line_popover.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_swipe_card.dart';
import '../../shared/widgets/bv_undo_bar.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import '../../shared/widgets/bv_writing_toolbar.dart';
import '../../shared/widgets/lazy_rows.dart';
import '../chat/thread_screen.dart' show ChatActionRow;
import '../chat/chat_state.dart' show keepFileProvider;
import '../chat/voice.dart';
import '../entry/entry_state.dart' show authUserIdProvider;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../work/daybook_draft.dart' show DaybookDraft;
import '../work/daybook_words.dart';
import '../library/library_parts.dart' show maxFileBytes, pickDocumentProvider;
import '../work/daybook_writing.dart'
    show newPostIdProvider, pickDueProvider, pickReminderProvider;
import '../work/work_outbox.dart' show keepPhotoProvider, pickPhotoProvider;
import 'note_draft.dart';
import 'note_filter.dart';
import 'note_share.dart';
import 'note_location.dart';
import 'note_outline.dart'
    show copiedBlock, numberAt, numberLabel, visibleLines;
import 'note_page_editor.dart';
import 'note_reminders.dart' show remindsAt;
import 'note_writing.dart';
import 'notebook_page_parts.dart';
import 'notebook_state.dart';

/// A page of My notebook (review 99A, PG4 2635:38121): the path from My
/// notebook, its icon and title (both edited in place), its pages at the
/// top, then its entries newest first, a day at a time, each on its slip.
/// Only its owner reads it. "Write in this page" writes an entry
/// (PG2 2635:37894, F106/F107): the slip alone above the additions bar,
/// + opening the categories in place of the keyboard; the bar attaches a
/// location, photos, PDFs, a date, a reminder or a voice block.
/// Long-press an entry, then tap others, to move them to another page.
///
/// [NotebookPageScreen.write] is "New entry" (A2): it opens writing at
/// once, the page chip under the entry (PG3: the page picker); Send goes
/// to the page it went into.
class NotebookPageScreen extends ConsumerStatefulWidget {
  const NotebookPageScreen({super.key, required String this.pageId, this.entry})
    : archived = false;

  const NotebookPageScreen.write({super.key})
    : pageId = null,
      entry = null,
      archived = false;

  /// "Archived ›" (review 100 Part 3b): the page's archived entries,
  /// newest first; swiped toward the start, Unarchive.
  const NotebookPageScreen.archived({
    super.key,
    required String this.pageId,
    this.entry,
  }) : archived = true;

  /// Null: "New entry".
  final String? pageId;

  /// An entry to show (a search hit, A5).
  final String? entry;

  final bool archived;

  @override
  ConsumerState<NotebookPageScreen> createState() => _NotebookPageScreenState();
}

/// What stands in place of the keyboard while writing (F107): the
/// location sheet; the block list and 📎 are cards over the bar (review
/// 100 Part 5).
enum _Panel { none, location }

/// The card open over the bar (review 100 Part 5): +, 📷 or 📎.
enum _BarCard { blocks, photo, add }

class _NotebookPageScreenState extends ConsumerState<NotebookPageScreen> {
  static const _tick = Duration(milliseconds: 200);

  bool _holding = false;
  bool _recording = false;
  bool _cancelling = false;
  Duration _elapsed = Duration.zero;
  Stopwatch? _watch;
  Timer? _recordTimer;

  /// F106: the slip at the end of today is being written, with the
  /// keyboard up and the tools above it.
  bool _writing = false;

  /// F107: the location sheet (NBX4) in place of the keyboard, and the
  /// kind the cursor's line is.
  _Panel _panel = _Panel.none;

  /// Review 100 Part 5: the bar's card that is open, over the bar, the
  /// keyboard kept up under it.
  final _barCard = BvLinePopover();
  _BarCard? _barOpen;
  final _barKey = GlobalKey();
  NoteBlockKind _kind = NoteBlockKind.text;

  /// B3: the camera, the files or a permission prompt is in front: the
  /// app going behind doesn't put the slip down.
  int _away = 0;

  final _slipKey = GlobalKey();
  final _editorKey = GlobalKey<NotePageEditorState>();

  /// Review 101 A: the page's rows built now, by index; and the row of the
  /// entry it was opened at.
  final _built = <int, BuildContext>{};
  int? _entryRow;
  final _titleFocus = FocusNode();
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    // The app going behind another, or closing: the slip is kept as the
    // Draft (it is already on the phone). Coming back, what waits goes
    // (B8).
    _life = AppLifecycleListener(
      onHide: () {
        if (_away == 0) _putDown();
      },
      onResume: () => unawaited(ref.read(notebookProvider.notifier).retry()),
    );
    // B8: the notebook opening sends what waits. "New entry" opens
    // writing at once (A2).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(notebookProvider.notifier).retry());
      // D1: an edit left open when the app closed opens again in the
      // editor, as the entry was when it was opened; nothing is sent until
      // the person goes Back (B2).
      final left = ref.read(noteDraftProvider)?.editing;
      if (left != null) {
        _editOpened = _shape(NoteDraft.of(left));
        unawaited(_goOn());
      } else if (widget.pageId == null) {
        unawaited(_write());
      }
      if (widget.archived) return;
    });
  }

  /// The page chip under the entry (A2): on New entry, and on a Draft
  /// begun for another page.
  bool _chip(NoteDraft draft) =>
      widget.pageId == null || draft.intoPage != widget.pageId;

  @override
  void dispose() {
    _edge?.cancel();
    _lifted?.remove();
    _picker.hide();
    _barCard.hide();
    _filterCard.hide();
    for (final f in _draftFocus.values) {
      f.dispose();
    }
    _pageTitle.dispose();
    _pageTitleFocus.dispose();
    _life.dispose();
    _titleFocus.dispose();
    _recordTimer?.cancel();
    if (_recording) unawaited(ref.read(voiceRecorderProvider).cancel());
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  DaybookWords _words() => DaybookWords(
    AppLocalizations.of(context),
    Localizations.localeOf(context).toLanguageTag(),
    use24: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  NoteDraftNotifier get _drafts => ref.read(noteDraftProvider.notifier);

  /// [run] with the app's own screen behind something else (B3).
  Future<T> _awayFor<T>(Future<T> Function() run) async {
    _away++;
    try {
      return await run();
    } finally {
      _away--;
    }
  }

  /// "Write in this page" or "New entry": a new slip, or the Draft again
  /// (one at a time), with the keyboard up. A new one goes into this page;
  /// on New entry, into the page the chip starts on: the last page used,
  /// or a new page on a fresh notebook (A2).
  Future<void> _write() async {
    // Review 100 B3: always a new entry. A Draft in hand is put aside as
    // its own card; an edit left open is saved in place first (B2).
    final held = ref.read(noteDraftProvider);
    if (held != null) {
      if (held.editing != null) {
        await _finishEdit(quiet: true);
      } else {
        await _drafts.park();
      }
    }
    if (ref.read(noteDraftProvider) == null) {
      final latest = ref.read(notebookProvider).value?.latest?.id;
      final page = widget.pageId ?? latest;
      await _drafts.put(
        NoteDraft(
          id: ref.read(newPostIdProvider)(),
          startedAt: ref.read(clockProvider)(),
          pageId: page,
          newPageId: page == null ? ref.read(newPostIdProvider)() : null,
        ),
      );
    }
    return _goOn();
  }

  /// The Draft in hand goes on being written, with the keyboard up.
  Future<void> _goOn() async {
    final draft = ref.read(noteDraftProvider);
    if (draft == null) return;
    if (draft.intoPage == null && widget.pageId != null) {
      // A Draft from before pages: it goes on in this page.
      await _change((d) => d.copyWith(pageId: () => widget.pageId));
    }
    if (!mounted) return;
    setState(() => _writing = true);
    _showSlip();
  }

  /// A Draft's card tapped: the one put aside [id] goes on.
  Future<void> _resume(String id) async {
    if (ref.read(noteDraftProvider)?.id != id) await _drafts.resume(id);
    _forgetCard(id);
    return _goOn();
  }

  /// A Draft's card is gone (it goes on in the slip, or it was discarded):
  /// its editor key and title focus too (D11), once the frame is drawn.
  void _forgetCard(String id) {
    _draftKeys.remove(id);
    final focus = _draftFocus.remove(id);
    if (focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => focus.dispose());
    }
  }

  /// Discard at the top bar's end (review 100 Part 0): the new entry
  /// being written is put down and thrown away, with "Discarded · Undo".
  Future<void> _discardWriting() async {
    final draft = ref.read(noteDraftProvider);
    if (draft == null || draft.editing != null) return;
    _closeBar();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _writing = false;
      _panel = _Panel.none;
    });
    await _discardDraft(draft, writing: true);
    if (widget.pageId == null && mounted) Navigator.of(context).maybePop();
  }

  /// A Draft's card swiped toward the start (review 100 Part 3b), or the
  /// entry being written discarded: gone, with Undo.
  Future<void> _discardDraft(NoteDraft draft, {bool writing = false}) async {
    final l10n = AppLocalizations.of(context);
    final parked = ref.read(parkedDraftsProvider.notifier);
    final inHand = ref.read(noteDraftProvider)?.id == draft.id;
    if (inHand) {
      // Its files stay until the Undo bar has gone.
      await _drafts.park();
    }
    await parked.drop(draft.id);
    _forgetCard(draft.id);
    if (!mounted) return;
    final bar = showBvUndoBar(
      context,
      message: writing ? l10n.notebookDiscarded : l10n.notebookDraftDiscarded,
      actionLabel: l10n.daybookUndo,
      onAction: () => unawaited(parked.keep(draft)),
      bottom: 0,
    );
    unawaited(
      bar.closed.then((why) {
        if (why == SnackBarClosedReason.action) return;
        for (final local in draftLocals(draft)) {
          unawaited(DaybookDraft.deleteKept(local));
        }
      }),
    );
  }

  /// What a saved entry being edited looks like, to tell a change (B2).
  static String _shape(NoteDraft d) => jsonEncode(
    d.toJson()
      ..remove('started_at')
      ..remove('editing'),
  );

  /// The edit as it was opened; null after the app was closed mid-edit.
  String? _editOpened;

  /// Back from a saved entry (review 100 B2): saved in place when it
  /// changed, with "Saved · Undo" (Undo puts back the entry as it was
  /// opened); nothing at all when it didn't. Never a Draft.
  Future<void> _finishEdit({bool quiet = false}) async {
    final draft = ref.read(noteDraftProvider);
    final was = draft?.editing;
    if (draft == null || was == null) return;
    final changed = _editOpened == null || _editOpened != _shape(draft);
    _editOpened = null;
    if (!changed) {
      await _drafts.discard();
      return;
    }
    if (!draft.ready) {
      // D3: emptied and left, it is deleted, with Undo (the Delete rules:
      // it goes when the bar closes). Held on the phone first, then the
      // Draft goes (D2).
      if (mounted) {
        await holdWithUndo(
          context,
          ref,
          // H5: to Deleted items, as every delete is (99B B3).
          NoteChange.deleteEntries([was.id], at: ref.read(clockProvider)()),
          AppLocalizations.of(context).notebookUndoDeleted,
        );
      }
      await _drafts.discard();
      return;
    }
    final note = _noteOf(draft);
    final notebook = ref.read(notebookProvider.notifier);
    // D2: the Draft goes only once the edit is in the phone's outbox.
    await notebook.saveOnPhone(note, baseVersion: was.version);
    await _drafts.discard(keepFiles: true);
    if (!quiet && mounted) {
      final l10n = AppLocalizations.of(context);
      showBvUndoBar(
        context,
        message: l10n.notebookSavedEdit,
        actionLabel: l10n.daybookUndo,
        onAction: () => unawaited(notebook.save(was)),
        bottom: 0,
      );
    }
  }

  /// Lines deleted from the entry being written (review 100 BH12): from a
  /// saved entry they go to Deleted items as "Part of an entry", held in
  /// the phone's outbox while their Undo bar shows (H6: an app closed then
  /// loses nothing), and sent when it goes; the edit then starts from the
  /// version that makes. Lines it never had (written in this edit) just go.
  void _linesDeleted(List<String> lines, Future<bool> kept) {
    final draft = ref.read(noteDraftProvider);
    final was = draft?.editing;
    if (draft == null || was == null) return;
    final saved = {for (final b in was.blocks ?? const <PageBlock>[]) b.id};
    if (!lines.every(saved.contains)) return;
    final notebook = ref.read(notebookProvider.notifier);
    unawaited(
      notebook
          .hold(
            NoteChange.deleteLines(
              was.id,
              lines,
              ref.read(newPostIdProvider)(),
            ),
          )
          .then((_) {
            _editMoved(was.id, gone: lines.toSet());
            return kept;
          })
          .then((yes) async {
            if (yes) return notebook.releaseHeld();
            // Undo: off the phone, and the edit starts where it was.
            if (await notebook.undoHeld()) {
              final d = ref.read(noteDraftProvider);
              if (d != null && d.editing?.id == was.id) {
                await _drafts.put(d.copyWith(editing: () => was));
              }
            }
          }),
    );
  }

  /// The entry being edited was saved meanwhile (lines went to Deleted
  /// items, or to another page): the edit goes on from the next version.
  void _editMoved(String id, {Set<String> gone = const {}}) {
    final d = ref.read(noteDraftProvider);
    final was = d?.editing;
    if (d == null || was == null || was.id != id) return;
    unawaited(
      _drafts.put(
        d.copyWith(
          editing: () => was.copyWith(
            version: was.version + 1,
            blocks: [
              for (final b in was.blocks ?? const <PageBlock>[])
                if (!gone.contains(b.id)) b,
            ],
          ),
        ),
      ),
    );
  }

  /// A refused note's words back (B15). D4: a refused edit of an entry
  /// the server still has stays an edit of it, back in the editor with its
  /// link; only a new entry comes back as its own Draft card (beside the
  /// one in hand, if any, B3).
  Future<void> _takeBack(Note lost, {bool elsewhere = false}) async {
    if (elsewhere) {
      // H15: changed on another phone meanwhile: its words come back as a
      // Draft of their own, marked; the entry stays as the server has it.
      final back = NoteDraft(
        id: ref.read(newPostIdProvider)(),
        startedAt: ref.read(clockProvider)(),
        title: lost.pageTitle,
        blocks: lost.pageBlocks,
        dueAt: lost.dueAt,
        remindAt: lost.remindAt,
        location: lost.location,
        pageId: lost.pageId,
        changedElsewhere: true,
      );
      await (ref.read(noteDraftProvider) == null
          ? _drafts.put(back)
          : ref.read(parkedDraftsProvider.notifier).keep(back));
      return;
    }
    NotebookData? data;
    try {
      data = await ref.read(notebookProvider.future);
    } on Object {
      data = null;
    }
    if (!mounted) return;
    final saved = data?.all.where((n) => n.id == lost.id).firstOrNull;
    if (saved != null) {
      final hand = ref.read(noteDraftProvider);
      if (hand != null && hand.id != lost.id) {
        if (hand.editing != null) {
          await _finishEdit(quiet: true);
        } else {
          await _drafts.park();
        }
      }
      final back = NoteDraft.back(lost, editing: saved);
      await _drafts.put(back);
      // Back with no new change leaves it as the server has it: never a
      // loop of refusals. Undo still gives back the saved entry.
      _editOpened = _shape(back);
      return _goOn();
    }
    final back = NoteDraft.back(
      lost,
    ).copyWith(photos: const [], files: const [], location: () => null);
    await (ref.read(noteDraftProvider) == null
        ? _drafts.put(back)
        : ref.read(parkedDraftsProvider.notifier).keep(back));
  }

  /// The entry to save from [draft]: in its page, with the pin as the
  /// notebook has it now (B14) and no reminder whose time went by (B16).
  Note _noteOf(NoteDraft draft) {
    final now = ref.read(clockProvider)();
    final data = ref.read(notebookProvider).value;
    var note = draft.toNote(now);
    final into = draft.intoPage ?? widget.pageId ?? data?.latest?.id;
    note = note.copyWith(pageId: into);
    final current = data?.all.where((n) => n.id == note.id).firstOrNull;
    if (current != null) note = note.copyWith(pinned: current.pinned);
    final remind = note.remindAt;
    if (remind != null && !remind.isAfter(now)) {
      note = note.copyWith(remindAt: () => null);
      _toast(AppLocalizations.of(context).notebookReminderGone);
    }
    return note;
  }

  // Review 102 N3: an entry held, then moved within its day.

  /// Each entry's row, measured when one is moved in its day.
  final _rowKeys = <String, GlobalKey>{};

  /// Each day's entries on the page, top to bottom, as last built.
  var _dayIds = <DateTime, List<String>>{};

  /// The entry held, and where the finger went down.
  ({String id, Offset at})? _held;

  /// The entry being moved, while it is; its lifted card and line, and the
  /// page scrolling by itself at an edge.
  _Arranging? _arranging;
  OverlayEntry? _lifted;
  Timer? _edge;

  bool _canArrange(Note n, bool selecting) =>
      !widget.archived && !selecting && !n.pinned;

  bool get _stillMotion => MediaQuery.of(context).disableAnimations;

  /// An entry's row: held and moved, it lands elsewhere in its day; held
  /// and let go, it is selected (as a long-press always did).
  Widget _arrangeable(
    Note n, {
    required bool selecting,
    required Widget Function() card,
    required Widget child,
  }) {
    final a = _arranging;
    final mine = a != null && a.day == dayOf(n.createdAt);
    final shift = mine && !_stillMotion ? a.shift(n.id) : 0.0;
    return KeyedSubtree(
      key: _rowKeys.putIfAbsent(n.id, GlobalKey.new),
      child: _ArrangeHold(
        enabled: _canArrange(n, selecting),
        onStart: (at) => _held = (id: n.id, at: at),
        onMove: (at) => _moveHeld(n, at, card),
        onEnd: () => _letGo(n),
        onCancel: _endArranging,
        child: AnimatedContainer(
          duration: a == null
              ? Duration.zero
              : BvNotebookPagesSpec.arrangeSlide,
          curve: BvMotion.standard,
          transform: Matrix4.translationValues(0, shift, 0),
          child: Opacity(
            opacity: mine && a.id == n.id && !_stillMotion ? 0 : 1,
            child: child,
          ),
        ),
      ),
    );
  }

  void _moveHeld(Note n, Offset at, Widget Function() card) {
    final held = _held;
    if (held == null || held.id != n.id) return;
    var a = _arranging;
    if (a == null) {
      if ((at - held.at).distance < kTouchSlop) return;
      a = _beginArranging(n, held.at, card);
      if (a == null) return;
    }
    a.finger = at.dy;
    _placeArranged(a);
  }

  /// The card lifts: every row of its day measured, where it was held.
  _Arranging? _beginArranging(Note n, Offset at, Widget Function() card) {
    final day = dayOf(n.createdAt);
    final ids = _dayIds[day];
    final held = _rowKeys[n.id]?.currentContext;
    if (ids == null || ids.length < 2 || held == null) return null;
    final position = Scrollable.maybeOf(held)?.position;
    if (position == null) return null;
    final rects = <String, Rect>{};
    for (final id in ids) {
      final box =
          _rowKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
      // A row not built (far off screen) can't be passed: the move waits.
      if (box == null || !box.attached || !box.hasSize) return null;
      final topLeft = box.localToGlobal(Offset.zero);
      rects[id] = Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy + position.pixels,
        box.size.width,
        box.size.height,
      );
    }
    final a = _Arranging(
      id: n.id,
      day: day,
      ids: ids,
      rects: rects,
      grab: at.dy + position.pixels - rects[n.id]!.top,
      position: position,
    )..finger = at.dy;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _arranging = a);
    final lifted = OverlayEntry(builder: (_) => _arrangedOverlay(card));
    _lifted = lifted;
    Overlay.of(context).insert(lifted);
    _edge = Timer.periodic(
      BvNotebookPagesSpec.arrangeFrame,
      (_) => _edgeScroll(),
    );
    return a;
  }

  /// Where it would land now; the others slide aside.
  void _placeArranged(_Arranging a) {
    final to = a.landing();
    if (to != a.to) {
      setState(() => a.to = to);
    }
    _lifted?.markNeedsBuild();
  }

  /// Near the list's top or bottom edge, the page scrolls by itself.
  void _edgeScroll() {
    final a = _arranging;
    if (a == null) return;
    final view = a.position.context.notificationContext?.findRenderObject();
    if (view is! RenderBox || !view.attached) return;
    final top = view.localToGlobal(Offset.zero).dy;
    final bottom = top + view.size.height;
    const edge = BvNotebookPagesSpec.arrangeEdge;
    final step = a.finger < top + edge
        ? -BvNotebookPagesSpec.arrangeStep
        : a.finger > bottom - edge
        ? BvNotebookPagesSpec.arrangeStep
        : 0.0;
    if (step == 0) return;
    final p = a.position;
    final to = (p.pixels + step).clamp(p.minScrollExtent, p.maxScrollExtent);
    if (to == p.pixels) return;
    p.jumpTo(to);
    _placeArranged(a);
  }

  /// The lifted card under the finger, and the line where it lands.
  Widget _arrangedOverlay(Widget Function() card) {
    final a = _arranging;
    if (a == null || !mounted) return const SizedBox.shrink();
    final px = a.position.pixels;
    final rect = a.rects[a.id]!;
    final landing = a.tops()[a.id]! - px - BvNotebookPagesSpec.entryGap / 2;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: rect.left,
            width: rect.width,
            top: landing - BvNotebookPagesSpec.arrangeLine / 2,
            height: BvNotebookPagesSpec.arrangeLine,
            child: const ColoredBox(
              key: Key('arrange-line'),
              color: BvColors.borderSelected,
            ),
          ),
          if (!_stillMotion)
            Positioned(
              left: rect.left,
              width: rect.width,
              top: a.top() - px,
              child: DecoratedBox(
                key: const Key('note-lifted'),
                decoration: const BoxDecoration(
                  borderRadius: BvNotebookPagesSpec.entryRadius,
                  boxShadow: BvShadow.slipLifted,
                ),
                child: Material(type: MaterialType.transparency, child: card()),
              ),
            ),
        ],
      ),
    );
  }

  /// Let go: moved, it lands; held and let go without a move, selected.
  void _letGo(Note n) {
    final a = _arranging;
    _held = null;
    if (a == null) {
      _select(n);
      return;
    }
    final before = a.ids;
    final after = a.order();
    _endArranging();
    if (!listEquals(before, after)) _arrange(after, undo: before);
  }

  void _endArranging() {
    _edge?.cancel();
    _edge = null;
    _lifted?.remove();
    _lifted = null;
    _held = null;
    if (_arranging != null && mounted) setState(() => _arranging = null);
  }

  /// The day's new order, saved, with "Moved · Undo".
  void _arrange(List<String> order, {required List<String> undo}) {
    final l10n = AppLocalizations.of(context);
    final notebook = ref.read(notebookProvider.notifier);
    unawaited(notebook.arrangeDay(order));
    showBvUndoBar(
      context,
      message: l10n.notebookUndoMoved,
      actionLabel: l10n.daybookUndo,
      onAction: () => unawaited(notebook.arrangeDay(undo)),
      bottom: 0,
    );
  }

  /// A screen reader's Move up and Move down, within the day.
  Map<CustomSemanticsAction, VoidCallback>? _moves(Note n, bool selecting) {
    if (!_canArrange(n, selecting)) return null;
    final ids = _dayIds[dayOf(n.createdAt)];
    if (ids == null || ids.length < 2) return null;
    final l10n = AppLocalizations.of(context);
    final i = ids.indexOf(n.id);
    List<String> moved(int step) {
      final o = [...ids]..removeAt(i);
      return o..insert(i + step, n.id);
    }

    return {
      if (i > 0)
        CustomSemanticsAction(label: l10n.notebookMoveUp): () =>
            _arrange(moved(-1), undo: ids),
      if (i < ids.length - 1)
        CustomSemanticsAction(label: l10n.notebookMoveDown): () =>
            _arrange(moved(1), undo: ids),
    };
  }

  /// Opened at an entry (from Filter or search): the page goes to it until
  /// it is built (review 101 A), then puts it near the top.
  Future<void> _showEntry() async {
    final row = _entryRow;
    final some = _built.values.where((c) => c.mounted).firstOrNull;
    final position = some == null ? null : Scrollable.maybeOf(some)?.position;
    if (row != null && position != null) {
      await scrollUntilBuilt(position, _built, row);
    }
    if (!mounted) return;
    final at = _entryKey.currentContext;
    if (at != null && at.mounted) {
      await Scrollable.ensureVisible(at, alignment: 0.2);
    }
  }

  /// The slip in view, its end above the bar (B10).
  void _showSlip() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final slip = _slipKey.currentContext;
    if (slip == null || !slip.mounted) return;
    unawaited(
      Scrollable.ensureVisible(
        slip,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: BvMotion.fast,
        curve: BvMotion.standard,
      ),
    );
  });

  /// Edit: the note's slip is written in place. A Draft left of another
  /// note goes on first (one at a time).
  Future<void> _edit(Note note) async {
    final draft = ref.read(noteDraftProvider);
    if (draft != null && draft.id != note.id) {
      if (draft.editing != null) {
        await _finishEdit(quiet: true);
      } else {
        await _drafts.park();
      }
    }
    if (ref.read(noteDraftProvider) == null) {
      final opened = NoteDraft.of(note);
      await _drafts.put(opened);
      _editOpened = _shape(opened);
    }
    return _goOn();
  }

  /// Back, the app going behind, or Send: the slip is put down. One with
  /// anything in it stays as the Draft (NBW5); an empty one is gone. Back
  /// on New entry goes back to the pages too.
  void _leave() {
    _putDown();
    if (widget.pageId != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  void _putDown() {
    if (!_writing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _writing = false;
      _panel = _Panel.none;
    });
    // B2: a saved entry is saved in place; only a new one is a Draft.
    if (ref.read(noteDraftProvider)?.editing != null) {
      unawaited(_finishEdit());
    } else {
      unawaited(_drafts.close());
    }
  }

  /// Send (it replaces Save): the note is kept in its page, and the slip
  /// is gone. "New page" makes the page with it, titled from its first
  /// line and marked new (A2). New entry then shows that page.
  Future<void> _send() async {
    final draft = ref.read(noteDraftProvider);
    if (draft == null || !draft.ready) return;
    final l10n = AppLocalizations.of(context);
    final data = ref.read(notebookProvider).value;
    final note = _noteOf(draft);
    final into = note.pageId;
    final made = draft.newPageId != null;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _writing = false;
      _panel = _Panel.none;
    });
    // B13: the note is on the phone's list before the draft goes.
    final saving = ref
        .read(notebookProvider.notifier)
        .save(note, newPageTitle: made ? draft.firstLine : null);
    await _drafts.discard(keepFiles: true);
    if (widget.pageId == null && into != null && mounted) {
      // Review 99 C5: back to the pages list, where the page shows at the
      // top (with its new mark), and "Saved in {page} · Open".
      final router = GoRouter.of(context);
      final into0 = data?.page(into);
      final name = made
          ? (draft.firstLine.isEmpty ? l10n.notebookUntitled : draft.firstLine)
          : into0 == null
          ? l10n.notebookMyNotes
          : pageName(l10n, into0);
      showBvUndoBar(
        context,
        message: l10n.notebookSavedIn(name),
        actionLabel: l10n.notebookOpen,
        onAction: () => router.push(AppRoutes.notebookPage(into)),
        bottom: 0,
      );
      Navigator.of(context).pop();
    }
    await saving;
  }

  Future<void> _change(NoteDraft Function(NoteDraft d) change) async {
    final draft = ref.read(noteDraftProvider);
    if (draft != null) await _drafts.put(change(draft));
  }

  /// One of the bar's cards (review 100 Part 5): it opens over its tool,
  /// the keyboard and the cursor kept (B4.5); a second tap on the tool, a
  /// tap elsewhere or Back closes it.
  void _openBar(_BarCard card) {
    if (_barOpen == card) return _closeBar();
    _closeBar();
    if (card == _BarCard.blocks) {
      // Review 98: the list is for a new line below this one (an empty text
      // line is turned itself).
      _editorKey.currentState?.lineForGrid();
    }
    setState(() {
      _kind = _editorKey.currentState?.currentKind ?? _kind;
      _barOpen = card;
    });
    _barCard.show(
      context,
      // Over the bar, from its start (BH7, BH8).
      anchor: () => _barKey.currentContext,
      above: true,
      barrier: true,
      onDismiss: _closeBar,
      builder: (context) => switch (card) {
        _BarCard.blocks =>
          _editorKey.currentState?.blockList(onPick: _pickKind) ??
              const SizedBox.shrink(),
        _BarCard.photo => _photoCard(context),
        _BarCard.add => _addCard(context),
      },
    );
  }

  void _closeBar() {
    if (_barOpen == null && !_barCard.isOpen) return;
    _barCard.hide();
    if (mounted) setState(() => _barOpen = null);
  }

  /// A kind from the block list: inserted, or the empty line turned; the
  /// keyboard stays.
  void _pickKind(NoteBlockKind kind) {
    _closeBar();
    _editorKey.currentState?.insertKind(kind);
  }

  /// A reminder's short value (review 100 H9): "7:00 am" today, "Tomorrow
  /// 7:00 am", "Fri 7:00 am" within the week, else "Thu 29 Oct 7:00 am".
  static String _shortWhen(
    AppLocalizations l10n,
    DaybookWords words,
    DateTime at,
    DateTime now,
  ) {
    final day = dayOf(at);
    final today = dayOf(now);
    final time = words.time.clock(at);
    if (day == today) return time;
    return l10n.notebookShortWhen(
      day == today.add(const Duration(days: 1))
          ? l10n.notebookTomorrow
          : day.difference(today).inDays < DateTime.daysPerWeek
          ? words.shortWeekday(day)
          : words.shortDate(day),
      time,
    );
  }

  /// 📷 (review 100 Part 5): Camera or Gallery, as today's Image.
  Widget _photoCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BvPopoverMenu<bool>.line(
      key: const Key('note-image-menu'),
      items: [
        BvMenuItem(
          key: const Key('note-image-camera'),
          value: true,
          label: l10n.daybookCamera,
          icon: BvIcons.camera,
        ),
        BvMenuItem(
          key: const Key('note-image-gallery'),
          value: false,
          label: l10n.daybookAttachPhotos,
          icon: BvIcons.image,
        ),
      ],
      onSelected: (camera) {
        _closeBar();
        unawaited(_addPhoto(camera: camera));
      },
    );
  }

  /// 📎 Add (review 100 BH7): File · Location · Date · Reminder; a row
  /// with a value shows it at its end, with a ✕ that takes it off.
  Widget _addCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draft = ref.watch(noteDraftProvider);
    if (draft == null) return const SizedBox.shrink();
    final words = _words();
    final now = ref.read(clockProvider)();
    final location = draft.location;
    final due = draft.dueAt;
    final remind = draft.remindAt;
    void clear(NoteDraft Function(NoteDraft d) change) {
      _closeBar();
      unawaited(_change(change));
    }

    return BvPopoverMenu<String>.line(
      key: const Key('note-add-menu'),
      tiles: false,
      items: [
        BvMenuItem(
          key: const Key('note-add-file'),
          value: 'file',
          label: l10n.notebookFile,
          icon: BvIcons.document,
          detail: draft.files.isEmpty
              ? null
              : l10n.notebookFileCount(draft.files.length),
          // H16: its ✕ takes the files off, as Location's and Reminder's.
          onClear: draft.files.isEmpty
              ? null
              : () => clear((d) => d.copyWith(files: const [])),
          clearKey: const Key('note-add-file-clear'),
          clearLabel: l10n.notebookRemove,
        ),
        BvMenuItem(
          key: const Key('note-add-location'),
          value: 'location',
          label: l10n.notebookLocation,
          icon: BvIcons.place,
          detail: location == null || location.isEmpty
              ? null
              : locationLabel(l10n, location),
          onClear: location == null || location.isEmpty
              ? null
              : () => clear((d) => d.copyWith(location: () => null)),
          clearKey: const Key('note-add-location-clear'),
          clearLabel: l10n.notebookRemove,
        ),
        BvMenuItem(
          key: const Key('note-add-date'),
          value: 'date',
          label: l10n.notebookDate,
          icon: BvIcons.due,
          detail: due == null ? null : todoDue(words, due, now),
          onClear: due == null
              ? null
              : () => clear((d) => d.copyWith(dueAt: () => null)),
          clearKey: const Key('note-add-date-clear'),
          clearLabel: l10n.notebookRemove,
        ),
        BvMenuItem(
          key: const Key('note-add-remind'),
          value: 'remind',
          label: l10n.notebookReminder,
          icon: BvIcons.remind,
          detail: remind == null ? null : _shortWhen(l10n, words, remind, now),
          onClear: remind == null
              ? null
              : () => clear((d) => d.copyWith(remindAt: () => null)),
          clearKey: const Key('note-add-remind-clear'),
          clearLabel: l10n.notebookRemove,
        ),
      ],
      onSelected: (row) {
        _closeBar();
        switch (row) {
          case 'file':
            unawaited(_addFile());
          case 'location':
            _toggleLocation();
          case 'date':
            unawaited(_pickDue());
          case 'remind':
            unawaited(_pickRemind());
        }
      },
    );
  }

  /// Location (NBX4): its sheet, or closed again.
  void _toggleLocation() {
    if (_panel == _Panel.location) {
      _closeLocation();
      return;
    }
    // D8 (B4.5): the keyboard stays up, the cursor kept.
    setState(() => _panel = _Panel.location);
  }

  void _closeLocation() {
    setState(() => _panel = _Panel.none);
    _editorKey.currentState?.focusCurrent();
  }

  /// Date (NBX3): the daybook's day-and-time picker; a day with no time
  /// is kept at the day's start, and reads as the day.
  Future<void> _pickDue() async {
    final draft = ref.read(noteDraftProvider);
    if (draft == null) return;
    final due = draft.dueAt;
    final picked = await ref.read(pickDueProvider)(
      context,
      now: ref.read(clockProvider)(),
      day: due == null ? null : dayOf(due),
      at: due,
    );
    if (picked == null || !mounted) return;
    final day = picked.day;
    await _change(
      (d) => d.copyWith(dueAt: () => day == null ? null : picked.at ?? day),
    );
  }

  /// Remind me: as on a saved note's menu, a day and a time (no time is
  /// that morning), never one gone by.
  Future<void> _pickRemind() async {
    final draft = ref.read(noteDraftProvider);
    if (draft == null) return;
    final at = await _askReminder(draft.remindAt);
    if (at == null || !mounted) return;
    await _change((d) => d.copyWith(remindAt: () => at.value));
  }

  /// A reminder picked with its own picker (B5); `(value: null)` is
  /// Remove, null is cancelled or a time gone by.
  Future<({DateTime? value})?> _askReminder(DateTime? kept) async {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider)();
    final picked = await ref.read(pickReminderProvider)(
      context,
      now: now,
      day: kept == null ? null : dayOf(kept),
      at: kept,
    );
    if (!mounted || picked == null) return null;
    final day = picked.day;
    final at = day == null
        ? null
        : picked.at ?? DateTime(day.year, day.month, day.day, _morningHour);
    if (at != null && !at.isAfter(now)) {
      _toast(l10n.notebookRemindPast);
      return null;
    }
    if (at != null) await _offerExact();
    return (value: at);
  }

  static const _exactAskedKey = 'notebook_exact_asked';

  /// The first Remind me, on a phone that keeps alarms inexact (Android
  /// 12+): asked once, with one line why, to allow exact alarms in the
  /// phone's own setting. Refused or not now, reminders stay inexact.
  Future<void> _offerExact() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final reminders = ref.read(phoneRemindersProvider);
    if (prefs.getBool(_exactAskedKey) ?? false) return;
    if (await reminders.canBeExact()) return;
    await prefs.setBool(_exactAskedKey, true);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final open = await showBvDialog(
      context: context,
      title: l10n.notebookExactTitle,
      body: l10n.notebookExactBody,
      cancelLabel: l10n.notebookExactNotNow,
      confirmLabel: l10n.notebookExactOpen,
    );
    if (open) await reminders.openExactSetting();
  }

  /// Image (NBX3): the camera or the gallery, made safe to leave the
  /// phone (cleanPhoto, F60) and kept in the app's folder until it is
  /// sent; at most 10 on a note.
  Future<void> _addPhoto({required bool camera}) async {
    final l10n = AppLocalizations.of(context);
    final draft = ref.read(noteDraftProvider);
    if (draft == null) return;
    if (draft.photos.length >= Note.photosMax) {
      _toast(l10n.notebookPhotosFull);
      return;
    }
    final picked = await _awayFor(
      () => ref.read(pickPhotoProvider)(
        camera: camera,
        onPreparing: ref
            .read(photosPreparingProvider(notePhotosCard).notifier)
            .set,
      ),
    );
    final kept = [
      for (final p in picked.photos) await ref.read(keepPhotoProvider)(p),
    ];
    if (kept.isNotEmpty) {
      await _change(
        (d) => d.copyWith(
          photos: [
            ...d.photos,
            for (final k in kept) NotePhoto(local: k),
          ].take(Note.photosMax).toList(),
        ),
      );
    }
    if (!mounted) return;
    if (picked.refused > 0) _toast(l10n.photoCannotOpen);
    _back();
  }

  /// File (NBX3): a PDF from the phone, up to the Library's 25 MB; at
  /// most 10 on a note.
  Future<void> _addFile() async {
    final l10n = AppLocalizations.of(context);
    final draft = ref.read(noteDraftProvider);
    if (draft == null) return;
    if (draft.files.length >= Note.filesMax) {
      _toast(l10n.notebookFilesFull);
      return;
    }
    final picked = await _awayFor(
      () => ref.read(pickDocumentProvider)(pdfOnly: true),
    );
    final file = picked.file;
    if (!mounted || file == null || !file.isPdf) return _back();
    if ((file.bytes ?? 0) > maxFileBytes) {
      _toast(l10n.chatFileTooBig);
      return _back();
    }
    final local = await ref.read(keepFileProvider)(file.local, 'pdf');
    await _change(
      (d) => d.copyWith(
        files: [
          ...d.files,
          NoteFile(local: local, name: file.name, bytes: file.bytes),
        ].take(Note.filesMax).toList(),
      ),
    );
    if (mounted) _back();
  }

  /// Back from a picker: still writing, the keyboard on the line (B3).
  void _back() {
    if (!mounted || !_writing) return;
    _editorKey.currentState?.focusCurrent();
    _showSlip();
  }

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context);
    final recorder = ref.read(voiceRecorderProvider);
    _holding = true;
    await ref.read(voicePlayerProvider.notifier).pause();
    if (!await _awayFor(recorder.allowed)) {
      if (mounted) _toast(l10n.chatMicDenied);
      return;
    }
    if (!_holding || !mounted) return;
    await recorder.start();
    if (!_holding || !mounted) {
      await recorder.cancel();
      return;
    }
    _watch = clock.stopwatch()..start();
    setState(() {
      _recording = true;
      _cancelling = false;
      _elapsed = Duration.zero;
    });
    _recordTimer = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      setState(() => _elapsed = _watch!.elapsed);
      if (_elapsed >= maxVoice) unawaited(_endRecording());
    });
  }

  void _slide(Offset offset) {
    final cancelling = offset.distance > BvChatSpec.slideToCancel;
    if (cancelling != _cancelling) setState(() => _cancelling = cancelling);
  }

  /// Release: keep it; slid away: throw it away. While a slip is written
  /// (the Voice addition, F107) it is a voice block inside the note;
  /// otherwise a voice note of its own.
  Future<void> _endRecording() async {
    _holding = false;
    _recordTimer?.cancel();
    if (!_recording) return;
    final l10n = AppLocalizations.of(context);
    final recorder = ref.read(voiceRecorderProvider);
    final measured = _watch?.elapsed ?? _elapsed;
    final length = measured > maxVoice ? maxVoice : measured;
    final cancel = _cancelling;
    setState(() {
      _recording = false;
      _cancelling = false;
    });
    if (cancel) {
      await recorder.cancel();
      return;
    }
    final path = await recorder.stop();
    if (!mounted || path == null) return;
    if (length < minVoice) {
      _toast(l10n.notebookTooShort);
      return;
    }
    final editor = _editorKey.currentState;
    if (_writing && editor != null) {
      editor.insertVoice(
        PageVoice(
          ref.read(newPostIdProvider)(),
          local: path,
          durationMs: length.inMilliseconds,
        ),
      );
      return;
    }
    final file = File(path);
    await ref
        .read(notebookProvider.notifier)
        .save(
          Note(
            id: ref.read(newPostIdProvider)(),
            kind: NoteKind.voice,
            createdAt: ref.read(clockProvider)(),
            recording: NoteRecording(
              local: path,
              bytes: file.existsSync() ? file.lengthSync() : null,
              durationMs: length.inMilliseconds,
            ),
            pageId: widget.pageId ?? ref.read(noteDraftProvider)?.intoPage,
          ),
        );
  }

  /// A menu is open (review 100 B5): nothing opens a second one behind it.
  bool _menuOpen = false;

  /// [open] unless a menu is open already; the next one may open once it
  /// has closed.
  Future<void> _oneMenu(Future<void> Function() open) async {
    if (_menuOpen) return;
    _menuOpen = true;
    try {
      await open();
    } finally {
      _menuOpen = false;
    }
  }

  /// Remind me: a day and a time (the reminder's picker; no time is 9 am),
  /// or Remove. Saved as the note's remind_at; this phone sets the
  /// reminder (ReminderHost).
  Future<void> _remind(Note note) async {
    final at = await _askReminder(note.remindAt);
    if (at == null || !mounted) return;
    await ref
        .read(notebookProvider.notifier)
        .save(note.copyWith(remindAt: () => at.value));
  }

  /// Archive or Unarchive (review 100 Part 3b): at once, with Undo for
  /// 5 s; then it goes.
  Future<void> _archive(Note note, {required bool on}) {
    final l10n = AppLocalizations.of(context);
    return holdWithUndo(
      context,
      ref,
      NoteChange.archive(note.id, on: on, at: ref.read(clockProvider)()),
      on ? l10n.notebookArchivedUndo : l10n.notebookUnarchivedUndo,
    );
  }

  /// The swipe's one-time hint (review 100 Part 3b), kept on the phone,
  /// and whether this page has shown it.
  String get _hintKey =>
      'notebook_swipe_hint:${ref.read(authUserIdProvider).value ?? ''}';
  bool _hinted = false;

  /// A reminder picked with no time: that morning.
  static const _morningHour = 9;

  /// A copy of an entry's photo of its own (a copy, or a share), which
  /// may be deleted once sent; null when it can't be had.
  Future<String?> _photoCopy(NotePhoto p) async {
    try {
      final local = p.local;
      if (local != null && File(local).existsSync()) {
        return await ref.read(keepPhotoProvider)(XFile(local));
      }
      final path = p.path;
      if (path == null) return null;
      final bytes = await ref.read(notebookRepositoryProvider).download(path);
      return await ref.read(keepPhotoProvider)(
        XFile.fromData(bytes, mimeType: p.mime, name: 'photo.jpg'),
      );
    } on Object {
      return null;
    }
  }

  /// Each Draft card's own editor and title, read only (B3).
  final _draftKeys = <String, GlobalKey<NotePageEditorState>>{};
  final _draftFocus = <String, FocusNode>{};

  /// Entries selected (A4: long-press one, then tap others).
  final Set<String> _selected = {};

  /// The page's title, edited in place (A3).
  final _pageTitle = TextEditingController();
  final _pageTitleFocus = FocusNode();
  String? _titleOf;

  /// The page has been marked opened (A2), and the search hit shown.
  bool _opened = false;
  bool _shownEntry = false;
  final _entryKey = GlobalKey();

  /// The page a Filter starts with: this one (review 100 Part 8).
  String? get _filterHome => widget.pageId;

  /// The Filter (review 100 Part 8), its card and its button; the card
  /// ends where the top bar's last action does (H10, BH9).
  late NoteFilterState _filter = NoteFilterState(page: widget.pageId);
  final _filterCard = BvLinePopover();
  final _filterKey = GlobalKey();

  /// This page's sort (review 102 N5), kept on the phone for it alone; an
  /// archive shows newest first.
  late var _sort = widget.pageId == null || widget.archived
      ? EntrySort.newest
      : EntrySort.of(
          ref
              .read(sharedPreferencesProvider)
              .getString(entrySortKey(widget.pageId!)),
        );

  void _setSort(EntrySort sort) {
    final page = widget.pageId;
    if (page == null) return;
    setState(() => _sort = sort);
    final prefs = ref.read(sharedPreferencesProvider);
    if (sort == EntrySort.newest) {
      unawaited(prefs.remove(entrySortKey(page)));
    } else {
      unawaited(prefs.setString(entrySortKey(page), sort.json));
    }
  }

  void _openFilter(NotebookData data, {bool pages = false}) {
    if (_filterCard.isOpen) return _filterCard.hide();
    showNoteFilter(
      context,
      _filterCard,
      anchor: () => _filterKey.currentContext,
      data: data,
      filter: _filter,
      pages: pages,
      onChanged: (f) => setState(() => _filter = f),
      sorts: widget.archived ? const [] : EntrySort.values,
      sort: _sort,
      onSort: (s) => _setSort(s as EntrySort),
    );
  }

  Widget _filterButton(NotebookData data, String key) => NoteFilterButton(
    key: Key(key),
    on: _filter.on,
    onPressed: () => _openFilter(data),
  );

  /// The chips and the entries found, while the Filter is on.
  Widget _filtered(NotebookData data) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      NoteFilterChips(
        data: data,
        filter: _filter,
        onClear: () =>
            setState(() => _filter = NoteFilterState(page: _filterHome)),
        onPage: () => _openFilter(data, pages: true),
      ),
      Expanded(
        child: NoteFilterResults(data: data, filter: _filter),
      ),
    ],
  );

  /// The page chip's picker (PG3), over the slip.
  final _picker = BvLinePopover();
  final _chipKey = GlobalKey();

  /// Move to page… (A4): entries into a page picked on a sheet, or into a
  /// new one titled from the first of them.
  Future<void> _moveEntries(List<Note> notes) async {
    final l10n = AppLocalizations.of(context);
    final data = ref.read(notebookProvider).value;
    if (data == null || notes.isEmpty) return;
    final from = data.pageOf(notes.first);
    final pick = await showPagePickerSheet(
      context,
      data: data,
      title: l10n.notebookMoveToPage,
      current: from,
    );
    if (pick == null || !mounted) return;
    final notebook = ref.read(notebookProvider.notifier);
    final String to;
    if (pick.kind == PagePickKind.newPage) {
      to = ref.read(newPostIdProvider)();
      final at = ref.read(clockProvider)();
      await notebook.newPage(
        NotebookPage(
          id: to,
          title: entryFirstLine(notes.first),
          createdAt: at,
          lastActivityAt: at,
        ),
      );
    } else {
      to = pick.id!;
    }
    await notebook.moveNotes([for (final n in notes) n.id], to);
    if (!mounted) return;
    setState(_selected.clear);
    final page = ref.read(notebookProvider).value?.page(to);
    // Review 100 Part 3: "Moved to {page} · Open".
    final router = GoRouter.of(context);
    showBvUndoBar(
      context,
      message: l10n.notebookMovedTo(
        page == null ? l10n.notebookNewPage : pageName(l10n, page),
      ),
      actionLabel: l10n.notebookOpen,
      onAction: () => router.push(AppRoutes.notebookPage(to)),
      bottom: 0,
    );
  }

  /// Duplicate (review 100 Part 3): a copy right under each, with the same
  /// time (ruling 6: no "Copy" mark); its reminder isn't copied, so nobody gets two
  /// alarms. Undo for 5 s.
  Future<void> _duplicateSelected(List<Note> notes) async {
    final l10n = AppLocalizations.of(context);
    setState(_selected.clear);
    final copies = [for (final n in notes) await _copyOf(n)];
    if (!mounted) return;
    await holdWithUndo(
      context,
      ref,
      NoteChange.duplicate([for (final n in notes) n.id], copies),
      l10n.notebookUndoDuplicated,
    );
  }

  /// [note] as a new entry: its lines with new ids, no reminder; its
  /// photos, files and recordings as copies of their own (each file
  /// belongs to its entry on the server), those that can be had.
  Future<Note> _copyOf(Note note) async {
    String id() => ref.read(newPostIdProvider)();
    final photos = <NotePhoto>[];
    for (final p in note.photos) {
      final local = await _photoCopy(p);
      if (local != null) photos.add(NotePhoto(local: local));
    }
    final blocks = <PageBlock>[];
    for (final b in note.blocks ?? const <PageBlock>[]) {
      if (b case PageVoice(:final path?)) {
        final local = await _fileCopy(path, b.local, 'm4a');
        if (local != null) {
          blocks.add(PageVoice(id(), local: local, durationMs: b.durationMs));
        }
        continue;
      }
      blocks.add(copiedBlock(b, id));
    }
    final files = <NoteFile>[];
    for (final f in note.files) {
      final local = await _fileCopy(f.path, f.local, 'pdf');
      if (local != null) {
        files.add(NoteFile(local: local, name: f.name, bytes: f.bytes));
      }
    }
    return Note(
      id: id(),
      kind: note.kind,
      createdAt: note.createdAt,
      body: note.body,
      points: note.points,
      dueAt: note.dueAt,
      title: note.title,
      blocks: note.blocks == null ? null : blocks,
      location: note.location,
      photos: photos,
      files: files,
      pageId: note.pageId,
    );
  }

  /// A file of an entry as a copy of its own on the phone; null when it
  /// can't be had (no signal).
  Future<String?> _fileCopy(
    String? path,
    String? local,
    String extension,
  ) async {
    try {
      if (local != null && File(local).existsSync()) {
        return await ref.read(keepFileProvider)(local, extension);
      }
      if (path == null) return null;
      final bytes = await ref.read(notebookRepositoryProvider).download(path);
      final temp = File(
        '${Directory.systemTemp.path}/${ref.read(newPostIdProvider)()}.$extension',
      );
      await temp.writeAsBytes(bytes);
      return await ref.read(keepFileProvider)(temp.path, extension);
    } on Object {
      return null;
    }
  }

  /// A line with its children, from the line menu (A4): a new entry of
  /// its own in the page picked (or a new page titled from it).
  Future<bool> _moveLine(List<PageBlock> lines) async {
    final l10n = AppLocalizations.of(context);
    final data = ref.read(notebookProvider).value;
    if (data == null || lines.isEmpty) return false;
    final from = ref.read(noteDraftProvider)?.intoPage ?? widget.pageId;
    final pick = await showPagePickerSheet(
      context,
      data: data,
      title: l10n.notebookMoveToPage,
      current: from,
    );
    if (pick == null || !mounted) return false;
    final notebook = ref.read(notebookProvider.notifier);
    final at = ref.read(clockProvider)();
    final words = blockWords(lines.first);
    String? newTitle;
    final String to;
    if (pick.kind == PagePickKind.newPage) {
      to = ref.read(newPostIdProvider)();
      newTitle = words.isEmpty ? '' : words.first;
    } else {
      to = pick.id!;
    }
    await notebook.save(
      Note(
        id: ref.read(newPostIdProvider)(),
        kind: NoteKind.text,
        createdAt: at,
        blocks: lines,
        body: pageDigest('', lines),
        pageId: to,
      ),
      newPageTitle: newTitle,
    );
    // Review 99 C6: the entry it left is saved as it now stands, so a
    // discard can't leave the part in both pages. A brand-new entry has
    // nothing saved yet: the part only leaves the draft.
    final draft = ref.read(noteDraftProvider);
    final was = draft?.editing;
    if (draft != null && was != null) {
      final gone = {for (final b in lines) b.id};
      final left = draft
          .copyWith(
            blocks: [
              for (final b in draft.blocks)
                if (!gone.contains(b.id)) b,
            ],
          )
          .toNote(was.createdAt);
      final current = ref
          .read(notebookProvider)
          .value
          ?.all
          .where((n) => n.id == was.id)
          .firstOrNull;
      await notebook.save(
        left.copyWith(
          pageId: draft.intoPage ?? was.pageId,
          pinned: current?.pinned ?? was.pinned,
        ),
      );
      _editMoved(was.id);
    }
    if (!mounted) return true;
    final page = ref.read(notebookProvider).value?.page(to);
    _toast(
      l10n.notebookMovedTo(
        page == null ? l10n.notebookNewPage : pageName(l10n, page),
      ),
    );
    return true;
  }

  /// Delete the selected entries (review 100 Part 3): gone at once with
  /// Undo for 5 s, kept in the phone's outbox, then in Deleted items (99B).
  Future<void> _deleteSelected(List<Note> notes) async {
    final l10n = AppLocalizations.of(context);
    setState(_selected.clear);
    await holdWithUndo(
      context,
      ref,
      NoteChange.deleteEntries([
        for (final n in notes) n.id,
      ], at: ref.read(clockProvider)()),
      l10n.notebookUndoDeleted,
    );
  }

  /// How many lines of the entry being written are selected (BH12).
  int _linesPicked = 0;

  /// The selection bar, where Share's card opens (BH4).
  final _selectionBarKey = GlobalKey();

  /// Share (review 100 Part 6) on one entry.
  void _shareEntry(Note note) => unawaited(
    shareEntry(
      context,
      ref,
      note: note,
      card: _barCard,
      anchor: () => _selectionBarKey.currentContext,
      onDone: () {
        if (mounted) setState(_selected.clear);
      },
    ),
  );

  /// The saved entry the selected lines are shared from: a new entry,
  /// not sent yet, has nothing on the server to share in part.
  Note? _linesSaved() => ref.read(noteDraftProvider)?.editing;

  /// Share on selected lines (BH12): the line with the lines under it,
  /// once the edit in hand is saved in place (H2).
  void _shareLines(Note saved) {
    final editor = _editorKey.currentState;
    if (editor == null) return;
    unawaited(
      shareEntry(
        context,
        ref,
        note: saved,
        lines: editor.selectedLines(),
        card: _barCard,
        anchor: () => _selectionBarKey.currentContext,
        saved: _saveInPlace,
        onDone: () => _editorKey.currentState?.endLineSelection(),
      ),
    );
  }

  /// The edit in hand saved in place, writing going on (review 100 H2):
  /// the entry as it now is, the edit then starting from its next version.
  Future<Note?> _saveInPlace() async {
    final draft = ref.read(noteDraftProvider);
    final was = draft?.editing;
    if (draft == null || was == null) return null;
    if (_editOpened == _shape(draft)) return was;
    final note = _noteOf(draft);
    await ref
        .read(notebookProvider.notifier)
        .saveOnPhone(note, baseVersion: was.version);
    final now = note.copyWith(version: was.version + 1);
    final kept = draft.copyWith(editing: () => now);
    await _drafts.put(kept);
    _editOpened = _shape(kept);
    return now;
  }

  /// Move (BH12): the selected lines, with the lines under them, become
  /// an entry of their own in the page picked; they leave this one.
  Future<void> _moveLines() async {
    final editor = _editorKey.currentState;
    if (editor == null) return;
    final ids = editor.selectedLineIds;
    final moved = await _moveLine(editor.selectedLines());
    if (moved && mounted) _editorKey.currentState?.removeLines(ids);
  }

  /// A long-press selects an entry; while selecting, a tap adds or
  /// takes one away.
  void _select(Note note) => setState(() {
    if (!_selected.remove(note.id)) _selected.add(note.id);
  });

  /// The title, kept when it changed (A3).
  void _keepTitle(NotebookPage page) {
    final title = _pageTitle.text.trim();
    if (title == page.title.trim()) return;
    unawaited(
      ref.read(notebookProvider.notifier).editPage(page.copyWith(title: title)),
    );
  }

  Future<void> _pickIcon(NotebookPage page) async {
    final icon = await showPageIconSheet(context, page.icon);
    if (icon == null || icon == page.icon || !mounted) return;
    await ref
        .read(notebookProvider.notifier)
        .editPage(page.copyWith(title: _pageTitle.text.trim(), icon: icon));
  }

  /// A page's ⋯ (A3, A4): a page inside it, Pin, Move into… and Delete.
  Future<void> _pageMenu(NotebookPage page) =>
      _oneMenu(() => _openPageMenu(page));

  Future<void> _openPageMenu(NotebookPage page) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showBvSheet<String>(
      context: context,
      builder: (sheet) => Column(
        key: const Key('page-menu'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChatActionRow(
            key: const Key('page-menu-sub'),
            icon: BvIcons.add,
            label: l10n.notebookNewSubPage,
            onTap: () => Navigator.of(sheet).pop('sub'),
          ),
          ChatActionRow(
            key: const Key('page-menu-pin'),
            icon: BvIcons.pin,
            label: page.pinned ? l10n.daybookUnpin : l10n.notebookPinPage,
            onTap: () => Navigator.of(sheet).pop('pin'),
          ),
          ChatActionRow(
            key: const Key('page-menu-move'),
            icon: BvIcons.moveInto,
            label: l10n.notebookMoveInto,
            onTap: () => Navigator.of(sheet).pop('move'),
          ),
          ChatActionRow(
            key: const Key('page-menu-delete'),
            icon: BvIcons.delete,
            label: l10n.notebookDeletePage,
            destructive: true,
            onTap: () => Navigator.of(sheet).pop('delete'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final notebook = ref.read(notebookProvider.notifier);
    switch (choice) {
      case 'sub':
        final at = ref.read(clockProvider)();
        final id = ref.read(newPostIdProvider)();
        await notebook.newPage(
          NotebookPage(
            id: id,
            parentId: page.id,
            createdAt: at,
            lastActivityAt: at,
          ),
        );
        if (mounted) unawaited(context.push(AppRoutes.notebookPage(id)));
      case 'pin':
        await notebook.pinPages([page.id], on: !page.pinned);
      case 'move':
        final data = ref.read(notebookProvider).value;
        if (data == null) return;
        final pick = await showPagePickerSheet(
          context,
          data: data,
          title: l10n.notebookMoveInto,
          current: page.parentId,
          hidden: data.tree(page.id),
          newPage: false,
          top: true,
        );
        if (pick == null) return;
        await notebook.movePages([page.id], pick.id);
      case 'delete':
        await holdWithUndo(
          context,
          ref,
          NoteChange.deletePages([page.id]),
          l10n.notebookPagesDeleted(1),
        );
        if (mounted) Navigator.of(context).maybePop();
    }
  }

  /// The page chip's picker (PG3), over the slip; a pick goes back to
  /// writing.
  void _openPicker(NotebookData data, NoteDraft draft) {
    if (_picker.isOpen) return _picker.hide();
    _picker.show(
      context,
      anchor: () => _chipKey.currentContext,
      barrier: true,
      above: true,
      onDismiss: _picker.hide,
      builder: (_) => PagePickerCard(
        child: PagePicker(
          data: data,
          current: draft.newPageId == null ? draft.pageId : null,
          newPageChosen: draft.newPageId != null,
          onPick: (pick) {
            _picker.hide();
            unawaited(
              _change(
                (d) => pick.kind == PagePickKind.newPage
                    ? d.copyWith(
                        pageId: () => null,
                        newPageId: () =>
                            d.newPageId ?? ref.read(newPostIdProvider)(),
                      )
                    : d.copyWith(pageId: () => pick.id, newPageId: () => null),
              ),
            );
            _editorKey.currentState?.focusCurrent();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = _words();
    final now = ref.watch(clockProvider)();
    final notebook = ref.watch(notebookProvider);
    final data = notebook.value ?? NotebookData();
    final draft = ref.watch(noteDraftProvider);
    // B10: as the slip grows, its end stays above the bar.
    ref.listen(noteDraftProvider, (_, _) {
      if (_writing) _showSlip();
    });
    // B15: a refused note is said, and its words come back as the Draft.
    ref.listen(noteRefusedProvider, (_, refused) {
      if (refused == null) return;
      final (:note, :elsewhere) = refused;
      ref.read(noteRefusedProvider.notifier).seen();
      _toast(l10n.notebookCouldntKeep);
      unawaited(_takeBack(note, elsewhere: elsewhere));
    });
    final page = data.page(widget.pageId ?? draft?.intoPage ?? data.latest?.id);
    if (page != null && widget.pageId != null && notebook.hasValue) {
      if (!_opened) {
        _opened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(ref.read(notebookProvider.notifier).openPage(page));
          }
        });
      }
      if (_titleOf != page.id ||
          (!_pageTitleFocus.hasFocus && _pageTitle.text != page.title)) {
        _titleOf = page.id;
        _pageTitle.text = page.title;
      }
    }
    final writingNow = _writing && draft != null;
    final selecting = _selected.isNotEmpty;
    // BH12: lines of the entry being written are selected.
    final picking = writingNow && _linesPicked > 0;
    final kept = page == null
        ? const <Note>[]
        : widget.archived
        ? data.archived(page.id)
        : data.entries(page.id);
    // Newest first as kept, or oldest first (review 102 N5).
    final entries = _sort == EntrySort.oldest ? kept.reversed.toList() : kept;
    final chosen = [
      for (final n in entries)
        if (_selected.contains(n.id)) n,
    ];
    if (widget.entry != null && !_shownEntry && entries.isNotEmpty) {
      _shownEntry = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_showEntry()),
      );
    }

    Widget writingSlip(NoteDraft draft, {required bool writing}) {
      final into = data.page(draft.intoPage);
      final inHand = draft.id == ref.read(noteDraftProvider)?.id;
      return Padding(
        key: writing ? _slipKey : null,
        padding: const EdgeInsetsDirectional.only(
          bottom: BvNotebookSpec.slipGap,
        ),
        child: NoteWritingSlip(
          key: ValueKey(('note-writing', draft.id)),
          writing: writing,
          words: words,
          onOpen: () => unawaited(_resume(draft.id)),
          shown: inHand ? null : draft,
          onPickDue: () => unawaited(_pickDue()),
          onPickRemind: () => unawaited(_pickRemind()),
          onLocation: _toggleLocation,
          editorKey: inHand
              ? _editorKey
              : _draftKeys.putIfAbsent(draft.id, GlobalKey.new),
          titleFocus: inHand
              ? _titleFocus
              : _draftFocus.putIfAbsent(draft.id, FocusNode.new),
          // The bar's ⇥ ⇤ follow the line being written.
          onCurrentKind: (k) => setState(() => _kind = k),
          onMoveLine: writing ? _moveLine : null,
          onLinesSelected: writing
              ? (n) => setState(() => _linesPicked = n)
              : null,
          onLinesDeleted: writing ? _linesDeleted : null,
          chip: writing && _chip(draft)
              ? NotePageChip(
                  key: _chipKey,
                  icon: into == null ? BvIcons.add : pageIconData(into.icon),
                  label: l10n.notebookPageChip(
                    into == null ? l10n.notebookNewPage : pageName(l10n, into),
                  ),
                  onTap: () => _openPicker(data, draft),
                )
              : null,
        ),
      );
    }

    // The swipe's hint, on the top card, the first time a page with
    // entries opens (review 100 Part 3b).
    final prefs = ref.read(sharedPreferencesProvider);
    final hintFirst =
        !widget.archived && !_hinted && !(prefs.getBool(_hintKey) ?? false);

    Widget slip(Note n) => NoteSlip(note: n, words: words, now: now);

    Widget entry(Note n, {bool first = false}) => _arrangeable(
      n,
      selecting: selecting,
      card: () => slip(n),
      child: Padding(
        key: n.id == widget.entry ? _entryKey : null,
        padding: const EdgeInsetsDirectional.only(
          bottom: BvNotebookPagesSpec.entryGap,
        ),
        child: BvSwipeCard(
          key: ValueKey(('swipe', n.id)),
          id: n.id,
          enabled: !selecting,
          hint: first && hintFirst,
          onHinted: () {
            _hinted = true;
            unawaited(prefs.setBool(_hintKey, true));
          },
          endActions: widget.archived
              ? const []
              : [
                  BvSwipeAction(
                    key: Key('swipe-pin-${n.id}'),
                    icon: BvIcons.pin,
                    label: n.pinned ? l10n.daybookUnpin : l10n.notebookPin,
                    color: BvColors.textPrimary,
                    onTap: () => unawaited(
                      ref.read(notebookProvider.notifier).pin(n, on: !n.pinned),
                    ),
                  ),
                  if (n.kind != NoteKind.voice)
                    BvSwipeAction(
                      key: Key('swipe-remind-${n.id}'),
                      icon: BvIcons.remind,
                      label: remindsAt(n, now)
                          ? l10n.notebookChangeReminder
                          : l10n.notebookReminder,
                      color: BvColors.textWarning,
                      onTap: () => unawaited(_remind(n)),
                    ),
                ],
          startAction: BvSwipeAction(
            key: Key('swipe-archive-${n.id}'),
            icon: BvIcons.archive,
            label: widget.archived
                ? l10n.notebookUnarchive
                : l10n.notebookArchive,
            color: BvColors.actionPrimary,
            onTap: () => unawaited(_archive(n, on: !widget.archived)),
          ),
          child: Semantics(
            container: true,
            customSemanticsActions: _moves(n, selecting),
            child: NoteSlip(
              note: n,
              words: words,
              now: now,
              selected: _selected.contains(n.id),
              onEdit: widget.archived
                  ? null
                  : selecting
                  ? () => _select(n)
                  : n.kind == NoteKind.voice
                  ? null
                  : () => _edit(n),
              onLongPress: widget.archived || _canArrange(n, selecting)
                  ? null
                  : () => _select(n),
            ),
          ),
        ),
      ),
    );

    // Newest first, a day at a time (A3); the pinned ones first.
    final pinned = [
      for (final n in entries)
        if (n.pinned) n,
    ];
    final byDay = <DateTime, List<Note>>{};
    for (final n in entries) {
      if (!n.pinned) byDay.putIfAbsent(dayOf(n.createdAt), () => []).add(n);
    }
    // Review 102 N3: each day in its hand order.
    for (final day in byDay.keys.toList()) {
      byDay[day] = inHandOrder(
        byDay[day]!,
        oldestFirst: _sort == EntrySort.oldest,
      );
    }
    _dayIds = {
      for (final MapEntry(key: day, value: notes) in byDay.entries)
        day: [for (final n in notes) n.id],
    };
    // B3: every Draft of a new entry in this page, each its own card; the
    // one in hand first.
    bool here(NoteDraft d) =>
        page != null && (d.intoPage ?? data.latest?.id) == page.id;
    final drafts = [
      if (!widget.archived)
        if (draft != null &&
            !writingNow &&
            draft.editing == null &&
            here(draft))
          draft,
      if (!widget.archived)
        for (final d in ref.watch(parkedDraftsProvider))
          if (here(d) && d.id != draft?.id) d,
    ];

    Widget browse(NotebookPage page) {
      final path = data.path(page.id);
      // Review 101 A: a row at a time, built only on screen and a small
      // margin. A row keeps its key, so it keeps its place (its swipe, its
      // selection) as rows come and go above it.
      final rows = <(Key?, Widget Function())>[
        (
          null,
          () => Wrap(
            key: const Key('page-path'),
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: BvNotebookPagesSpec.pathGap,
            children: [
              for (final (i, name) in [
                l10n.notebookTitle,
                for (final p in path.take(path.length - 1)) pageName(l10n, p),
              ].indexed) ...[
                Text(
                  name,
                  textDirection: directionOf(name),
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
                ),
                Icon(
                  BvIcons.caretForward,
                  key: ValueKey(('page-path-caret', i)),
                  size: BvNotebookPagesSpec.pathCaret,
                  color: BvColors.iconSecondary,
                ),
              ],
            ],
          ),
        ),
        (null, () => const SizedBox(height: BvNotebookPagesSpec.pathBottom)),
        (
          null,
          () => Row(
            spacing: BvNotebookPagesSpec.titleGap,
            children: [
              Semantics(
                button: true,
                label: l10n.notebookPageIcon,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const Key('page-icon'),
                  onTap: () => _pickIcon(page),
                  child: PageIconBox(
                    icon: pageIconData(page.icon),
                    size: BvNotebookPagesSpec.titleBox,
                    glyph: BvNotebookPagesSpec.titleGlyph,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  key: const Key('page-title'),
                  controller: _pageTitle,
                  focusNode: _pageTitleFocus,
                  maxLength: NotebookPage.titleMax,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _keepTitle(page),
                  onTapOutside: (_) {
                    if (_pageTitleFocus.hasFocus) {
                      _pageTitleFocus.unfocus();
                      _keepTitle(page);
                    }
                  },
                  style: type.headingMd.copyWith(color: BvColors.textPrimary),
                  decoration:
                      bvBareField(
                        hint: pageName(l10n, page),
                        style: type.headingMd,
                      ).copyWith(
                        counterText: '',
                        // "My notes" is its name, not a hint.
                        hintStyle: page.myNotes && page.title.isEmpty
                            ? type.headingMd.copyWith(
                                color: BvColors.textPrimary,
                              )
                            : null,
                      ),
                ),
              ),
            ],
          ),
        ),
        (null, () => const SizedBox(height: BvNotebookPagesSpec.titleBottom)),
        for (final sub
            in widget.archived
                ? const <NotebookPage>[]
                : data.children(page.id))
          (
            ValueKey(('page-row', sub.id)),
            () => Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: BvNotebookPagesSpec.rowsGap,
              ),
              child: pageRowFor(
                context,
                data,
                sub,
                words: words,
                now: now,
                onTap: () => context.push(AppRoutes.notebookPage(sub.id)),
              ),
            ),
          ),
        if (drafts.isNotEmpty) ...[
          (
            const ValueKey('drafts-label'),
            () => NotebookLabel(l10n.daybookDraft),
          ),
          for (final d in drafts)
            (
              ValueKey(('draft-row', d.id)),
              () => BvSwipeCard(
                key: Key('note-draft-card-${d.id}'),
                id: d.id,
                enabled: !selecting,
                startAction: BvSwipeAction(
                  key: Key('swipe-discard-${d.id}'),
                  icon: BvIcons.discard,
                  label: l10n.notebookDiscardDraft,
                  color: BvColors.textDestructive,
                  onTap: () => unawaited(_discardDraft(d)),
                ),
                child: writingSlip(d, writing: false),
              ),
            ),
        ],
        if (pinned.isNotEmpty) ...[
          (
            const ValueKey('pinned-label'),
            () => NotebookLabel(l10n.notebookPinnedLabel),
          ),
          for (final n in pinned)
            (
              ValueKey(('entry-row', n.id)),
              () => entry(n, first: n == entries.first),
            ),
        ],
        for (final day in byDay.keys) ...[
          (
            ValueKey(('day-row', day)),
            () => Padding(
              padding: const EdgeInsetsDirectional.only(
                top: BvNotebookPagesSpec.dayTop,
              ),
              child: NotebookLabel(words.compactDate(day)),
            ),
          ),
          for (final n in byDay[day]!)
            (
              ValueKey(('entry-row', n.id)),
              () => entry(
                n,
                first:
                    pinned.isEmpty &&
                    n == byDay[day]!.first &&
                    day == byDay.keys.first,
              ),
            ),
        ],
        if (widget.archived && entries.isEmpty && notebook.hasValue)
          (null, () => EmptyNote(l10n.notebookArchivedEmpty)),
        if (!widget.archived && data.archived(page.id).isNotEmpty)
          (
            const ValueKey('archived-row'),
            () => ArchivedRow(
              onTap: () => context.push(AppRoutes.notebookArchived(page.id)),
            ),
          ),
      ];
      final rowOf = <Key, int>{
        for (final (i, (key, _)) in rows.indexed) ?key: i,
      };
      final opened = widget.entry;
      _entryRow = opened == null
          ? null
          : rowOf[ValueKey(('entry-row', opened))];
      return ListView.builder(
        key: const Key('notebook-list'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          BvSpace.gutter,
          BvSpace.s8,
          BvSpace.gutter,
          BvSpace.s64 + BvSpace.s32,
        ),
        itemCount: rows.length,
        findChildIndexCallback: (key) => rowOf[key],
        itemBuilder: (context, i) => LazyRow(
          key: rows[i].$1,
          index: i,
          built: _built,
          child: rows[i].$2(),
        ),
      );
    }

    Widget body() {
      if (writingNow) {
        return LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            key: const Key('notebook-list'),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvNotebookSpec.gutter,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [writingSlip(draft, writing: true)],
              ),
            ),
          ),
        );
      }
      if (page != null && _filter.on && !widget.archived) {
        return _filtered(data);
      }
      if (page != null) {
        final list = BvSwipeGroup(child: browse(page));
        if (_sort == EntrySort.newest) return list;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NoteSortChip(
              sort: _sort,
              onClear: () => _setSort(EntrySort.newest),
            ),
            Expanded(child: list),
          ],
        );
      }
      if (notebook.isLoading) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: EmptyNote(
          notebook.hasError
              ? l10n.notebookCouldntLoad
              : l10n.notebookPageNotFound,
        ),
      );
    }

    final writingTitle = draft == null
        ? ''
        : draft.newPageId != null || page == null
        ? l10n.notebookNewPage
        : pageName(l10n, page);
    return PopScope(
      // Back while writing closes the grid or the location sheet first,
      // then puts the slip down, kept as the Draft (NBW5); while
      // selecting, it stops selecting.
      canPop: !_writing && !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Review 100 B5: Back closes an open card first.
        if (_picker.isOpen) {
          _picker.hide();
          return;
        }
        if (_barCard.isOpen) {
          _closeBar();
          return;
        }
        if (_editorKey.currentState?.closeMenus() ?? false) return;
        if (picking) {
          _editorKey.currentState?.endLineSelection();
          return;
        }
        if (selecting) {
          setState(_selected.clear);
          return;
        }
        if (_panel != _Panel.none) {
          setState(() => _panel = _Panel.none);
          return;
        }
        _leave();
      },
      // B6 (D12): the iPhone's swipe from the edge does what ← does here
      // too, while writing or selecting.
      child: BvBackSwipe(
        holding: _writing || selecting,
        child: Scaffold(
          backgroundColor: BvColors.surfaceApp,
          appBar: AppBar(
            backgroundColor: BvColors.surfaceApp,
            leading: selecting || picking
                ? IconButton(
                    key: const Key('selection-close'),
                    tooltip: l10n.notebookCloseSelection,
                    icon: const Icon(BvIcons.close),
                    onPressed: picking
                        ? () => _editorKey.currentState?.endLineSelection()
                        : () => setState(_selected.clear),
                  )
                : null,
            title: widget.archived
                ? Text(l10n.notebookArchivedRow)
                : picking
                ? Text(l10n.notebookLinesSelected(_linesPicked))
                : selecting
                ? Text(l10n.notebookSelected(_selected.length))
                : writingNow
                ? Text(writingTitle, key: const Key('writing-page-title'))
                : null,
            actions: [
              if (writingNow && !picking && draft.editing == null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: BvSpace.s8),
                  child: TextButton(
                    key: const Key('writing-discard'),
                    onPressed: () => unawaited(_discardWriting()),
                    child: Text(
                      l10n.notebookDiscardDraft,
                      style: type.labelMd.copyWith(
                        color: BvColors.textDestructive,
                      ),
                    ),
                  ),
                ),
              if (!selecting &&
                  !writingNow &&
                  page != null &&
                  !widget.archived) ...[
                _filterButton(data, 'page-filter'),
                IconButton(
                  key: const Key('page-search'),
                  tooltip: l10n.notebookSearchTip,
                  icon: const Icon(BvIcons.search),
                  // Search keeps the Filter that is on (Part 8).
                  onPressed: () => context.push(
                    AppRoutes.notebookSearchIn(
                      kind: _filter.kind?.json,
                      page: _filter.on ? _filter.page : null,
                    ),
                  ),
                ),
                KeyedSubtree(
                  key: _filterKey,
                  child: IconButton(
                    key: const Key('page-more'),
                    tooltip: l10n.daybookMore,
                    icon: const Icon(BvIcons.more),
                    onPressed: () => _pageMenu(page),
                  ),
                ),
              ],
            ],
          ),
          floatingActionButton:
              !writingNow &&
                  !selecting &&
                  page != null &&
                  !widget.archived &&
                  !_filter.on
              ? WriteHereButton(onTap: () => unawaited(_write()))
              : null,
          body: Column(
            children: [
              Expanded(child: body()),
              if (writingNow && !picking)
                SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KeyedSubtree(key: _barKey, child: _tools(l10n, draft)),
                      if (_panel == _Panel.location)
                        NoteLocationPanel(
                          location: draft.location,
                          onChanged: (l) => unawaited(
                            _change((d) => d.copyWith(location: () => l)),
                          ),
                          onDone: _closeLocation,
                        ),
                    ],
                  ),
                ),
            ],
          ),
          // Review 100 Part 0: one bar for what is selected, entries or
          // lines, with the same actions in the same order (BH2, BH12).
          bottomNavigationBar: picking
              ? SelectionBar(
                  key: _selectionBarKey,
                  actions: [
                    if (_linesSaved() case final saved?)
                      SelectionAction(
                        key: const Key('select-share'),
                        icon: BvIcons.shareEntry,
                        label: l10n.notebookShare,
                        onTap: () => _shareLines(saved),
                      ),
                    SelectionAction(
                      key: const Key('select-move'),
                      icon: BvIcons.pageFolder,
                      label: l10n.notebookMove,
                      onTap: () => unawaited(_moveLines()),
                    ),
                    SelectionAction(
                      key: const Key('select-duplicate'),
                      icon: BvIcons.duplicate,
                      label: l10n.notebookDuplicate,
                      onTap: () =>
                          _editorKey.currentState?.duplicateSelectedLines(),
                    ),
                    SelectionAction(
                      key: const Key('select-delete'),
                      icon: BvIcons.delete,
                      label: l10n.delete,
                      destructive: true,
                      onTap: () =>
                          _editorKey.currentState?.deleteSelectedLines(),
                    ),
                  ],
                )
              : selecting
              ? SelectionBar(
                  key: _selectionBarKey,
                  actions: [
                    // Share is for one entry (Part 3), once the server can
                    // have it (H2: not while it waits with no signal).
                    if (chosen.length == 1 &&
                        !(ref
                                .read(notebookProvider.notifier)
                                .waits(chosen.single.id) &&
                            !ref.watch(signalProvider)))
                      SelectionAction(
                        key: const Key('select-share'),
                        icon: BvIcons.shareEntry,
                        label: l10n.notebookShare,
                        onTap: () => _shareEntry(chosen.single),
                      ),
                    SelectionAction(
                      key: const Key('select-move'),
                      icon: BvIcons.pageFolder,
                      label: l10n.notebookMove,
                      onTap: () => _moveEntries(chosen),
                    ),
                    SelectionAction(
                      key: const Key('select-duplicate'),
                      icon: BvIcons.duplicate,
                      label: l10n.notebookDuplicate,
                      onTap: () => unawaited(_duplicateSelected(chosen)),
                    ),
                    SelectionAction(
                      key: const Key('select-delete'),
                      icon: BvIcons.delete,
                      label: l10n.delete,
                      destructive: true,
                      onTap: () => _deleteSelected(chosen),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  /// The bar above the keyboard (review 100 BH6): + for the block list,
  /// 📷 Photo, 📎 Add, then ⇥ and ⇤ each only while the line being written
  /// can move that way (review 98: hidden, not greyed); at the far end the
  /// 🎤 (hold to record a voice block) and Send. A tool whose card is open
  /// is on a grey square; 📷 or 📎 has a dot when something is attached.
  /// Inside a saved entry Send reads Done and saves it in place (B2).
  Widget _tools(AppLocalizations l10n, NoteDraft draft) {
    final editor = _editorKey.currentState;
    final deeper = editor?.canIndentCurrent ?? false;
    final out = editor?.canOutdentCurrent ?? false;
    final added =
        draft.files.isNotEmpty ||
        !(draft.location?.isEmpty ?? true) ||
        draft.dueAt != null ||
        draft.remindAt != null;
    final saved = draft.editing != null;
    return BvWritingToolbar.tools(
      key: const Key('note-tools'),
      categories: BvWritingTool(
        key: const Key('note-tool-categories'),
        icon: BvIcons.add,
        label: l10n.notebookBlocks,
        onTap: () => _openBar(_BarCard.blocks),
      ),
      categoriesOpen: _barOpen == _BarCard.blocks,
      beside: [
        if (deeper)
          BvWritingTool(
            key: const Key('note-tool-indent'),
            icon: BvIcons.indent,
            label: l10n.notebookIndent,
            onTap: () => editor!.indentCurrent(),
          ),
        if (out)
          BvWritingTool(
            key: const Key('note-tool-outdent'),
            icon: BvIcons.outdent,
            label: l10n.notebookOutdent,
            onTap: () => editor!.outdentCurrent(),
          ),
      ],
      tools: [
        BvWritingTool(
          key: const Key('note-tool-image'),
          icon: BvIcons.camera,
          label: l10n.notebookPhoto,
          active: _barOpen == _BarCard.photo,
          dot: draft.photos.isEmpty ? null : const Key('note-tool-image-dot'),
          onTap: () => _openBar(_BarCard.photo),
        ),
        BvWritingTool(
          key: const Key('note-tool-add'),
          icon: BvIcons.attach,
          label: l10n.notebookAdd,
          active: _barOpen == _BarCard.add || _panel == _Panel.location,
          dot: added ? const Key('note-tool-add-dot') : null,
          onTap: () => _openBar(_BarCard.add),
        ),
        // F107: hold for a voice block inside the note.
        BvWritingTool(
          key: const Key('note-tool-voice'),
          icon: BvIcons.microphone,
          label: l10n.notebookVoiceTool,
          onTap: () => _toast(l10n.notebookHoldToRecord),
          onHoldStart: _startRecording,
          onHoldMove: _slide,
          onHoldEnd: _endRecording,
        ),
      ],
      field: _recording
          ? RecordingBar(elapsed: _elapsed, cancelling: _cancelling)
          : null,
      postLabel: saved ? l10n.notebookDone : l10n.chatSend,
      onPost: saved
          ? _putDown
          : draft.ready
          ? () => unawaited(_send())
          : null,
    );
  }
}

/// A Space's chip in Put in a Space (2557:35481): its first letter on its
/// colour, the same colour its rows have in My calendar.
class SpaceChip extends StatelessWidget {
  const SpaceChip({super.key, required this.id, required this.name});

  final String id;
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: BvSize.avatarSm,
    height: BvSize.avatarSm,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: BvProjectColors.forId(id),
      borderRadius: BvRadius.smallAll,
    ),
    child: Text(
      name.trim().characters.take(1).toUpperCase().join(),
      style: BvType.of(context).labelMd.copyWith(color: BvColors.textInverse),
    ),
  );
}

/// A note on its slip: the kind and time on the first line, then the
/// words; a to-do's box and its due in the action colour; a checklist's
/// title and points; a voice note's player; its photos (F106). "Waiting
/// to send" while it is
/// still on the phone; "Went into a Space" once put in one.
class NoteSlip extends ConsumerWidget {
  const NoteSlip({
    super.key,
    required this.note,
    required this.words,
    required this.now,
    this.onEdit,
    this.onLongPress,
    this.selected = false,
  });

  final Note note;
  final DaybookWords words;
  final DateTime now;
  final VoidCallback? onEdit;

  /// A long-press: select it (review 99 A4); its other actions are on its
  /// swipe (review 100 Part 3b).
  final VoidCallback? onLongPress;

  /// Selected for Move to page…: lifted, with the selected edge.
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final notebook = ref.read(notebookProvider.notifier);
    final kind = switch (note.kind) {
      NoteKind.text => l10n.notebookNote,
      NoteKind.checklist => l10n.daybookKindChecklist,
      NoteKind.todo => l10n.notebookTodo,
      NoteKind.voice => l10n.notebookVoice,
    };
    final main = type.bodyMd.copyWith(color: BvColors.textPrimary);
    final struck = main.copyWith(
      color: BvColors.textSecondary,
      decoration: TextDecoration.lineThrough,
      decorationColor: BvColors.textSecondary,
    );
    final due = note.dueAt;
    final title = note.isPage ? note.title.trim() : '';
    final children = <Widget>[
      // PG4: the title, or the kind, with the time at the end, then ⋯.
      Row(
        key: Key('note-head-${note.id}'),
        spacing: BvSpace.s8,
        children: [
          Expanded(
            child: title.isEmpty
                ? BvSlipQuiet(kind)
                : Text(
                    title,
                    textDirection: directionOf(title),
                    style: type.headingMd.copyWith(color: BvColors.textPrimary),
                  ),
          ),
          Text(
            words.time.clock(note.createdAt),
            style: type.metadata.copyWith(color: BvColors.textSecondary),
          ),
        ],
      ),
      if (note.isPage)
        NotePageSummary(note: note, words: words, now: now, showTitle: false)
      else
        switch (note.kind) {
          NoteKind.text => BvSlipNote(note.body),
          NoteKind.todo => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvSpace.s8,
            children: [
              NoteBox(
                key: Key('note-done-${note.id}'),
                ticked: note.done,
                onTap: () => notebook.setDone(note, on: !note.done),
                child: Text(note.body, style: note.done ? struck : main),
              ),
              if (due != null)
                Row(
                  spacing: BvNotebookSpec.dueGap,
                  children: [
                    const Icon(
                      BvIcons.due,
                      size: BvNotebookSpec.dueIcon,
                      color: BvColors.textAction,
                    ),
                    Flexible(
                      child: Text(
                        todoDue(words, due, now),
                        style: type.metadata.copyWith(
                          color: note.done
                              ? BvColors.textSecondary
                              : BvColors.textAction,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          NoteKind.checklist => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BvNotebookSpec.pointGap,
            children: [
              if (note.body.isNotEmpty)
                Text(
                  note.body,
                  style: type.labelMd.copyWith(color: BvColors.textPrimary),
                ),
              for (final (i, p) in note.points.indexed)
                NoteBox(
                  key: Key('note-point-${note.id}-$i'),
                  ticked: p.done,
                  onTap: () => notebook.tick(note, i),
                  child: Text(p.text, style: p.done ? struck : main),
                ),
            ],
          ),
          NoteKind.voice => VoiceNote(
            id: note.id,
            duration: note.recording?.duration ?? Duration.zero,
            path: note.recording?.path,
            local: note.recording?.path == null ? note.recording?.local : null,
            linkOf: (ref, path) =>
                ref.read(notebookRepositoryProvider).recordingUrl(path),
          ),
        },
      if (note.photos.isNotEmpty && !note.isPage)
        NotePhotos(key: Key('note-photos-${note.id}'), photos: note.photos),
      if (remindsAt(note, now))
        BvSlipQuiet(
          key: Key('note-reminder-${note.id}'),
          l10n.notebookReminderLine(
            reminderWhen(l10n, words, note.remindAt!, now),
          ),
        ),
      if (note.waiting) BvSlipQuiet(l10n.daybookWaitingToSend),
      if (note.shares.lastOrNull case final share?)
        BvSlipQuiet(
          key: Key('note-share-mark-${note.id}'),
          switch (share.target) {
            NoteShareTarget.feed => l10n.notebookMarkFeed(
              words.time.clock(share.at),
            ),
            NoteShareTarget.space => l10n.notebookMarkTo(
              share.name ?? '',
              words.time.clock(share.at),
            ),
            NoteShareTarget.message => l10n.notebookMarkSent(
              share.name ?? '',
              words.time.clock(share.at),
            ),
          },
        )
      else if (note.putInPostId != null && !note.waiting)
        BvSlipQuiet(l10n.notebookPut),
    ];
    // PG4: a plain white card; selected (A4, BH2), tinted and lifted with
    // the selected edge.
    return DecoratedBox(
      key: Key('note-${note.id}'),
      decoration: BoxDecoration(
        color: selected ? BvColors.surfaceBrandSoft : BvColors.surfaceElevated,
        borderRadius: BvNotebookPagesSpec.entryRadius,
        boxShadow: selected ? BvShadow.slipLifted : BvShadow.slip,
      ),
      child: DecoratedBox(
        key: selected ? Key('note-selected-${note.id}') : null,
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: selected
              ? Border.all(
                  color: BvColors.borderSelected,
                  width: BvStroke.thick,
                )
              : null,
          borderRadius: BvNotebookPagesSpec.entryRadius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BvNotebookPagesSpec.entryRadius,
            onTap: onEdit,
            onLongPress: onLongPress,
            child: Padding(
              padding: BvNotebookPagesSpec.entryPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BvNotebookPagesSpec.entryLinesGap,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A page note on its saved slip (F107, review 92): the bold title, the
/// first three lines of its page (a to-do ticks here too), then its chips:
/// the location, the date, and its photos and files as icons with how
/// many ("2 photos"). A tap opens it for editing in place.
class NotePageSummary extends ConsumerWidget {
  const NotePageSummary({
    super.key,
    required this.note,
    required this.words,
    required this.now,
    this.showTitle = true,
  });

  final Note note;
  final DaybookWords words;
  final DateTime now;

  /// False on a page's slip (PG4): its head says the title.
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final main = type.bodyMd.copyWith(color: BvColors.textPrimary);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final blocks = note.blocks ?? const <PageBlock>[];
    // Folded lines hide what is under them here too.
    final open = visibleLines(blocks, {
      for (final b in blocks)
        if (b.folded) b.id,
    });
    final shown = [
      for (final i in open.take(BvNoteBlocksSpec.slipLines)) (i, blocks[i]),
    ];
    final more = open.length > shown.length;
    Text line(String text, TextStyle style) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textDirection: directionOf(text),
      style: style,
    );
    Widget block(int i, PageBlock b) => switch (b) {
      PageTodo(:final text, :final done) => Row(
        spacing: BvNoteBlocksSpec.lineGap,
        children: [
          NoteTick(
            key: Key('note-summary-tick-${b.id}'),
            ticked: done,
            onTap: () =>
                ref.read(notebookProvider.notifier).tickBlock(note, b.id),
          ),
          Expanded(
            child: line(
              text,
              done
                  ? main.copyWith(
                      color: BvColors.textSecondary,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: BvColors.textSecondary,
                    )
                  : main,
            ),
          ),
        ],
      ),
      PageBullet(:final text) => Row(
        spacing: BvNoteBlocksSpec.lineGap,
        children: [
          const NoteBullet(),
          Expanded(child: line(text, main)),
        ],
      ),
      PageNumbered(:final text) => Row(
        spacing: BvNoteBlocksSpec.lineGap,
        children: [
          NoteNumber(numberLabel(numberAt(blocks, i), b.indent)),
          Expanded(child: line(text, main)),
        ],
      ),
      PageCallout(:final text) => NoteCallout(child: line(text, main)),
      PageQuote(:final text) => NoteQuote(child: line(text, main)),
      PageHeading(:final text, :final level) => line(
        text,
        (level == 1 ? type.titleMd : type.emphasis).copyWith(
          color: BvColors.textPrimary,
        ),
      ),
      PageDivider() => const NoteDividerLine(),
      PageVoice(:final path, :final local, :final duration) => VoiceNote(
        id: b.id,
        duration: duration,
        path: path,
        local: path == null ? local : null,
        linkOf: (ref, path) =>
            ref.read(notebookRepositoryProvider).recordingUrl(path),
      ),
      PageTable(:final rows) => line(
        [for (final r in rows.take(1)) r.join(' · ')].join(),
        main,
      ),
      _ => line(blockWords(b).join(' · '), main),
    };
    final location = note.location;
    final due = note.dueAt;
    final chips = <Widget>[
      if (location != null && !location.isEmpty)
        NoteChip(icon: BvIcons.place, label: locationLabel(l10n, location)),
      if (due != null)
        NoteChip(icon: BvIcons.due, label: todoDue(words, due, now)),
      if (note.photos.isNotEmpty)
        NoteChip(
          icon: BvIcons.image,
          label: l10n.notebookPhotoCount(note.photos.length),
        ),
      if (note.files.isNotEmpty)
        NoteChip(
          icon: BvIcons.document,
          label: l10n.notebookFileCount(note.files.length),
        ),
    ];
    return Column(
      key: Key('note-page-${note.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvNotebookSpec.pointGap,
      children: [
        if (showTitle && note.title.trim().isNotEmpty)
          Text(
            note.title.trim(),
            textDirection: directionOf(note.title),
            style: type.headingMd.copyWith(color: BvColors.textPrimary),
          ),
        for (final (i, b) in shown)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: b.indent * BvNoteBlocksSpec.indent,
            ),
            child: block(i, b),
          ),
        if (more) Text('…', style: quiet),
        if (chips.isNotEmpty)
          Wrap(
            key: Key('note-page-chips-${note.id}'),
            spacing: BvNoteWritingSpec.chipsGap,
            runSpacing: BvNoteWritingSpec.chipsGap,
            children: chips,
          ),
      ],
    );
  }
}

/// A reminder's time on its slip: "today 4:00 pm", "tomorrow 9:00 am",
/// "Sun 18 Oct 9:00 am". In grey: it is the person's own, not a due
/// (review 87 Q4).
String reminderWhen(
  AppLocalizations l10n,
  DaybookWords words,
  DateTime at,
  DateTime now,
) {
  final day = dayOf(at);
  final today = dayOf(now);
  final name = day == today
      ? l10n.daybookToday
      : day == today.add(const Duration(days: 1))
      ? l10n.daybookTomorrow
      : words.shortDate(day);
  return l10n.notebookReminderWhen(name, words.time.clock(at));
}

/// A to-do's due as its slip says it: "by today 4:00 pm"; a day with no
/// time ("by Sun 18 Oct") when it was saved at the day's start.
String todoDue(DaybookWords words, DateTime due, DateTime now) {
  final day = dayOf(due);
  final allDay = due == day;
  return words.due(
    day,
    allDay ? null : due,
    now: now,
    late: allDay ? day.isBefore(dayOf(now)) : due.isBefore(now),
  );
}

/// A to-do's or a checklist point's box (2557:35412): 18, filled in the
/// action colour with a check once ticked. The whole row is the target.
class NoteBox extends StatelessWidget {
  const NoteBox({
    super.key,
    required this.ticked,
    required this.onTap,
    required this.child,
  });

  final bool ticked;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: ticked,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BvSize.iconLg),
        child: Row(
          spacing: BvNotebookSpec.boxGap,
          children: [
            Container(
              width: BvNotebookSpec.box,
              height: BvNotebookSpec.box,
              decoration: BoxDecoration(
                color: ticked ? BvColors.actionPrimary : null,
                borderRadius: const BorderRadius.all(
                  Radius.circular(BvNotebookSpec.boxRadius),
                ),
                border: ticked
                    ? null
                    : Border.all(
                        color: BvColors.borderInput,
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
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

/// An entry being moved within its day (review 102 N3). Places are in the
/// page: a row's top on screen plus how far the page is scrolled.
class _Arranging {
  _Arranging({
    required this.id,
    required this.day,
    required this.ids,
    required this.rects,
    required this.grab,
    required this.position,
  }) : to = ids.indexOf(id);

  final String id;
  final DateTime day;

  /// The day's entries as they were, top to bottom.
  final List<String> ids;

  /// Each row where it was.
  final Map<String, Rect> rects;

  /// From the row's top to the finger.
  final double grab;
  final ScrollPosition position;

  /// The finger, on screen.
  double finger = 0;

  /// Where it lands among the day's entries.
  int to;

  double get _height => rects[id]!.height;

  /// The moved row's top in the page: under the finger, kept within its day
  /// (at the day's edge it stops).
  double top() => (finger + position.pixels - grab).clamp(
    rects[ids.first]!.top,
    rects[ids.last]!.bottom - _height,
  );

  /// Where it lands: past each row whose middle it has reached, down or
  /// up (at its day's edge, past the last).
  int landing() {
    final from = ids.indexOf(id);
    final middle = top() + _height / 2;
    var to = from;
    for (var i = from + 1; i < ids.length; i++) {
      if (middle >= rects[ids[i]]!.center.dy) to = i;
    }
    for (var i = from - 1; i >= 0; i--) {
      if (middle <= rects[ids[i]]!.center.dy) to = i;
    }
    return to;
  }

  List<String> order() => [...ids]
    ..remove(id)
    ..insert(to, id);

  /// Each row's top in [order], from the day's first.
  Map<String, double> tops() {
    var at = rects[ids.first]!.top;
    return {for (final o in order()) o: (at, at += rects[o]!.height).$1};
  }

  /// How far [other] slides aside.
  double shift(String other) => tops()[other]! - rects[other]!.top;
}

/// Hold, then move without lifting (review 102 N3); a hold let go with no
/// move ends too. Off, the card's own long-press stands.
class _ArrangeHold extends StatelessWidget {
  const _ArrangeHold({
    required this.enabled,
    required this.onStart,
    required this.onMove,
    required this.onEnd,
    required this.onCancel,
    required this.child,
  });

  final bool enabled;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      if (enabled)
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(debugOwner: this),
              (r) => r
                ..onLongPressStart = ((d) => onStart(d.globalPosition))
                ..onLongPressMoveUpdate = ((d) => onMove(d.globalPosition))
                ..onLongPressEnd = ((_) => onEnd())
                ..onLongPressCancel = onCancel,
            ),
    },
    child: child,
  );
}
