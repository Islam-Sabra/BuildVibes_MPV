import 'package:flutter/material.dart';
import '../../shared/widgets/bv_tap_target.dart';
import '../../core/design/daybook_page_specs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart' show BvStroke;
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../core/design/daybook_paper_specs.dart';
import '../../core/l10n/bidi.dart' show ltrRun;
import '../../data/models/daybook.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_quote_block.dart';
import '../../shared/widgets/bv_card_history.dart';
import '../../shared/widgets/bv_checklist_point.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_faces.dart';
import '../../shared/widgets/bv_hold_button.dart';
import '../../shared/widgets/bv_marked_text.dart';
import '../../shared/widgets/bv_photo_strip.dart';
import '../../shared/widgets/bv_popover_menu.dart' show bvGlobalRect;
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_torn_edge.dart';
import '../../shared/widgets/bv_text_field.dart' show BvWesternDigitsFormatter;
import '../library/library_parts.dart' show bvMegabyte;
import '../spaces/former_member.dart';
import 'daybook_kinds.dart';
import 'daybook_marks.dart' show postFilesProvider;
import 'daybook_page.dart' show forLineWithTasks;
import 'daybook_photos.dart';
import 'daybook_report.dart' show DaybookReportBody;
import 'daybook_target_card.dart' show DaybookTargetRows;
import 'daybook_words.dart';

/// What a card lets the reader do (the loop). Null callbacks are not
/// offered: a Viewer gets none.
@immutable
class DaybookCardActions {
  const DaybookCardActions({
    this.onOpen,
    this.onHold,
    this.onCheck,
    this.onSignDone,
    this.onGiveTo,
    this.onTick,
    this.onAck,
    this.onOpenFile,
    this.onOpenPage,
    this.onOpenChild,
    this.onOpenQuote,
    this.onOpenNewer,
    this.onShareReport,
  });

  /// The same, with [onOpenQuote] (F87) and [onOpenNewer] (F76).
  DaybookCardActions withLinks({
    VoidCallback? openQuote,
    VoidCallback? openNewer,
  }) => DaybookCardActions(
    onOpen: onOpen,
    onHold: onHold,
    onCheck: onCheck,
    onSignDone: onSignDone,
    onGiveTo: onGiveTo,
    onTick: onTick,
    onAck: onAck,
    onOpenFile: onOpenFile,
    onOpenPage: onOpenPage,
    onOpenChild: onOpenChild,
    onOpenQuote: openQuote ?? onOpenQuote,
    onOpenNewer: openNewer ?? onOpenNewer,
    onShareReport: onShareReport,
  );

  /// A tap opens it (review 105 Part 2): its page, with what the old
  /// long-press menu held (the lead's ruling Q3).
  final VoidCallback? onOpen;

  /// A hold selects it (SP6): Share · Duplicate · Delete at the bottom.
  final VoidCallback? onHold;

  /// Hold to check (review 94), while it needs the reader's check.
  final VoidCallback? onCheck;

  /// The owner's "Sign as done" (O1).
  final VoidCallback? onSignDone;

  /// "Give to someone else", when the owner can no longer sign it.
  final ValueChanged<Rect>? onGiveTo;

  /// Tick a checklist's point, or untick it (Lead and Crew).
  final DaybookTick? onTick;

  /// Got it, Received, Add to my calendar or On my way (Viewers too).
  final DaybookAckTap? onAck;

  /// A file post's preview: the file, full screen.
  final VoidCallback? onOpenFile;

  /// "Open the page ›" (slice 5): the post's page over the daybook
  /// (everyone who sees the post, Viewers too).
  final VoidCallback? onOpenPage;

  /// A target's row (slice 6): that work item's own card.
  final ValueChanged<String>? onOpenChild;

  /// F87: the quote opens the Space chat message it was made from.
  final VoidCallback? onOpenQuote;

  /// F76: an older version's "Replaced by V2 ›" opens the newer one's post.
  final VoidCallback? onOpenNewer;

  /// A daily report's Share as PDF (slice 7).
  final VoidCallback? onShareReport;
}

/// The card's quiet grey line, "Open the page ›", when its page holds
/// more than the card shows. No count of blocks. The same line says
/// "Replaced by V2 · today ›" on an older version's post (F76).
class DaybookOpenPage extends StatelessWidget {
  const DaybookOpenPage({
    super.key,
    required this.onTap,
    this.label,
    this.tapKey = const Key('card-open-page'),
  });

  final VoidCallback? onTap;

  /// Null: "Open the page".
  final String? label;
  final Key tapKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = BvType.of(
      context,
    ).bodySm.copyWith(color: BvColors.textSecondary);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: BvTapTarget(
        child: Semantics(
          button: true,
          child: GestureDetector(
            key: tapKey,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: BvSpace.s2,
              children: [
                Flexible(
                  child: Text(
                    label ?? l10n.pageOpen,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                const Icon(
                  BvIcons.caretForward,
                  size: BvPageSpec.openCaret,
                  color: BvColors.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One card on the daybook (v13, review 53 Part B): a post and what
/// happened to it. From the top: the header (author, ref or kind, the time
/// of the latest activity), what the post is, the history (the last three
/// lines, then [expanded] all), and the reader's one action. [lifted]
/// draws it over the dim under the menu, with no gestures.
///
/// A work item has its title, facts, the latest proof photo with its
/// stamp, and Sign as done or the double-tap hint. The other kinds (slice
/// 2, K1–K3 v13): a checklist ticked in place ("2 of 5 ticked"); an
/// announcement with Got it; a scheduled activity on its calendar leaf
/// with Add to my calendar, then On my way on the day; a file with its
/// preview, NEW VERSION when it replaces one, who received it, and
/// Received.
///
/// A [viewer] gets no paper clip and no action. A card still [waiting] to
/// be sent says so, and shows its photo from the phone ([localPhoto]).
class DaybookCardView extends StatelessWidget {
  const DaybookCardView({
    super.key,
    required this.card,
    required this.words,
    required this.me,
    required this.now,
    required this.activityAt,
    this.viewer = false,
    this.waiting = false,
    this.changeWaiting = false,
    this.sending,
    this.couldNotSend = false,
    this.localPhoto,
    this.waitingPhotos = const [],
    this.actions = const DaybookCardActions(),
    this.landing = false,
    this.lifted = false,
    this.selected = false,
    this.expanded = false,
    this.onEarlier,
    this.lineKey,
    this.onTap,
    this.nameOf,
    this.taskTables,
    this.taskCount,
  });

  /// The card as the phone shows it: what waits to be sent is already on
  /// it.
  final DaybookCard card;
  final DaybookWords words;
  final String? me;
  final DateTime now;

  /// Its latest activity, as the header says it.
  final DateTime activityAt;
  final bool viewer;
  final bool waiting;

  /// A change to it (a tick, Got it, a send-back, give to, an update)
  /// waits for a signal (slice 10): the card says "Waiting to send" and
  /// stays as it is otherwise.
  final bool changeWaiting;

  /// F73: on its way now, with a file's bytes while it uploads; null while
  /// it waits for a signal.
  final ({int? sent, int? total})? sending;

  /// The server refused it: a post while another card was being written,
  /// or a sign-off (its photos stay on the phone). A tap fixes it.
  final bool couldNotSend;
  final String? localPhoto;

  /// A new post's photos still on the phone, each marked while it waits to
  /// be uploaded (F51).
  final List<({String local, bool waiting})> waitingPhotos;
  final DaybookCardActions actions;

  /// The CHECKED stamp lands now (a check made here).
  final bool landing;
  final bool lifted;

  /// Held and selected (SP6).
  final bool selected;

  /// The whole history shows, not only the last three lines.
  final bool expanded;

  /// "Show earlier".
  final VoidCallback? onEarlier;

  /// Each history line's key, so a trace can scroll to it.
  final Key Function(String id)? lineKey;

  /// A tap on the card, instead of opening it (while writing, while
  /// selecting, or a refused one to fix).
  final VoidCallback? onTap;

  /// Who ticked a point, by id.
  final DaybookNameOf? nameOf;

  /// A work item's tables of tasks (review 105 SP3), under its facts, and
  /// their rows ticked of all ("1 of 3 ticked" on the For line).
  final Widget? taskTables;
  final ({int ticked, int total})? taskCount;

  /// History lines drawn collapsed.
  static const shownLines = 3;

  DaybookPost get _post => card.post;

  /// The paper clip: the card needs the reader.
  bool get clip => card.need != null && !viewer && !waiting;

  /// The same card with [actions], or [lifted] over the dim.
  DaybookCardView copyWith({
    DaybookCardActions? actions,
    bool? lifted,
    bool? selected,
    VoidCallback? Function()? onTap,
  }) => DaybookCardView(
    key: key,
    card: card,
    words: words,
    me: me,
    now: now,
    activityAt: activityAt,
    viewer: viewer,
    waiting: waiting,
    changeWaiting: changeWaiting,
    sending: sending,
    couldNotSend: couldNotSend,
    localPhoto: localPhoto,
    waitingPhotos: waitingPhotos,
    actions: actions ?? this.actions,
    landing: landing,
    lifted: lifted ?? this.lifted,
    selected: selected ?? this.selected,
    expanded: expanded,
    onEarlier: onEarlier,
    // A lifted copy draws over the card itself: its lines have no keys.
    lineKey: (lifted ?? this.lifted) ? null : lineKey,
    onTap: onTap == null ? this.onTap : onTap(),
    nameOf: nameOf,
    taskTables: taskTables,
    taskCount: taskCount,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final post = _post;
    if (!post.isWorkItem) return _kindCard(context, l10n);
    final proof = card.proof;
    final hasPhoto = localPhoto != null || (proof?.photos.isNotEmpty ?? false);
    final stamp = _stamp(l10n);
    final chips = [
      for (final f in post.attachments)
        BvSlipChip(
          icon: BvIcons.document,
          label: f.revLabel == null
              ? fileName(f.name)
              : l10n.daybookFileChip(fileName(f.name), f.revLabel!),
        ),
      if (post.pointsTotal > 0)
        BvSlipChip(
          icon: BvIcons.workItems,
          label: l10n.daybookPoints(post.pointsTotal),
        ),
    ];
    final ref = post.ref;
    final authorId = post.authorId;
    final noteOnly = proof != null && !hasPhoto;
    final action = lifted ? null : _action(context, l10n, hasPhoto);
    final history = _history(l10n);

    return BvSlip(
      tear: BvSlipBorder.forId(post.id).variant,
      // With no proof, only CANCELLED is stamped, at the corner.
      stamp: proof == null && post.cancelled ? stamp : null,
      clip: clip,
      cancelled: post.cancelled,
      lifted: lifted,
      selected: selected,
      onTap: lifted ? null : onTap ?? actions.onOpen,
      onLongPress: lifted ? null : actions.onHold,
      children: [
        BvSlipHeader(
          name: personName(l10n, post.authorName),
          label: authorId != null && authorId == me ? l10n.daybookYou : null,
          ref: ref == null ? null : l10n.daybookCardRef(ref),
          time: words.time.clock(activityAt),
          tint: authorId == null
              ? BvAvatarTints.plain
              : BvAvatarTints.forId(authorId),
        ),
        BvSlipTitle(post.title, cancelled: post.cancelled),
        // A walk is its rows: its owner is its author, its due theirs.
        if (!post.isTarget)
          BvSlipFacts(
            children: [
              BvSlipFact(
                icon: BvIcons.person,
                text: forLineWithTasks(
                  l10n,
                  words.meta(post, me: me, now: now),
                  taskCount,
                ),
                marks: _factMarks(context),
              ),
              if ((post.place ?? '').isNotEmpty)
                BvSlipFact(icon: BvIcons.place, text: post.place!),
            ],
          )
        else if ((post.place ?? '').isNotEmpty)
          BvSlipFacts(
            children: [BvSlipFact(icon: BvIcons.place, text: post.place!)],
          ),
        ?_quote(),
        if (chips.isNotEmpty) BvSlipChips(children: chips),
        ?taskTables,
        if (post.isTarget)
          DaybookTargetRows(
            post: post,
            // Still the phone's walk (sent or not, until the page
            // reads it back): its photos are the phone's own.
            waiting: waiting || waitingPhotos.isNotEmpty,
            viewer: viewer,
            onOpenChild: lifted ? null : actions.onOpenChild,
            onShowAll: lifted ? null : actions.onOpenPage,
          ),
        ?_openPage(),
        if (localPhoto != null)
          _LocalPhoto(path: localPhoto!, stamp: proof == null ? null : stamp)
        else if (proof != null && proof.photos.isNotEmpty)
          _Photo(path: proof.photos.first.path, stamp: stamp)
        // A target's photos are on its rows' strip, not here.
        else if (proof == null &&
            !post.isTarget &&
            (post.coverPath != null || waitingPhotos.isNotEmpty))
          DaybookCardPhotos(post: post, waiting: waitingPhotos),
        // A proof with only a note (F6): the note, and the stamp
        // pressed under it, with no empty frame.
        if (noteOnly && (proof.note ?? '').isNotEmpty) BvSlipNote(proof.note!),
        if (noteOnly && stamp != null)
          Padding(
            padding: BvSlipSpec.stampNoPhotoPadding,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: stamp,
            ),
          ),
        ?history,
        if (couldNotSend)
          BvSlipError(l10n.daybookCouldNotSend)
        else if (waiting || changeWaiting)
          _waitingLine(context, l10n),
        ?action,
      ],
    );
  }

  /// "Open the page ›" while its page holds blocks.
  Widget? _openPage() {
    final open = actions.onOpenPage;
    // A daily report shows its page on its card (R2).
    if (_post.isReport) return null;
    if (!_post.hasPage || open == null || lifted) return null;
    return DaybookOpenPage(onTap: open);
  }

  /// F73: "Sending · 3.1 of 8.7 MB" with a thin line while a file goes up,
  /// "Sending" while the rest goes; "Waiting to send" only with no signal.
  Widget _waitingLine(BuildContext context, AppLocalizations l10n) {
    final going = sending;
    if (going == null) return BvSlipQuiet(l10n.daybookWaitingToSend);
    final sent = going.sent;
    final total = going.total;
    if (sent == null || total == null || total <= 0) {
      return BvSlipQuiet(l10n.daybookSending);
    }
    String mb(int bytes) => BvWesternDigitsFormatter.normalise(
      (bytes / bvMegabyte).toStringAsFixed(1),
    );
    return Column(
      key: const Key('card-sending'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s4,
      children: [
        BvSlipQuiet(l10n.daybookSendingBytes(mb(sent), mb(total))),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(BvRadius.tiny)),
          child: LinearProgressIndicator(
            value: (sent / total).clamp(0, 1).toDouble(),
            minHeight: BvStroke.medium,
            color: BvColors.actionPrimary,
            backgroundColor: BvColors.surfaceSubtle,
          ),
        ),
      ],
    );
  }

  /// The message it was made from (review 64), quoted.
  Widget? _quote() {
    final quote = _post.quote;
    if (quote == null) return null;
    return BvQuoteBlock(
      key: const Key('card-quote'),
      from: words.quoteFrom(quote, now),
      text: quote.text,
      onTap: lifted ? null : actions.onOpenQuote,
    );
  }

  /// F34: who it is for in the emphasis weight and the primary colour; the
  /// due grey, the primary colour today, red when late.
  List<BvMark> _factMarks(BuildContext context) {
    final type = BvType.of(context);
    final m = words.metaMarks(_post, me: me, now: now);
    return [
      (part: m.who, style: type.emphasis.copyWith(color: BvColors.textPrimary)),
      if (m.due != null)
        (part: m.due!, style: type.bodyMd.copyWith(color: bvDueColor(m.tone))),
    ];
  }

  /// A checklist, an announcement, an activity or a file post (K1–K3
  /// v13): the same paper, header and history as a work item's card.
  Widget _kindCard(BuildContext context, AppLocalizations l10n) {
    final post = _post;
    final authorId = post.authorId;
    final history = _history(l10n);
    final cancelled = post.cancelled
        ? BvInkStamp(
            label: l10n.daybookStampCancelled,
            size: BvInkStampSize.sm,
            tone: BvInkStampTone.muted,
          )
        : null;
    return Builder(
      builder: (context) => BvSlip(
        key: Key('kind-card-${post.kind}'),
        tear: BvSlipBorder.forId(post.id).variant,
        stamp: cancelled,
        clip: clip,
        cancelled: post.cancelled,
        lifted: lifted,
        selected: selected,
        onTap: lifted ? null : onTap ?? actions.onOpen,
        onLongPress: lifted ? null : actions.onHold,
        children: [
          BvSlipHeader(
            name: personName(l10n, post.authorName),
            label: authorId != null && authorId == me ? l10n.daybookYou : null,
            // Review 95: every kind has its number, before its kind word.
            ref: switch (post.ref) {
              final ref? => l10n.daybookCardRefKind(
                ltrRun(ref),
                _kindWord(l10n),
              ),
              null => _kindWord(l10n),
            },
            time: words.time.clock(activityAt),
            tint: authorId == null
                ? BvAvatarTints.plain
                : BvAvatarTints.forId(authorId),
          ),
          ..._kindBody(context, l10n),
          ?_openPage(),
          ?history,
          if (couldNotSend)
            BvSlipError(l10n.daybookCouldNotSend)
          else if (waiting || changeWaiting)
            _waitingLine(context, l10n),
        ],
      ),
    );
  }

  /// "· note", "· checklist", "· scheduled", "· for receipt", "· to
  /// everyone".
  String _kindWord(AppLocalizations l10n) => switch (_post.kind) {
    DaybookPost.noteKind => l10n.daybookKindNoteWord,
    DaybookPost.checklistKind => l10n.daybookKindChecklistWord,
    DaybookPost.activityKind => l10n.daybookKindActivityWord,
    DaybookPost.fileKind => l10n.daybookKindFileWord,
    DaybookPost.reportKind => l10n.daybookKindReportWord,
    _ => l10n.daybookToEveryone,
  };

  List<Widget> _kindBody(BuildContext context, AppLocalizations l10n) {
    final post = _post;
    final act = lifted || waiting ? null : actions.onAck;
    final action = daybookAckAction(l10n, post, me: me, now: now, onAck: act);
    // Photos added with 📎 or the camera: the first one on the card.
    // F51: the post's photos (the first large, two small beside it), and
    // its Library files as chips (F39).
    final cover = post.coverPath == null && waitingPhotos.isEmpty
        ? null
        : DaybookCardPhotos(post: post, waiting: waitingPhotos);
    final files = waiting ? null : DaybookCardFiles(post: post);
    // The head of the card ([head], the photos), with the files under the
    // last of them: with none, the files take no room (no empty gap).
    List<Widget> top(Widget head) {
      Widget withFiles(Widget above) => files == null
          ? above
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [above, files],
            );
      return cover == null ? [withFiles(head)] : [head, withFiles(cover)];
    }

    Widget row(Widget? leading) => Row(
      spacing: BvAckPillSpec.rowGap,
      children: [
        ?leading,
        // The action takes the room left, at the end; a long label ends
        // with an ellipsis rather than running off the card.
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: action,
          ),
        ),
      ],
    );
    switch (post.kind) {
      // A daily report (R2, review 79 §5): the day, then its page.
      case DaybookPost.reportKind:
        return [
          BvSlipTitle(post.title, cancelled: post.cancelled),
          DaybookReportBody(
            post: post,
            words: words,
            onOpenRef: lifted || waiting ? null : actions.onOpenChild,
            onShare: lifted || waiting || post.cancelled
                ? null
                : actions.onShareReport,
          ),
        ];
      // A note (K5 v13 2598:36260): the title, its words, then the
      // photos, for information; no faces and no buttons (F58).
      case DaybookPost.noteKind:
        return [
          BvSlipTitle(post.title, cancelled: post.cancelled),
          if ((post.body ?? '').isNotEmpty) BvSlipNote(post.body!),
          ?_quote(),
          ?cover,
          ?files,
        ];
      case DaybookPost.checklistKind:
        return [
          ...top(BvSlipTitle(post.title, cancelled: post.cancelled)),
          if ((post.body ?? '').isNotEmpty) BvSlipNote(post.body!),
          ?_quote(),
          BvSlipFacts(
            children: [
              if (post.people.isNotEmpty)
                BvSlipFact(
                  icon: BvIcons.person,
                  text: words.peopleFor(post.people, me: me),
                ),
              if (post.dueDate != null)
                BvSlipFact(
                  icon: BvIcons.due,
                  text: words.checklistDue(post, now),
                ),
            ],
          ),
          if (post.pointsTotal > 0)
            BvChecklistProgress(
              ticked: post.pointsTicked,
              total: post.pointsTotal,
              label: l10n.daybookTicked(post.pointsTicked, post.pointsTotal),
            ),
          if (!waiting)
            DaybookChecklistPoints(
              post: post,
              words: words,
              me: me,
              nameOf: nameOf ?? (_) => null,
              onTick: lifted || viewer ? null : actions.onTick,
            ),
        ];
      case DaybookPost.activityKind:
        return [
          ...top(DaybookActivityWhat(post: post, words: words, now: now)),
          if ((post.body ?? '').isNotEmpty) BvSlipNote(post.body!),
          ?_quote(),
          if (post.people.isNotEmpty || action != null)
            row(
              post.people.isEmpty
                  ? null
                  : BvFaces(facesOf(l10n, post.people), large: true),
            ),
        ];
      case DaybookPost.fileKind:
        final file = post.file;
        final rev = file?.revLabel;
        return [
          if (file != null)
            DaybookFilePreview(
              file: file,
              newVersion: post.newVersion,
              onTap: lifted ? null : actions.onOpenFile,
            ),
          BvSlipTitle(
            rev == null || post.title.contains(rev)
                ? post.title
                : l10n.daybookFileTitle(post.title, rev),
            cancelled: post.cancelled,
          ),
          if (file != null)
            BvSlipFact(icon: BvIcons.document, text: words.fileFact(file)),
          // F76: an older version says which replaced it; a tap opens its
          // post.
          if (file != null && file.newerVersionNo != null)
            DaybookOpenPage(
              key: const Key('card-replaced-by'),
              tapKey: const Key('card-replaced-by-tap'),
              label: words.replacedBy(file, now),
              onTap: lifted || file.newerPostId == null
                  ? null
                  : actions.onOpenNewer,
            ),
          if ((post.body ?? '').isNotEmpty) BvSlipNote(post.body!),
          ?_quote(),
          if (!waiting)
            Consumer(
              builder: (context, ref, _) {
                final by = acknowledgedBy(ref, post.id, DaybookAck.received);
                if (by.isEmpty) return const SizedBox.shrink();
                return DaybookFacesLine(
                  key: const Key('received-by'),
                  // F48: who, with the time each tapped Received.
                  onTap: lifted
                      ? null
                      : () => showDaybookAcks(
                          context,
                          title: l10n.daybookReceived,
                          faces: acksOf(ref, post.id, DaybookAck.received),
                          now: now,
                        ),
                  faces: facesOf(l10n, by),
                  text: l10n.daybookReceivedBy(
                    words.someNames([
                      for (final p in by) personName(l10n, p.name),
                    ]),
                  ),
                );
              },
            ),
          if (action != null)
            Align(alignment: AlignmentDirectional.centerStart, child: action),
        ];
      default:
        // An announcement off its pin (K1's pinned one sits under the
        // masthead): the words, and the author's faces of who got it.
        return [
          ...top(BvSlipTitle(post.title, cancelled: post.cancelled)),
          if ((post.body ?? '').isNotEmpty) BvSlipNote(post.body!),
          ?_quote(),
          Consumer(
            builder: (context, ref, _) {
              final by = waiting
                  ? const <DaybookPerson>[]
                  : acknowledgedBy(ref, post.id, DaybookAck.gotIt);
              if (by.isEmpty && action == null) {
                return const SizedBox.shrink();
              }
              return row(
                by.isEmpty
                    ? null
                    : DaybookFacesLine(
                        key: const Key('got-it-by'),
                        faces: facesOf(l10n, by),
                        onTap: lifted
                            ? null
                            : () => showDaybookAcks(
                                context,
                                title: l10n.daybookGotIt,
                                faces: acksOf(ref, post.id, DaybookAck.gotIt),
                                now: now,
                              ),
                      ),
              );
            },
          ),
        ];
    }
  }

  /// The stamp of the latest proof (DONE, CHECKED, SENT BACK, CANCELLED);
  /// none on a refused proof, which isn't done.
  Widget? _stamp(AppLocalizations l10n) {
    final proof = card.proof;
    if (proof == null) {
      return _post.cancelled
          ? BvInkStamp(
              label: l10n.daybookStampCancelled,
              size: BvInkStampSize.sm,
              tone: BvInkStampTone.muted,
            )
          : null;
    }
    final outcome = proof.outcome;
    return switch (outcome.kind) {
      DaybookOutcomeKind.done when couldNotSend => null,
      DaybookOutcomeKind.done => BvInkStamp(
        label: l10n.daybookStampDone,
        size: BvInkStampSize.lg,
        subline: words.stampLine(proof.byName, proof.at),
      ),
      DaybookOutcomeKind.checked => BvInkStamp(
        label: l10n.daybookStampChecked,
        size: BvInkStampSize.lg,
        tone: BvInkStampTone.positive,
        subline: words.stampLine(outcome.byName, outcome.at ?? proof.at),
        land: landing,
      ),
      DaybookOutcomeKind.sentBack => BvInkStamp(
        label: l10n.daybookStampSentBack,
        size: BvInkStampSize.lg,
        tone: BvInkStampTone.destructive,
        subline: words.stampLine(outcome.byName, outcome.at ?? proof.at),
      ),
      DaybookOutcomeKind.cancelled => BvInkStamp(
        label: l10n.daybookStampCancelled,
        size: BvInkStampSize.lg,
        tone: BvInkStampTone.muted,
      ),
    };
  }

  /// The history: the last three lines (or all), oldest at the top, with
  /// Show earlier above them while older ones are left.
  ///
  /// What the card already shows isn't said again as a line ([hiddenLines]);
  /// Show earlier (the whole history) has every line.
  Widget? _history(AppLocalizations l10n) {
    final hidden = expanded ? const <String>{} : hiddenLines(card.history);
    final all = foldPageEdits(
      [
        for (final e in card.history)
          if (e.shown && !hidden.contains(e.id)) e,
      ].reversed.toList(),
    );
    final cut = !expanded && all.length > shownLines;
    final lines = cut ? all.sublist(all.length - shownLines) : all;
    final earlier = cut || card.historyMore;
    if (lines.isEmpty && !earlier) return null;
    return BvCardHistory(
      lines: [for (final e in lines) _line(l10n, e)],
      earlierLabel: earlier && !lifted ? l10n.daybookShowEarlier : null,
      onEarlier: onEarlier,
      lineKey: lineKey,
    );
  }

  /// The lines a card leaves out of its history (newest first, as the
  /// server sends it), since the card already says it:
  /// - ticks: a ticked point shows who ticked it and when (review 61 G2);
  /// - un-ticks (F42, F43): only the latest, on a point that is unticked
  ///   now, and not when whoever ticked it took it back within a minute
  ///   (a correction, not a step of the work);
  /// - Received and Got it: the faces and "Received by …" say it, with the
  ///   times one tap away (F48). On my way keeps its lines (K3).
  static Set<String> hiddenLines(List<DaybookEvent> history) {
    final hidden = <String>{};
    final byPoint = <String, List<DaybookEvent>>{};
    for (final e in history) {
      switch (e.kind) {
        case DaybookEventKind.ticked || DaybookEventKind.unticked:
          byPoint.putIfAbsent(e.pointId ?? e.point ?? e.id, () => []).add(e);
        case DaybookEventKind.received || DaybookEventKind.gotIt:
          hidden.add(e.id);
        default:
          break;
      }
    }
    for (final lines in byPoint.values) {
      final latest = lines.first;
      final tick = lines
          .skip(1)
          .where((e) => e.kind == DaybookEventKind.ticked)
          .firstOrNull;
      final correction =
          tick != null &&
          tick.byId == latest.byId &&
          latest.at.difference(tick.at) <= correctionWindow;
      for (final e in lines) {
        final kept =
            identical(e, latest) &&
            e.kind == DaybookEventKind.unticked &&
            !correction;
        if (!kept) hidden.add(e.id);
      }
    }
    return hidden;
  }

  /// An un-tick this soon after one's own tick is a correction (F43).
  static const correctionWindow = Duration(minutes: 1);

  BvHistoryLine _line(AppLocalizations l10n, DaybookEvent e) {
    final phrase = words.eventPhrase(e, me: me, now: now);
    final detail = words.eventDetail(e);
    final by = e.byId;
    return BvHistoryLine(
      id: e.id,
      name: personName(l10n, e.byName),
      lead: detail == null ? phrase : l10n.daybookHistoryLead(phrase),
      detail: detail,
      time: words.time.parts(e.at),
      tint: by == null ? BvAvatarTints.plain : BvAvatarTints.forId(by),
    );
  }

  /// The reader's one action: Sign as done, Hold to check (review 94), or
  /// Give to someone else; nothing once checked.
  Widget? _action(BuildContext context, AppLocalizations l10n, bool hasPhoto) {
    if (viewer || waiting) return null;
    final signDone = actions.onSignDone;
    final giveTo = actions.onGiveTo;
    final check = actions.onCheck;
    return switch (card.need) {
      DaybookNeed.toSign when signDone != null => BvSlipPill.action(
        label: l10n.daybookSignAsDone,
        icon: BvIcons.camera,
        onTap: signDone,
      ),
      // Checking locks the item: held, never a tap (review 94).
      DaybookNeed.toCheck when check != null => BvHoldButton(
        key: const Key('hold-check'),
        label: l10n.holdToCheck,
        icon: BvIcons.check,
        hint: l10n.holdKeepHolding,
        onConfirmed: check,
        confirm: () => showBvDialog(
          context: context,
          title: l10n.holdCheckTitle,
          body: l10n.holdCheckBody,
          cancelLabel: l10n.holdNotNow,
          confirmLabel: l10n.daybookCheck,
        ),
      ),
      DaybookNeed.giveTo when giveTo != null => Builder(
        builder: (context) => BvSlipPill.action(
          label: l10n.daybookGiveTo,
          icon: BvIcons.person,
          onTap: () => giveTo(bvGlobalRect(context)),
        ),
      ),
      _ => null,
    };
  }

  /// "M-201" from "M-201.pdf": the chip names the drawing, not its format.
  static String fileName(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 && name.length - dot <= _extensionMax
        ? name.substring(0, dot)
        : name;
  }

  static const _extensionMax = 5;
}

/// A photo from the Space's private files, on a card.
class _Photo extends ConsumerWidget {
  const _Photo({required this.path, this.stamp});

  final String path;
  final Widget? stamp;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BvSlipPhoto(
    height: BvSlipSpec.photoHeightCard,
    stamp: stamp,
    image: ref.watch(daybookPhotoProvider(path)),
  );
}

/// A photo still on the phone, waiting to be sent.
class _LocalPhoto extends ConsumerWidget {
  const _LocalPhoto({required this.path, this.stamp});

  final String path;
  final Widget? stamp;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BvSlipPhoto(
    height: BvSlipSpec.photoHeightCard,
    stamp: stamp,
    image: ref.watch(localPhotoProvider(path)),
  );
}

/// A post's photos on its card (F51): the server's, in order, or a new
/// post's still on the phone. Before its files are read, the cover alone.
/// A tap opens them all in a swipeable viewer.
class DaybookCardPhotos extends ConsumerWidget {
  const DaybookCardPhotos({
    super.key,
    required this.post,
    this.waiting = const [],
  });

  final DaybookPost post;
  final List<({String local, bool waiting})> waiting;

  /// The photos, each with whether it still waits to be sent.
  List<BvStripPhoto> _photos(WidgetRef ref) {
    if (waiting.isNotEmpty) {
      return [
        for (final p in waiting)
          (image: ref.watch(localPhotoProvider(p.local)), waiting: p.waiting),
      ];
    }
    final files = ref.watch(postFilesProvider(post.id)).value;
    final paths = files == null
        ? [?post.coverPath]
        : [
            for (final f in files)
              if (f.isPhoto) f.path!,
          ];
    return [
      for (final p in paths)
        (image: ref.watch(daybookPhotoProvider(p)), waiting: false),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = _photos(ref);
    if (photos.isEmpty) return const SizedBox.shrink();
    final close = MaterialLocalizations.of(context).closeButtonLabel;
    return BvPhotoStrip(
      photos: photos,
      onOpen: (i) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          // Watched again here, so a photo still loading shows when it
          // comes.
          builder: (_) => Consumer(
            builder: (context, ref, _) => BvPhotoViewer(
              images: [for (final p in _photos(ref)) p.image],
              first: i,
              closeLabel: close,
            ),
          ),
        ),
      ),
    );
  }
}

/// The Library files added to a checklist, an announcement or an activity
/// with 📎 (F39), as chips ("M-201 Rev C").
class DaybookCardFiles extends ConsumerWidget {
  const DaybookCardFiles({super.key, required this.post});

  final DaybookPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final files = [
      for (final f
          in ref.watch(postFilesProvider(post.id)).value ??
              const <DaybookPostFile>[])
        if (f.libraryFileId != null) f,
    ];
    if (files.isEmpty) return const SizedBox.shrink();
    // Under what is above it, a slip's gap apart (it sits in that
    // widget's own column, so with no files there is no gap).
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: BvSlipSpec.gap),
      child: BvSlipChips(
        children: [
          for (final f in files)
            BvSlipChip(
              icon: BvIcons.document,
              label: f.revLabel == null
                  ? DaybookCardView.fileName(f.name ?? '')
                  : l10n.daybookFileChip(
                      DaybookCardView.fileName(f.name ?? ''),
                      f.revLabel!,
                    ),
            ),
        ],
      ),
    );
  }
}

/// F93: one edit session is one line. The same person's page edits within
/// [pageSession] of each other fold into the latest. [oldestFirst] is the
/// history oldest first; so is the result. The post page lists every edit.
List<DaybookEvent> foldPageEdits(List<DaybookEvent> oldestFirst) {
  final out = <DaybookEvent>[];
  for (final e in oldestFirst) {
    final last = out.lastOrNull;
    if (last != null &&
        e.kind == DaybookEventKind.edited &&
        last.kind == DaybookEventKind.edited &&
        e.pageOnly &&
        last.pageOnly &&
        e.byId == last.byId &&
        e.at.difference(last.at) <= pageSession) {
      out[out.length - 1] = e;
    } else {
      out.add(e);
    }
  }
  return out;
}

/// How long one page edit session lasts on the card (F93).
const pageSession = Duration(minutes: 10);
