import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart' show BvChatSpec;
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../core/photo_privacy.dart' show photosPreparingProvider;
import '../../core/l10n/bidi.dart';
import '../../core/l10n/locale_controller.dart' show sharedPreferencesProvider;
import '../../core/push/reminders.dart' show phoneRemindersProvider;
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../data/models/note.dart';
import '../../data/models/post_page.dart';
import '../../data/models/space.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_daybook_masthead.dart';
import '../../shared/widgets/bv_day_divider.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_post_bar.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_torn_edge.dart';
import '../../shared/widgets/bv_writing_toolbar.dart';
import '../chat/thread_screen.dart' show ChatActionRow;
import '../chat/chat_state.dart' show keepFileProvider;
import '../chat/voice.dart';
import '../create/create_sheet.dart' show workItemSpacesProvider;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../spaces/space_screen.dart' show SpaceOpen;
import '../work/daybook_draft.dart' show daybookDraftProvider;
import '../work/daybook_words.dart';
import '../library/library_parts.dart' show maxFileBytes, pickDocumentProvider;
import '../work/daybook_writing.dart'
    show newPostIdProvider, pickDueProvider, pickReminderProvider;
import '../work/work_outbox.dart' show keepPhotoProvider, pickPhotoProvider;
import 'note_draft.dart';
import 'note_location.dart';
import 'note_page_editor.dart';
import 'note_reminders.dart' show remindsAt;
import 'note_writing.dart';
import 'notebook_state.dart';

/// My notebook (NB1 2557:35384, review 83): a private daybook. Only its
/// owner reads it. Built on v13 paper: no hour spine, each slip says its
/// kind and time on its first line. The masthead and the pinned notes on
/// the brand-soft band at the top; the days at the foot, today first,
/// then earlier days. "Note" writes one in place at the end of today
/// (F106, review 90), as a page (F107, review 92): + opens the categories
/// in place of the keyboard, and the additions bar attaches a location,
/// photos, PDFs, a date, a reminder or a voice block. Hold the mic for a
/// voice note.
class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({super.key});

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

/// What stands in place of the keyboard while writing (F107).
enum _Panel { none, categories, location }

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
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
    // B8: the notebook opening sends what waits.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(notebookProvider.notifier).retry());
    });
  }

  @override
  void dispose() {
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

  /// "Note": a slip at the end of today, or the Draft again (one at a
  /// time), with the keyboard up.
  Future<void> _write() async {
    if (ref.read(noteDraftProvider) == null) {
      await _drafts.put(
        NoteDraft(
          id: ref.read(newPostIdProvider)(),
          startedAt: ref.read(clockProvider)(),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _writing = true);
    _showSlip();
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
      if (!draft.isEmpty) {
        _toast(AppLocalizations.of(context).notebookDraftFirst);
        return _write();
      }
      await _drafts.discard();
    }
    if (ref.read(noteDraftProvider) == null) {
      await _drafts.put(NoteDraft.of(note));
    }
    return _write();
  }

  /// Back, the app going behind, or Send: the slip is put down. One with
  /// anything in it stays as the Draft (NBW5); an empty one is gone.
  void _putDown() {
    if (!_writing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _writing = false;
      _panel = _Panel.none;
    });
    unawaited(_drafts.close());
  }

  /// Send (it replaces Save): the note is kept, and the slip is gone.
  Future<void> _send() async {
    final draft = ref.read(noteDraftProvider);
    if (draft == null || !draft.ready) return;
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider)();
    var note = draft.toNote(now);
    // B14: the pin as the notebook has it now, not as the edit began.
    final current = ref
        .read(notebookProvider)
        .value
        ?.where((n) => n.id == note.id)
        .firstOrNull;
    if (current != null) note = note.copyWith(pinned: current.pinned);
    // B16: a reminder whose time went by while it was a draft goes.
    final remind = note.remindAt;
    if (remind != null && !remind.isAfter(now)) {
      note = note.copyWith(remindAt: () => null);
      _toast(l10n.notebookReminderGone);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _writing = false;
      _panel = _Panel.none;
    });
    // B13: the note is on the phone's list before the draft goes.
    final saving = ref.read(notebookProvider.notifier).save(note);
    await _drafts.discard(keepFiles: true);
    _showEnd();
    await saving;
  }

  /// The end of today in view (B9): where the notebook opens, and where a
  /// sent note goes.
  void _showEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final end = _todayEnd.currentContext;
    if (end == null || !end.mounted) return;
    unawaited(
      Scrollable.ensureVisible(
        end,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: BvMotion.fast,
        curve: BvMotion.standard,
      ),
    );
  });

  /// After today's last slip.
  final _todayEnd = GlobalKey();

  /// The notebook has been shown at the end of today once (B9).
  var _shownToday = false;

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
          ),
        );
    _showEnd();
  }

  /// The note's menu (2557:35481): Put in a Space with the Spaces (and,
  /// for a note with a GPS position, "Include my GPS position", off), Pin
  /// to the top, Remind me (not for a voice note), Edit and Delete.
  Future<void> _menu(Note note) async {
    final l10n = AppLocalizations.of(context);
    List<SpaceSummary> spaces = const [];
    if (note.canPut) {
      final keep = ref.listenManual(workItemSpacesProvider, (_, _) {});
      spaces = await ref
          .read(workItemSpacesProvider.future)
          .catchError((Object _) => const <SpaceSummary>[])
          .whenComplete(keep.close);
      if (!mounted) return;
    }
    final type = BvType.of(context);
    final gps = note.location?.hasGps ?? false;
    var includeGps = false;
    final choice = await showBvSheet<Object>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Column(
          key: const Key('note-menu'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (note.canPut) ...[
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s8),
                child: Text(
                  l10n.dmPutInSpace,
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
                ),
              ),
              if (spaces.isEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s8),
                  child: Text(
                    l10n.notebookPutNone,
                    style: type.bodyMd.copyWith(color: BvColors.textSecondary),
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
              key: const Key('note-delete'),
              icon: BvIcons.delete,
              label: l10n.delete,
              destructive: true,
              onTap: () => Navigator.of(sheet).pop('delete'),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = _words();
    final now = ref.watch(clockProvider)();
    final today = dayOf(now);
    final notebook = ref.watch(notebookProvider);
    final notes = notebook.value ?? const <Note>[];
    final draft = ref.watch(noteDraftProvider);
    // B10: as the slip grows, its end stays above the bar.
    ref.listen(noteDraftProvider, (_, _) {
      if (_writing) _showSlip();
    });
    if (!_shownToday && notebook.hasValue) {
      _shownToday = true;
      _showEnd();
    }
    // B15: a refused note is said, and its words come back as the Draft.
    ref.listen(noteRefusedProvider, (_, lost) {
      if (lost == null) return;
      ref.read(noteRefusedProvider.notifier).seen();
      _toast(l10n.notebookCouldntKeep);
      if (ref.read(noteDraftProvider) == null) {
        unawaited(
          _drafts.put(
            NoteDraft.of(
              lost,
            ).copyWith(photos: const [], files: const [], location: () => null),
          ),
        );
      }
    });
    final pinned = [
      for (final n in notes)
        if (n.pinned) n,
    ];
    // Each day oldest to newest (NB1); today first, then earlier days.
    final byDay = <DateTime, List<Note>>{};
    for (final n in notes.reversed) {
      if (n.pinned) continue;
      byDay.putIfAbsent(dayOf(n.createdAt), () => []).add(n);
    }
    // F106: the slip being written, or the Draft, among today's notes at
    // the time it was started (so at the end of today); an edit in the
    // edited note's place.
    final editing = draft?.editing;
    final inPlace =
        editing != null &&
        (byDay[dayOf(editing.createdAt)]?.any((n) => n.id == editing.id) ??
            false);
    if (draft != null && !inPlace) byDay.putIfAbsent(today, () => []);
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    Widget slip(Note n) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: BvNotebookSpec.slipGap),
      child: NoteSlip(
        note: n,
        words: words,
        now: now,
        onMenu: () => _menu(n),
        onEdit: n.kind == NoteKind.voice ? null : () => _edit(n),
      ),
    );

    Widget writingSlip() => Padding(
      key: _slipKey,
      padding: const EdgeInsetsDirectional.only(bottom: BvNotebookSpec.slipGap),
      child: NoteWritingSlip(
        key: ValueKey(('note-writing', draft!.id)),
        writing: _writing,
        words: words,
        onOpen: _write,
        onPickDue: () => unawaited(_pickDue()),
        onPickRemind: () => unawaited(_pickRemind()),
        onLocation: _toggleLocation,
        editorKey: _editorKey,
        titleFocus: _titleFocus,
        onCurrentKind: (k) => _kind = k,
      ),
    );

    List<Widget> dayNotes(DateTime day) {
      final list = byDay[day]!;
      if (draft == null) return [for (final n in list) slip(n)];
      if (inPlace) {
        return [
          for (final n in list) n.id == editing.id ? writingSlip() : slip(n),
        ];
      }
      if (day != today) return [for (final n in list) slip(n)];
      final at = dayOf(draft.startedAt) == today ? draft.startedAt : now;
      // A note made since (a voice note while writing) comes after it.
      final before = list.where((n) => n.createdAt.isBefore(at)).length;
      return [
        for (final n in list.take(before)) slip(n),
        writingSlip(),
        for (final n in list.skip(before)) slip(n),
      ];
    }

    List<Widget> dayPart(DateTime day) => [
      ...dayNotes(day),
      if (day == today) SizedBox(key: _todayEnd),
    ];

    final drafting = draft != null;
    final daysPart = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s12),
            child: BvDayDivider(
              label: day == today
                  ? l10n.daybookTodayDivider
                  : words.compactDate(day),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvNotebookSpec.gutter,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: dayPart(day),
            ),
          ),
        ],
      ],
    );

    final writingNow = _writing && draft != null;
    return PopScope(
      // Back while writing closes the grid or the location sheet first,
      // then puts the slip down, kept as the Draft (NBW5).
      canPop: !_writing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_panel != _Panel.none) {
          setState(() => _panel = _Panel.none);
          return;
        }
        _putDown();
      },
      child: Scaffold(
        backgroundColor: BvColors.surfaceApp,
        appBar: AppBar(
          backgroundColor: BvColors.surfaceApp,
          title: Text(l10n.notebookTitle),
          actions: [
            IconButton(
              key: const Key('notebook-calendar'),
              tooltip: l10n.calendarTitle,
              icon: const Icon(BvIcons.calendar),
              onPressed: () => context.push(AppRoutes.calendar),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: BvSpace.s12),
              child: _OnlyYou(onTap: () => _toast(l10n.notebookOnlyYouBody)),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: notebook.hasError && notes.isEmpty && !drafting
                  ? Padding(
                      padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                      child: EmptyNote(l10n.notebookCouldntLoad),
                    )
                  : LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        key: const Key('notebook-list'),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              bottom: BvSpace.s12,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    BvDaybookMasthead(
                                      weekday: words.weekday(today),
                                      date: words.dayMonth(today),
                                    ),
                                    for (final n in pinned)
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.fromSTEB(
                                              BvNotebookSpec.gutter,
                                              0,
                                              BvNotebookSpec.gutter,
                                              BvSpace.s12,
                                            ),
                                        child: PinnedNote(
                                          note: n,
                                          onTap: () => _menu(n),
                                        ),
                                      ),
                                    if (notes.isEmpty &&
                                        !drafting &&
                                        !notebook.isLoading)
                                      _Empty(type: type, l10n: l10n),
                                  ],
                                ),
                                daysPart,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: writingNow
                  ? Column(
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
                    )
                  : BvPostBar(
                      placeholder: l10n.notebookNote,
                      onWrite: () => unawaited(_write()),
                      field: _recording
                          ? RecordingBar(
                              elapsed: _elapsed,
                              cancelling: _cancelling,
                            )
                          : null,
                      end: RecordButton(
                        onStart: _startRecording,
                        onSlide: _slide,
                        onEnd: _endRecording,
                        onTap: () => _toast(l10n.chatRecord),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The additions bar (NBX1 2619:36779): + for the categories, a thin
  /// line, then Location, Image, File, Date, Remind me and Voice, then
  /// Send. An addition in use is tinted; Send is grey until there is
  /// something to keep.
  Widget _tools(AppLocalizations l10n, NoteDraft draft) =>
      BvWritingToolbar.tools(
        key: const Key('note-tools'),
        categories: BvWritingTool(
          key: const Key('note-tool-categories'),
          icon: BvIcons.create,
          label: l10n.notebookCategories,
          onTap: _toggleCategories,
        ),
        categoriesOpen: _panel == _Panel.categories,
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

/// "Only you" (2557:35400): a quiet pill; a tap says what it means.
class _OnlyYou extends StatelessWidget {
  const _OnlyYou({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Semantics(
      button: true,
      child: Material(
        key: const Key('notebook-only-you'),
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
              spacing: BvNotebookSpec.pillGap,
              children: [
                const Icon(
                  BvIcons.info,
                  size: BvNotebookSpec.pillIcon,
                  color: BvColors.iconPrimary,
                ),
                Text(
                  l10n.notebookOnlyYou,
                  style: type.labelSm.copyWith(color: BvColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The empty notebook (N2's words).
class _Empty extends StatelessWidget {
  const _Empty({required this.type, required this.l10n});

  final BvTypeSet type;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('notebook-empty'),
    padding: const EdgeInsetsDirectional.all(BvSpace.s32),
    child: Column(
      spacing: BvSpace.s8,
      children: [
        const Icon(
          BvIcons.notebook,
          size: BvNotebookSpec.emptyIcon,
          color: BvColors.iconSecondary,
        ),
        Text(
          l10n.notebookEmptyTitle,
          textAlign: TextAlign.center,
          style: type.titleMd.copyWith(color: BvColors.textPrimary),
        ),
        Text(
          l10n.notebookEmptyBody,
          textAlign: TextAlign.center,
          style: type.bodyMd.copyWith(color: BvColors.textSecondary),
        ),
      ],
    ),
  );
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

/// A pinned note on the brand-soft band (2557:35405): its words, and the
/// dot the frame pins it with.
class PinnedNote extends StatelessWidget {
  const PinnedNote({super.key, required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Material(
      key: Key('note-pinned-${note.id}'),
      color: BvColors.surfaceBrandSoft,
      borderRadius: BvRadius.controlAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(
            BvNotebookSpec.pinnedPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvSpace.s8,
            children: [
              const Icon(
                BvIcons.pin,
                size: BvNotebookSpec.dueIcon,
                color: BvColors.iconAction,
              ),
              Expanded(
                child: Text(
                  note.kind == NoteKind.checklist
                      ? [
                          note.body,
                          for (final p in note.points) '· ${p.text}',
                        ].join('\n')
                      : note.body,
                  style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  });

  final Note note;
  final DaybookWords words;
  final DateTime now;
  final VoidCallback onMenu;
  final VoidCallback? onEdit;

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
    return BvSlip(
      key: Key('note-${note.id}'),
      tear: BvSlipBorder.forId(note.id).variant,
      menu: BvSlipCornerMenu(label: l10n.daybookMore, onTap: onMenu),
      onTap: onEdit,
      onLongPress: onMenu,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            end: BvSlipCornerMenu.reserve,
          ),
          child: BvSlipQuiet(
            l10n.notebookSlipHead(kind, words.time.clock(note.createdAt)),
          ),
        ),
        if (note.isPage)
          NotePageSummary(note: note, words: words, now: now)
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
              local: note.recording?.path == null
                  ? note.recording?.local
                  : null,
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
      ],
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
  });

  final Note note;
  final DaybookWords words;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final main = type.bodyMd.copyWith(color: BvColors.textPrimary);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final blocks = note.blocks ?? const <PageBlock>[];
    final shown = blocks.take(BvNoteBlocksSpec.slipLines).toList();
    final more = blocks.length > shown.length;
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
          NoteNumber(_number(blocks, i)),
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
        if (note.title.trim().isNotEmpty)
          Text(
            note.title.trim(),
            textDirection: directionOf(note.title),
            style: type.headingMd.copyWith(color: BvColors.textPrimary),
          ),
        for (final (i, b) in shown.indexed) block(i, b),
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

  static int _number(List<PageBlock> blocks, int index) {
    var n = 1;
    for (var i = index - 1; i >= 0 && blocks[i] is PageNumbered; i--) {
      n++;
    }
    return n;
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
