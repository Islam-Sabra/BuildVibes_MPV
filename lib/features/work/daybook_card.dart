import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../core/design/daybook_paper_specs.dart';
import '../../data/models/daybook.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_card_history.dart';
import '../../shared/widgets/bv_checklist_point.dart';
import '../../shared/widgets/bv_faces.dart';
import '../../shared/widgets/bv_marked_text.dart';
import '../../shared/widgets/bv_popover_menu.dart' show bvGlobalRect;
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_swipe_reveal.dart';
import '../../shared/widgets/bv_torn_edge.dart';
import '../spaces/former_member.dart';
import 'daybook_kinds.dart';
import 'daybook_photos.dart';
import 'daybook_words.dart';

/// What a card lets the reader do (the loop). Null callbacks are not
/// offered: a Viewer gets none.
@immutable
class DaybookCardActions {
  const DaybookCardActions({
    this.onMenu,
    this.onCheck,
    this.onSignDone,
    this.onGiveTo,
    this.onUpdate,
    this.onTick,
    this.onAck,
    this.onOpenFile,
  });

  /// Long-press, or a tap: the lifted card and its menu. Gets the card's
  /// place on screen, so a tap is never a dead end (F16).
  final ValueChanged<Rect>? onMenu;

  /// Double-tap the proof photo (B3), while it needs the reader's check.
  final VoidCallback? onCheck;

  /// The owner's "Sign as done" (O1).
  final VoidCallback? onSignDone;

  /// "Give to someone else", when the owner can no longer sign it.
  final ValueChanged<Rect>? onGiveTo;

  /// Swipe towards the end side: add an update (Y1), a shortcut to the
  /// menu's Add update. Gets the card's place on screen.
  final ValueChanged<Rect>? onUpdate;

  /// Tick a checklist's point, or untick it (Lead and Crew).
  final DaybookTick? onTick;

  /// Got it, Received, Add to my calendar or On my way (Viewers too).
  final DaybookAckTap? onAck;

  /// A file post's preview: the file, full screen.
  final VoidCallback? onOpenFile;
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
    this.couldNotSend = false,
    this.localPhoto,
    this.actions = const DaybookCardActions(),
    this.landing = false,
    this.lifted = false,
    this.expanded = false,
    this.onEarlier,
    this.lineKey,
    this.onTap,
    this.nameOf,
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

  /// The server refused it: a post while another card was being written,
  /// or a sign-off (its photos stay on the phone). A tap fixes it.
  final bool couldNotSend;
  final String? localPhoto;
  final DaybookCardActions actions;

  /// The CHECKED stamp lands now (a check made here).
  final bool landing;
  final bool lifted;

  /// The whole history shows, not only the last three lines.
  final bool expanded;

  /// "Show earlier".
  final VoidCallback? onEarlier;

  /// Each history line's key, so a trace can scroll to it.
  final Key Function(String id)? lineKey;

  /// A tap on the card, instead of the menu.
  final VoidCallback? onTap;

  /// Who ticked a point, by id.
  final DaybookNameOf? nameOf;

  /// History lines drawn collapsed.
  static const shownLines = 3;

  DaybookPost get _post => card.post;

  /// The paper clip: the card needs the reader.
  bool get clip => card.need != null && !viewer && !waiting;

  /// The same card with [actions], or [lifted] over the dim.
  DaybookCardView copyWith({DaybookCardActions? actions, bool? lifted}) =>
      DaybookCardView(
        key: key,
        card: card,
        words: words,
        me: me,
        now: now,
        activityAt: activityAt,
        viewer: viewer,
        waiting: waiting,
        couldNotSend: couldNotSend,
        localPhoto: localPhoto,
        actions: actions ?? this.actions,
        landing: landing,
        lifted: lifted ?? this.lifted,
        expanded: expanded,
        onEarlier: onEarlier,
        // A lifted copy draws over the card itself: its lines have no keys.
        lineKey: (lifted ?? this.lifted) ? null : lineKey,
        onTap: onTap,
        nameOf: nameOf,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final post = _post;
    if (!post.isWorkItem) return _kindCard(context, l10n);
    final proof = card.proof;
    final hasPhoto = localPhoto != null || (proof?.photos.isNotEmpty ?? false);
    final stamp = _stamp(l10n);
    final check = card.need == DaybookNeed.toCheck && !lifted
        ? actions.onCheck
        : null;
    final chips = [
      for (final f in post.attachments)
        BvSlipChip(
          icon: BvIcons.document,
          label: f.revLabel == null
              ? _fileName(f.name)
              : l10n.daybookFileChip(_fileName(f.name), f.revLabel!),
        ),
      if (post.pointsTotal > 0)
        BvSlipChip(
          icon: BvIcons.workItems,
          label: l10n.daybookPoints(post.pointsTotal),
        ),
    ];
    final ref = post.item?.ref;
    final authorId = post.authorId;
    final noteOnly = proof != null && !hasPhoto;
    final action = lifted ? null : _action(context, l10n, hasPhoto);
    final history = _history(l10n);

    final paper = Builder(
      builder: (context) {
        final menu = actions.onMenu;
        return BvSlip(
          tear: BvSlipBorder.forId(post.id).variant,
          // With no proof, only CANCELLED is stamped, at the corner.
          stamp: proof == null && post.cancelled ? stamp : null,
          clip: clip,
          cancelled: post.cancelled,
          lifted: lifted,
          onTap: lifted
              ? null
              : onTap ??
                    (menu == null ? null : () => menu(bvGlobalRect(context))),
          onLongPress: lifted || menu == null
              ? null
              : () => menu(bvGlobalRect(context)),
          children: [
            BvSlipHeader(
              name: personName(l10n, post.authorName),
              label: authorId != null && authorId == me
                  ? l10n.daybookYou
                  : null,
              ref: ref == null ? null : l10n.daybookCardRef(ref),
              time: words.time.parts(activityAt),
              tint: authorId == null
                  ? BvAvatarTints.plain
                  : BvAvatarTints.forId(authorId),
            ),
            BvSlipTitle(post.title, cancelled: post.cancelled),
            BvSlipFacts(
              children: [
                BvSlipFact(
                  icon: BvIcons.person,
                  text: words.meta(post, me: me, now: now),
                  marks: _factMarks(context),
                ),
                if ((post.place ?? '').isNotEmpty)
                  BvSlipFact(icon: BvIcons.place, text: post.place!),
              ],
            ),
            if (post.isLate(now))
              BvSlipLate(l10n.daybookLate(post.lateDays(now))),
            if (chips.isNotEmpty) BvSlipChips(children: chips),
            if (localPhoto != null)
              _LocalPhoto(
                path: localPhoto!,
                stamp: proof == null ? null : stamp,
              )
            else if (proof != null && proof.photos.isNotEmpty)
              _Photo(
                path: proof.photos.first.path,
                stamp: stamp,
                onDoubleTap: check,
              )
            else if (proof == null && post.coverPath != null)
              _Photo(path: post.coverPath!),
            // A proof with only a note (F6): the note, and the stamp
            // pressed under it, with no empty frame.
            if (noteOnly && (proof.note ?? '').isNotEmpty)
              BvSlipNote(proof.note!),
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
            else if (waiting)
              BvSlipQuiet(l10n.daybookWaitingToSend),
            ?action,
          ],
        );
      },
    );
    final update = actions.onUpdate;
    if (lifted || update == null) return paper;
    return Builder(
      builder: (context) => BvSwipeReveal(
        actionLabel: l10n.daybookAddUpdate,
        onAction: () => update(bvGlobalRect(context)),
        child: paper,
      ),
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
    final menu = actions.onMenu;
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
        onTap: lifted
            ? null
            : onTap ??
                  (menu == null ? null : () => menu(bvGlobalRect(context))),
        onLongPress: lifted || menu == null
            ? null
            : () => menu(bvGlobalRect(context)),
        children: [
          BvSlipHeader(
            name: personName(l10n, post.authorName),
            label: authorId != null && authorId == me ? l10n.daybookYou : null,
            ref: _kindWord(l10n),
            time: words.time.parts(activityAt),
            tint: authorId == null
                ? BvAvatarTints.plain
                : BvAvatarTints.forId(authorId),
          ),
          ..._kindBody(context, l10n),
          ?history,
          if (couldNotSend)
            BvSlipError(l10n.daybookCouldNotSend)
          else if (waiting)
            BvSlipQuiet(l10n.daybookWaitingToSend),
        ],
      ),
    );
  }

  /// "· checklist", "· scheduled", "· file", "· to everyone".
  String _kindWord(AppLocalizations l10n) => switch (_post.kind) {
    DaybookPost.checklistKind => l10n.daybookKindChecklistWord,
    DaybookPost.activityKind => l10n.daybookKindActivityWord,
    DaybookPost.fileKind => l10n.daybookKindFileWord,
    _ => l10n.daybookToEveryone,
  };

  List<Widget> _kindBody(BuildContext context, AppLocalizations l10n) {
    final post = _post;
    final act = lifted || waiting ? null : actions.onAck;
    final action = daybookAckAction(l10n, post, me: me, now: now, onAck: act);
    // Photos added with 📎 or the camera: the first one on the card.
    final cover = post.coverPath == null ? null : _Photo(path: post.coverPath!);
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
      case DaybookPost.checklistKind:
        return [
          BvSlipTitle(post.title, cancelled: post.cancelled),
          ?cover,
          if ((post.body ?? '').isNotEmpty) BvSlipNote(post.body!),
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
          DaybookActivityWhat(post: post, words: words, now: now),
          ?cover,
          if ((post.body ?? '').isNotEmpty) BvSlipNote(post.body!),
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
          if ((post.body ?? '').isNotEmpty) BvSlipNote(post.body!),
          if (!waiting)
            Consumer(
              builder: (context, ref, _) {
                final by = acknowledgedBy(ref, post.id, DaybookAck.received);
                if (by.isEmpty) return const SizedBox.shrink();
                return DaybookFacesLine(
                  key: const Key('received-by'),
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
          BvSlipTitle(post.title, cancelled: post.cancelled),
          ?cover,
          if ((post.body ?? '').isNotEmpty) BvSlipNote(post.body!),
          Consumer(
            builder: (context, ref, _) {
              final by = waiting
                  ? const <DaybookPerson>[]
                  : acknowledgedBy(ref, post.id, DaybookAck.gotIt);
              if (by.isEmpty && action == null) {
                return const SizedBox.shrink();
              }
              return row(
                by.isEmpty ? null : BvFaces(facesOf(l10n, by), large: true),
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
  /// Review 61 G2: a ticked point already says who ticked it and when, so
  /// the card leaves out tick lines (a checklist's, or a work item's
  /// points); un-ticks, edits and the rest stay. Show earlier (the whole
  /// history) has them all.
  Widget? _history(AppLocalizations l10n) {
    final all = [
      for (final e in card.history)
        if (e.shown && (expanded || e.kind != DaybookEventKind.ticked)) e,
    ].reversed.toList();
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

  /// The reader's one action: Sign as done, the double-tap hint, or Give
  /// to someone else; nothing once checked.
  Widget? _action(BuildContext context, AppLocalizations l10n, bool hasPhoto) {
    if (viewer || waiting) return null;
    final signDone = actions.onSignDone;
    final giveTo = actions.onGiveTo;
    return switch (card.need) {
      DaybookNeed.toSign when signDone != null => BvSlipPill.action(
        label: l10n.daybookSignAsDone,
        icon: BvIcons.camera,
        onTap: signDone,
      ),
      // A proof with only a note is checked from the menu.
      DaybookNeed.toCheck when hasPhoto && actions.onCheck != null =>
        BvSlipPill.hint(label: l10n.daybookDoubleTapToCheck),
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
  static String _fileName(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 && name.length - dot <= _extensionMax
        ? name.substring(0, dot)
        : name;
  }

  static const _extensionMax = 5;
}

/// A photo from the Space's private files, on a card.
class _Photo extends ConsumerWidget {
  const _Photo({required this.path, this.stamp, this.onDoubleTap});

  final String path;
  final Widget? stamp;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BvSlipPhoto(
    height: BvSlipSpec.photoHeightCard,
    stamp: stamp,
    onDoubleTap: onDoubleTap,
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
