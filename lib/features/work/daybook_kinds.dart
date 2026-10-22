import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../data/models/daybook.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_ack_pill.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_calendar_leaf.dart';
import '../../shared/widgets/bv_checklist_point.dart';
import '../../shared/widgets/bv_faces.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_tap_target.dart';
import '../spaces/former_member.dart';
import 'daybook_marks.dart';
import 'daybook_photos.dart';
import 'daybook_words.dart';

/// Ticks a point ([on]) or unticks it.
typedef DaybookTick = void Function(DaybookPoint point, {required bool on});

/// Gives an acknowledgement ([on]) or takes it back.
typedef DaybookAckTap = void Function(DaybookAck kind, {required bool on});

/// A person's name by their id, for a face (the Space's people, then the
/// card's history); null: "Former member".
typedef DaybookNameOf = String? Function(String id);

/// The points of a checklist card (K1 v13 2594:36129), each ticked in
/// place: 48-point rows, the ticked ones struck through with who and when.
/// A tick made here shows at once ([daybookMarksProvider]). [onTick] null:
/// read only (a Viewer). A ticked point is unticked by whoever ticked it,
/// or by the author.
class DaybookChecklistPoints extends ConsumerWidget {
  const DaybookChecklistPoints({
    super.key,
    required this.post,
    required this.words,
    required this.me,
    required this.nameOf,
    this.onTick,
    this.only,
  });

  final DaybookPost post;
  final DaybookWords words;
  final String? me;
  final DaybookNameOf nameOf;
  final DaybookTick? onTick;

  /// A page's checklist block (slice 5): these points, in this order.
  final List<String>? only;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final points = ref.watch(checklistPointsProvider(post.id)).value;
    if (points == null) return const SizedBox.shrink();
    final marks = {
      for (final m in ref.watch(daybookMarksProvider))
        if (m.postId == post.id && m.isTick) m.pointId: m,
    };
    final mine = post.authorId != null && post.authorId == me;
    return Column(
      key: Key('checklist-points-${post.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in _shown(points))
          _point(l10n, markedPoint(p, marks[p.id], me), mine: mine),
      ],
    );
  }

  List<DaybookPoint> _shown(List<DaybookPoint> points) {
    final ids = only;
    if (ids == null) return points;
    final byId = {for (final p in points) p.id: p};
    return [for (final id in ids) ?byId[id]];
  }

  Widget _point(AppLocalizations l10n, DaybookPoint p, {required bool mine}) {
    final by = p.tickedById;
    final tick = onTick;
    final mayUntick = mine || (by != null && by == me);
    return BvChecklistPoint(
      key: Key('checklist-point-${p.id}'),
      text: p.text,
      tick: p.ticked
          ? (
              name: personName(l10n, by == null ? null : nameOf(by)),
              tint: by == null ? BvAvatarTints.plain : BvAvatarTints.forId(by),
              time: words.time.parts(p.tickedAt!),
            )
          : null,
      onTap: tick == null || post.cancelled || (p.ticked && !mayUntick)
          ? null
          : () => tick(p, on: !p.ticked),
    );
  }

  /// [p] as a tick or an un-tick made here shows it, until the server has
  /// it.
  static DaybookPoint markedPoint(
    DaybookPoint p,
    DaybookMark? mark,
    String? me,
  ) {
    if (mark == null) return p;
    return mark.on
        ? DaybookPoint(
            id: p.id,
            text: p.text,
            tickedAt: p.tickedAt ?? mark.at,
            tickedById: p.ticked ? p.tickedById : me,
          )
        : DaybookPoint(id: p.id, text: p.text);
  }
}

/// A row of faces and a small grey line: who received a file ("Received
/// by Omar Haddad and Rakesh Nair"). A tap ([onTap]) lists them with their
/// times (F48).
class DaybookFacesLine extends StatelessWidget {
  const DaybookFacesLine({
    super.key,
    required this.faces,
    this.text,
    this.onTap,
  });

  final List<BvFace> faces;
  final String? text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final line = Row(
      spacing: BvAckPillSpec.rowGap,
      children: [
        BvFaces(faces, large: true),
        if (text != null)
          Expanded(
            child: Text(
              text!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BvType.of(
                context,
              ).metadata.copyWith(color: BvColors.textSecondary),
            ),
          ),
      ],
    );
    if (onTap == null) return line;
    return BvTapTarget(
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: line,
        ),
      ),
    );
  }
}

/// Who acknowledged a post, each with the time they did (F48: for
/// document control), newest first, on a small sheet. [title] says what
/// ("Received", "Got it").
Future<void> showDaybookAcks(
  BuildContext context, {
  required String title,
  required List<DaybookAckFace> faces,
  required DateTime now,
}) {
  final l10n = AppLocalizations.of(context);
  final words = DaybookWords(
    l10n,
    Localizations.localeOf(context).toLanguageTag(),
    use24: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final newest = [...faces]..sort((a, b) => b.at.compareTo(a.at));
  return showBvSheet<void>(
    context: context,
    title: title,
    builder: (context) => Column(
      key: const Key('acks-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in newest)
          BvListRow(
            key: Key('ack-row-${f.profileId}'),
            title: personName(l10n, f.name),
            leading: BvAvatar(
              name: personName(l10n, f.name),
              size: BvAvatarSize.list,
              tint: BvAvatarTints.forId(f.profileId),
            ),
            // Only the time: the row opens nothing, so no chevron.
            trailing: BvRowTrailing.badge(
              Text(
                words.ackTime(f.at, now),
                style: BvType.of(
                  context,
                ).bodyMd.copyWith(color: BvColors.textSecondary),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Faces of [people] (id and name).
List<BvFace> facesOf(AppLocalizations l10n, Iterable<DaybookPerson> people) => [
  for (final p in people)
    (name: personName(l10n, p.name), tint: BvAvatarTints.forId(p.id)),
];

/// Who acknowledged [postId] with [kind], with their times, as the server
/// lets the reader see.
List<DaybookAckFace> acksOf(WidgetRef ref, String postId, DaybookAck kind) => [
  for (final a in ref.watch(postAcksProvider(postId)).value ?? const [])
    if (a.kind == kind) a,
];

/// Who acknowledged [post] with [kind], as the server lets the reader see:
/// faces only, never a number. The author sees Got it, On my way and In
/// my calendar; everyone who sees a file sees who received it.
List<DaybookPerson> acknowledgedBy(
  WidgetRef ref,
  String postId,
  DaybookAck kind,
) => [
  for (final a in ref.watch(postAcksProvider(postId)).value ?? const [])
    if (a.kind == kind) DaybookPerson(id: a.profileId, name: a.name),
];

/// The one action on an announcement, a file or an activity for [post]'s
/// reader at [now], or null.
Widget? daybookAckAction(
  AppLocalizations l10n,
  DaybookPost post, {
  required String? me,
  required DateTime now,
  required DaybookAckTap? onAck,
}) {
  if (onAck == null || post.cancelled) return null;
  final mine = post.authorId != null && post.authorId == me;
  BvAckPill pill(
    DaybookAck kind,
    String label, {
    IconData? icon,
    bool primary = false,
    String? doneLabel,
  }) {
    final given = post.myAcks.contains(kind);
    return BvAckPill(
      key: Key('ack-${kind.json}'),
      label: given ? doneLabel ?? label : label,
      icon: icon,
      tone: given
          ? BvAckPillTone.done
          : primary
          ? BvAckPillTone.primary
          : BvAckPillTone.soft,
      onTap: () => onAck(kind, on: !given),
    );
  }

  switch (post.kind) {
    // The author's own announcement and file ask nothing of them: they see
    // who got it instead.
    case DaybookPost.announcementKind when !mine:
      return pill(DaybookAck.gotIt, l10n.daybookGotIt, icon: BvIcons.check);
    // F76: nobody confirms an old version.
    case DaybookPost.fileKind when !mine && !(post.file?.hasNewer ?? false):
      return pill(
        DaybookAck.received,
        l10n.daybookReceived,
        icon: BvIcons.check,
      );
    case DaybookPost.activityKind:
      final start = post.startsAt;
      final end = post.activityEnd;
      if (start == null || end == null || !now.isBefore(end)) return null;
      // On my way from 3 hours before the start (ack's own window).
      if (!now.isBefore(start.subtract(onMyWayFrom))) {
        return pill(DaybookAck.onMyWay, l10n.daybookOnMyWay, primary: true);
      }
      return pill(
        DaybookAck.inMyCalendar,
        l10n.daybookAddToCalendar,
        icon: BvIcons.due,
        doneLabel: l10n.daybookInMyCalendar,
      );
    default:
      return null;
  }
}

/// On my way opens this long before an activity starts (the server's
/// `ack`).
const onMyWayFrom = Duration(hours: 3);

/// A scheduled activity's middle (K2 v13 2594:36287): the calendar leaf,
/// then the title, when it is and where.
class DaybookActivityWhat extends StatelessWidget {
  const DaybookActivityWhat({
    super.key,
    required this.post,
    required this.words,
    required this.now,
  });

  final DaybookPost post;
  final DaybookWords words;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final start = post.startsAt!;
    final leaf = words.leaf(start);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BvCalendarLeafSpec.gap,
      children: [
        BvCalendarLeaf(weekday: leaf.weekday, day: leaf.day, month: leaf.month),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BvCalendarLeafSpec.linesGap,
            children: [
              BvSlipTitle(post.title, cancelled: post.cancelled),
              // Cancelled (F46): the time struck through, no countdown.
              Text(
                words.activityWhen(
                  start,
                  post.endsAt,
                  now,
                  cancelled: post.cancelled,
                ),
                key: const Key('activity-when'),
                style: type.bodyMd.copyWith(
                  color: BvColors.textSecondary,
                  decoration: post.cancelled
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              if ((post.place ?? '').isNotEmpty)
                BvSlipFact(icon: BvIcons.place, text: post.place!),
            ],
          ),
        ),
      ],
    );
  }
}

/// A file post's big preview (K2 v13 2594:36329), with NEW VERSION when it
/// replaces an older one ("REPLACES REV C"). A tap opens the file.
class DaybookFilePreview extends ConsumerWidget {
  const DaybookFilePreview({
    super.key,
    required this.file,
    required this.newVersion,
    this.onTap,
  });

  final DaybookFile file;
  final bool newVersion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final path = file.path;
    final image = path == null
        ? null
        : ref.watch(filePreviewProvider((path: path, mime: file.mime))).value;
    // F75: "REPLACES V1", else the older one's revision or name.
    final replaced = file.replacesVersionNo != null
        ? l10n.libraryVersionNo(file.replacesVersionNo!)
        : file.replacesRev ?? file.replacesName;
    final photo = Stack(
      children: [
        BvSlipPhoto(
          key: const Key('file-preview'),
          height: BvFileCardSpec.previewHeight,
          image: image,
        ),
        if (image == null)
          const Positioned.fill(
            child: Center(
              child: Icon(
                BvIcons.document,
                size: BvSize.iconLg,
                color: BvColors.iconSecondary,
              ),
            ),
          ),
        if (newVersion)
          PositionedDirectional(
            top: BvFileCardSpec.stampTop,
            start: BvFileCardSpec.stampStart,
            child: BvInkStamp(
              key: const Key('stamp-new-version'),
              label: file.versionNo == null
                  ? l10n.daybookStampNewVersion
                  : l10n.daybookStampNewVersionNo(
                      l10n.libraryVersionNo(file.versionNo!),
                    ),
              size: BvInkStampSize.lg,
              subline: replaced == null
                  ? null
                  : l10n.daybookStampReplaces(replaced.toUpperCase()),
            ),
          ),
      ],
    );
    if (onTap == null) return photo;
    return Semantics(
      button: true,
      child: GestureDetector(onTap: onTap, child: photo),
    );
  }
}
