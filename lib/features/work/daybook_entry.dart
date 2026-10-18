import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_paper_specs.dart';
import '../../data/models/daybook.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_daybook_spine.dart';
import '../../shared/widgets/bv_popover_menu.dart' show bvGlobalRect;
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_swipe_reveal.dart';
import '../../shared/widgets/bv_torn_edge.dart';
import '../../shared/widgets/bv_update_note.dart';
import '../spaces/former_member.dart';
import 'daybook_words.dart';

/// What a slip lets the reader do (the loop, slice 1 part 1d). Null
/// callbacks are not offered: a Viewer gets none.
@immutable
class DaybookSlipActions {
  const DaybookSlipActions({
    this.onLongPress,
    this.onCheck,
    this.onSignDone,
    this.onUpdate,
  });

  /// Long-press: the lifted slip and its menu. Gets the slip's place on
  /// screen. Until a slip opens its own page (slice 5), a short press
  /// shows the same menu, so a tap is never a dead end (F16).
  final ValueChanged<Rect>? onLongPress;

  /// Double-tap the proof photo (B3).
  final VoidCallback? onCheck;

  /// The owner's "Sign as done" pill (O1).
  final VoidCallback? onSignDone;

  /// Swipe towards the end side: add an update (Y1), a shortcut to the
  /// menu's Add update. Gets the slip's place on screen.
  final ValueChanged<Rect>? onUpdate;
}

/// One entry on the daybook's spine: its time, the dot, and its slip (D1,
/// L1, DY1, V1, the loop's frames). See [DaybookSlip].
class DaybookEntry extends StatelessWidget {
  const DaybookEntry({super.key, required this.slip, required this.words});

  final DaybookSlip slip;
  final DaybookWords words;

  @override
  Widget build(BuildContext context) {
    final at = words.spineClock(slip.record.at);
    return BvSpineEntry(
      key: Key('daybook-entry-${slip.record.id}'),
      time: at.time,
      period: at.period,
      dot: slip.dot,
      child: slip,
    );
  }
}

/// The slip of a daybook entry: a work item [DaybookPost], the owner's
/// proof ([DaybookSignOff]: quote, big photo, large stamp, note) or an
/// update ([DaybookUpdate]: a small note quoting the item, Y2). [lifted]
/// draws it over the dim under the long-press menu, with no gestures.
///
/// A [viewer] gets no paper clip and no hint. A post or proof still
/// [waiting] to be sent says so, and shows its photo from the phone
/// ([localPhoto]).
class DaybookSlip extends StatelessWidget {
  const DaybookSlip({
    super.key,
    required this.record,
    required this.words,
    required this.me,
    required this.now,
    this.viewer = false,
    this.waiting = false,
    this.couldNotSend = false,
    this.localPhoto,
    this.actions = const DaybookSlipActions(),
    this.landing = false,
    this.checker,
    this.lifted = false,
    this.onTap,
  });

  final DaybookRecord record;
  final DaybookWords words;
  final String? me;
  final DateTime now;
  final bool viewer;
  final bool waiting;

  /// The server refused it: a post while another card was being written,
  /// or a sign-off (its photos stay on the phone). A tap fixes it.
  final bool couldNotSend;
  final String? localPhoto;
  final DaybookSlipActions actions;

  /// The CHECKED stamp lands now (a check made here).
  final bool landing;

  /// Who checks a proof next (the work item's author), for its owner.
  final String? checker;
  final bool lifted;

  /// A tap on the slip.
  final VoidCallback? onTap;

  /// The spine's dot: needs you, checked, or quiet.
  BvSpineDot get dot {
    final r = record;
    return switch (r) {
      DaybookPost() when _postClip(r) => BvSpineDot.needsYou,
      DaybookPost() when r.stamp?.kind == DaybookStampKind.checked =>
        BvSpineDot.checked,
      DaybookSignOff() when _signOffClip(r) => BvSpineDot.needsYou,
      DaybookSignOff() when r.outcome.kind == DaybookOutcomeKind.checked =>
        BvSpineDot.checked,
      DaybookSentBack() when r.needsMe && !viewer && !waiting =>
        BvSpineDot.needsYou,
      _ => BvSpineDot.quiet,
    };
  }

  bool _postClip(DaybookPost p) => p.needsMe && !viewer && !waiting;
  bool _signOffClip(DaybookSignOff s) => s.needsMe && !viewer && !waiting;

  @override
  Widget build(BuildContext context) {
    final record = this.record;
    final slip = switch (record) {
      DaybookPost() => _postSlip(context, record),
      DaybookSignOff() => _signOffSlip(context, record),
      DaybookSentBack() => _sentBackSlip(context, record),
      DaybookUpdate() => _updateNote(context, record),
    };
    final update = actions.onUpdate;
    if (lifted || update == null || record is! DaybookPost) return slip;
    return Builder(
      builder: (context) => BvSwipeReveal(
        actionLabel: AppLocalizations.of(context).daybookAddUpdate,
        onAction: () => update(bvGlobalRect(context)),
        child: slip,
      ),
    );
  }

  /// The same slip with [actions], or [lifted] over the dim.
  DaybookSlip copyWith({DaybookSlipActions? actions, bool? lifted}) =>
      DaybookSlip(
        key: key,
        record: record,
        words: words,
        me: me,
        now: now,
        viewer: viewer,
        waiting: waiting,
        couldNotSend: couldNotSend,
        localPhoto: localPhoto,
        actions: actions ?? this.actions,
        landing: landing,
        checker: checker,
        lifted: lifted ?? this.lifted,
        onTap: onTap,
      );

  BvSlipHeader _header(
    AppLocalizations l10n,
    String? personId,
    String? name, {
    String? action,
  }) => BvSlipHeader(
    name: personName(l10n, name),
    label: personId != null && personId == me ? l10n.daybookYou : null,
    action: action,
    tint: personId == null
        ? BvAvatarTints.plain
        : BvAvatarTints.forId(personId),
  );

  /// The slip with its long-press, measured where it is on screen. A
  /// short press does what [onTap] says, else shows the same menu.
  Widget _slip({
    required String id,
    required List<Widget> children,
    Widget? stamp,
    bool clip = false,
    bool cancelled = false,
  }) {
    final press = actions.onLongPress;
    return Builder(
      builder: (context) => BvSlip(
        tear: BvSlipBorder.forId(id).variant,
        stamp: stamp,
        clip: clip,
        cancelled: cancelled,
        lifted: lifted,
        onTap: lifted
            ? null
            : onTap ??
                  (press == null ? null : () => press(bvGlobalRect(context))),
        onLongPress: lifted || press == null
            ? null
            : () => press(bvGlobalRect(context)),
        children: children,
      ),
    );
  }

  Widget _postSlip(BuildContext context, DaybookPost post) {
    final l10n = AppLocalizations.of(context);
    final clip = _postClip(post);
    final cancelledAt = post.stamp?.at;
    final edited = words.editedDue(post.dueEdit, now);
    final given = post.givenTo;
    final stamp = switch (post.cancelled
        ? DaybookStampKind.cancelled
        : post.stamp?.kind) {
      DaybookStampKind.cancelled => BvInkStamp(
        label: l10n.daybookStampCancelled,
        size: BvInkStampSize.sm,
        tone: BvInkStampTone.muted,
      ),
      DaybookStampKind.done => BvInkStamp(label: l10n.daybookStampDone),
      DaybookStampKind.checked => BvInkStamp(
        label: l10n.daybookStampChecked,
        tone: BvInkStampTone.positive,
      ),
      // SENT BACK is on the proof it answered; the send-back has its own
      // slip (S1).
      DaybookStampKind.sentBack || DaybookStampKind.newVersion || null => null,
    };
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
    // The author cancelled it: "Cancelled by you" for them.
    final byMe =
        post.authorId != null &&
        post.authorId == me &&
        post.stamp?.byName == post.authorName;
    final signDone = actions.onSignDone;
    return _slip(
      id: post.id,
      stamp: stamp,
      clip: clip,
      cancelled: post.cancelled,
      children: [
        _header(l10n, post.authorId, post.authorName),
        BvSlipTitle(post.title, cancelled: post.cancelled),
        BvSlipMeta(
          post.cancelled && cancelledAt != null
              ? byMe
                    ? l10n.daybookCancelledByYou(words.clock(cancelledAt))
                    : l10n.daybookCancelledBy(
                        personName(l10n, post.stamp?.byName),
                        words.clock(cancelledAt),
                      )
              : words.meta(post, me: me, now: now),
        ),
        if (post.isLate(now)) BvSlipLate(l10n.daybookLate(post.lateDays(now))),
        if ((post.place ?? '').isNotEmpty) BvSlipPlace(post.place!),
        if (chips.isNotEmpty) BvSlipChips(children: chips),
        if (localPhoto != null)
          _LocalPhoto(path: localPhoto!, height: BvSlipSpec.photoHeightCover)
        else if (post.coverPath != null)
          _Photo(path: post.coverPath!, height: BvSlipSpec.photoHeightCover),
        if (given != null)
          BvSlipHistory(
            l10n.daybookGivenTo(
              personName(l10n, given.toName),
              personName(l10n, given.fromName),
              words.clock(given.at),
            ),
          ),
        if (edited != null) BvSlipHistory(edited),
        if (couldNotSend)
          BvSlipError(l10n.daybookCouldNotSend)
        else if (waiting)
          BvSlipHistory(l10n.daybookWaitingToSend),
        if (signDone != null && !lifted)
          BvSlipPill.action(
            label: l10n.daybookSignAsDone,
            icon: BvIcons.camera,
            onTap: signDone,
          ),
      ],
    );
  }

  /// "M-201" from "M-201.pdf": the chip names the drawing, not its format.
  static String _fileName(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 && name.length - dot <= _extensionMax
        ? name.substring(0, dot)
        : name;
  }

  static const _extensionMax = 5;

  Widget _signOffSlip(BuildContext context, DaybookSignOff s) {
    final l10n = AppLocalizations.of(context);
    final clip = _signOffClip(s);
    final outcome = s.outcome;
    final cancelled = outcome.kind == DaybookOutcomeKind.cancelled;
    // A refused proof isn't done: no stamp until it is sent.
    final stamp = switch (outcome.kind) {
      DaybookOutcomeKind.done when couldNotSend => null,
      DaybookOutcomeKind.done => BvInkStamp(
        label: l10n.daybookStampDone,
        size: BvInkStampSize.lg,
        subline: words.stampLine(s.actorName, s.at),
      ),
      DaybookOutcomeKind.checked => BvInkStamp(
        label: l10n.daybookStampChecked,
        size: BvInkStampSize.lg,
        tone: BvInkStampTone.positive,
        subline: words.stampLine(outcome.byName, outcome.at ?? s.at),
        land: landing,
      ),
      DaybookOutcomeKind.sentBack => BvInkStamp(
        label: l10n.daybookStampSentBack,
        size: BvInkStampSize.lg,
        tone: BvInkStampTone.destructive,
        subline: words.stampLine(outcome.byName, outcome.at ?? s.at),
      ),
      DaybookOutcomeKind.cancelled => BvInkStamp(
        label: l10n.daybookStampCancelled,
        size: BvInkStampSize.lg,
        tone: BvInkStampTone.muted,
      ),
    };
    final hasPhoto = localPhoto != null || s.photos.isNotEmpty;
    final check = clip && !lifted ? actions.onCheck : null;
    final checkedAt = outcome.at;
    return _slip(
      id: s.id,
      clip: clip,
      cancelled: cancelled,
      children: [
        _header(l10n, s.actorId, s.actorName, action: l10n.daybookSignedAsDone),
        BvSlipQuote(s.title),
        if (localPhoto != null)
          _LocalPhoto(
            path: localPhoto!,
            height: BvSlipSpec.photoHeightProof,
            stamp: stamp,
          )
        else if (s.photos.isNotEmpty)
          _Photo(
            path: s.photos.first.path,
            height: BvSlipSpec.photoHeightProof,
            stamp: stamp,
            onDoubleTap: check,
          ),
        if ((s.note ?? '').isNotEmpty) BvSlipNote(s.note!),
        // With no photo (F6), the stamp is pressed under the note: no
        // empty frame, and clear of the header.
        if (!hasPhoto && stamp != null)
          Padding(
            padding: BvSlipSpec.stampNoPhotoPadding,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: stamp,
            ),
          ),
        if (clip && hasPhoto)
          BvSlipPill.hint(label: l10n.daybookDoubleTapToCheck),
        if (outcome.kind == DaybookOutcomeKind.checked &&
            outcome.byId != null &&
            outcome.byId == me &&
            checkedAt != null)
          BvSlipHistory(l10n.daybookYouChecked(words.clock(checkedAt))),
        // The reason and note are on the send-back's own slip (S1).
        if (outcome.kind == DaybookOutcomeKind.sentBack)
          BvSlipHistory(
            l10n.daybookSentBackAt(words.clock(outcome.at ?? s.at)),
          ),
        if (outcome.kind == DaybookOutcomeKind.done &&
            s.actorId == me &&
            checker != null &&
            !couldNotSend)
          BvSlipHistory(l10n.daybookChecksNext(checker!)),
        // A refused sign-off keeps its photos on the phone (review 47,
        // answer 5): a tap reopens the proof.
        if (couldNotSend)
          BvSlipError(l10n.daybookCouldNotSend)
        else if (waiting)
          BvSlipHistory(l10n.daybookWaitingToSend),
      ],
    );
  }

  /// A send-back at its own time (S1 2530:33826): who sent it back, the
  /// quote, the reason and note, and for the owner the paper clip with
  /// Sign as done while it is the latest.
  Widget _sentBackSlip(BuildContext context, DaybookSentBack b) {
    final l10n = AppLocalizations.of(context);
    final clip = b.needsMe && !viewer && !waiting;
    final signDone = actions.onSignDone;
    return _slip(
      id: b.id,
      clip: clip,
      cancelled: b.cancelled,
      children: [
        _header(l10n, b.actorId, b.actorName, action: l10n.daybookSentItBack),
        BvSlipQuote(b.title),
        BvSlipNote(words.sentBackText(b.reason, b.note)),
        if (signDone != null && !lifted)
          BvSlipPill.action(
            label: l10n.daybookSignAsDone,
            icon: BvIcons.camera,
            onTap: signDone,
          ),
      ],
    );
  }

  Widget _updateNote(BuildContext context, DaybookUpdate u) {
    final l10n = AppLocalizations.of(context);
    final note = BvUpdateNote(
      key: Key('daybook-update-${u.id}'),
      quote: u.title,
      name: personName(l10n, u.actorName),
      text: u.note ?? '',
      tint: u.actorId == null
          ? BvAvatarTints.plain
          : BvAvatarTints.forId(u.actorId!),
      photo: u.photos.isEmpty
          ? null
          : _Photo(
              path: u.photos.first.path,
              height: BvSlipSpec.photoHeightCover,
            ),
    );
    final press = actions.onLongPress;
    if (lifted || press == null) return note;
    return Builder(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => press(bvGlobalRect(context)),
        child: note,
      ),
    );
  }
}

/// A photo in the Space's private files, through a short-lived link; null
/// while the link loads. Screens stand in for it in tests.
final daybookPhotoProvider = Provider.autoDispose
    .family<ImageProvider?, String>((ref, path) {
      final url = ref.watch(workPhotoUrlProvider(path)).value;
      return url == null ? null : NetworkImage(url);
    });

/// A photo kept on the phone (a draft's, or one waiting to be sent).
final localPhotoProvider = Provider.autoDispose.family<ImageProvider, String>(
  (ref, path) => FileImage(File(path)),
);

/// A photo from the Space's private files, cropped to [height].
class _Photo extends ConsumerWidget {
  const _Photo({
    required this.path,
    required this.height,
    this.stamp,
    this.onDoubleTap,
  });

  final String path;
  final double height;
  final Widget? stamp;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BvSlipPhoto(
    height: height,
    stamp: stamp,
    onDoubleTap: onDoubleTap,
    image: ref.watch(daybookPhotoProvider(path)),
  );
}

/// A photo still on the phone, waiting to be sent.
class _LocalPhoto extends ConsumerWidget {
  const _LocalPhoto({required this.path, required this.height, this.stamp});

  final String path;
  final double height;
  final Widget? stamp;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BvSlipPhoto(
    height: height,
    stamp: stamp,
    image: ref.watch(localPhotoProvider(path)),
  );
}
