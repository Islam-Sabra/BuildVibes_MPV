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
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_torn_edge.dart';
import '../spaces/former_member.dart';
import 'daybook_words.dart';

/// One entry on the daybook's spine: its time, the dot, and its slip (D1,
/// L1, DY1, V1). A work item [DaybookPost], the owner's proof
/// ([DaybookSignOff]: quote, big photo, large stamp, note) or an update
/// ([DaybookUpdate]: a small note quoting the item). Read only in slice 1
/// part 1c: opening a post in place, the long-press menu and double-tap come
/// in later parts.
///
/// A [viewer] gets no paper clip and no hint. A post still [waiting] to be
/// sent (no signal) says so, and shows its photo from the phone
/// ([localCover]).
class DaybookEntry extends StatelessWidget {
  const DaybookEntry({
    super.key,
    required this.record,
    required this.words,
    required this.me,
    required this.now,
    this.viewer = false,
    this.waiting = false,
    this.localCover,
  });

  final DaybookRecord record;
  final DaybookWords words;
  final String? me;
  final DateTime now;
  final bool viewer;
  final bool waiting;
  final String? localCover;

  @override
  Widget build(BuildContext context) {
    final record = this.record;
    final (dot, slip) = switch (record) {
      DaybookPost() => _postSlip(context, record),
      DaybookSignOff() => _signOffSlip(context, record),
      DaybookUpdate() => _updateSlip(context, record),
    };
    return BvSpineEntry(
      key: Key('daybook-entry-${record.id}'),
      time: words.clock(record.at),
      dot: dot,
      child: slip,
    );
  }

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

  (BvSpineDot, Widget) _postSlip(BuildContext context, DaybookPost post) {
    final l10n = AppLocalizations.of(context);
    final clip = post.needsMe && !viewer && !waiting;
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
      DaybookStampKind.sentBack => BvInkStamp(
        label: l10n.daybookStampSentBack,
        tone: BvInkStampTone.destructive,
      ),
      DaybookStampKind.newVersion || null => null,
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
    final slip = BvSlip(
      tear: BvSlipBorder.forId(post.id).variant,
      stamp: stamp,
      clip: clip,
      cancelled: post.cancelled,
      children: [
        _header(l10n, post.authorId, post.authorName),
        BvSlipTitle(post.title, cancelled: post.cancelled),
        BvSlipMeta(
          post.cancelled && cancelledAt != null
              ? l10n.daybookCancelledBy(
                  personName(l10n, post.stamp?.byName),
                  words.clock(cancelledAt),
                )
              : words.meta(post, me: me, now: now),
        ),
        if (post.isLate(now)) BvSlipLate(l10n.daybookLate(post.lateDays(now))),
        if ((post.place ?? '').isNotEmpty) BvSlipPlace(post.place!),
        if (chips.isNotEmpty) BvSlipChips(children: chips),
        if (localCover != null)
          _LocalPhoto(path: localCover!)
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
        if (waiting) BvSlipHistory(l10n.daybookWaitingToSend),
      ],
    );
    final dot = clip
        ? BvSpineDot.needsYou
        : post.stamp?.kind == DaybookStampKind.checked
        ? BvSpineDot.checked
        : BvSpineDot.quiet;
    return (dot, slip);
  }

  /// "M-201" from "M-201.pdf": the chip names the drawing, not its format.
  static String _fileName(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 && name.length - dot <= _extensionMax
        ? name.substring(0, dot)
        : name;
  }

  static const _extensionMax = 5;

  (BvSpineDot, Widget) _signOffSlip(BuildContext context, DaybookSignOff s) {
    final l10n = AppLocalizations.of(context);
    final clip = s.needsMe && !viewer;
    final outcome = s.outcome;
    final cancelled = outcome.kind == DaybookOutcomeKind.cancelled;
    final stamp = switch (outcome.kind) {
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
    final photo = s.photos.firstOrNull;
    final slip = BvSlip(
      tear: BvSlipBorder.forId(s.id).variant,
      // With no photo, the stamp goes on the slip.
      stamp: photo == null ? stamp : null,
      clip: clip,
      cancelled: cancelled,
      children: [
        _header(l10n, s.actorId, s.actorName, action: l10n.daybookSignedAsDone),
        BvSlipQuote(s.title),
        if (photo != null)
          _Photo(
            path: photo.path,
            height: BvSlipSpec.photoHeightProof,
            stamp: stamp,
          ),
        if ((s.note ?? '').isNotEmpty) BvSlipNote(s.note!),
        // The double-tap itself comes with the loop (part 1d).
        if (clip) BvSlipPill.hint(label: l10n.daybookDoubleTapToCheck),
      ],
    );
    final dot = clip
        ? BvSpineDot.needsYou
        : outcome.kind == DaybookOutcomeKind.checked
        ? BvSpineDot.checked
        : BvSpineDot.quiet;
    return (dot, slip);
  }

  (BvSpineDot, Widget) _updateSlip(BuildContext context, DaybookUpdate u) {
    final l10n = AppLocalizations.of(context);
    final photo = u.photos.firstOrNull;
    return (
      BvSpineDot.quiet,
      BvSlip(
        tear: BvSlipBorder.forId(u.id).variant,
        children: [
          _header(
            l10n,
            u.actorId,
            u.actorName,
            action: l10n.daybookAddedUpdate,
          ),
          BvSlipQuote(u.title),
          if ((u.note ?? '').isNotEmpty) BvSlipNote(u.note!),
          if (photo != null)
            _Photo(path: photo.path, height: BvSlipSpec.photoHeightCover),
        ],
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

/// A photo kept on the phone (a draft's, or a post's waiting to be sent).
final localPhotoProvider = Provider.autoDispose.family<ImageProvider, String>(
  (ref, path) => FileImage(File(path)),
);

/// A photo from the Space's private files, cropped to [height].
class _Photo extends ConsumerWidget {
  const _Photo({required this.path, required this.height, this.stamp});

  final String path;
  final double height;
  final Widget? stamp;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BvSlipPhoto(
    height: height,
    stamp: stamp,
    image: ref.watch(daybookPhotoProvider(path)),
  );
}

/// The cover of a post still waiting to be sent, from the phone.
class _LocalPhoto extends ConsumerWidget {
  const _LocalPhoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BvSlipPhoto(
    height: BvSlipSpec.photoHeightCover,
    image: ref.watch(localPhotoProvider(path)),
  );
}
