import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/location/location_reader.dart';
import '../../data/models/check_in.dart';
import '../../data/models/space.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_segmented.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_time_picker.dart';
import '../../shared/widgets/bv_writing_rows.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/space_errors.dart' show showSpaceMessage;
import 'daybook_draft.dart';
import 'daybook_words.dart';
import 'daybook_writing.dart' show DaybookWriter;

/// Review 109 CI1: what a Check-in's lines open.
enum CheckInPick { teams, time, place }

/// [t] as the app writes a time ("7:00").
String checkInClock(DaybookWords words, DayTime t) =>
    words.time.clock(DateTime(2000, 1, 1, t.hour, t.minute));

/// "Steel fixers + Formwork", or the whole Space.
String checkInTeamsLine(
  AppLocalizations l10n,
  List<({String id, String name})> teams,
) {
  if (teams.isEmpty) return l10n.daybookWholeSpace;
  return teams
      .skip(1)
      .fold(teams.first.name, (line, t) => l10n.checkInTeamsJoin(line, t.name));
}

/// The Set place here reading, while it runs, per Space.
final checkInPlaceReadingProvider = NotifierProvider.autoDispose
    .family<CheckInPlaceReading, bool, String>(CheckInPlaceReading.new);

class CheckInPlaceReading extends Notifier<bool> {
  CheckInPlaceReading(this.spaceId);

  final String spaceId;

  @override
  bool build() => false;

  void set(bool on) => state = on;
}

/// A Check-in's lines (CI1): For (Teams or the whole Space; Viewers are
/// never asked), Check-in (its time and allowance) and Place (Set place
/// here). Send stays off until the place is set.
List<BvWritingRow> checkInLines(
  AppLocalizations l10n,
  DaybookWords words,
  DaybookPostDraft draft, {
  required bool reading,
  required Object? ask,
  required ValueChanged<CheckInPick> onPick,
}) {
  final time = draft.inTime;
  return [
    BvWritingRow(
      key: const Key('writing-check-in-for'),
      label: l10n.checkInFor,
      value: checkInTeamsLine(l10n, draft.checkInTeams),
      icon: draft.checkInTeams.isEmpty ? BvIcons.people : BvIcons.team,
      onTap: () => onPick(CheckInPick.teams),
    ),
    BvWritingRow(
      key: const Key('writing-check-in-time'),
      label: l10n.checkInRowIn,
      value: time == null
          ? l10n.daybookRowChoose
          : l10n.checkInTimeAllow(checkInClock(words, time), draft.inAllow),
      icon: time == null ? null : BvIcons.clock,
      empty: time == null,
      ask: ask,
      onTap: () => onPick(CheckInPick.time),
    ),
    BvWritingRow(
      key: const Key('writing-check-in-place'),
      label: l10n.checkInRowPlace,
      value: reading
          ? l10n.checkInReading
          : draft.siteSet
          ? l10n.checkInPlaceSet
          : l10n.checkInSetPlace,
      icon: draft.siteSet ? BvIcons.check : BvIcons.place,
      call: !draft.siteSet,
      onTap: reading ? null : () => onPick(CheckInPick.place),
    ),
  ];
}

/// What + added to a Check-in (CI1): Check-out and Every day, each a chip
/// with ×.
List<({Key key, Key clearKey, IconData icon, String label, CheckInChip chip})>
checkInChips(AppLocalizations l10n, DaybookWords words, DaybookPostDraft d) => [
  if (d.outTime case final out?)
    (
      key: const Key('writing-check-out-chip'),
      clearKey: const Key('writing-check-out-chip-clear'),
      icon: BvIcons.checkOut,
      label: l10n.checkInOutChip(
        checkInClock(words, out),
        d.outAllow ?? checkInDefaultAllowance,
      ),
      chip: CheckInChip.checkOut,
    ),
  if (d.daily)
    (
      key: const Key('writing-every-day-chip'),
      clearKey: const Key('writing-every-day-chip-clear'),
      icon: BvIcons.repeat,
      label: l10n.checkInEveryDay,
      chip: CheckInChip.everyDay,
    ),
];

enum CheckInChip { checkOut, everyDay }

/// Set place here (CI1): the Lead's location, read once, now. That point
/// is the post's site. Refused, off or weak says so, and nothing is set.
Future<void> setCheckInPlace(
  BuildContext context,
  WidgetRef ref,
  DaybookWriter writer,
) async {
  final l10n = AppLocalizations.of(context);
  final reading = ref.read(checkInPlaceReadingProvider(writer.spaceId).notifier)
    ..set(true);
  final LocationRead read;
  try {
    read = await readForCheckIn(ref.read(locationReaderProvider));
  } finally {
    if (context.mounted) reading.set(false);
  }
  if (!context.mounted) return;
  if (!read.hasPoint) {
    showSpaceMessage(
      context,
      read.miss == LocationMiss.refused
          ? l10n.checkInPlaceRefused
          : l10n.checkInPlaceFailed,
    );
    return;
  }
  await writer.setSite((lat: read.lat!, lng: read.lng!));
}

/// A time on the wheels; a provider so tests can stand in.
typedef PickCheckInClock =
    Future<TimeOfDay?> Function(
      BuildContext context, {
      required TimeOfDay initial,
      required String title,
    });

final pickCheckInClockProvider = Provider<PickCheckInClock>(
  (ref) =>
      (context, {required initial, required title}) =>
          showBvTimePicker(context, initial: initial, title: title),
);

/// The Check-in line, or + → Check-out (CI1, CI1b): the time, and the
/// allowance as one single choice (0 · 10 · 15 · 30 min). Null when put
/// down.
Future<({DayTime time, int allow})?> pickCheckInTime(
  BuildContext context, {
  required bool out,
  DayTime? time,
  int allow = checkInDefaultAllowance,
  DayTime? suggested,
}) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<({DayTime time, int allow})>(
    context: context,
    title: out ? l10n.checkInExtraOut : l10n.checkInRowIn,
    builder: (_) => CheckInTimeSheet(
      out: out,
      time: time,
      allow: checkInAllowances.contains(allow)
          ? allow
          : checkInDefaultAllowance,
      suggested: suggested,
    ),
  );
}

class CheckInTimeSheet extends ConsumerStatefulWidget {
  const CheckInTimeSheet({
    super.key,
    required this.out,
    required this.time,
    required this.allow,
    this.suggested,
  });

  final bool out;
  final DayTime? time;
  final int allow;

  /// Where the wheels start when no time is chosen yet.
  final DayTime? suggested;

  @override
  ConsumerState<CheckInTimeSheet> createState() => _CheckInTimeSheetState();
}

class _CheckInTimeSheetState extends ConsumerState<CheckInTimeSheet> {
  late DayTime? _time = widget.time;
  late int _allow = widget.allow;

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider)();
    final start = _time ?? widget.suggested ?? DayTime((now.hour + 1) % 24, 0);
    final picked = await ref.read(pickCheckInClockProvider)(
      context,
      initial: TimeOfDay(hour: start.hour, minute: start.minute),
      title: widget.out ? l10n.checkOutTimeHelp : l10n.checkInTimeHelp,
    );
    if (picked == null || !mounted) return;
    setState(() => _time = DayTime(picked.hour, picked.minute));
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
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final time = _time;
    return Column(
      key: Key(widget.out ? 'check-out-sheet' : 'check-in-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s12,
      children: [
        BvListRow(
          key: const Key('check-in-sheet-time'),
          leading: const BvRowIcon(BvIcons.clock),
          title: l10n.checkInTimeLabel,
          trailing: BvRowTrailing.value(
            time == null ? l10n.daybookRowChoose : checkInClock(words, time),
          ),
          onTap: () => unawaited(_pick()),
        ),
        Text(l10n.checkInAllowance, style: quiet),
        BvSegmented<int>(
          key: const Key('check-in-allowance'),
          segments: [
            for (final m in checkInAllowances)
              BvSegment(
                key: Key('check-in-allow-$m'),
                value: m,
                label: l10n.checkInMinutes(m),
              ),
          ],
          value: _allow,
          onChanged: (m) => setState(() => _allow = m),
        ),
        Text(
          l10n.checkInSheetNote(_allow, checkInSiteMetres),
          key: const Key('check-in-sheet-note'),
          style: quiet,
        ),
        BvButton(
          key: const Key('check-in-sheet-done'),
          label: l10n.notebookDone,
          expand: true,
          onPressed: time == null
              ? null
              : () => Navigator.of(context).pop((time: time, allow: _allow)),
        ),
      ],
    );
  }
}

/// For (CI1): the same Teams as Team offers, more than one allowed, or
/// the whole Space. Null when put down.
Future<List<({String id, String name})>?> pickCheckInTeams(
  BuildContext context, {
  required List<SpaceTeam> teams,
  required List<({String id, String name})> chosen,
}) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<List<({String id, String name})>>(
    context: context,
    title: l10n.checkInFor,
    builder: (_) => _CheckInTeamsSheet(teams: teams, chosen: chosen),
  );
}

class _CheckInTeamsSheet extends StatefulWidget {
  const _CheckInTeamsSheet({required this.teams, required this.chosen});

  final List<SpaceTeam> teams;
  final List<({String id, String name})> chosen;

  @override
  State<_CheckInTeamsSheet> createState() => _CheckInTeamsSheetState();
}

class _CheckInTeamsSheetState extends State<_CheckInTeamsSheet> {
  late final Set<String> _ids = {for (final t in widget.chosen) t.id};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const Key('check-in-teams-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BvListRow(
          key: const Key('check-in-team-all'),
          leading: const BvRowIcon(BvIcons.people),
          title: l10n.daybookWholeSpace,
          trailing: BvRowTrailing.check(selected: _ids.isEmpty),
          onTap: () => setState(_ids.clear),
        ),
        for (final t in widget.teams)
          BvListRow(
            key: Key('check-in-team-${t.id}'),
            leading: const BvRowIcon(BvIcons.team),
            title: t.name,
            trailing: BvRowTrailing.check(selected: _ids.contains(t.id)),
            onTap: () => setState(
              () => _ids.contains(t.id) ? _ids.remove(t.id) : _ids.add(t.id),
            ),
          ),
        const SizedBox(height: BvSpace.s12),
        BvButton(
          key: const Key('check-in-teams-done'),
          label: l10n.notebookDone,
          expand: true,
          onPressed: () => Navigator.of(context).pop([
            for (final t in widget.teams)
              if (_ids.contains(t.id)) (id: t.id, name: t.name),
          ]),
        ),
      ],
    );
  }
}
