import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../data/models/note.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_daybook_masthead.dart';
import '../../shared/widgets/bv_day_divider.dart';
import '../../shared/widgets/bv_paper_clip.dart';
import '../account/account_parts.dart' show myMarketProvider;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../work/daybook_words.dart';
import 'notebook_state.dart';

/// The first day of [day]'s week, [weekStart] counted from Sunday (0) as
/// the market pack has it.
DateTime weekOf(DateTime day, int weekStart) {
  final d = dayOf(day);
  final index = d.weekday % DateTime.daysPerWeek;
  final back = (index - weekStart) % DateTime.daysPerWeek;
  return DateTime(d.year, d.month, d.day - back);
}

/// My calendar (CAL1 2557:35587, review 83): what my Spaces have for me
/// and my notebook's to-dos, a week at a time. The week starts on the
/// market pack's day (rule 5); swipe the strip for the week before or
/// after. Rows from the chosen day to the week's end, a divider per day.
/// Nothing counted (rule 3).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

int _byDayThenTime(CalendarRow a, CalendarRow b) {
  final day = a.day.compareTo(b.day);
  if (day != 0) return day;
  final at = a.startsAt;
  final bt = b.startsAt;
  if (at == null || bt == null)
    return (at == null ? 0 : 1) - (bt == null ? 0 : 1);
  return at.compareTo(bt);
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime? _chosen;

  int get _weekStart =>
      ref.read(myMarketProvider)?.weekStart ??
      MaterialLocalizations.of(context).firstDayOfWeekIndex;

  void _turn(int weeks) {
    final from = _chosen ?? dayOf(ref.read(clockProvider)());
    setState(
      () => _chosen = weekOf(
        DateTime(from.year, from.month, from.day + weeks * 7),
        _weekStart,
      ),
    );
  }

  void _open(CalendarRow row) {
    if (row.kind == CalendarKind.todo) {
      context.pop();
      return;
    }
    final space = row.spaceId;
    final post = row.postId;
    if (space == null || post == null) return;
    context.push(AppRoutes.spaceCard(space, post));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final today = dayOf(ref.watch(clockProvider)());
    final chosen = _chosen ?? today;
    final start = weekOf(chosen, _weekStart);
    final days = [
      for (var i = 0; i < DateTime.daysPerWeek; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    final week = ref.watch(calendarProvider((from: days.first, to: days.last)));
    final rows = week.value ?? const <CalendarRow>[];
    final busy = {for (final r in rows) r.day};
    // By day; on a day, all-day rows first (CAL1), then by time. The
    // server sends them by time, all-day ones last.
    final shown = [
      for (final r in rows)
        if (!r.day.isBefore(chosen)) r,
    ]..sort(_byDayThenTime);
    final byDay = <DateTime, List<CalendarRow>>{};
    for (final r in shown) {
      byDay.putIfAbsent(r.day, () => []).add(r);
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(
        backgroundColor: BvColors.surfaceApp,
        title: Text(l10n.calendarTitle),
      ),
      body: ListView(
        key: const Key('calendar-list'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s24),
        children: [
          BvDaybookMasthead(
            weekday: words.month(chosen),
            date: words.year(chosen),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.gutter,
            ),
            child: Text(
              l10n.calendarSubtitle,
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
          ),
          // The week strip: swipe for the week before or after.
          Semantics(
            customSemanticsActions: {
              CustomSemanticsAction(label: l10n.calendarWeekBefore): () =>
                  _turn(-1),
              CustomSemanticsAction(label: l10n.calendarWeekAfter): () =>
                  _turn(1),
            },
            child: GestureDetector(
              key: const Key('calendar-week'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v.abs() < BvCalendarSpec.swipe) return;
                // Towards the start of the line: the next week.
                final next = rtl ? v > 0 : v < 0;
                _turn(next ? 1 : -1);
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: BvSpace.s8,
                  vertical: BvCalendarSpec.stripPadding,
                ),
                child: Row(
                  children: [
                    for (final d in days)
                      Expanded(
                        child: _Day(
                          day: d,
                          words: words,
                          chosen: d == chosen,
                          busy: busy.contains(d),
                          onTap: () => setState(() => _chosen = d),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (week.hasError && rows.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: EmptyNote(l10n.calendarCouldntLoad),
            )
          else if (week.hasValue && shown.isEmpty)
            Padding(
              key: const Key('calendar-empty'),
              padding: const EdgeInsetsDirectional.all(BvSpace.s32),
              child: Column(
                spacing: BvSpace.s8,
                children: [
                  const Icon(
                    BvIcons.calendar,
                    size: BvNotebookSpec.emptyIcon,
                    color: BvColors.iconSecondary,
                  ),
                  Text(
                    l10n.calendarEmpty,
                    textAlign: TextAlign.center,
                    style: type.titleMd.copyWith(color: BvColors.textPrimary),
                  ),
                  Text(
                    l10n.calendarEmptyBody,
                    textAlign: TextAlign.center,
                    style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            for (final day in byDay.keys) ...[
              if (day != chosen)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: BvSpace.s4,
                  ),
                  child: BvDayDivider(label: words.weekdayDay(day)),
                ),
              for (final r in byDay[day]!)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    BvSpace.gutter,
                    0,
                    BvSpace.gutter,
                    BvCalendarSpec.rowGap,
                  ),
                  child: CalendarRowTile(
                    row: r,
                    words: words,
                    today: today,
                    onTap: () => _open(r),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

/// A day in the week strip: the weekday over its number, a dot when
/// something falls on it; the chosen day on the orange pill.
class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.words,
    required this.chosen,
    required this.busy,
    required this.onTap,
  });

  final DateTime day;
  final DaybookWords words;
  final bool chosen;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final ink = chosen ? BvColors.textInverse : BvColors.textPrimary;
    return Semantics(
      selected: chosen,
      button: true,
      child: InkWell(
        key: Key('calendar-day-${day.month}-${day.day}'),
        borderRadius: const BorderRadius.all(
          Radius.circular(BvCalendarSpec.dayRadius),
        ),
        onTap: onTap,
        child: Center(
          child: Container(
            width: BvCalendarSpec.dayPill,
            height: BvCalendarSpec.dayHeight,
            decoration: chosen
                ? const BoxDecoration(
                    color: BvColors.actionPrimary,
                    borderRadius: BorderRadius.all(
                      Radius.circular(BvCalendarSpec.dayRadius),
                    ),
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  words.shortWeekday(day),
                  maxLines: 1,
                  style: type.metadata.copyWith(
                    color: chosen ? ink : BvColors.textSecondary,
                  ),
                ),
                Text(
                  words.dayNumber(day),
                  maxLines: 1,
                  style: type.titleLg.copyWith(color: ink),
                ),
                const SizedBox(height: BvCalendarSpec.dotGap),
                Container(
                  width: BvCalendarSpec.dot,
                  height: BvCalendarSpec.dot,
                  decoration: BoxDecoration(
                    color: busy
                        ? (chosen
                              ? BvColors.textInverse
                              : BvColors.textSecondary)
                        : null,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of My calendar (2557:35588): the Space's colour bar (the
/// notebook's slate for a to-do), the time or All day, what it is in the
/// action colour, the title, the Space and place or My notebook, and the
/// paper clip when it waits on me.
class CalendarRowTile extends StatelessWidget {
  const CalendarRowTile({
    super.key,
    required this.row,
    required this.words,
    required this.today,
    required this.onTap,
  });

  final CalendarRow row;
  final DaybookWords words;
  final DateTime today;
  final VoidCallback onTap;

  String _label(AppLocalizations l10n) => switch (row.kind) {
    CalendarKind.todo => l10n.notebookTodo,
    CalendarKind.activity => l10n.calendarScheduled,
    CalendarKind.workItem when row.done => l10n.calendarToCheck,
    CalendarKind.workItem when row.needsMe => l10n.calendarDueForYou,
    _ => row.day == today ? l10n.calendarDueToday : l10n.calendarDue,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final starts = row.startsAt;
    // A to-do saved with a day only reads as all day.
    final allDay =
        starts == null ||
        (row.kind == CalendarKind.todo && starts == dayOf(starts));
    final colour = row.spaceId == null
        ? BvCalendarSpec.notebookColor
        : BvProjectColors.forId(row.spaceId!);
    final where = row.kind == CalendarKind.todo
        ? l10n.notebookTitle
        : [
            if (row.spaceName != null) inOwnDirection(row.spaceName!),
            if ((row.place ?? '').isNotEmpty) inOwnDirection(row.place!),
          ].join(' · ');
    final struck = row.kind == CalendarKind.todo && row.done;
    return Material(
      key: Key('calendar-row-${row.postId ?? row.noteId}'),
      color: BvColors.surfaceElevated,
      borderRadius: const BorderRadius.all(
        Radius.circular(BvCalendarSpec.rowRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvCalendarSpec.rowPadding),
          child: Row(
            spacing: BvCalendarSpec.columnGap,
            children: [
              Container(
                width: BvCalendarSpec.bar,
                height: BvCalendarSpec.barHeight,
                decoration: BoxDecoration(
                  color: colour,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(BvCalendarSpec.barRadius),
                  ),
                ),
              ),
              SizedBox(
                width: BvCalendarSpec.timeWidth,
                child: Text(
                  allDay ? l10n.calendarAllDay : words.time.clock(starts),
                  key: const Key('calendar-row-time'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(l10n),
                      style: type.metadata.copyWith(color: BvColors.textAction),
                    ),
                    Text(
                      row.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodyMd.copyWith(
                        color: struck
                            ? BvColors.textSecondary
                            : BvColors.textPrimary,
                        decoration: struck ? TextDecoration.lineThrough : null,
                        decorationColor: BvColors.textSecondary,
                      ),
                    ),
                    if (where.isNotEmpty)
                      Text(
                        where,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (row.needsMe)
                const SizedBox(
                  key: Key('calendar-row-clip'),
                  width: BvCalendarSpec.clipWidth,
                  child: BvPaperClip.row(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
