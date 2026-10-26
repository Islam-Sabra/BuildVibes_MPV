import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart' show BvChatSpec, BvStroke;
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../core/photo_privacy.dart' show photosPreparingProvider;
import '../../core/l10n/bidi.dart';
import '../../core/l10n/locale_controller.dart' show sharedPreferencesProvider;
import '../../core/push/reminders.dart' show phoneRemindersProvider;
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../data/models/note.dart';
import '../../data/models/notebook_page.dart';
import '../../data/models/post_page.dart';
import '../../data/models/space.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_line_popover.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_undo_bar.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import '../../shared/widgets/bv_writing_toolbar.dart';
import '../chat/thread_screen.dart' show ChatActionRow;
import '../chat/chat_state.dart' show keepFileProvider;
import '../chat/voice.dart';
import '../create/create_sheet.dart' show workItemSpacesProvider;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../spaces/space_screen.dart' show SpaceOpen;
import '../work/daybook_draft.dart' show DaybookDraft, daybookDraftProvider;
import '../work/daybook_words.dart';
import '../library/library_parts.dart' show maxFileBytes, pickDocumentProvider;
import '../work/daybook_writing.dart'
    show newPostIdProvider, pickDueProvider, pickReminderProvider;
import '../work/work_outbox.dart' show keepPhotoProvider, pickPhotoProvider;
import 'note_draft.dart';
import 'note_location.dart';
import 'note_outline.dart' show numberAt, numberLabel, visibleLines;
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
  const NotebookPageScreen({
    super.key,
    required String this.pageId,
    this.entry,
  });

  const NotebookPageScreen.write({super.key}) : pageId = null, entry = null;

  /// Null: "New entry".
  final String? pageId;

  /// An entry to show (a search hit, A5).
  final String? entry;

  @override
  ConsumerState<NotebookPageScreen> createState() => _NotebookPageScreenState();
}

/// What stands in place of the keyboard while writing (F107).
enum _Panel { none, categories, location }

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

  /// F107: the categories grid (NBX2) or the location sheet (NBX4) in
  /// place of the keyboard, and the kind the cursor's line is.
  _Panel _panel = _Panel.none;
  NoteBlockKind _kind = NoteBlockKind.text;

  /// B3: the camera, the files or a permission prompt is in front: the
  /// app going behind doesn't put the slip down.
  int _away = 0;

  final _slipKey = GlobalKey();
  final _editorKey = GlobalKey<NotePageEditorState>();
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
    });
  }

  /// The page chip under the entry (A2): on New entry, and on a Draft
  /// begun for another page.
  bool _chip(NoteDraft draft) =>
      widget.pageId == null || draft.intoPage != widget.pageId;

  @override
  void dispose() {
    _picker.hide();
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
    return _goOn();
  }

  /// A Draft's ⋯ (review 100 B2): Discard, with Undo.
  Future<void> _draftMenu(NoteDraft draft) =>
      _oneMenu(() => _openDraftMenu(draft));

  Future<void> _openDraftMenu(NoteDraft draft) async {
    final l10n = AppLocalizations.of(context);
    final discard = await showBvSheet<bool>(
      context: context,
      builder: (sheet) => ChatActionRow(
        key: const Key('note-draft-discard'),
        icon: BvIcons.delete,
        label: l10n.notebookDiscardDraft,
        destructive: true,
        onTap: () => Navigator.of(sheet).pop(true),
      ),
    );
    if (discard != true || !mounted) return;
    final parked = ref.read(parkedDraftsProvider.notifier);
    final inHand = ref.read(noteDraftProvider)?.id == draft.id;
    if (inHand) {
      // Its files stay until the Undo bar has gone.
      await _drafts.park();
    }
    await parked.drop(draft.id);
    if (!mounted) return;
    final bar = showBvUndoBar(
      context,
      message: l10n.notebookDraftDiscarded,
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
    if (!changed || !draft.ready) {
      await _drafts.discard();
      return;
    }
    final note = _noteOf(draft);
    final notebook = ref.read(notebookProvider.notifier);
    final saving = notebook.save(note);
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
    await saving;
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

  /// + (NBX1): the categories in place of the keyboard, or the keyboard
  /// back.
  void _toggleCategories() {
    if (_panel == _Panel.categories) {
      setState(() => _panel = _Panel.none);
      _editorKey.currentState?.focusCurrent();
      return;
    }
    // Review 98: the grid is for a new line below this one (an empty text
    // line is turned itself).
    _editorKey.currentState?.lineForGrid();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _kind = _editorKey.currentState?.currentKind ?? _kind;
      _panel = _Panel.categories;
    });
  }

  /// A tile: inserted, or the empty line turned; the keyboard comes back.
  /// The Voice note tile says how to record.
  void _pickKind(NoteBlockKind kind) {
    if (kind == NoteBlockKind.voice) {
      _toast(AppLocalizations.of(context).notebookHoldVoice);
      return;
    }
    setState(() => _panel = _Panel.none);
    _editorKey.currentState?.insertKind(kind);
  }

  /// Location (NBX4): its sheet, or closed again.
  void _toggleLocation() {
    if (_panel == _Panel.location) {
      _closeLocation();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
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
  Future<void> _addPhoto() async {
    final l10n = AppLocalizations.of(context);
    final draft = ref.read(noteDraftProvider);
    if (draft == null) return;
    if (draft.photos.length >= Note.photosMax) {
      _toast(l10n.notebookPhotosFull);
      return;
    }
    final camera = await showBvSheet<bool>(
      context: context,
      builder: (sheet) => Column(
        key: const Key('note-image-menu'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChatActionRow(
            key: const Key('note-image-camera'),
            icon: BvIcons.camera,
            label: l10n.daybookCamera,
            onTap: () => Navigator.of(sheet).pop(true),
          ),
          ChatActionRow(
            key: const Key('note-image-gallery'),
            icon: BvIcons.image,
            label: l10n.daybookAttachPhotos,
            onTap: () => Navigator.of(sheet).pop(false),
          ),
        ],
      ),
    );
    if (camera == null || !mounted) return;
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

  /// The note's menu (2557:35481): Put in a Space with the Spaces (and,
  /// for a note with a GPS position, "Include my GPS position", off), Pin
  /// to the top, Remind me (not for a voice note), Edit and Delete.
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

  Future<void> _menu(Note note) => _oneMenu(() => _entryMenu(note));

  /// The entry's menu opens at once (review 100 B5); its Spaces come in
  /// as they load.
  Future<void> _entryMenu(Note note) async {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final gps = note.location?.hasGps ?? false;
    var includeGps = false;
    final choice = await showBvSheet<Object>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Consumer(
          builder: (sheet, ref, _) {
            final loaded = note.canPut
                ? ref.watch(workItemSpacesProvider)
                : const AsyncData(<SpaceSummary>[]);
            final spaces = loaded.value ?? const <SpaceSummary>[];
            return Column(
              key: const Key('note-menu'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (note.canPut) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: BvSpace.s8,
                    ),
                    child: Text(
                      l10n.dmPutInSpace,
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ),
                  if (!loaded.hasValue && !loaded.hasError)
                    const SizedBox.shrink()
                  else if (spaces.isEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: BvSpace.s8,
                      ),
                      child: Text(
                        l10n.notebookPutNone,
                        style: type.bodyMd.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                    )
                  else ...[
                    if (gps)
                      BvListRow(
                        key: const Key('note-include-gps'),
                        leading: const BvRowIcon(BvIcons.place),
                        title: l10n.notebookIncludeGps,
                        trailing: BvRowTrailing.check(selected: includeGps),
                        onTap: () => setSheet(() => includeGps = !includeGps),
                      ),
                    for (final space in spaces)
                      BvListRow(
                        key: Key('note-space-${space.id}'),
                        title: space.name,
                        leading: SpaceChip(id: space.id, name: space.name),
                        trailing: const BvRowTrailing.none(),
                        onTap: () => Navigator.of(sheet).pop(space),
                      ),
                  ],
                  const Divider(),
                ],
                ChatActionRow(
                  key: const Key('note-pin'),
                  icon: BvIcons.pin,
                  label: note.pinned ? l10n.daybookUnpin : l10n.notebookPinTop,
                  onTap: () => Navigator.of(sheet).pop('pin'),
                ),
                if (note.kind != NoteKind.voice)
                  ChatActionRow(
                    key: const Key('note-remind'),
                    icon: BvIcons.remind,
                    label: l10n.notebookRemindMe,
                    onTap: () => Navigator.of(sheet).pop('remind'),
                  ),
                if (note.kind != NoteKind.voice)
                  ChatActionRow(
                    key: const Key('note-edit'),
                    icon: BvIcons.edit,
                    label: l10n.daybookEdit,
                    onTap: () => Navigator.of(sheet).pop('edit'),
                  ),
                ChatActionRow(
                  key: const Key('note-move'),
                  icon: BvIcons.moveInto,
                  label: l10n.notebookMoveToPage,
                  onTap: () => Navigator.of(sheet).pop('move'),
                ),
                ChatActionRow(
                  key: const Key('note-delete'),
                  icon: BvIcons.delete,
                  label: l10n.delete,
                  destructive: true,
                  onTap: () => Navigator.of(sheet).pop('delete'),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final notebook = ref.read(notebookProvider.notifier);
    switch (choice) {
      case SpaceSummary space:
        await _putIn(note, space, includeGps: includeGps);
      case 'pin':
        await notebook.pin(note, on: !note.pinned);
      case 'remind':
        await _remind(note);
      case 'move':
        await _moveEntries([note]);
      case 'edit':
        await _edit(note);
      case 'delete':
        final yes = await showBvDialog(
          context: context,
          title: l10n.notebookDeleteTitle,
          body: l10n.notebookDeleteBody,
          cancelLabel: l10n.commonCancel,
          confirmLabel: l10n.delete,
          destructive: true,
        );
        if (yes) await notebook.delete(note);
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

  /// A reminder picked with no time: that morning.
  static const _morningHour = 9;

  /// The Space's writing card opens with the note's words; nothing is
  /// posted until Post. The note stays here, private. F107: what goes is
  /// note_for_space's (the typed location; the GPS only when
  /// [includeGps]), with the note's photos (B11: copies for the card);
  /// with no signal, the same from the phone's note.
  Future<void> _putIn(
    Note note,
    SpaceSummary space, {
    required bool includeGps,
  }) async {
    final repo = ref.read(notebookRepositoryProvider);
    var carried = note.copyWith(
      location: () {
        final l = note.location;
        return l == null || includeGps ? l : l.withoutGps();
      },
    );
    try {
      final row = await repo.forSpace(note.id, includeGps: includeGps);
      carried = Note.fromJson({
        ...row,
        'created_at': note.createdAt.toUtc().toIso8601String(),
      }).copyWith(photos: note.photos);
    } on SpaceException {
      // No signal: the note as the phone has it, with the same rule.
    }
    final photos = <String>[];
    var missed = 0;
    for (final p in carried.photos) {
      final copy = await _photoCopy(p);
      copy == null ? missed++ : photos.add(copy);
    }
    if (!mounted) return;
    if (missed > 0) _toast(AppLocalizations.of(context).notebookPhotosStay);
    await ref
        .read(daybookDraftProvider(space.id).notifier)
        .fromNote(ref.read(newPostIdProvider)(), carried, photos: photos);
    if (!mounted) return;
    unawaited(context.push(AppRoutes.space(space.id), extra: SpaceOpen.write));
  }

  /// A copy of a note's photo for a Space's card (its own file, which the
  /// card may delete once posted); null when it can't be had.
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
    _toast(
      l10n.notebookMovedTo(
        page == null ? l10n.notebookNewPage : pageName(l10n, page),
      ),
    );
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

  /// Delete the selected entries, after one confirm.
  Future<void> _deleteSelected(List<Note> notes) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showBvDialog(
      context: context,
      title: l10n.notebookDeleteTitle,
      body: l10n.notebookDeleteBody,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!yes || !mounted) return;
    final notebook = ref.read(notebookProvider.notifier);
    setState(_selected.clear);
    for (final n in notes) {
      await notebook.delete(n);
    }
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
    ref.listen(noteRefusedProvider, (_, lost) {
      if (lost == null) return;
      ref.read(noteRefusedProvider.notifier).seen();
      _toast(l10n.notebookCouldntKeep);
      final back = NoteDraft.back(
        lost,
      ).copyWith(photos: const [], files: const [], location: () => null);
      // Its own Draft card; beside the one in hand if there is one (B3).
      unawaited(
        ref.read(noteDraftProvider) == null
            ? _drafts.put(back)
            : ref.read(parkedDraftsProvider.notifier).keep(back),
      );
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
    final entries = page == null ? const <Note>[] : data.entries(page.id);
    final chosen = [
      for (final n in entries)
        if (_selected.contains(n.id)) n,
    ];
    if (widget.entry != null && !_shownEntry && entries.isNotEmpty) {
      _shownEntry = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final at = _entryKey.currentContext;
        if (at != null && at.mounted) {
          unawaited(Scrollable.ensureVisible(at, alignment: 0.2));
        }
      });
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
          onMenu: writing ? null : () => unawaited(_draftMenu(draft)),
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

    Widget entry(Note n) => Padding(
      key: n.id == widget.entry ? _entryKey : null,
      padding: const EdgeInsetsDirectional.only(
        bottom: BvNotebookPagesSpec.entryGap,
      ),
      child: NoteSlip(
        note: n,
        words: words,
        now: now,
        selected: _selected.contains(n.id),
        onMenu: () => _menu(n),
        onEdit: selecting
            ? () => _select(n)
            : n.kind == NoteKind.voice
            ? null
            : () => _edit(n),
        onLongPress: () => _select(n),
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
    // B3: every Draft of a new entry in this page, each its own card; the
    // one in hand first.
    bool here(NoteDraft d) =>
        page != null && (d.intoPage ?? data.latest?.id) == page.id;
    final drafts = [
      if (draft != null && !writingNow && draft.editing == null && here(draft))
        draft,
      for (final d in ref.watch(parkedDraftsProvider))
        if (here(d) && d.id != draft?.id) d,
    ];

    Widget browse(NotebookPage page) {
      final path = data.path(page.id);
      return ListView(
        key: const Key('notebook-list'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          BvSpace.gutter,
          BvSpace.s8,
          BvSpace.gutter,
          BvSpace.s64 + BvSpace.s32,
        ),
        children: [
          Wrap(
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
          const SizedBox(height: BvNotebookPagesSpec.pathBottom),
          Row(
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
          const SizedBox(height: BvNotebookPagesSpec.titleBottom),
          for (final sub in data.children(page.id))
            Padding(
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
          if (drafts.isNotEmpty) ...[
            NotebookLabel(l10n.daybookDraft),
            for (final d in drafts)
              KeyedSubtree(
                key: Key('note-draft-card-${d.id}'),
                child: writingSlip(d, writing: false),
              ),
          ],
          if (pinned.isNotEmpty) ...[
            NotebookLabel(l10n.notebookPinnedLabel),
            for (final n in pinned) entry(n),
          ],
          for (final day in byDay.keys) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: BvNotebookPagesSpec.dayTop,
              ),
              child: NotebookLabel(words.compactDate(day)),
            ),
            for (final n in byDay[day]!) entry(n),
          ],
        ],
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
      if (page != null) return browse(page);
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
        if (_editorKey.currentState?.closeMenus() ?? false) return;
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
      child: Scaffold(
        backgroundColor: BvColors.surfaceApp,
        appBar: AppBar(
          backgroundColor: BvColors.surfaceApp,
          leading: selecting
              ? IconButton(
                  key: const Key('selection-close'),
                  tooltip: l10n.notebookCloseSelection,
                  icon: const Icon(BvIcons.close),
                  onPressed: () => setState(_selected.clear),
                )
              : null,
          title: selecting
              ? Text(l10n.notebookSelected(_selected.length))
              : writingNow
              ? Text(writingTitle, key: const Key('writing-page-title'))
              : null,
          actions: [
            if (!selecting && !writingNow && page != null) ...[
              IconButton(
                key: const Key('page-search'),
                tooltip: l10n.notebookSearchTip,
                icon: const Icon(BvIcons.search),
                onPressed: () => context.push(AppRoutes.notebookSearch),
              ),
              IconButton(
                key: const Key('page-more'),
                tooltip: l10n.daybookMore,
                icon: const Icon(BvIcons.more),
                onPressed: () => _pageMenu(page),
              ),
            ],
          ],
        ),
        floatingActionButton: !writingNow && !selecting && page != null
            ? WriteHereButton(onTap: () => unawaited(_write()))
            : null,
        body: Column(
          children: [
            Expanded(child: body()),
            if (writingNow)
              SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tools(l10n, draft),
                    if (_panel == _Panel.categories)
                      SizedBox(
                        height: BvNoteBlocksSpec.panelHeight,
                        child: NoteCategoriesGrid(
                          current: _kind,
                          onPick: _pickKind,
                        ),
                      ),
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
        bottomNavigationBar: selecting
            ? SelectionBar(
                actions: [
                  SelectionAction(
                    key: const Key('select-move'),
                    icon: BvIcons.moveInto,
                    label: l10n.notebookMoveToPage,
                    onTap: () => _moveEntries(chosen),
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
    );
  }

  /// The additions bar (NBX1 2619:36779): + for the categories, ⇥ and ⇤
  /// each only while the line being written can move that way (review 93;
  /// review 98 NBY3, NBY4: hidden, not greyed), a thin line, then
  /// Location, Image, File, Date, Remind me and Voice, then Send. An
  /// addition in use is tinted; Send is grey until there is something to
  /// keep.
  Widget _tools(AppLocalizations l10n, NoteDraft draft) {
    final editor = _editorKey.currentState;
    final deeper = editor?.canIndentCurrent ?? false;
    final out = editor?.canOutdentCurrent ?? false;
    return BvWritingToolbar.tools(
      key: const Key('note-tools'),
      categories: BvWritingTool(
        key: const Key('note-tool-categories'),
        icon: BvIcons.create,
        label: l10n.notebookCategories,
        onTap: _toggleCategories,
      ),
      categoriesOpen: _panel == _Panel.categories,
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
          key: const Key('note-tool-location'),
          icon: BvIcons.place,
          label: l10n.notebookLocation,
          active:
              _panel == _Panel.location || !(draft.location?.isEmpty ?? true),
          onTap: _toggleLocation,
        ),
        BvWritingTool(
          key: const Key('note-tool-image'),
          icon: BvIcons.image,
          label: l10n.notebookImage,
          active: draft.photos.isNotEmpty,
          onTap: () => unawaited(_addPhoto()),
        ),
        BvWritingTool(
          key: const Key('note-tool-file'),
          icon: BvIcons.attach,
          label: l10n.notebookFile,
          active: draft.files.isNotEmpty,
          onTap: () => unawaited(_addFile()),
        ),
        BvWritingTool(
          key: const Key('note-tool-date'),
          icon: BvIcons.due,
          label: l10n.notebookDate,
          active: draft.dueAt != null,
          onTap: () => unawaited(_pickDue()),
        ),
        BvWritingTool(
          key: const Key('note-tool-remind'),
          icon: BvIcons.remind,
          label: l10n.notebookRemindMe,
          active: draft.remindAt != null,
          onTap: () => unawaited(_pickRemind()),
        ),
        // F107: hold for a voice block inside the note.
        BvWritingTool(
          key: const Key('note-tool-voice'),
          icon: BvIcons.microphone,
          label: l10n.notebookVoiceTool,
          onTap: () => _toast(l10n.chatRecord),
          onHoldStart: _startRecording,
          onHoldMove: _slide,
          onHoldEnd: _endRecording,
        ),
      ],
      field: _recording
          ? RecordingBar(elapsed: _elapsed, cancelling: _cancelling)
          : null,
      postLabel: l10n.chatSend,
      onPost: draft.ready ? () => unawaited(_send()) : null,
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
    required this.onMenu,
    this.onEdit,
    this.onLongPress,
    this.selected = false,
  });

  final Note note;
  final DaybookWords words;
  final DateTime now;
  final VoidCallback onMenu;
  final VoidCallback? onEdit;

  /// A long-press: select it (review 99 A4); the ⋯ opens [onMenu].
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
          Semantics(
            button: true,
            label: l10n.daybookMore,
            excludeSemantics: true,
            child: InkResponse(
              key: Key('note-menu-${note.id}'),
              onTap: onMenu,
              radius: BvNotebookPagesSpec.entryMenu,
              child: const SizedBox.square(
                dimension: BvNotebookPagesSpec.entryMenu,
                child: Icon(
                  BvIcons.more,
                  size: BvSize.iconSm,
                  color: BvColors.iconSecondary,
                ),
              ),
            ),
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
      if (note.putInPostId != null && !note.waiting)
        BvSlipQuiet(l10n.notebookPut),
    ];
    // PG4: a plain white card; selected (A4), lifted with the selected edge.
    return DecoratedBox(
      key: Key('note-${note.id}'),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
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
            onLongPress: onLongPress ?? onMenu,
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
