import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/around_specs.dart' show BvSpaceEmblemSpec;
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/messages_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/bv_time.dart';
import '../../data/models/chat.dart';
import '../../data/models/dm.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/repositories/dm_repository.dart';
import '../../data/repositories/safety_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../chat/chat_state.dart' show keepFileProvider;
import '../chat/thread_screen.dart';
import 'dm_live.dart';
import '../chat/voice.dart';
import '../create/create_sheet.dart' show workItemSpacesProvider;
import '../library/library_parts.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../safety/report_flow.dart';
import '../spaces/former_member.dart';
import '../spaces/space_errors.dart';
import '../work/work_outbox.dart' show pickPhotoProvider;
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart' show DaybookQuote;
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_quote_block.dart';
import '../../shared/widgets/bv_space_emblem.dart';
import '../entry/entry_state.dart' show myProfileProvider;
import '../spaces/space_screen.dart' show SpaceOpen;
import '../work/daybook_draft.dart' show daybookDraftProvider;
import '../work/daybook_words.dart';
import '../work/daybook_writing.dart' show newPostIdProvider;
import '../../shared/widgets/bv_name_text.dart';
import '../notebook/notebook_state.dart';

/// A message on its way, shown at once as mine ("Sending…", or "Not sent ·
/// Retry").
class _Pending {
  _Pending({
    required this.id,
    required this.body,
    this.replyTo,
    this.files = const [],
  });

  final String id;
  final String body;
  final DmMessage? replyTo;

  /// Photos and PDFs, or one voice note, still on the phone.
  final List<PhoneFile> files;
  var failed = false;

  PhoneFile? get voice =>
      files.length == 1 && files.single.isVoice ? files.single : null;
}

/// A conversation between two people (DM2 2561:35447, AR 2563:170): the
/// person and what they do, "Both in …" when they share one, the
/// messages, and the composer. Holding a message (DM3): Reply, Copy, and
/// Report or Delete. A request from someone new (DM6) has "Not in your
/// Spaces · Decline · Block" and its photos behind "Tap to show"; replying
/// opens it. A new conversation ([DmThreadScreen.withPerson]) has no
/// thread until its first message is sent.
class DmThreadScreen extends ConsumerStatefulWidget {
  const DmThreadScreen({super.key, required String this.threadId})
    : profileId = null,
      person = null;

  const DmThreadScreen.withPerson({
    super.key,
    required String this.profileId,
    this.person,
  }) : threadId = null;

  final String? threadId;
  final String? profileId;

  /// Who it is with, as the profile showed them, until the thread loads.
  final DmPerson? person;

  @override
  ConsumerState<DmThreadScreen> createState() => _DmThreadScreenState();
}

class _DmThreadScreenState extends ConsumerState<DmThreadScreen> {
  late final DmRepository _repo = ref.read(dmRepositoryProvider);
  final _text = TextEditingController();
  final _files = <PhoneFile>[];
  final _pending = <_Pending>[];
  final _shown = <String>{};
  String? _threadId;
  DmThreadPage? _page;
  DmMessage? _replyTo;
  StreamSubscription<String>? _live;
  var _loading = true;
  var _failed = false;

  // A voice note being recorded (as in Space chat, S8k): hold the mic,
  // slide away to cancel, release to send.
  var _recording = false;
  var _holding = false;
  var _cancelling = false;
  var _elapsed = Duration.zero;
  Stopwatch? _watch;
  Timer? _recordTimer;

  static const _maxFiles = 10;
  static const _tick = Duration(milliseconds: 250);

  /// Which conversation is on screen (F81: no banner for it).
  late final OpenDmThread _onScreen;

  @override
  void initState() {
    super.initState();
    _onScreen = ref.read(openDmThreadProvider.notifier);
    _threadId = widget.threadId;
    _showing(_threadId);
    unawaited(_open());
  }

  void _showing(String? threadId) {
    if (threadId == null) return;
    // Not while the tree builds.
    unawaited(Future.microtask(() => _onScreen.set(threadId)));
  }

  @override
  void dispose() {
    final id = _threadId;
    unawaited(Future.microtask(() => _onScreen.clear(id)));
    _live?.cancel();
    _recordTimer?.cancel();
    _text.dispose();
    super.dispose();
  }

  /// A new conversation finds the pair's thread when there is one already.
  Future<void> _open() async {
    try {
      if (_threadId == null) {
        final inbox = await _repo.inbox();
        final requests = await _repo.requests();
        _threadId = [
          ...inbox.threads,
          ...requests,
        ].where((r) => r.person.id == widget.profileId).firstOrNull?.threadId;
      }
      await _reload();
    } on SpaceException {
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reload() async {
    final id = _threadId;
    if (id == null) return;
    final page = await _repo.page(id);
    if (!mounted) return;
    setState(() {
      _page = page;
      _pending.removeWhere(
        (p) => page?.messages.any((m) => m.id == p.id) ?? false,
      );
    });
    _listen(id);
    unawaited(_repo.markRead(id));
    ref.invalidate(dmInboxProvider);
  }

  void _listen(String threadId) {
    if (_live != null) return;
    _showing(threadId);
    _live = _repo.changes(threadId).listen((_) => unawaited(_reload()));
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  DmPerson? get _person => _page?.person ?? widget.person;

  String _name(AppLocalizations l10n) {
    final p = _person;
    return personName(l10n, p == null || p.former ? null : p.name);
  }

  /// Sends what the composer holds.
  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty && _files.isEmpty) return;
    final pending = _Pending(
      id: newUuid(),
      body: body,
      replyTo: _replyTo,
      files: List.of(_files),
    );
    setState(() {
      _text.clear();
      _files.clear();
      _replyTo = null;
    });
    await _deliver(pending);
  }

  /// Shows [pending] at once as mine, then sends it: its files first, then
  /// the message (the same id again on a retry: never sent twice).
  Future<void> _deliver(_Pending pending) async {
    final l10n = AppLocalizations.of(context);
    final body = pending.body;
    final files = pending.files;
    setState(() {
      pending.failed = false;
      if (!_pending.contains(pending)) _pending.add(pending);
    });
    try {
      final uploads = [
        for (final f in files)
          DmUpload(
            path: await _repo.upload(pending.id, f),
            name: f.name,
            bytes: f.bytes,
            durationMs: f.durationMs,
          ),
      ];
      final thread = _threadId;
      if (thread == null) {
        final started = await _repo.start(
          threadId: newUuid(),
          to: widget.profileId!,
          messageId: pending.id,
          body: body.isEmpty ? null : body,
          attachments: uploads,
        );
        if (!mounted) return;
        if (started.paused) {
          setState(() => _pending.remove(pending));
          _toast(
            l10n.dmPaused(
              BvTime.of(
                context,
              ).moment(started.until!, ref.read(clockProvider)()),
            ),
          );
          return;
        }
        if (started.warning) _toast(l10n.dmWarning);
        _threadId = started.threadId;
      } else {
        await _repo.send(
          id: pending.id,
          threadId: thread,
          body: body.isEmpty ? null : body,
          replyTo: pending.replyTo?.id,
          attachments: uploads,
        );
      }
      await _reload();
    } on SpaceException catch (e) {
      if (!mounted) return;
      setState(() => pending.failed = true);
      showSpaceError(context, e);
    }
  }

  Future<void> _retry(_Pending p) => _deliver(p);

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
    final pending = _Pending(
      id: newUuid(),
      body: '',
      replyTo: _replyTo,
      // A voice note goes on its own.
      files: [
        PhoneFile(
          local: path,
          name: path.split(Platform.pathSeparator).last,
          mime: 'audio/mp4',
          bytes: file.existsSync() ? file.lengthSync() : null,
          durationMs: length.inMilliseconds,
        ),
      ],
    );
    setState(() => _replyTo = null);
    await _deliver(pending);
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  /// Camera, or a photo or a PDF from the phone (DM2's 📎).
  Future<void> _attach() async {
    final l10n = AppLocalizations.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    final choice = await showBvSheet<int>(
      context: context,
      builder: (sheet) => Column(
        key: const Key('dm-attach-sheet'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatActionRow(
            icon: BvIcons.camera,
            label: l10n.chatAttachCamera,
            onTap: () => Navigator.of(sheet).pop(0),
          ),
          ChatActionRow(
            icon: BvIcons.image,
            label: l10n.chatAttachGallery,
            onTap: () => Navigator.of(sheet).pop(1),
          ),
          ChatActionRow(
            icon: BvIcons.document,
            label: l10n.chatAttachPdf,
            onTap: () => Navigator.of(sheet).pop(2),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    PhoneFile? picked;
    var refused = false;
    if (choice == 2) {
      (file: picked, :refused) = await ref.read(pickDocumentProvider)(
        pdfOnly: true,
      );
    } else {
      final photos = await ref.read(pickPhotoProvider)(camera: choice == 0);
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

  /// DM3: Reply, Copy, and Delete for my own or Report for theirs.
  Future<void> _actions(DmMessage m) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showBvSheet<String>(
      context: context,
      builder: (sheet) => Column(
        key: const Key('dm-actions'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatActionRow(
            key: const Key('dm-action-reply'),
            icon: BvIcons.reply,
            label: l10n.chatReply,
            onTap: () => Navigator.of(sheet).pop('reply'),
          ),
          // DM4: the words become a work item in a Space you post in.
          if ((m.body ?? '').trim().isNotEmpty && !m.deleted)
            ChatActionRow(
              key: const Key('dm-action-space'),
              icon: BvIcons.workItems,
              label: l10n.dmPutInSpace,
              onTap: () => Navigator.of(sheet).pop('space'),
            ),
          // Slice 8: its words as a note in My notebook, private.
          if ((m.body ?? '').trim().isNotEmpty && !m.deleted)
            ChatActionRow(
              key: const Key('dm-action-notebook'),
              icon: BvIcons.notebook,
              label: l10n.notebookSaveMessage,
              onTap: () => Navigator.of(sheet).pop('notebook'),
            ),
          if ((m.body ?? '').isNotEmpty)
            ChatActionRow(
              key: const Key('dm-action-copy'),
              icon: BvIcons.copy,
              label: l10n.chatCopy,
              onTap: () => Navigator.of(sheet).pop('copy'),
            ),
          if (m.fromMe)
            ChatActionRow(
              key: const Key('dm-action-delete'),
              icon: BvIcons.delete,
              label: l10n.chatDelete,
              destructive: true,
              onTap: () => Navigator.of(sheet).pop('delete'),
            )
          else
            ChatActionRow(
              key: const Key('dm-action-report'),
              icon: BvIcons.report,
              label: l10n.chatReport,
              destructive: true,
              onTap: () => Navigator.of(sheet).pop('report'),
            ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'space':
        await _putInSpace(m);
      case 'notebook':
        await ref
            .read(notebookProvider.notifier)
            .keep(
              ref.read(newPostIdProvider)(),
              m.body!,
              ref.read(clockProvider)(),
            );
        if (mounted) _toast(l10n.notebookSaved);
      case 'reply':
        setState(() => _replyTo = m);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.body ?? ''));
        if (mounted) _toast(l10n.chatCopied);
      case 'delete':
        try {
          await _repo.delete(m.id);
          await _reload();
        } on SpaceException catch (e) {
          if (mounted) showSpaceError(context, e);
        }
      case 'report':
        await startReport(
          context,
          kind: ReportKind.dmMessage,
          id: m.id,
          onReported: () => unawaited(_reload()),
        );
    }
  }

  /// DM4–DM5 (review 64): pick a Space you can post in; its daybook opens
  /// with a work item being written, the message quoted in it. The message
  /// itself never leaves the thread, and nothing is posted until Post.
  Future<void> _putInSpace(DmMessage m) async {
    final l10n = AppLocalizations.of(context);
    // Where the server lets me post work: a Space admin may have turned
    // posting off for a Lead or Crew member (pass_rights).
    // Kept alive while it reads (it is autoDispose).
    final keep = ref.listenManual(workItemSpacesProvider, (_, _) {});
    final postable = await ref
        .read(workItemSpacesProvider.future)
        .catchError((Object _) => const <SpaceSummary>[])
        .whenComplete(keep.close);
    if (!mounted) return;
    final me = ref.read(myProfileProvider).value;
    final author = m.fromMe
        ? (me == null ? null : '${me.firstName} ${me.lastName}'.trim())
        : (_person?.former ?? true ? null : _person!.name);
    final quote = DaybookQuote(
      text: m.body!.trim(),
      authorName: author,
      at: m.createdAt,
    );
    final now = ref.read(clockProvider)();
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final picked = await showBvSheet<SpaceSummary>(
      context: context,
      title: l10n.dmPutInSpace,
      builder: (sheet) => Column(
        key: const Key('dm-put-in-space'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s12,
        children: [
          BvQuoteBlock(
            from: words.quoteFrom(quote, now),
            text: quote.text,
            maxLines: 2,
          ),
          if (postable.isEmpty)
            Text(
              l10n.dmPutInSpaceNone,
              style: BvType.of(
                context,
              ).bodyMd.copyWith(color: BvColors.textSecondary),
            )
          else
            ClipRRect(
              borderRadius: BvRadius.cardAll,
              child: BvListGroup(
                rows: [
                  for (final space in postable)
                    BvListRow(
                      key: Key('dm-space-${space.id}'),
                      title: space.name,
                      leading: const BvSpaceEmblem(
                        height: BvSpaceEmblemSpec.tile,
                      ),
                      onTap: () => Navigator.of(sheet).pop(space),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    await ref
        .read(daybookDraftProvider(picked.id).notifier)
        .quoteMessage(ref.read(newPostIdProvider)(), quote);
    if (!mounted) return;
    unawaited(context.push(AppRoutes.space(picked.id), extra: SpaceOpen.write));
  }

  /// The thread's ⋯ (review 41): Mute or Unmute, Report the person, Block.
  Future<void> _menu() async {
    final l10n = AppLocalizations.of(context);
    final page = _page;
    final person = _person;
    if (page == null || person == null || person.former) return;
    final name = _name(l10n);
    final choice = await showBvSheet<String>(
      context: context,
      builder: (sheet) => Column(
        key: const Key('dm-menu'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatActionRow(
            key: const Key('dm-menu-mute'),
            icon: BvIcons.notificationsOff,
            label: page.muted ? l10n.dmUnmute : l10n.dmMute,
            onTap: () => Navigator.of(sheet).pop('mute'),
          ),
          ChatActionRow(
            key: const Key('dm-menu-report'),
            icon: BvIcons.report,
            label: l10n.dmReportPerson(inOwnDirection(name)),
            destructive: true,
            onTap: () => Navigator.of(sheet).pop('report'),
          ),
          ChatActionRow(
            key: const Key('dm-menu-block'),
            icon: BvIcons.block,
            label: l10n.blockPerson(inOwnDirection(name)),
            destructive: true,
            onTap: () => Navigator.of(sheet).pop('block'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'mute':
        try {
          await _repo.mute(page.threadId, on: !page.muted);
          await _reload();
        } on SpaceException catch (e) {
          if (mounted) showSpaceError(context, e);
        }
      case 'report':
        await startReport(
          context,
          kind: ReportKind.profile,
          id: person.id,
          person: (id: person.id, name: name),
          onBlocked: () => context.pop(),
        );
      case 'block':
        await _block();
    }
  }

  Future<void> _block() async {
    final person = _person;
    if (person == null) return;
    await confirmBlock(
      context,
      personId: person.id,
      name: _name(AppLocalizations.of(context)),
      onChanged: (blocked) {
        ref.invalidate(dmInboxProvider);
        if (blocked && mounted) context.pop();
      },
    );
  }

  /// DM6 Decline: it leaves my lists quietly; the sender isn't told.
  Future<void> _decline() async {
    final l10n = AppLocalizations.of(context);
    final id = _threadId;
    if (id == null) return;
    try {
      await _repo.decline(id);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    ref
      ..invalidate(dmInboxProvider)
      ..invalidate(dmRequestsProvider);
    if (!mounted) return;
    _toast(l10n.dmDeclined(inOwnDirection(_name(l10n))));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // A push, the app back in front, or the list's live change (F81).
    ref.listen(dmChangeProvider, (_, change) {
      if (change != null && change.touches(_threadId) && _threadId != null) {
        unawaited(_reload());
      }
    });
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final person = _person;
    final name = _name(l10n);
    final page = _page;
    final about = [
      ?person?.headline,
      if (person?.company != null) inOwnDirection(person!.company!),
    ].join(' · ');
    final request = page?.state == DmState.request;
    final messages = page?.messages ?? const <DmMessage>[];
    final now = ref.watch(clockProvider)();
    final locale = Localizations.localeOf(context).toLanguageTag();
    DateTime dayOf(DateTime t) {
      final l = t.toLocal();
      return DateTime(l.year, l.month, l.day);
    }

    // Newest first, as the server sends them (the list is reversed); mine
    // on the way at the end, and a day's chip above its first message.
    // F98: the start of the conversation shows who it is with, above the
    // first message (the list is reversed: last is top).
    final atStart =
        page != null &&
        person != null &&
        messages.length < BvMessagesSpec.pageSize;
    final entries = <Widget>[
      for (final p in _pending.reversed) _pendingBubble(l10n, type, p),
      for (var i = 0; i < messages.length; i++) ...[
        _bubble(l10n, type, messages[i]),
        if (i == messages.length - 1 ||
            dayOf(messages[i + 1].createdAt) != dayOf(messages[i].createdAt))
          _DayChip(
            chatDayLabel(
              l10n,
              locale,
              dayOf(messages[i].createdAt),
              DateTime(now.year, now.month, now.day),
            ),
          ),
      ],
      if (atStart) _PersonCard(person: person, name: name, about: about),
    ];
    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(
        backgroundColor: BvColors.surfaceApp,
        titleSpacing: 0,
        title: Row(
          spacing: BvSpace.s8,
          children: [
            BvAvatar(
              name: name,
              size: BvAvatarSize.sm,
              tint: person == null ? null : BvAvatarTints.forId(person.id),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inOwnDirection(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.titleMd,
                  ),
                  if (about.isNotEmpty)
                    Text(
                      about,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (page != null && !(person?.former ?? true))
            IconButton(
              key: const Key('dm-more'),
              tooltip: l10n.profileMore,
              icon: const Icon(BvIcons.more, color: BvColors.iconPrimary),
              onPressed: _menu,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // DM2: a pill under the header, never a count.
          if (page?.sharedSpaceName != null)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: BvMessagesSpec.stripPaddingVertical,
              ),
              child: Center(
                child: _Pill(
                  key: const Key('dm-both-in'),
                  icon: BvIcons.team,
                  text: l10n.dmBothIn(inOwnDirection(page!.sharedSpaceName!)),
                ),
              ),
            ),
          if (request)
            _Strip(
              key: const Key('dm-request-strip'),
              child: Row(
                spacing: BvSpace.s8,
                children: [
                  const Icon(
                    BvIcons.info,
                    size: BvSize.iconMd,
                    color: BvColors.iconSecondary,
                  ),
                  Expanded(
                    child: Text(
                      l10n.dmNotInSpaces,
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('dm-decline'),
                    onPressed: _decline,
                    style: TextButton.styleFrom(
                      foregroundColor: BvColors.textSecondary,
                    ),
                    child: Text(l10n.dmDecline),
                  ),
                  TextButton(
                    key: const Key('dm-block'),
                    onPressed: _block,
                    style: TextButton.styleFrom(
                      foregroundColor: BvColors.textDestructive,
                    ),
                    child: Text(l10n.block),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed
                ? Center(child: EmptyNote(l10n.errorGeneric))
                : ListView(
                    key: const Key('dm-messages'),
                    reverse: true,
                    padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                    children: [
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: BvSpace.s8,
                          ),
                          child: e,
                        ),
                    ],
                  ),
          ),
          if (_replyTo != null)
            ChatReplyBanner(
              reply: _asReply(l10n, _replyTo!),
              onCancel: () => setState(() => _replyTo = null),
            ),
          if (!(person?.former ?? false))
            ChatComposer(
              controller: _text,
              files: _files,
              onChanged: () => setState(() {}),
              onSend: () => unawaited(_send()),
              onAttach: _files.length < _maxFiles ? _attach : null,
              onRemove: (f) => setState(() => _files.remove(f)),
              recording: _recording,
              cancelling: _cancelling,
              elapsed: _elapsed,
              canRecord: true,
              onRecordStart: _startRecording,
              onRecordSlide: _slide,
              onRecordEnd: _endRecording,
              onRecordTap: () => _toast(l10n.chatRecord),
            ),
        ],
      ),
    );
  }

  /// A message as the chat's reply line shows it: "You" or their name.
  ChatReply _asReply(AppLocalizations l10n, DmMessage m) => ChatReply(
    id: m.id,
    kind: m.kind,
    authorName: m.fromMe ? l10n.chatYou : _name(l10n),
    body: m.body,
    deleted: m.deleted,
  );

  Widget _bubble(AppLocalizations l10n, BvTypeSet type, DmMessage m) {
    final reply = m.replyTo;
    final hidden = m.tapToShow && !_shown.contains(m.id);
    return ChatBubble(
      id: m.id,
      avatars: false,
      mine: m.fromMe,
      name: null,
      avatarName: null,
      text: m.deleted ? l10n.chatDeleted : m.body ?? '',
      deleted: m.deleted,
      reply: reply == null
          ? null
          : ChatReply(
              id: reply.id,
              kind: ChatKind.text,
              authorName: reply.fromMe ? l10n.chatYou : _name(l10n),
              body: reply.text,
              deleted: reply.deleted,
            ),
      media: m.files.isEmpty || m.deleted
          ? null
          : hidden
          ? _TapToShow(onTap: () => setState(() => _shown.add(m.id)))
          : m.files.length == 1 && m.files.single.isVoice
          ? VoiceNote(
              id: m.id,
              path: m.files.single.path,
              duration: Duration(milliseconds: m.files.single.durationMs ?? 0),
              linkOf: (ref, path) => ref.read(dmFileUrlProvider(path).future),
            )
          : _DmFiles(files: m.files),
      footer: Text(
        BvTime.of(context).clock(m.createdAt),
        style: type.metadata.copyWith(color: BvColors.textSecondary),
      ),
      onLongPress: m.deleted ? null : () => unawaited(_actions(m)),
    );
  }

  Widget _pendingBubble(AppLocalizations l10n, BvTypeSet type, _Pending p) =>
      ChatBubble(
        id: p.id,
        avatars: false,
        mine: true,
        name: null,
        avatarName: null,
        text: p.body,
        deleted: false,
        media: p.voice == null
            ? null
            : VoiceNote(
                id: p.id,
                local: p.voice!.local,
                duration: Duration(milliseconds: p.voice!.durationMs ?? 0),
              ),
        reply: p.replyTo == null ? null : _asReply(l10n, p.replyTo!),
        footer: p.failed
            ? GestureDetector(
                key: Key('dm-retry-${p.id}'),
                onTap: () => unawaited(_retry(p)),
                child: Text(
                  '${l10n.chatNotSent} · ${l10n.chatRetry}',
                  style: type.metadata.copyWith(
                    color: BvColors.textDestructive,
                  ),
                ),
              )
            : Text(
                l10n.chatSending,
                style: type.metadata.copyWith(color: BvColors.textSecondary),
              ),
        onLongPress: null,
      );
}

/// F98: at the start of a conversation, who it is with: face, name, what
/// they do · company, and View profile (none for a deleted account). The
/// Space you share stays in DM2's pill under the header.
class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.name,
    required this.about,
  });

  final DmPerson person;
  final String name;
  final String about;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Padding(
      key: const Key('dm-person-card'),
      padding: const EdgeInsetsDirectional.only(
        bottom: BvMessagesSpec.personMarginBottom,
      ),
      child: Column(
        spacing: BvSpace.s8,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: BvColors.surfaceElevated,
              borderRadius: BvMessagesSpec.requestRadius,
              border: Border.all(color: BvColors.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(
                BvMessagesSpec.personPadding,
              ),
              child: Column(
                spacing: BvMessagesSpec.personGap,
                children: [
                  BvAvatar(
                    name: name,
                    size: BvAvatarSize.lg,
                    tint: BvAvatarTints.forId(person.id),
                  ),
                  const SizedBox(height: BvSpace.s4),
                  Text(
                    inOwnDirection(name),
                    textAlign: TextAlign.center,
                    style: type.titleMd,
                  ),
                  if (about.isNotEmpty)
                    Text(
                      about,
                      textAlign: TextAlign.center,
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  if (!person.former)
                    TextButton(
                      key: const Key('dm-view-profile'),
                      onPressed: () =>
                          context.push('${AppRoutes.people}/${person.id}'),
                      child: Text(l10n.dmViewProfile),
                    ),
                ],
              ),
            ),
          ),
          Text(
            l10n.dmStartLine,
            style: type.metadata.copyWith(color: BvColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A thin line under the header: "Both in …", or a request's strip.
class _Strip extends StatelessWidget {
  const _Strip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: BvSpace.gutter,
      vertical: BvMessagesSpec.stripPaddingVertical,
    ),
    decoration: const BoxDecoration(
      color: BvColors.surfaceSubtle,
      border: Border(
        bottom: BorderSide(color: BvColors.borderSubtle, width: BvStroke.thin),
      ),
    ),
    child: child,
  );
}

/// DM6: a photo or file from someone you haven't answered, until tapped.
class _TapToShow extends StatelessWidget {
  const _TapToShow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Nothing is loaded until the tap: a covered area, as DM6 draws the
    // blurred photo, with the pill in its middle.
    return GestureDetector(
      key: const Key('dm-tap-to-show'),
      onTap: onTap,
      child: Container(
        height: BvMessagesSpec.hiddenHeight,
        width: BvMessagesSpec.hiddenWidth,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: BvColors.overlayDim,
          borderRadius: BvRadius.controlAll,
        ),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvSpace.s12,
            vertical: BvSpace.s6,
          ),
          decoration: const BoxDecoration(
            color: BvColors.surfaceElevated,
            borderRadius: BvRadius.roundAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvSpace.s6,
            children: [
              const Icon(
                BvIcons.image,
                size: BvSize.iconSm,
                color: BvColors.iconPrimary,
              ),
              Text(l10n.dmTapToShow, style: BvType.of(context).labelSm),
            ],
          ),
        ),
      ),
    );
  }
}

/// A message's photos and PDFs, through short-lived links.
class _DmFiles extends ConsumerWidget {
  const _DmFiles({required this.files});

  final List<DmFile> files;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s4,
      children: [
        for (final f in files)
          if (f.isPhoto)
            ClipRRect(
              borderRadius: BvRadius.controlAll,
              child: switch (ref.watch(dmFileUrlProvider(f.path))) {
                AsyncData(:final value) => Image.network(
                  value,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox(height: BvSize.controlLg),
                ),
                _ => const SizedBox(height: BvSize.controlLg),
              },
            )
          else
            // DM2: a white card, the icon on its tile, the name and size.
            Container(
              key: Key('dm-file-${f.path}'),
              padding: const EdgeInsetsDirectional.all(BvSpace.s12),
              decoration: const BoxDecoration(
                color: BvColors.surfaceElevated,
                borderRadius: BvRadius.controlAll,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: BvSpace.s12,
                children: [
                  Container(
                    width: BvSize.controlMd,
                    height: BvSize.controlMd,
                    decoration: const BoxDecoration(
                      color: BvColors.surfaceSubtle,
                      borderRadius: BvRadius.smallAll,
                    ),
                    child: Icon(
                      f.isVoice ? BvIcons.microphone : BvIcons.document,
                      size: BvSize.iconMd,
                      color: BvColors.iconPrimary,
                    ),
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (f.isVoice)
                          Text(
                            l10n.messagesVoice(voiceLengthOf(f.durationMs)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.labelSm,
                          )
                        else
                          BvNameText(
                            f.name ?? l10n.chatFile,
                            style: type.labelSm,
                          ),
                        if (f.bytes != null)
                          Text(
                            fileSize(l10n, f.bytes),
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
      ],
    );
  }
}

/// "0:24": a voice note's length.
String voiceLengthOf(int? ms) {
  final s = ((ms ?? 0) / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// A short-lived link to a message's file.
final dmFileUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(dmRepositoryProvider).fileUrl(path),
);

/// A small grey pill: "Both in …" (DM2).
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: BvSpace.s12,
      vertical: BvSpace.s4,
    ),
    decoration: const BoxDecoration(
      color: BvColors.surfaceSubtle,
      borderRadius: BvRadius.roundAll,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s6,
      children: [
        Icon(icon, size: BvSize.iconSm, color: BvColors.iconSecondary),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BvType.of(
              context,
            ).metadata.copyWith(color: BvColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

/// A day above its first message (DM2): "Tue", "Yesterday", "Today".
class _DayChip extends StatelessWidget {
  const _DayChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(vertical: BvSpace.s8),
    child: Center(
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.s12,
          vertical: BvSpace.s2,
        ),
        decoration: const BoxDecoration(
          color: BvColors.surfaceSubtle,
          borderRadius: BvRadius.roundAll,
        ),
        child: Text(
          label,
          style: BvType.of(
            context,
          ).metadata.copyWith(color: BvColors.textSecondary),
        ),
      ),
    ),
  );
}
