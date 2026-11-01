import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/check_in.dart';
import '../../data/models/daybook.dart';
import '../../data/repositories/space_repository.dart' show spaceDetailProvider;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_slip.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'check_in_marking.dart';
import 'check_in_words.dart';
import 'composer_check_in.dart' show checkInClock;
import 'daybook_words.dart';

/// A check-in stamp (CI4, CI5): its words on a soft green, amber or grey
/// label, with its icon: ✓ on time and on site, a clock when late, the
/// map pin when not at site, (i) when the location wasn't shared.
class CheckInStamp extends StatelessWidget {
  const CheckInStamp({
    super.key,
    required this.text,
    required this.tone,
    required this.icon,
  });

  /// A mark's stamp.
  factory CheckInStamp.of(String text, CheckInMark mark, {Key? key}) =>
      CheckInStamp(
        key: key,
        text: text,
        tone: mark.tone,
        icon: switch (mark) {
          CheckInMark(onTime: false) => BvIcons.clock,
          CheckInMark(place: CheckInPlace.away) => BvIcons.place,
          CheckInMark(place: CheckInPlace.notShared) => BvIcons.info,
          _ => BvIcons.check,
        },
      );

  /// Missed (grey).
  factory CheckInStamp.missed(AppLocalizations l10n, {Key? key}) =>
      CheckInStamp(
        key: key,
        text: l10n.checkInMissed,
        tone: CheckInTone.quiet,
        icon: BvIcons.info,
      );

  final String text;
  final CheckInTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final (ground, ink) = switch (tone) {
      CheckInTone.good => (BvColors.surfacePositiveSoft, BvColors.textPositive),
      CheckInTone.warn => (BvColors.surfaceWarningSoft, BvColors.textWarning),
      CheckInTone.quiet => (BvColors.surfaceSubtle, BvColors.textSecondary),
    };
    return Container(
      padding: BvCheckInSpec.stampPadding,
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BvCheckInSpec.stampRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BvCheckInSpec.stampGap,
        children: [
          Icon(icon, size: BvCheckInSpec.stampIcon, color: ink),
          Flexible(
            child: Text(
              text,
              style: BvType.of(context).emphasisSm.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Review 109 CI4 (2706:39534): a Check-in on its card. The kind in the
/// action colour with Every day or Once; the title; its times; then only
/// the reader's own stamps, and what they may do now: Check in (by its
/// on-time limit), Try again while not at site and still open, Check out
/// (off until its time). Its creator gets their list (CI5).
class DaybookCheckInBody extends ConsumerStatefulWidget {
  const DaybookCheckInBody({
    super.key,
    required this.post,
    required this.words,
    this.spaceId,
    this.lifted = false,
  });

  final DaybookPost post;
  final DaybookWords words;
  final String? spaceId;

  /// Drawn only (lifted, waiting to send, or for a Viewer): no buttons.
  final bool lifted;

  @override
  ConsumerState<DaybookCheckInBody> createState() => _DaybookCheckInBodyState();
}

class _DaybookCheckInBodyState extends ConsumerState<DaybookCheckInBody> {
  var _busy = false;

  Future<void> _mark(CheckInMarkKind kind) async {
    setState(() => _busy = true);
    await checkInFromCard(
      context,
      ref,
      postId: widget.post.id,
      spaceId: widget.spaceId,
      kind: kind,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final post = widget.post;
    final c = post.checkIn;
    final words = widget.words;
    final spaceId = widget.spaceId;
    final zone = spaceId == null
        ? null
        : ref.watch(spaceDetailProvider(spaceId)).value?.timeZone;
    String at(DateTime t) => checkInTimeOf(words.time, zone, t);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final now = ref.watch(clockProvider)();
    final step = c?.stepAt(now);
    final today = c?.today;
    final lifted = widget.lifted || _busy;
    final repeat = c == null
        ? null
        : c.stopped
        ? l10n.checkInStopped
        : c.daily
        ? l10n.checkInEveryDay
        : l10n.checkInOnce;
    Widget? action;
    if (c != null && step != null && today != null) {
      action = switch (step.action) {
        CheckInAction.checkIn => BvButton(
          key: Key('check-in-${post.id}'),
          label: l10n.checkInBy(at(today.inUntil)),
          icon: BvIcons.place,
          expand: true,
          onPressed: lifted
              ? null
              : () => unawaited(_mark(CheckInMarkKind.checkIn)),
        ),
        CheckInAction.inSoon => BvButton(
          key: Key('check-in-${post.id}'),
          label: l10n.checkInFrom(at(today.inOpensAt)),
          expand: true,
          onPressed: null,
        ),
        CheckInAction.checkOut => BvButton(
          key: Key('check-out-${post.id}'),
          label: l10n.checkOutButton,
          icon: BvIcons.checkOut,
          expand: true,
          onPressed: lifted
              ? null
              : () => unawaited(_mark(CheckInMarkKind.checkOut)),
        ),
        CheckInAction.outSoon => BvButton(
          key: Key('check-out-${post.id}'),
          label: l10n.checkOutFrom(at(today.outOpensAt!)),
          expand: true,
          onPressed: null,
        ),
        CheckInAction.none => null,
      };
    }
    final myIn = c?.myIn;
    final myOut = c?.myOut;
    return Column(
      key: Key('check-in-card-${post.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvCheckInSpec.gap,
      children: [
        Row(
          spacing: BvSpace.s6,
          children: [
            const Icon(
              BvIcons.place,
              size: BvCheckInSpec.stampIcon,
              color: BvColors.iconAction,
            ),
            Expanded(
              child: Text(
                l10n.daybookKindCheckIn,
                style: type.emphasisSm.copyWith(color: BvColors.textAction),
              ),
            ),
            if (repeat != null)
              Text(
                repeat,
                key: Key('check-in-repeat-${post.id}'),
                style: quiet,
              ),
          ],
        ),
        BvSlipTitle(
          post.title,
          cancelled: post.cancelled,
          maxLines: BvShortCardSpec.titleLines,
        ),
        if (c != null)
          BvSlipFact(
            icon: BvIcons.clock,
            text: c.outTime == null
                ? l10n.checkInTimesIn(checkInClock(words, c.inTime))
                : l10n.checkInTimes(
                    checkInClock(words, c.inTime),
                    checkInClock(words, c.outTime!),
                  ),
          ),
        if ((post.body ?? '').isNotEmpty)
          BvSlipNote(post.body!, maxLines: BvShortCardSpec.detailLines),
        if (myIn != null || myOut != null || (step?.missed ?? false))
          Wrap(
            spacing: BvSpace.s6,
            runSpacing: BvSpace.s6,
            children: [
              if (myIn != null)
                CheckInStamp.of(
                  checkInStampText(
                    l10n,
                    words.time,
                    zone,
                    myIn,
                    CheckInMarkKind.checkIn,
                  ),
                  myIn,
                  key: Key('check-in-stamp-in-${post.id}'),
                ),
              if (myOut != null)
                CheckInStamp.of(
                  checkInStampText(
                    l10n,
                    words.time,
                    zone,
                    myOut,
                    CheckInMarkKind.checkOut,
                  ),
                  myOut,
                  key: Key('check-in-stamp-out-${post.id}'),
                ),
              if (step?.missed ?? false)
                CheckInStamp.missed(
                  l10n,
                  key: Key('check-in-missed-${post.id}'),
                ),
            ],
          ),
        if (c != null && c.asked && today != null && !today.runs && !c.stopped)
          Text(l10n.checkInNotToday, style: quiet),
        if (step?.tryAgain ?? false)
          BvButton(
            key: Key('check-in-again-${post.id}'),
            label: l10n.checkInTryAgain,
            icon: BvIcons.place,
            style: BvButtonStyle.secondary,
            expand: true,
            onPressed: lifted
                ? null
                : () => unawaited(_mark(CheckInMarkKind.checkIn)),
          ),
        ?action,
        if (c != null && c.seesList && spaceId != null)
          BvButton(
            key: Key('check-in-list-${post.id}'),
            label: l10n.checkInSeeList,
            icon: BvIcons.people,
            style: BvButtonStyle.tertiary,
            expand: true,
            onPressed: widget.lifted
                ? null
                : () => unawaited(
                    context.push(AppRoutes.spaceCheckIn(spaceId, post.id)),
                  ),
          ),
      ],
    );
  }
}
