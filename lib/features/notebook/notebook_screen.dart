import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart' show BvChatSpec;
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../data/models/note.dart';
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
import '../chat/thread_screen.dart' show ChatActionRow;
import '../chat/voice.dart';
import '../create/create_sheet.dart' show workItemSpacesProvider;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../spaces/space_screen.dart' show SpaceOpen;
import '../work/daybook_draft.dart' show daybookDraftProvider;
import '../work/daybook_words.dart';
import '../work/daybook_writing.dart' show newPostIdProvider, pickDueProvider;
import 'note_reminders.dart' show remindsAt;
import 'note_writer.dart';
import 'notebook_state.dart';

/// My notebook (NB1 2557:35384, review 83): a private daybook. Only its
/// owner reads it. Built on v13 paper: no hour spine, each slip says its
/// kind and time on its first line. Today first, under the masthead, with
/// the pinned notes on the brand-soft band; earlier days below. "Note"
/// writes one; hold the mic for a voice note.
class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({super.key});

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
  static const _tick = Duration(milliseconds: 200);

  bool _holding = false;
  bool _recording = false;
  bool _cancelling = false;
  Duration _elapsed = Duration.zero;
  Stopwatch? _watch;
  Timer? _recordTimer;

  @override
  void dispose() {
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

  Future<void> _write([Note? note]) => showNoteWriter(context, ref, note: note);

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context);
    final recorder = ref.read(voiceRecorderProvider);
    _holding = true;
    await ref.read(voicePlayerProvider.notifier).pause();
    if (!await recorder.allowed()) {
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

  /// Release: keep it as a voice note; slid away: throw it away.
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
  }

  /// The note's menu (2557:35481): Put in a Space with the Spaces, Pin to
  /// the top, Remind me (not for a voice note), Edit and Delete.
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
    final choice = await showBvSheet<Object>(
      context: context,
      builder: (sheet) => Column(
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
            else
              for (final space in spaces)
                BvListRow(
                  key: Key('note-space-${space.id}'),
                  title: space.name,
                  leading: SpaceChip(id: space.id, name: space.name),
                  trailing: const BvRowTrailing.none(),
                  onTap: () => Navigator.of(sheet).pop(space),
                ),
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
              icon: BvIcons.calendar,
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
    );
    if (!mounted || choice == null) return;
    final notebook = ref.read(notebookProvider.notifier);
    switch (choice) {
      case SpaceSummary space:
        await _putIn(note, space);
      case 'pin':
        await notebook.pin(note, on: !note.pinned);
      case 'remind':
        await _remind(note);
      case 'edit':
        await _write(note);
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

  /// Remind me: a day and a time (the daybook's picker; no time is 9 am),
  /// or Remove. Saved as the note's remind_at; this phone sets the
  /// reminder (ReminderHost).
  Future<void> _remind(Note note) async {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider)();
    final kept = note.remindAt;
    final picked = await ref.read(pickDueProvider)(
      context,
      now: now,
      day: kept == null ? null : dayOf(kept),
      at: kept,
    );
    if (!mounted || picked == null) return;
    final day = picked.day;
    final at = day == null
        ? null
        : picked.at ??
              DateTime(day.year, day.month, day.day, _morningHour);
    if (at != null && !at.isAfter(now)) {
      _toast(l10n.notebookRemindPast);
      return;
    }
    await ref
        .read(notebookProvider.notifier)
        .save(note.copyWith(remindAt: () => at));
  }

  /// A reminder picked with no time: that morning.
  static const _morningHour = 9;

  /// The Space's writing card opens with the note's words; nothing is
  /// posted until Post. The note stays here, private.
  Future<void> _putIn(Note note, SpaceSummary space) async {
    await ref
        .read(daybookDraftProvider(space.id).notifier)
        .fromNote(ref.read(newPostIdProvider)(), note);
    if (!mounted) return;
    unawaited(context.push(AppRoutes.space(space.id), extra: SpaceOpen.write));
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
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    Widget slip(Note n) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: BvNotebookSpec.slipGap),
      child: NoteSlip(
        note: n,
        words: words,
        now: now,
        onMenu: () => _menu(n),
        onEdit: n.kind == NoteKind.voice ? null : () => _write(n),
      ),
    );

    return Scaffold(
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
            child: notebook.hasError && notes.isEmpty
                ? Padding(
                    padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                    child: EmptyNote(l10n.notebookCouldntLoad),
                  )
                : ListView(
                    key: const Key('notebook-list'),
                    padding: const EdgeInsetsDirectional.only(
                      bottom: BvSpace.s24,
                    ),
                    children: [
                      BvDaybookMasthead(
                        weekday: words.weekday(today),
                        date: words.dayMonth(today),
                      ),
                      for (final n in pinned)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            BvNotebookSpec.gutter,
                            0,
                            BvNotebookSpec.gutter,
                            BvSpace.s12,
                          ),
                          child: PinnedNote(note: n, onTap: () => _menu(n)),
                        ),
                      if (notes.isEmpty && !notebook.isLoading)
                        _Empty(type: type, l10n: l10n),
                      for (final day in days) ...[
                        if (day != today)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              bottom: BvSpace.s12,
                            ),
                            child: BvDayDivider(label: words.compactDate(day)),
                          ),
                        Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: BvNotebookSpec.gutter,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [for (final n in byDay[day]!) slip(n)],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: BvPostBar(
              placeholder: l10n.notebookNote,
              onWrite: _write,
              field: _recording
                  ? RecordingBar(elapsed: _elapsed, cancelling: _cancelling)
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
    );
  }
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
/// title and points; a voice note's player. "Waiting to send" while it is
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
