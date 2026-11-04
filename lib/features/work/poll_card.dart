import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../data/models/daybook.dart';
import '../../data/models/poll.dart';
import '../../data/repositories/space_repository.dart' show spacePeopleProvider;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_faces.dart';
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_stamp.dart';
import 'composer_poll.dart' show PollRing;
import '../spaces/former_member.dart' show personName;
import 'daybook_kinds.dart' show facesOf;
import 'daybook_words.dart';

/// Review 116 PL3: a decided poll's work item title, "question: answer",
/// without the question's own question mark before the colon.
String pollWorkItemTitle(
  AppLocalizations l10n,
  String question,
  String answer,
) => l10n.pollWorkItemTitle(
  question.trim().replaceFirst(RegExp(r'[?؟]+$'), '').trimRight(),
  answer.trim(),
);

/// Review 116 PL2 and PL3: a poll on its card. Open: each option with its
/// ring, a thin bar against the most chosen and the faces of who chose it
/// (never a percentage, rule 3); one tap chooses, another changes, the same
/// again takes it back; More than one toggles. Closes and "Not yet: …"
/// under them. Closed: DECIDED with the winner, TIED with "Tap the answer
/// that wins." for its creator, or "Closed with no answers"; who closed it;
/// Make it a work item.
class DaybookPollBody extends ConsumerStatefulWidget {
  const DaybookPollBody({
    super.key,
    required this.post,
    required this.words,
    required this.spaceId,
    required this.me,
    required this.now,
    this.onVote,
    this.onDecide,
    this.onWorkItem,
  });

  final DaybookPost post;
  final DaybookWords words;
  final String? spaceId;
  final String? me;
  final DateTime now;

  /// The reader's choices, all of them at once (vote_poll); null while the
  /// card is lifted or waiting.
  final ValueChanged<Set<String>>? onVote;

  /// A tie's winner, by its creator or a Space admin (decide_poll).
  final ValueChanged<String>? onDecide;

  /// Make it a work item, titled "question: answer"; its creator's or a
  /// Space admin's.
  final ValueChanged<String>? onWorkItem;

  @override
  ConsumerState<DaybookPollBody> createState() => _DaybookPollBodyState();
}

class _DaybookPollBodyState extends ConsumerState<DaybookPollBody> {
  /// What the reader chose here, shown at once until the server's card
  /// comes back.
  Set<String>? _chosen;

  @override
  void didUpdateWidget(DaybookPollBody old) {
    super.didUpdateWidget(old);
    if (!identical(old.post.poll, widget.post.poll)) _chosen = null;
  }

  DaybookPoll? get _poll {
    final poll = widget.post.poll;
    final chosen = _chosen;
    final me = widget.me;
    final spaceId = widget.spaceId;
    if (poll == null || chosen == null || me == null) return poll;
    final person = spaceId == null
        ? null
        : ref.read(spacePeopleProvider(spaceId)).value?.member(me)?.person;
    return poll.chosen(chosen, me: me, myName: person?.fullName);
  }

  void _tap(DaybookPoll poll, PollOption o) {
    final vote = widget.onVote;
    if (vote == null) return;
    final mine = poll.mine;
    final picked = poll.multi
        ? (mine.contains(o.id) ? ({...mine}..remove(o.id)) : {...mine, o.id})
        : (mine.contains(o.id) ? <String>{} : {o.id});
    // In the options' order, whatever order they were tapped in.
    final next = {
      for (final p in poll.options)
        if (picked.contains(p.id)) p.id,
    };
    setState(() => _chosen = next);
    vote(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final post = widget.post;
    final poll = _poll;
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final title = BvSlipTitle(post.title, cancelled: post.cancelled);
    if (poll == null) return title;
    final words = widget.words;
    final closed = poll.isClosed(widget.now);
    final decided = poll.decided;
    final pick = closed && poll.tied ? widget.onDecide : null;
    final most = poll.most;
    final closedAt = poll.closedAt ?? poll.closesAt;
    VoidCallback? onTap(PollOption o) {
      if (pick != null) return () => pick(o.id);
      if (closed || widget.onVote == null) return null;
      return () => _tap(poll, o);
    }

    return Column(
      key: Key('poll-${post.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        title,
        if (closed && decided != null)
          Row(
            key: const Key('poll-decided'),
            spacing: BvSpace.s8,
            children: [
              BvInkStamp(
                label: l10n.pollDecided,
                size: BvInkStampSize.sm,
                tone: BvInkStampTone.positive,
              ),
              Flexible(
                child: Text(
                  decided.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.emphasis.copyWith(color: BvColors.textPrimary),
                ),
              ),
            ],
          )
        else if (closed && poll.tied)
          Align(
            key: const Key('poll-tied'),
            alignment: AlignmentDirectional.centerStart,
            child: BvInkStamp(
              label: l10n.pollTied,
              size: BvInkStampSize.sm,
              tone: BvInkStampTone.muted,
            ),
          ),
        if (closed && !poll.voted)
          Text(l10n.pollNoAnswers, style: quiet)
        else
          for (final o in poll.options)
            _PollOptionRow(
              option: o,
              most: most,
              won: closed && o.id == poll.decidedOption,
              onTap: onTap(o),
            ),
        if (pick != null) Text(l10n.pollPickWinner, style: quiet),
        if (!closed && poll.notYet.isNotEmpty)
          Text(
            l10n.pollNotYet(
              poll.notYetMore > 0
                  ? l10n.pollNamesMore(
                      poll.notYet.join(l10n.daybookNamesComma),
                      poll.notYetMore,
                    )
                  : words.names(poll.notYet),
            ),
            key: const Key('poll-not-yet'),
            style: quiet,
          ),
        if (!closed && poll.closesAt != null)
          BvSlipFact(
            key: const Key('poll-closes'),
            icon: BvIcons.clock,
            text: l10n.pollCloses(words.pollWhen(poll.closesAt!, widget.now)),
          ),
        if (closed && closedAt != null)
          Text(
            poll.closedByName == null
                ? l10n.pollClosedAt(words.pollWhen(closedAt, widget.now))
                : l10n.pollClosedBy(
                    personName(l10n, poll.closedByName),
                    words.pollWhen(closedAt, widget.now),
                  ),
            key: const Key('poll-closed-by'),
            style: quiet,
          ),
        if (closed && decided != null && widget.onWorkItem != null)
          BvButton(
            key: const Key('poll-make-work-item'),
            label: l10n.pollMakeWorkItem,
            icon: BvIcons.workItems,
            style: BvButtonStyle.secondary,
            expand: true,
            onPressed: () => widget.onWorkItem!(
              pollWorkItemTitle(l10n, post.title, decided.label),
            ),
          ),
      ],
    );
  }
}

/// One option: its ring, its words, the faces of who chose it, and a thin
/// bar under them against the most chosen option.
class _PollOptionRow extends StatelessWidget {
  const _PollOptionRow({
    required this.option,
    required this.most,
    required this.won,
    this.onTap,
  });

  final PollOption option;
  final int most;
  final bool won;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final o = option;
    final share = most == 0 ? 0.0 : o.count / most;
    return Semantics(
      button: onTap != null,
      selected: o.mine,
      child: InkWell(
        key: Key('poll-option-${o.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(BvRadius.control),
        child: Container(
          decoration: BoxDecoration(
            color: BvColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(BvRadius.control),
            border: won
                ? Border.all(
                    color: BvColors.textPrimary,
                    width: BvSpace.borderWidth,
                  )
                : null,
          ),
          padding: const EdgeInsetsDirectional.all(BvSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BvSpace.s8,
            children: [
              Row(
                spacing: BvSpace.s8,
                children: [
                  if (o.mine)
                    PollRing(key: Key('poll-mine-${o.id}'), on: true)
                  else
                    const PollRing(),
                  Expanded(
                    child: Text(
                      o.label,
                      style: (o.mine ? type.emphasis : type.bodyMd).copyWith(
                        color: BvColors.textPrimary,
                      ),
                    ),
                  ),
                  if (o.voters.isNotEmpty) BvFaces(facesOf(l10n, o.voters)),
                ],
              ),
              ClipRRect(
                key: Key('poll-bar-${o.id}'),
                borderRadius: BorderRadius.circular(BvRadius.control),
                child: SizedBox(
                  height: BvSpace.s4,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: BvColors.borderSubtle),
                      ),
                      FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: share,
                        heightFactor: 1,
                        child: const ColoredBox(color: BvColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
