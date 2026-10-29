import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/bv_time.dart';
import '../../core/push/push_messaging.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/chat.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_highlight.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_slip.dart' show BvSlipQuote;
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import 'shared_post_bubble.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../library/library_parts.dart';
import '../profile/widgets/profile_parts.dart';
import '../../data/repositories/safety_repository.dart';
import '../safety/report_flow.dart';
import '../spaces/space_errors.dart';
import '../work/work_outbox.dart' show pickPhotoProvider;
import 'chat_state.dart';
import '../../data/models/daybook.dart' show DaybookQuote;
import '../spaces/space_screen.dart' show SpaceOpen;
import '../work/daybook_draft.dart' show daybookDraftProvider;
import '../work/daybook_writing.dart' show newPostIdProvider;
import 'chat_tab.dart';
import 'meeting_notes_screen.dart';
import '../spaces/week_report_screen.dart' show WeekReportBubble;
import '../notebook/notebook_state.dart';
import 'voice.dart';
import '../spaces/former_member.dart';
import '../../shared/widgets/bv_name_text.dart';

/// S8k · the Everyone thread, S9k · a Team thread: messages live, replies,
/// work item cards, and messages kept on the phone after a weak signal.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({
    super.key,
    required this.spaceId,
    required this.threadId,
    this.atMessage,
    this.shareFile,
  });

  final String spaceId;
  final String threadId;

  /// F77: Share in chat: this Library file waits in the message box, so
  /// words can go with it before Send.
  final LibraryFile? shareFile;

  /// Opened from Search at this message: scrolled to it, highlighted.
  final String? atMessage;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final ChatRepository _repo = ref.read(chatRepositoryProvider);
  ChatReply? _replyTo;
  String? _newest;

  /// [ThreadScreen.atMessage]'s row, and its ring once it is found.
  final _atKey = GlobalKey();
  String? _flashAt;
  var _revealed = false;

  /// Photos and a PDF picked for the next message, kept on the phone.
  final _files = <PhoneFile>[];

  /// F77: a Library file to share with the next message.
  late LibraryFile? _sharing = widget.shareFile;
  static const _maxFiles = 10;

  // Recording a voice note. The length comes from a clock ([_watch]); the
  // timer only redraws the time shown (review 15).
  static const _tick = Duration(milliseconds: 250);
  Stopwatch? _watch;
  var _recording = false;

  /// The thumb is on the mic. Asking for the microphone or starting the
  /// recorder takes a moment; if the thumb is gone by then, nothing
  /// records (the first hold only grants the microphone).
  var _holding = false;
  var _cancelling = false;
  var _elapsed = Duration.zero;
  Timer? _recordTimer;

  late final PushMessaging _push = ref.read(pushMessagingProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_maybeLoadOlder);
    unawaited(_markRead());
    _clearNotification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    if (_recording) unawaited(ref.read(voiceRecorderProvider).cancel());
    // Leaving counts as read too.
    unawaited(_markRead());
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// A call, the home button or a locked screen: a recording is thrown
  /// away (the thumb-up may never come), and playback pauses.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Back on this thread: its notification goes (F102).
      _clearNotification();
      return;
    }
    unawaited(ref.read(voicePlayerProvider.notifier).pause());
    if (_recording || _holding) {
      _cancelling = true;
      unawaited(_endRecording());
    }
  }

  /// F102: the thread's phone notification (tagged with its id) goes once
  /// it is open.
  void _clearNotification() =>
      unawaited(_push.clearNotification(widget.threadId));

  Future<void> _markRead() async {
    try {
      await _repo.markRead(widget.threadId);
    } on SpaceException {
      // Read state catches up next time.
    }
  }

  // The list is reversed: the oldest messages are at the far end.
  void _maybeLoadOlder() {
    if (_scroll.position.extentAfter < BvSpace.s64 * 4) {
      unawaited(
        ref.read(threadMessagesProvider(widget.threadId).notifier).loadOlder(),
      );
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Camera, a photo from the phone, or a PDF (which also goes to the
  /// Library). Only for passes that may add files.
  Future<void> _attach() async {
    final l10n = AppLocalizations.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    final choice = await showBvSheet<_Attach>(
      context: context,
      builder: (context) => Column(
        key: const Key('chat-attach-sheet'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatActionRow(
            key: const Key('chat-attach-camera'),
            icon: BvIcons.camera,
            label: l10n.chatAttachCamera,
            onTap: () => Navigator.of(context).pop(_Attach.camera),
          ),
          ChatActionRow(
            key: const Key('chat-attach-gallery'),
            icon: BvIcons.image,
            label: l10n.chatAttachGallery,
            onTap: () => Navigator.of(context).pop(_Attach.gallery),
          ),
          ChatActionRow(
            key: const Key('chat-attach-pdf'),
            icon: BvIcons.document,
            label: l10n.chatAttachPdf,
            help: l10n.chatAttachPdfHelp,
            onTap: () => Navigator.of(context).pop(_Attach.pdf),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    PhoneFile? picked;
    var refused = false;
    if (choice == _Attach.pdf) {
      if (_files.any((f) => f.isPdf)) {
        _toast(l10n.chatOneDocument);
        return;
      }
      (file: picked, :refused) = await ref.read(pickDocumentProvider)(
        pdfOnly: true,
      );
    } else {
      final photos = await ref.read(pickPhotoProvider)(
        camera: choice == _Attach.camera,
      );
      final photo = photos.photos.firstOrNull;
      if (photo != null) picked = pickedPhoto(photo.path);
      refused = photos.refused > 0;
    }
    if (!mounted) return;
    // Review 74 H1: a photo nobody could open doesn't go.
    if (refused) _toast(l10n.photoCannotOpen);
    if (picked == null) return;
    if ((picked.bytes ?? 0) > maxFileBytes) {
      _toast(l10n.chatFileTooBig);
      return;
    }
    // A copy of our own, so it survives until the message is sent.
    final kept = await ref.read(keepFileProvider)(
      picked.local,
      picked.extension,
    );
    if (!mounted) return;
    setState(
      () => _files.add(
        PhoneFile(
          local: kept,
          name: picked!.name,
          mime: picked.mime,
          bytes: picked.bytes,
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    final recorder = ref.read(voiceRecorderProvider);
    _holding = true;
    // One sound at a time: a playing note pauses.
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
      // Two minutes at most: it sends itself.
      if (_elapsed >= maxVoice) unawaited(_endRecording());
    });
  }

  void _slide(Offset offset) {
    final cancelling = offset.distance > BvChatSpec.slideToCancel;
    if (cancelling != _cancelling) setState(() => _cancelling = cancelling);
  }

  /// Release: send it; slid away: throw it away; too short: say so.
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
      unawaited(_deleteQuietly(path));
      _toast(l10n.chatVoiceTooShort);
      return;
    }
    final file = File(path);
    final space = ref.read(spaceDetailProvider(widget.spaceId)).value;
    final m = PendingMessage(
      id: newUuid(),
      threadId: widget.threadId,
      spaceId: space?.id ?? widget.spaceId,
      body: '',
      createdAt: ref.read(clockProvider)(),
      reply: _replyTo,
      // A voice note goes on its own.
      files: [
        PendingFile(
          file: PhoneFile(
            local: path,
            name: path.split(Platform.pathSeparator).last,
            mime: 'audio/mp4',
            bytes: file.existsSync() ? file.lengthSync() : null,
            durationMs: length.inMilliseconds,
          ),
        ),
      ],
    );
    setState(() => _replyTo = null);
    await _deliver(() => ref.read(chatOutboxProvider.notifier).send(m));
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    final sharing = _sharing;
    if (sharing != null) {
      // F77: the Library file goes with the words typed (share_library_file).
      _text.clear();
      setState(() => _sharing = null);
      await _deliver(() async {
        await _repo.shareFile(
          id: newUuid(),
          threadId: widget.threadId,
          fileId: sharing.id,
          body: body.isEmpty ? null : body,
        );
        ref.invalidate(spaceThreadsProvider(widget.spaceId));
        return true;
      });
      if (_files.isEmpty) return;
      return _send();
    }
    if (body.isEmpty && _files.isEmpty) return;
    final space = ref.read(spaceDetailProvider(widget.spaceId)).value;
    final m = PendingMessage(
      id: newUuid(),
      threadId: widget.threadId,
      spaceId: space?.id ?? widget.spaceId,
      body: body,
      createdAt: ref.read(clockProvider)(),
      reply: _replyTo,
      files: [for (final f in _files) PendingFile(file: f)],
    );
    _text.clear();
    setState(() {
      _replyTo = null;
      _files.clear();
    });
    await _deliver(() => ref.read(chatOutboxProvider.notifier).send(m));
  }

  Future<void> _retry(String id) =>
      _deliver(() => ref.read(chatOutboxProvider.notifier).retry(id));

  Future<void> _deliver(Future<bool> Function() run) async {
    try {
      await run();
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
  }

  /// S8m (review 64): the Work tab opens with a work item being written,
  /// the message quoted in it ("From Rakesh Nair · 10:15"), made from it
  /// (p_source_message). A Team thread's message stays in that Team; the
  /// server checks it too. Nothing is posted until Post.
  /// Scrolls up the thread until [ThreadScreen.atMessage]'s row is built,
  /// then brings it to the middle and rings it (S Search).
  Future<void> _reveal() async {
    while (mounted && _atKey.currentContext == null && _scroll.hasClients) {
      final position = _scroll.position;
      if (position.pixels >= position.maxScrollExtent) break;
      _scroll.jumpTo(
        (position.pixels + position.viewportDimension).clamp(
          0,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
    final row = _atKey.currentContext;
    if (!mounted || row == null || !row.mounted) return;
    await Scrollable.ensureVisible(row, alignment: 0.5);
    if (mounted) setState(() => _flashAt = widget.atMessage);
  }

  Future<void> _turnIntoWorkItem(ChatMessage m) async {
    final thread = ref
        .read(spaceThreadsProvider(widget.spaceId))
        .value
        ?.where((t) => t.id == widget.threadId)
        .firstOrNull;
    final teamId = thread?.teamId;
    await ref
        .read(daybookDraftProvider(widget.spaceId).notifier)
        .quoteMessage(
          ref.read(newPostIdProvider)(),
          DaybookQuote(
            text: m.body!.trim(),
            authorName: m.authorName,
            at: m.createdAt,
          ),
          sourceMessageId: m.id,
          team: teamId == null
              ? null
              : (id: teamId, name: thread?.teamName ?? ''),
        );
    if (!mounted) return;
    unawaited(
      context.push(AppRoutes.space(widget.spaceId), extra: SpaceOpen.write),
    );
  }

  /// R3: the message's lines into work items; once posted, a line says so
  /// with Open, which opens the meeting's card in the daybook.
  Future<void> _meetingNotes(ChatMessage m) async {
    final l10n = AppLocalizations.of(context);
    final posted = await context.push<MeetingPosted>(
      AppRoutes.spaceMeeting(widget.spaceId, widget.threadId),
      extra: m,
    );
    if (posted == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('meeting-posted'),
          content: Text(l10n.meetingPosted(posted.count)),
          action: SnackBarAction(
            label: l10n.libraryOpen,
            onPressed: () => context.push(
              AppRoutes.spaceCard(widget.spaceId, posted.parentId),
            ),
          ),
        ),
      );
  }

  Future<void> _actions(ChatMessage m, {required bool canDelete}) async {
    final l10n = AppLocalizations.of(context);
    final me = ref.read(authUserIdProvider).value;
    // S8c: someone else's message (not a work item card) can be reported.
    final canReport =
        m.authorId != null && m.authorId != me && m.kind != ChatKind.workItem;
    // S8m: a message with words, for someone who may post work here.
    final canTurn =
        m.kind != ChatKind.workItem &&
        m.deletedAt == null &&
        (m.body ?? '').trim().isNotEmpty &&
        (ref
                .read(spaceDetailProvider(widget.spaceId))
                .value
                ?.myRights
                .createItems ??
            false);
    // Slice 9 (R3): a text message of two lines or more, line by line.
    final canMeet =
        canTurn && m.kind == ChatKind.text && hasMeetingLines(m.body);
    FocusManager.instance.primaryFocus?.unfocus();
    final choice = await showBvSheet<_Action>(
      context: context,
      builder: (context) => Column(
        key: const Key('chat-actions'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatActionRow(
            key: const Key('chat-action-reply'),
            icon: BvIcons.reply,
            label: l10n.chatReply,
            onTap: () => Navigator.of(context).pop(_Action.reply),
          ),
          // S8m: the words become a work item in this Space's daybook.
          if (canTurn)
            ChatActionRow(
              key: const Key('chat-action-work-item'),
              icon: BvIcons.workItems,
              label: l10n.chatTurnIntoWorkItem,
              onTap: () => Navigator.of(context).pop(_Action.workItem),
            ),
          if (canMeet)
            ChatActionRow(
              key: const Key('chat-action-meeting'),
              icon: BvIcons.workItems,
              label: l10n.meetingTurn,
              onTap: () => Navigator.of(context).pop(_Action.meeting),
            ),
          // Slice 8: its words as a note in My notebook, private.
          if ((m.body ?? '').trim().isNotEmpty)
            ChatActionRow(
              key: const Key('chat-action-notebook'),
              icon: BvIcons.notebook,
              label: l10n.notebookSaveMessage,
              onTap: () => Navigator.of(context).pop(_Action.notebook),
            ),
          ChatActionRow(
            key: const Key('chat-action-copy'),
            icon: BvIcons.copy,
            label: l10n.chatCopy,
            onTap: () => Navigator.of(context).pop(_Action.copy),
          ),
          if (canReport)
            ChatActionRow(
              key: const Key('chat-action-report'),
              icon: BvIcons.report,
              label: l10n.chatReport,
              onTap: () => Navigator.of(context).pop(_Action.report),
            ),
          if (canDelete)
            ChatActionRow(
              key: const Key('chat-action-delete'),
              icon: BvIcons.delete,
              label: l10n.chatDelete,
              destructive: true,
              onTap: () => Navigator.of(context).pop(_Action.delete),
            ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _Action.workItem:
        await _turnIntoWorkItem(m);
      case _Action.meeting:
        await _meetingNotes(m);
      case _Action.reply:
        setState(
          () => _replyTo = ChatReply(
            id: m.id,
            kind: m.kind,
            authorName: m.authorName,
            body: m.body,
          ),
        );
      case _Action.report:
        // Hidden for you at once; the thread reads again without it.
        await startReport(
          context,
          kind: ReportKind.message,
          id: m.id,
          onReported: () =>
              ref.invalidate(threadMessagesProvider(widget.threadId)),
        );
      case _Action.copy:
        await Clipboard.setData(ClipboardData(text: m.body ?? ''));
        if (mounted) _toast(l10n.chatCopied);
      case _Action.notebook:
        await ref
            .read(notebookProvider.notifier)
            .keep(
              ref.read(newPostIdProvider)(),
              m.body!,
              ref.read(clockProvider)(),
            );
        if (mounted) _toast(l10n.notebookSaved);
      case _Action.delete:
        final yes = await showBvDialog(
          context: context,
          title: l10n.chatDeleteTitle,
          body: l10n.chatDeleteBody,
          cancelLabel: l10n.commonCancel,
          confirmLabel: l10n.chatDeleteConfirm,
          destructive: true,
        );
        if (!yes || !mounted) return;
        try {
          await _repo.delete(m.id);
          await ref
              .read(threadMessagesProvider(widget.threadId).notifier)
              .refresh(m.id);
        } on SpaceException catch (e) {
          if (mounted) showSpaceError(context, e);
        }
    }
  }

  /// Search's message, at most this many pages back.
  static const _seekPages = 20;
  var _seeking = false;

  Future<void> _seekOlder() async {
    final at = widget.atMessage;
    final notifier = ref.read(threadMessagesProvider(widget.threadId).notifier);
    for (var n = 0; n < _seekPages && mounted && notifier.hasOlder; n++) {
      final before = ref
          .read(threadMessagesProvider(widget.threadId))
          .value
          ?.length;
      await notifier.loadOlder();
      if (!mounted) return;
      final now = ref.read(threadMessagesProvider(widget.threadId)).value;
      if (now?.any((m) => m.id == at) ?? false) return;
      // Nothing more came (no signal): stop here.
      if (now?.length == before) break;
    }
    if (mounted) setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final space = ref.watch(spaceDetailProvider(widget.spaceId)).value;
    final thread = ref
        .watch(spaceThreadsProvider(widget.spaceId))
        .value
        ?.where((t) => t.id == widget.threadId)
        .firstOrNull;
    final messages = ref.watch(threadMessagesProvider(widget.threadId));
    final pending = ref
        .watch(chatOutboxProvider)
        .where((p) => p.threadId == widget.threadId)
        .toList();
    final me = ref.watch(authUserIdProvider).value;

    // A new message while the thread is open is read at once.
    final newest = messages.value?.firstOrNull?.id;
    if (newest != null && newest != _newest) {
      _newest = newest;
      unawaited(_markRead());
    }

    final name = thread == null ? '' : threadName(l10n, thread);
    final shown = messages.value ?? const <ChatMessage>[];
    if (!_revealed &&
        widget.atMessage != null &&
        shown.any((m) => m.id == widget.atMessage)) {
      _revealed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
    // Older than the newest page (Search): read back to it, a page at a
    // time, then reveal it as above. Not found, the thread opens as is.
    else if (!_revealed &&
        !_seeking &&
        widget.atMessage != null &&
        messages.hasValue) {
      _seeking = true;
      unawaited(_seekOlder());
    }
    final sentIds = {for (final m in shown) m.id};
    // Newest first, to match the reversed list.
    final entries = <_Entry>[
      for (final p in pending.reversed)
        if (!sentIds.contains(p.id)) _Entry.pending(p),
      for (final m in shown) _Entry.message(m),
    ];

    // One full card per item: its newest step. Older steps are a line.
    final latestCards = <String>{};
    final seenItems = <String>{};
    for (final e in entries) {
      final item = e.message?.workItemId;
      if (e.isCard && item != null && seenItems.add(item)) {
        latestCards.add(e.message!.id);
      }
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.titleMd,
            ),
            if (space != null && thread != null)
              Text(
                joinMeta([
                  space.name,
                  thread.isEveryone ? l10n.chatEveryone : l10n.chatTeam,
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (thread != null && !thread.isEveryone)
            Container(
              key: const Key('chat-team-privacy'),
              width: double.infinity,
              color: BvColors.surfaceSubtle,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.gutter,
                vertical: BvSpace.s8,
              ),
              child: Text(
                l10n.chatTeamPrivacy(inOwnDirection(name)),
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
            ),
          Expanded(
            child: messages.hasValue || pending.isNotEmpty
                ? entries.isEmpty
                      ? Center(child: EmptyNote(l10n.chatNoMessages))
                      : ListView.builder(
                          key: const Key('chat-messages'),
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: BvSpace.gutter,
                            vertical: BvSpace.s12,
                          ),
                          itemCount: entries.length,
                          itemBuilder: (context, i) {
                            final view = _EntryView(
                              spaceId: widget.spaceId,
                              entry: entries[i],
                              older: i + 1 < entries.length
                                  ? entries[i + 1]
                                  : null,
                              newer: i > 0 ? entries[i - 1] : null,
                              latestCards: latestCards,
                              me: me,
                              iAmAdmin: space?.iAmAdmin ?? false,
                              onActions: _actions,
                              onRetry: _retry,
                            );
                            final at = widget.atMessage;
                            if (at == null || entries[i].message?.id != at) {
                              return view;
                            }
                            return BvHighlight(
                              key: _atKey,
                              flash: _flashAt,
                              child: view,
                            );
                          },
                        )
                : messages.hasError
                ? Center(child: EmptyNote(l10n.errorGeneric))
                : const Center(child: CircularProgressIndicator()),
          ),
          if (_replyTo != null)
            ChatReplyBanner(
              reply: _replyTo!,
              onCancel: () => setState(() => _replyTo = null),
            ),
          ChatComposer(
            controller: _text,
            files: _files,
            shared: [
              if (_sharing case final f?)
                _SharedFileChip(
                  file: f,
                  onRemove: () => setState(() => _sharing = null),
                ),
            ],
            onChanged: () => setState(() {}),
            onSend: _send,
            // Photos and files need the "add files" right; a Viewer
            // chats in text only.
            onAttach:
                (space?.myRights.addFiles ?? false) && _files.length < _maxFiles
                ? _attach
                : null,
            onRemove: (f) => setState(() => _files.remove(f)),
            recording: _recording,
            cancelling: _cancelling,
            elapsed: _elapsed,
            // Voice notes need the "add files" right too.
            canRecord: space?.myRights.addFiles ?? false,
            onRecordStart: _startRecording,
            onRecordSlide: _slide,
            onRecordEnd: _endRecording,
            onRecordTap: () => _toast(AppLocalizations.of(context).chatRecord),
          ),
        ],
      ),
    );
  }
}

enum _Action { reply, workItem, meeting, copy, delete, report, notebook }

enum _Attach { camera, gallery, pdf }

/// A message from the server, or one still on this phone.
class _Entry {
  _Entry.message(ChatMessage this.message) : pending = null;
  _Entry.pending(PendingMessage this.pending) : message = null;

  final ChatMessage? message;
  final PendingMessage? pending;

  DateTime get at => message?.createdAt ?? pending!.createdAt;
  String? authorId(String? me) => message == null ? me : message!.authorId;
  bool get isCard => message?.kind == ChatKind.workItem;
}

class _EntryView extends ConsumerWidget {
  const _EntryView({
    required this.spaceId,
    required this.entry,
    required this.older,
    required this.newer,
    required this.latestCards,
    required this.me,
    required this.iAmAdmin,
    required this.onActions,
    required this.onRetry,
  });

  final String spaceId;
  final _Entry entry;

  /// The messages above and below this one, if any.
  final _Entry? older;
  final _Entry? newer;

  /// Cards that show the whole item (its newest step in the thread).
  final Set<String> latestCards;
  final String? me;
  final bool iAmAdmin;
  final Future<void> Function(ChatMessage m, {required bool canDelete})
  onActions;
  final Future<void> Function(String id) onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final now = ref.watch(clockProvider)();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = BvTime.of(context).clock;

    final day = DateUtils.dateOnly(entry.at.toLocal());
    final newDay =
        older == null || DateUtils.dateOnly(older!.at.toLocal()) != day;
    final author = entry.authorId(me);
    // A new run: another person, a card, or a new day above.
    final startsRun =
        newDay ||
        older!.isCard ||
        entry.isCard ||
        older!.authorId(me) != author;
    // The run ends here when the next message is someone else's, a card,
    // or on another day: the avatar goes beside its last bubble.
    final endsRun =
        newer == null ||
        newer!.isCard ||
        newer!.authorId(me) != author ||
        DateUtils.dateOnly(newer!.at.toLocal()) != day;

    final Widget body;
    final m = entry.message;
    if (m != null && m.kind == ChatKind.workItem) {
      body = _CardEntry(
        spaceId: spaceId,
        message: m,
        time: time(m.createdAt),
        full: latestCards.contains(m.id),
      );
    } else {
      final mine = author != null && author == me;
      final pending = entry.pending;
      final Widget? media;
      if (m != null &&
          !m.deleted &&
          m.kind == ChatKind.voice &&
          m.attachments.isNotEmpty) {
        final a = m.attachments.first;
        media = VoiceNote(
          id: m.id,
          path: a.path,
          duration: Duration(milliseconds: a.durationMs ?? 0),
        );
      } else if (pending != null &&
          pending.files.length == 1 &&
          pending.files.single.file.isVoice) {
        final f = pending.files.single.file;
        media = VoiceNote(
          id: pending.id,
          local: f.local,
          duration: Duration(milliseconds: f.durationMs ?? 0),
        );
      } else if (m != null &&
          !m.deleted &&
          m.kind == ChatKind.file &&
          m.file == null) {
        // The Library file it showed was removed since (review 14).
        media = const _RemovedFile();
      } else if (m != null &&
          !m.deleted &&
          m.kind == ChatKind.report &&
          m.reportWeek != null) {
        // Slice 9: a shared week report opens with the reader's rights.
        media = WeekReportBubble(spaceId: spaceId, week: m.reportWeek!);
      } else if (m != null &&
          !m.deleted &&
          m.kind == ChatKind.post &&
          m.postId != null) {
        // Review 105B: a post of the Space's Work, its card.
        media = SharedPostBubble(spaceId: spaceId, postId: m.postId!);
      } else if (m != null && !m.deleted) {
        media = m.photos.isEmpty && m.file == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BvSpace.s4,
                children: [
                  if (m.photos.isNotEmpty)
                    _Photos(paths: [for (final a in m.photos) a.path]),
                  if (m.file != null)
                    _FileChip(
                      file: m.file!,
                      onTap: () => context.push(
                        AppRoutes.libraryFile(spaceId, m.file!.id),
                      ),
                    ),
                ],
              );
      } else if (pending != null && pending.files.isNotEmpty) {
        media = _Photos(
          local: [
            for (final f in pending.files)
              if (!f.file.isPdf) f.file.local,
          ],
          names: [
            for (final f in pending.files)
              if (f.file.isPdf) f.file.name,
          ],
        );
      } else {
        media = null;
      }
      body = ChatBubble(
        media: media,
        mine: mine,
        name: startsRun && !mine ? personName(l10n, m?.authorName) : null,
        avatarName: endsRun && !mine ? personName(l10n, m?.authorName) : null,
        text: m == null
            ? entry.pending!.body
            : m.deleted
            ? l10n.chatDeleted
            : m.body ?? '',
        deleted: m?.deleted ?? false,
        reply: m?.reply ?? entry.pending?.reply,
        footer: m != null
            ? Text(
                time(m.createdAt),
                style: type.metadata.copyWith(color: BvColors.textSecondary),
              )
            : _PendingFooter(pending: entry.pending!, onRetry: onRetry),
        onLongPress: m == null || m.deleted
            ? null
            : () => onActions(m, canDelete: mine || iAmAdmin),
        id: m?.id ?? entry.pending!.id,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (newDay)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: BvSpace.s12,
            ),
            child: Text(
              chatDayLabel(l10n, locale, day, DateUtils.dateOnly(now)),
              textAlign: TextAlign.center,
              style: type.labelSm.copyWith(color: BvColors.textSecondary),
            ),
          )
        else
          SizedBox(height: startsRun ? BvChatSpec.groupGap : BvChatSpec.runGap),
        body,
      ],
    );
  }
}

/// A day in a thread: "Today", "Yesterday", or "Wed 14 Oct".
String chatDayLabel(
  AppLocalizations l10n,
  String locale,
  DateTime day,
  DateTime today,
) {
  if (day == today) return l10n.chatToday;
  if (today.difference(day).inDays == 1) return l10n.chatYesterday;
  return BvWesternDigitsFormatter.normalise(
    DateFormat('EEE d MMM', locale).format(day),
  );
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.id,
    required this.mine,
    required this.name,
    required this.avatarName,
    required this.text,
    required this.deleted,
    required this.reply,
    required this.footer,
    required this.onLongPress,
    this.media,
    this.avatars = true,
  });

  final String id;
  final bool mine;

  /// A group thread keeps room for faces; a one-to-one (DM2) doesn't.
  final bool avatars;

  /// Photos or a file, above the text.
  final Widget? media;

  /// Above the first message of a run from someone else.
  final String? name;

  /// Beside the last message of that run.
  final String? avatarName;
  final String text;
  final bool deleted;
  final ChatReply? reply;
  final Widget footer;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final width = MediaQuery.sizeOf(context).width * BvChatSpec.bubbleMaxWidth;
    final bubble = GestureDetector(
      key: Key('chat-message-$id'),
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvChatSpec.bubblePaddingHorizontal,
          vertical: BvChatSpec.bubblePaddingVertical,
        ),
        decoration: BoxDecoration(
          color: mine ? BvColors.surfaceBrandSoft : BvColors.surfaceElevated,
          borderRadius: BvChatSpec.bubbleRadius,
          border: mine
              ? null
              : Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
        ),
        // As wide as its longest line, so short messages stay small; the
        // time then sits at the end of that width.
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: BvSpace.s4,
            children: [
              if (reply != null) _Quote(reply: reply!),
              ?media,
              if (text.isNotEmpty || media == null)
                Text(
                  text,
                  // In the language it was written in, not the app's.
                  textDirection: deleted ? null : directionOf(text),
                  style: deleted
                      ? type.bodyMd.copyWith(
                          color: BvColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        )
                      : type.bodyMd,
                ),
              Align(alignment: AlignmentDirectional.centerEnd, child: footer),
            ],
          ),
        ),
      ),
    );

    if (mine) {
      return Align(alignment: AlignmentDirectional.centerEnd, child: bubble);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BvSpace.s4,
      children: [
        if (name != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: BvChatSpec.avatar + BvChatSpec.avatarGap,
            ),
            child: Text(
              name!,
              style: type.labelSm.copyWith(color: BvColors.textSecondary),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: avatars ? BvChatSpec.avatarGap : 0,
          children: [
            if (avatarName != null)
              BvAvatar(name: avatarName!, size: BvAvatarSize.sm)
            else if (avatars)
              const SizedBox(width: BvChatSpec.avatar),
            Flexible(child: bubble),
          ],
        ),
      ],
    );
  }
}

/// The message a reply answers, quoted at the top of the bubble.
class _Quote extends StatelessWidget {
  const _Quote({required this.reply});

  final ChatReply reply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Container(
      key: const Key('chat-quote'),
      padding: const EdgeInsetsDirectional.only(start: BvSpace.s8),
      decoration: const BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: BvColors.textAction,
            width: BvChatSpec.replyBar,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            personName(l10n, reply.authorName),
            style: type.labelSm.copyWith(color: BvColors.textAction),
          ),
          Text(
            reply.deleted
                ? l10n.chatDeleted
                : inOwnDirection(chatSnippet(l10n, reply.kind, reply.body)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// "Sending…", or "Not sent · Retry".
class _PendingFooter extends StatelessWidget {
  const _PendingFooter({required this.pending, required this.onRetry});

  final PendingMessage pending;
  final Future<void> Function(String id) onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    if (!pending.failed) {
      return Text(
        l10n.chatSending,
        style: type.metadata.copyWith(color: BvColors.textSecondary),
      );
    }
    // Wraps rather than overflows in a narrow bubble.
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${l10n.chatNotSent} · ',
          style: type.metadata.copyWith(color: BvColors.textDestructive),
        ),
        GestureDetector(
          key: Key('chat-retry-${pending.id}'),
          onTap: () => onRetry(pending.id),
          child: Text(
            l10n.chatRetry,
            style: type.labelSm.copyWith(color: BvColors.textAction),
          ),
        ),
      ],
    );
  }
}

/// A work item step, posted by the server (before migration 18): who did
/// what, then the item's title quoted. Both open the Space's daybook,
/// where the work item lives (slice 1).
class _CardEntry extends ConsumerWidget {
  const _CardEntry({
    required this.spaceId,
    required this.message,
    required this.time,
    required this.full,
  });

  final String spaceId;
  final ChatMessage message;
  final String time;

  /// False for an older step of an item shown further down: one line.
  final bool full;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final items = ref.watch(workItemsProvider(spaceId)).value;
    final item = items?.where((i) => i.id == message.workItemId).firstOrNull;
    // Always the name: "You" doesn't fit the Arabic noun forms.
    final who = personName(l10n, message.authorName);
    final line = switch (message.eventKind) {
      WorkEventKind.done => l10n.chatCardDone(who),
      WorkEventKind.checked => l10n.chatCardChecked(who),
      WorkEventKind.sentBack => l10n.chatCardSentBack(who),
      WorkEventKind.reassigned => l10n.chatCardReassigned(who),
      _ => l10n.chatCardRaised(who),
    };

    // An old card for an item this person can't see (a Team item whose card
    // went to Everyone before migration 18, or a deleted post): a plain line,
    // with no title, no name and no link (review 34 L1).
    if (item == null && items != null) {
      return Text(
        joinMeta([l10n.chatCardHidden, time]),
        key: Key('chat-card-${message.id}'),
        style: type.bodySm.copyWith(color: BvColors.textSecondary),
      );
    }
    void open() => context.push(AppRoutes.space(spaceId));
    if (!full) {
      return InkWell(
        key: Key('chat-card-${message.id}'),
        onTap: item == null ? null : open,
        child: Text(
          // The reference first: two Latin parts side by side would merge
          // and swap places in a right-to-left line.
          joinMeta([?item?.ref, line, time]),
          style: type.bodySm.copyWith(color: BvColors.textSecondary),
        ),
      );
    }
    return Column(
      key: Key('chat-card-${message.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        Text(
          joinMeta([line, time]),
          style: type.bodySm.copyWith(color: BvColors.textSecondary),
        ),
        if (item != null)
          InkWell(
            key: Key('work-item-${item.id}'),
            onTap: open,
            child: BvSlipQuote(item.title),
          ),
      ],
    );
  }
}

class ChatReplyBanner extends StatelessWidget {
  const ChatReplyBanner({
    super.key,
    required this.reply,
    required this.onCancel,
  });

  final ChatReply reply;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Container(
      key: const Key('chat-replying'),
      color: BvColors.surfaceElevated,
      padding: const EdgeInsetsDirectional.only(
        start: BvSpace.gutter,
        top: BvSpace.s8,
      ),
      child: Row(
        spacing: BvSpace.s8,
        children: [
          const Icon(
            BvIcons.reply,
            size: BvSize.iconMd,
            color: BvColors.iconAction,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.chatReplyingTo(
                    inOwnDirection(personName(l10n, reply.authorName)),
                  ),
                  style: type.labelSm.copyWith(color: BvColors.textAction),
                ),
                Text(
                  inOwnDirection(chatSnippet(l10n, reply.kind, reply.body)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySm.copyWith(color: BvColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('chat-cancel-reply'),
            tooltip: l10n.chatCancelReply,
            icon: const Icon(BvIcons.close, color: BvColors.iconSecondary),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// The message box: one pill that grows, with Send inside when there is
/// text. Photos and voice notes come in parts 2 and 3.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.files,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
    required this.onRemove,
    required this.recording,
    required this.cancelling,
    required this.elapsed,
    required this.canRecord,
    required this.onRecordStart,
    required this.onRecordSlide,
    required this.onRecordEnd,
    required this.onRecordTap,
    this.shared = const [],
  });

  /// F77: a Library file waiting in the message box, not sent yet.
  final List<Widget> shared;

  final TextEditingController controller;
  final List<PhoneFile> files;
  final VoidCallback onChanged;
  final VoidCallback onSend;
  final bool recording;
  final bool cancelling;
  final Duration elapsed;
  final bool canRecord;
  final VoidCallback onRecordStart;
  final ValueChanged<Offset> onRecordSlide;
  final VoidCallback onRecordEnd;
  final VoidCallback onRecordTap;

  /// Null hides the paperclip (no "add files" right).
  final VoidCallback? onAttach;
  final ValueChanged<PhoneFile> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final hasText =
        controller.text.trim().isNotEmpty ||
        files.isNotEmpty ||
        shared.isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: BvColors.borderDefault, width: BvStroke.thin),
        ),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvSpace.gutter,
        vertical: BvSpace.s8,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BvSpace.s8,
          children: [
            if (files.isNotEmpty || shared.isNotEmpty)
              SingleChildScrollView(
                key: const Key('chat-picked'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: BvSpace.s8,
                  children: [
                    ...shared,
                    for (final f in files)
                      _PickedChip(file: f, onRemove: () => onRemove(f)),
                  ],
                ),
              ),
            Row(
              spacing: BvSpace.s4,
              children: [
                if (onAttach != null && !recording)
                  IconButton(
                    key: const Key('chat-attach'),
                    tooltip: l10n.chatAttach,
                    icon: const Icon(
                      BvIcons.attach,
                      color: BvColors.iconSecondary,
                    ),
                    onPressed: onAttach,
                  ),
                Expanded(
                  child: recording
                      ? RecordingBar(elapsed: elapsed, cancelling: cancelling)
                      : Container(
                          key: const Key('chat-composer'),
                          constraints: const BoxConstraints(
                            minHeight: BvSize.controlMd,
                          ),
                          padding: const EdgeInsetsDirectional.only(
                            start: BvSpace.s16,
                            end: BvSpace.s4,
                          ),
                          decoration: const BoxDecoration(
                            color: BvColors.surfaceSubtle,
                            borderRadius: BvRadius.roundAll,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('chat-input'),
                                  controller: controller,
                                  minLines: 1,
                                  maxLines: 5,
                                  maxLength: 4000,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: type.bodyMd,
                                  // The pill is the field: no theme border or padding.
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    counterText: '',
                                    contentPadding:
                                        const EdgeInsetsDirectional.symmetric(
                                          vertical: BvSpace.s8,
                                        ),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    hintText: l10n.chatMessageHint,
                                    hintStyle: type.bodyMd.copyWith(
                                      color: BvColors.textSecondary,
                                    ),
                                  ),
                                  onChanged: (_) => onChanged(),
                                ),
                              ),
                              if (hasText)
                                IconButton(
                                  key: const Key('chat-send'),
                                  tooltip: l10n.chatSend,
                                  icon: const Icon(
                                    BvIcons.send,
                                    color: BvColors.iconAction,
                                  ),
                                  onPressed: onSend,
                                )
                              else
                                const SizedBox(height: BvSize.controlMd),
                            ],
                          ),
                        ),
                ),
                // The mic when there's nothing to send (S8k); it stays put
                // while the thumb holds it.
                if (canRecord && (recording || !hasText))
                  RecordButton(
                    onStart: onRecordStart,
                    onSlide: onRecordSlide,
                    onEnd: onRecordEnd,
                    onTap: onRecordTap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChatActionRow extends StatelessWidget {
  const ChatActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.help,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final color = destructive ? BvColors.textDestructive : BvColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: BvSpace.s12),
        child: Row(
          spacing: BvSpace.s16,
          children: [
            Container(
              width: BvSize.avatarMd,
              height: BvSize.avatarMd,
              decoration: const BoxDecoration(
                color: BvColors.surfaceBrandSoft,
                borderRadius: BvRadius.controlAll,
              ),
              child: Icon(
                icon,
                size: BvSize.iconMd,
                color: destructive
                    ? BvColors.textDestructive
                    : BvColors.iconPrimary,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: type.bodyLg.copyWith(color: color)),
                  if (help != null)
                    Text(
                      help!,
                      style: type.bodySm.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photos in a bubble: one large, or a grid of up to four with "+N".
/// [paths] are in the Space (signed links); [local] are still on the phone,
/// with [names] for PDFs waiting to be sent.
class _Photos extends ConsumerWidget {
  const _Photos({
    this.paths = const [],
    this.local = const [],
    this.names = const [],
  });

  final List<String> paths;
  final List<String> local;
  final List<String> names;

  static const _shown = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = BvType.of(context);
    final count = paths.length + local.length;
    final single = count == 1;
    final size = single ? BvChatSpec.photoLarge : BvChatSpec.photoSmall;

    Widget tile(int i) {
      final ImageProvider? image;
      if (i < paths.length) {
        final url = ref.watch(fileUrlProvider(paths[i])).value;
        image = url == null ? null : NetworkImage(url);
      } else {
        image = FileImage(File(local[i - paths.length]));
      }
      final extra = count - _shown;
      return ClipRRect(
        key: Key('chat-photo-$i'),
        borderRadius: BvRadius.controlAll,
        child: SizedBox(
          width: size,
          height: single ? size * BvChatSpec.photoLargeAspect : size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: BvColors.surfaceSubtle),
              if (image != null)
                Image(
                  image: image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
              if (i == _shown - 1 && extra > 0)
                ColoredBox(
                  color: BvColors.overlayScrim,
                  child: Center(
                    child: Text(
                      '+$extra',
                      style: type.titleMd.copyWith(color: BvColors.textInverse),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BvSpace.s4,
      children: [
        if (count > 0)
          Wrap(
            spacing: BvSpace.s4,
            runSpacing: BvSpace.s4,
            children: [for (var i = 0; i < count && i < _shown; i++) tile(i)],
          ),
        for (final n in names)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvSpace.s8,
            children: [
              const Icon(
                BvIcons.document,
                size: BvSize.iconMd,
                color: BvColors.iconSecondary,
              ),
              Flexible(
                child: Text(
                  inOwnDirection(n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySm,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// A PDF in a bubble: its name, revision and size. Opens F1.
class _FileChip extends StatelessWidget {
  const _FileChip({required this.file, required this.onTap});

  final LibraryFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return InkWell(
      key: Key('chat-file-${file.id}'),
      onTap: onTap,
      borderRadius: BvRadius.controlAll,
      child: Container(
        padding: const EdgeInsetsDirectional.all(BvSpace.s8),
        decoration: const BoxDecoration(
          color: BvColors.surfaceSubtle,
          borderRadius: BvRadius.controlAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: BvSpace.s8,
          children: [
            const Icon(
              BvIcons.document,
              size: BvSize.iconLg,
              color: BvColors.iconPrimary,
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BvNameText(file.name, maxLines: 2, style: type.labelMd),
                  Text(
                    joinMeta([?file.revLabel, fileSize(l10n, file.bytes)]),
                    style: type.metadata.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A file picked for the next message, with Remove.
class _PickedChip extends StatelessWidget {
  const _PickedChip({required this.file, required this.onRemove});

  final PhoneFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Container(
      key: Key('chat-picked-${file.name}'),
      padding: const EdgeInsetsDirectional.only(start: BvSpace.s8),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvRadius.controlAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (file.isPdf)
            const Icon(
              BvIcons.document,
              size: BvSize.iconMd,
              color: BvColors.iconPrimary,
            )
          else
            ClipRRect(
              borderRadius: BvRadius.smallAll,
              child: Image.file(
                File(file.local),
                width: BvSize.iconLg,
                height: BvSize.iconLg,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const SizedBox(width: BvSize.iconLg),
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: BvChatSpec.pickedName),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: BvSpace.s8),
              // A camera photo's file name means nothing to people.
              child: file.isPdf
                  ? BvNameText(file.name, style: type.bodySm)
                  : Text(
                      l10n.chatPhoto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodySm,
                    ),
            ),
          ),
          IconButton(
            tooltip: l10n.chatRemoveFile,
            icon: const Icon(
              BvIcons.close,
              size: BvSize.iconSm,
              color: BvColors.iconSecondary,
            ),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// A file message whose Library file was removed.
class _RemovedFile extends StatelessWidget {
  const _RemovedFile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Container(
      key: const Key('chat-file-removed'),
      padding: const EdgeInsetsDirectional.all(BvSpace.s8),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvRadius.controlAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BvSpace.s8,
        children: [
          const Icon(
            BvIcons.document,
            size: BvSize.iconLg,
            color: BvColors.iconSecondary,
          ),
          Flexible(
            child: Text(
              l10n.chatFileRemoved,
              style: type.bodySm.copyWith(
                color: BvColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// F77: a Library file waiting in the message box: its name, and ✕.
class _SharedFileChip extends StatelessWidget {
  const _SharedFileChip({required this.file, required this.onRemove});

  final LibraryFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Container(
      key: Key('chat-sharing-${file.id}'),
      padding: const EdgeInsetsDirectional.only(start: BvSpace.s8),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvRadius.controlAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            BvIcons.document,
            size: BvSize.iconMd,
            color: BvColors.iconPrimary,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: BvChatSpec.pickedName),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: BvSpace.s8),
              child: BvNameText(file.name, style: type.bodySm),
            ),
          ),
          IconButton(
            tooltip: l10n.chatRemoveFile,
            icon: const Icon(
              BvIcons.close,
              size: BvSize.iconSm,
              color: BvColors.iconSecondary,
            ),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
