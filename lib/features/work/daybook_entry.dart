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

/// A work item on the daybook's spine: its time, the dot, and its slip
/// (D1, L1, DY1, V1). Read only in part 1b: opening it in place, the
/// long-press menu and double-tap come in later parts.
///
/// A [viewer] gets no paper clip.
class DaybookEntry extends StatelessWidget {
  const DaybookEntry({
    super.key,
    required this.post,
    required this.words,
    required this.me,
    required this.now,
    this.viewer = false,
  });

  final DaybookPost post;
  final DaybookWords words;
  final String? me;
  final DateTime now;
  final bool viewer;

  bool get _clip => post.needsMe && !viewer;

  BvSpineDot get _dot => _clip
      ? BvSpineDot.needsYou
      : post.stamp?.kind == DaybookStampKind.checked
      ? BvSpineDot.checked
      : BvSpineDot.quiet;

  @override
  Widget build(BuildContext context) => BvSpineEntry(
    key: Key('daybook-entry-${post.id}'),
    time: words.clock(post.createdAt),
    dot: _dot,
    child: _slip(context),
  );

  Widget? _stamp(AppLocalizations l10n) =>
      switch (post.cancelled ? DaybookStampKind.cancelled : post.stamp?.kind) {
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

  Widget _slip(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cancelledAt = post.stamp?.at;
    final edited = words.editedDue(post.dueEdit, now);
    return BvSlip(
      tear: BvSlipBorder.forId(post.id).variant,
      stamp: _stamp(l10n),
      clip: _clip,
      cancelled: post.cancelled,
      children: [
        BvSlipHeader(
          name: personName(l10n, post.authorName),
          label: post.authorId != null && post.authorId == me
              ? l10n.daybookYou
              : null,
          tint: post.authorId == null
              ? BvAvatarTints.plain
              : BvAvatarTints.forId(post.authorId!),
        ),
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
        if (post.pointsTotal > 0)
          BvSlipChips(
            children: [
              BvSlipChip(
                icon: BvIcons.workItems,
                label: l10n.daybookPoints(post.pointsTotal),
              ),
            ],
          ),
        if (post.coverPath != null) _Cover(path: post.coverPath!),
        if (edited != null) BvSlipHistory(edited),
      ],
    );
  }
}

/// The post's first photo, 110 high, from the Space's private files.
class _Cover extends ConsumerWidget {
  const _Cover({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(workPhotoUrlProvider(path)).value;
    return BvSlipPhoto(
      height: BvSlipSpec.photoHeightCover,
      image: url == null ? null : NetworkImage(url),
    );
  }
}
