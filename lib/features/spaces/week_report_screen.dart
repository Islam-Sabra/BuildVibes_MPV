import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/meeting_report_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/chat.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../data/models/space.dart';
import '../../data/models/week_report.dart';
import '../../data/repositories/chat_repository.dart' show spaceThreadsProvider;
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/week_report_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_calendar_leaf.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_torn_edge.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../account/account_parts.dart' show myMarketProvider;
import '../chat/chat_state.dart' show threadMessagesProvider;
import '../chat/chat_tab.dart' show threadName;
import '../notebook/calendar_screen.dart' show weekOf;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../work/daybook_photos.dart' show daybookPhotoProvider;
import '../work/daybook_words.dart';
import '../work/daybook_writing.dart' show newPostIdProvider;
import 'space_errors.dart';

/// A Space's week report from a week's first day, read again when the
/// week turns.
final weekReportProvider = FutureProvider.autoDispose
    .family<WeekReport, ({String spaceId, DateTime from, DateTime today})>(
      (ref, w) => ref
          .watch(weekReportRepositoryProvider)
          .weekReport(
            w.spaceId,
            from: w.from,
            to: DateTime(w.from.year, w.from.month, w.from.day + 6),
            today: w.today,
          ),
    );

/// The week of [day], from the market pack's first day (rule 5).
DateTime reportWeekOf(WidgetRef ref, BuildContext context, DateTime day) =>
    weekOf(
      day,
      ref.read(myMarketProvider)?.weekStart ??
          MaterialLocalizations.of(context).firstDayOfWeekIndex,
    );

/// "11 – 17 October", "28 September – 4 October": a week's days.
String weekRange(AppLocalizations l10n, DaybookWords words, DateTime from) {
  final to = DateTime(from.year, from.month, from.day + 6);
  return l10n.weekReportRange(
    from.month == to.month ? words.dayNumber(from) : words.dayMonth(from),
    words.dayMonth(to),
  );
}

/// MR1 (2566:35515, review 85): the week's work as the daybook holds it,
/// for every member, each seeing only what they may read. Four sections
/// on paper, each left out when empty: Needs a decision, Checked this
/// week, Targets, and Coming up (this week only: the server counts it
/// from now). ‹ and › turn the week; › stops at this week. Share in chat
/// sends the week to a chat thread. Names on rows, never totals (rule 3).
class WeekReportScreen extends ConsumerStatefulWidget {
  const WeekReportScreen({super.key, required this.spaceId, this.week});

  final String spaceId;

  /// A day in the week to open (a shared report's); this week when null.
  final DateTime? week;

  @override
  ConsumerState<WeekReportScreen> createState() => _WeekReportState();
}

class _WeekReportState extends ConsumerState<WeekReportScreen> {
  DateTime? _from;

  DaybookWords _words() => DaybookWords(
    AppLocalizations.of(context),
    Localizations.localeOf(context).toLanguageTag(),
    use24: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  void _open(String postId) =>
      context.push(AppRoutes.spaceCard(widget.spaceId, postId));

  /// Share in chat: the Space's threads I can write in, Everyone first.
  Future<void> _share(DateTime from) async {
    final l10n = AppLocalizations.of(context);
    List<ChatThread> threads;
    try {
      threads = await ref.read(spaceThreadsProvider(widget.spaceId).future);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    if (!mounted) return;
    final picked = await showBvSheet<ChatThread>(
      context: context,
      title: l10n.weekReportShareWhere,
      builder: (sheet) => ClipRRect(
        key: const Key('week-share-threads'),
        borderRadius: BvRadius.cardAll,
        child: BvListGroup(
          rows: [
            for (final t in [
              ...threads.where((t) => t.isEveryone),
              ...threads.where((t) => !t.isEveryone),
            ])
              BvListRow(
                key: Key('week-share-${t.id}'),
                title: threadName(l10n, t),
                leading: const Icon(BvIcons.chat, color: BvColors.iconPrimary),
                onTap: () => Navigator.of(sheet).pop(t),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await ref
          .read(weekReportRepositoryProvider)
          .share(
            id: ref.read(newPostIdProvider)(),
            threadId: picked.id,
            weekStart: from,
          );
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    if (!mounted) return;
    // The thread shows it at once when it opens.
    ref.invalidate(threadMessagesProvider(picked.id));
    showSpaceMessage(
      context,
      l10n.weekReportShared(inOwnDirection(threadName(l10n, picked))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = _words();
    final today = dayOf(ref.watch(clockProvider)());
    final thisWeek = reportWeekOf(ref, context, today);
    final from =
        _from ??
        (widget.week == null
            ? thisWeek
            : reportWeekOf(ref, context, widget.week!));
    final space = ref.watch(spaceDetailProvider(widget.spaceId)).value;
    final report = ref.watch(
      weekReportProvider((spaceId: widget.spaceId, from: from, today: today)),
    );
    final current = !from.isBefore(thisWeek);
    void turn(int weeks) => setState(
      () => _from = DateTime(from.year, from.month, from.day + 7 * weeks),
    );

    final value = report.value;
    final comingUp = current ? value?.comingUp ?? const [] : const [];

    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(
        backgroundColor: BvColors.surfaceApp,
        title: Text(l10n.weekReportTitle),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: BvSpace.s12),
            child: _SharePill(onTap: () => _share(from)),
          ),
        ],
      ),
      body: ListView(
        key: const Key('week-list'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          BvSpace.gutter,
          0,
          BvSpace.gutter,
          BvSpace.s32,
        ),
        children: [
          Row(
            spacing: BvWeekReportSpec.arrowGap,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weekRange(l10n, words, from),
                      key: const Key('week-range'),
                      style: type.titleLg.copyWith(color: BvColors.textPrimary),
                    ),
                    if (space != null)
                      Text(
                        space.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              _Arrow(
                key: const Key('week-before'),
                label: l10n.calendarWeekBefore,
                icon: BvIcons.caretBack,
                onTap: () => turn(-1),
              ),
              _Arrow(
                key: const Key('week-after'),
                label: l10n.calendarWeekAfter,
                icon: BvIcons.caretForward,
                onTap: current ? null : () => turn(1),
              ),
            ],
          ),
          const SizedBox(height: BvWeekReportSpec.sectionGap),
          if (report.hasError && value == null)
            EmptyNote(l10n.weekCouldntLoad)
          else if (value != null) ...[
            if (value.isEmpty ||
                (value.needsDecision.isEmpty &&
                    value.checked.isEmpty &&
                    value.targets.isEmpty &&
                    comingUp.isEmpty))
              Padding(
                key: const Key('week-empty'),
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: BvSpace.s24,
                ),
                child: Text(
                  l10n.weekEmpty,
                  textAlign: TextAlign.center,
                  style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                ),
              ),
            if (value.needsDecision.isNotEmpty)
              _Section(
                key: const Key('week-needs'),
                title: l10n.weekNeedsDecision,
                child: BvSlip(
                  clip: value.needsDecision.any((r) => r.needsMe),
                  paddingTop: BvSpace.s8,
                  paddingBottom: BvSpace.s4,
                  children: [
                    for (final (i, r) in value.needsDecision.indexed) ...[
                      if (i > 0) const Divider(height: BvSpace.borderWidth),
                      _DecisionLine(
                        row: r,
                        words: words,
                        today: today,
                        onTap: () => _open(r.postId),
                      ),
                    ],
                  ],
                ),
              ),
            if (value.checked.isNotEmpty)
              _Section(
                key: const Key('week-checked'),
                title: l10n.weekChecked,
                child: SizedBox(
                  height: BvWeekReportSpec.proofHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: value.checked.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: BvWeekReportSpec.proofGap),
                    itemBuilder: (context, i) {
                      final r = value.checked[i];
                      return SizedBox(
                        width: BvWeekReportSpec.proofWidth,
                        child: _Proof(
                          row: r,
                          words: words,
                          onTap: () => _open(r.postId),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (value.targets.isNotEmpty)
              _Section(
                key: const Key('week-targets'),
                title: l10n.weekTargets,
                child: BvSlip(
                  paddingTop: BvSpace.s8,
                  paddingBottom: BvSpace.s4,
                  children: [
                    for (final (i, r) in value.targets.indexed) ...[
                      if (i > 0) const Divider(height: BvSpace.borderWidth),
                      _TargetLine(
                        row: r,
                        words: words,
                        today: today,
                        onTap: () => _open(r.postId),
                      ),
                    ],
                  ],
                ),
              ),
            if (comingUp.isNotEmpty)
              _Section(
                key: const Key('week-coming'),
                title: l10n.weekComingUp,
                child: BvSlip(
                  paddingTop: BvSpace.s8,
                  paddingBottom: BvSpace.s4,
                  children: [
                    for (final (i, r) in comingUp.indexed) ...[
                      if (i > 0) const Divider(height: BvSpace.borderWidth),
                      _ComingLine(
                        row: r,
                        words: words,
                        today: today,
                        onTap: () => _open(r.postId),
                      ),
                    ],
                  ],
                ),
              ),
            Text(
              l10n.weekFoot,
              key: const Key('week-foot'),
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
          ] else
            const Padding(
              padding: EdgeInsetsDirectional.all(BvSpace.s32),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

/// MR1's Share in chat (2566:35527): a brand-soft pill with the chat icon.
class _SharePill extends StatelessWidget {
  const _SharePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Material(
      key: const Key('week-share'),
      color: BvColors.surfaceBrandSoft,
      borderRadius: BvRadius.roundAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: BvWeekReportSpec.pillHeight,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvWeekReportSpec.pillPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvSpace.s6,
            children: [
              const Icon(
                BvIcons.chat,
                size: BvWeekReportSpec.pillIcon,
                color: BvColors.textAction,
              ),
              Text(
                l10n.weekReportShare,
                style: type.labelSm.copyWith(color: BvColors.textAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ‹ or ›, a 36 round button; off when there is no week that way.
class _Arrow extends StatelessWidget {
  const _Arrow({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: onTap == null ? BvColors.surfaceApp : BvColors.surfaceSubtle,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: BvWeekReportSpec.arrow,
          child: Icon(
            icon,
            size: BvWeekReportSpec.arrowIcon,
            color: onTap == null
                ? BvColors.actionDisabled
                : BvColors.iconPrimary,
          ),
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(
      bottom: BvWeekReportSpec.sectionGap,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvWeekReportSpec.headingGap,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: BvType.of(
              context,
            ).titleMd.copyWith(color: BvColors.textPrimary),
          ),
        ),
        child,
      ],
    ),
  );
}

/// A row of Needs a decision (2566:35551): the title, who and why, and
/// the LATE, SENT BACK or DONE stamp.
class _DecisionLine extends StatelessWidget {
  const _DecisionLine({
    required this.row,
    required this.words,
    required this.today,
    required this.onTap,
  });

  final DecisionRow row;
  final DaybookWords words;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = words.l10n;
    final type = BvType.of(context);
    final why = switch (row.state) {
      DecisionState.late => l10n.weekLateBy(
        row.dueDate == null ? 0 : today.difference(row.dueDate!).inDays,
      ),
      DecisionState.sentBack => words.reason(row.reason),
      DecisionState.done => l10n.weekSignedDone(
        row.doneAt == null
            ? ''
            : '${words.shortWeekday(row.doneAt!)} ${words.time.clock(row.doneAt!)}',
      ),
    };
    final (stamp, tone) = switch (row.state) {
      DecisionState.late => (l10n.weekStampLate, BvInkStampTone.destructive),
      DecisionState.sentBack => (
        l10n.daybookStampSentBack,
        BvInkStampTone.destructive,
      ),
      DecisionState.done => (l10n.daybookStampDone, BvInkStampTone.action),
    };
    return InkWell(
      key: Key('week-decision-${row.postId}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: BvWeekReportSpec.rowPadding,
        ),
        child: Row(
          spacing: BvWeekReportSpec.stampGap,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                  ),
                  Text(
                    [
                      if (row.ownerName != null) inOwnDirection(row.ownerName!),
                      why,
                    ].join(' · '),
                    style: type.metadata.copyWith(
                      color: row.state == DecisionState.late
                          ? BvColors.textDestructive
                          : BvColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            BvInkStamp(
              key: Key('week-stamp-${row.state.json}'),
              label: stamp,
              size: BvInkStampSize.xs,
              tone: tone,
            ),
          ],
        ),
      ),
    );
  }
}

/// A proof card in Checked this week (2566:35571): the Done photo with
/// its CHECKED stamp, the title, and the day and who checked, on paper.
class _Proof extends ConsumerWidget {
  const _Proof({required this.row, required this.words, required this.onTap});

  final CheckedRow row;
  final DaybookWords words;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = BvType.of(context);
    final path = row.photoPath;
    final photo = path == null ? null : ref.watch(daybookPhotoProvider(path));
    final shape = BvSlipBorder.forId(
      row.postId,
      edgeHeight: BvSlipBorder.edgeHeightProof,
    );
    return DecoratedBox(
      key: Key('week-proof-${row.postId}'),
      decoration: ShapeDecoration(
        color: BvColors.surfaceElevated,
        shape: shape,
        shadows: BvShadow.proof,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvWeekReportSpec.proofPadding,
              BvWeekReportSpec.proofPaddingTop,
              BvWeekReportSpec.proofPadding,
              BvWeekReportSpec.proofPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvSpace.s6,
              children: [
                SizedBox(
                  height: BvWeekReportSpec.proofPhoto,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(BvRadius.photo),
                          ),
                          child: ColoredBox(
                            color: BvColors.surfaceSubtle,
                            child: photo == null
                                ? null
                                : Image(
                                    image: photo,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        end: BvSpace.s8,
                        bottom: BvSpace.s8,
                        child: BvInkStamp(
                          label: words.l10n.daybookStampChecked,
                          size: BvInkStampSize.xs,
                          tone: BvInkStampTone.positive,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  row.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                ),
                Text(
                  [
                    words.shortWeekday(row.checkedAt),
                    if (row.checkerName != null)
                      inOwnDirection(row.checkerName!),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A target (2566:35593): the title, the green progress line and "2 of 4
/// checked · by Sun 18 Oct". Its own progress, not a quality signal.
class _TargetLine extends StatelessWidget {
  const _TargetLine({
    required this.row,
    required this.words,
    required this.today,
    required this.onTap,
  });

  final TargetRow row;
  final DaybookWords words;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final share = row.total == 0 ? 0.0 : row.checked / row.total;
    final due = row.dueDate;
    return InkWell(
      key: Key('week-target-${row.postId}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: BvWeekReportSpec.rowPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BvSpace.s8,
          children: [
            Text(
              row.title,
              style: type.bodyMd.copyWith(color: BvColors.textPrimary),
            ),
            ClipRRect(
              borderRadius: BvRadius.roundAll,
              child: LinearProgressIndicator(
                value: share,
                minHeight: BvWeekReportSpec.progress,
                color: BvColors.feedbackSuccess,
                backgroundColor: BvColors.borderDefault,
              ),
            ),
            Text(
              [
                words.l10n.pageUnderChecked(row.checked, row.total),
                if (due != null)
                  words.due(
                    due,
                    row.dueAt,
                    now: today,
                    late: due.isBefore(today),
                  ),
              ].join(' · '),
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coming up (2566:35602): the calendar leaf, the title, and an
/// activity's time and place, or a work item's due and owner.
class _ComingLine extends StatelessWidget {
  const _ComingLine({
    required this.row,
    required this.words,
    required this.today,
    required this.onTap,
  });

  final ComingRow row;
  final DaybookWords words;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final day = row.day ?? today;
    final leaf = words.leaf(day);
    final line = row.activity
        ? [
            if (row.startsAt != null) words.time.clock(row.startsAt!),
            if ((row.place ?? '').isNotEmpty) inOwnDirection(row.place!),
          ]
        : [
            words.due(day, row.dueAt, now: today, late: false),
            if (row.ownerName != null) inOwnDirection(row.ownerName!),
          ];
    return InkWell(
      key: Key('week-coming-${row.postId}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: BvWeekReportSpec.rowPadding,
        ),
        child: Row(
          spacing: BvSpace.s12,
          children: [
            BvCalendarLeaf(
              weekday: leaf.weekday,
              day: leaf.day,
              month: leaf.month,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                  ),
                  Text(
                    line.join(' · '),
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

/// A week report shared in the chat: "Week report · 11 – 17 October" and
/// Open, which opens it with the reader's own rights.
class WeekReportBubble extends StatelessWidget {
  const WeekReportBubble({
    super.key,
    required this.spaceId,
    required this.week,
  });

  final String spaceId;
  final DateTime week;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return Material(
      key: const Key('chat-week-report'),
      color: BvColors.surfaceElevated,
      borderRadius: BvRadius.cardAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.spaceWeekReport(spaceId, week: week)),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.s12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvSpace.s12,
            children: [
              const Icon(BvIcons.month, color: BvColors.iconAction),
              Flexible(
                child: Text(
                  l10n.weekReportCard(weekRange(l10n, words, week)),
                  style: type.labelMd.copyWith(color: BvColors.textPrimary),
                ),
              ),
              Text(
                l10n.libraryOpen,
                style: type.labelMd.copyWith(color: BvColors.textAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
