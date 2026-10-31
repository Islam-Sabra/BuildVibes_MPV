import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../data/repositories/market_repository.dart';
import '../account/account_parts.dart' show myMarketProvider;
import '../notebook/notebook_page_screen.dart' show reminderWhen;
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'daybook_words.dart';
import 'daybook_writing.dart';
import 'space_day.dart';

const _morning = BvLaterSpec.morningHour;

/// The first working day after tomorrow, at 7:00 on [now]'s own clock (a
/// wall clock). [weekend] is the market pack's (markets.weekend; 0 is
/// Sunday).
DateTime nextWorkingDay(DateTime now, List<int> weekend) {
  var day = DateTime(now.year, now.month, now.day + 2, _morning);
  // A week has at least one working day; seven steps at most.
  for (var i = 0; i < 7 && weekend.contains(day.weekday % 7); i++) {
    day = DateTime(day.year, day.month, day.day + 1, _morning);
  }
  return day;
}

/// The time Post later chose: [at] the moment it goes; [wall] the same
/// as read on the clock it was chosen on (a Space's, or the phone's).
typedef LaterTime = ({DateTime at, DateTime wall});

/// Post later (review 108 PL1, 2701:39253): one choice of Tomorrow 7:00 ·
/// {next working day} 7:00 · Pick…, the line that it goes out even with
/// the phone off, then Schedule. Pops with the time, or null.
///
/// Review 108 V3: in a Space, its [zone] and its market's ([marketId])
/// weekend; elsewhere (null) the phone's clock and my own market.
Future<LaterTime?> showPostLaterSheet(
  BuildContext context, {
  String? zone,
  String? marketId,
}) => showBvSheet<LaterTime>(
  context: context,
  title: AppLocalizations.of(context).plTitle,
  builder: (sheet) => _PostLaterSheet(zone: zone, marketId: marketId),
);

enum _When { tomorrow, workday, picked }

class _PostLaterSheet extends ConsumerStatefulWidget {
  const _PostLaterSheet({this.zone, this.marketId});

  final String? zone;
  final String? marketId;

  @override
  ConsumerState<_PostLaterSheet> createState() => _PostLaterSheetState();
}

class _PostLaterSheetState extends ConsumerState<_PostLaterSheet> {
  var _when = _When.tomorrow;

  /// As picked: a wall clock in the sheet's zone.
  DateTime? _picked;

  DaybookWords _words(AppLocalizations l10n) => DaybookWords(
    l10n,
    Localizations.localeOf(context).toLanguageTag(),
    use24: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  Future<void> _pick(DateTime wallNow) async {
    final picked = await ref.read(pickReminderProvider)(
      context,
      now: wallNow,
      day: _picked == null ? null : dayOf(_picked!),
      at: _picked,
    );
    if (!mounted || picked == null || picked.day == null) return;
    final day = picked.day!;
    setState(() {
      _picked = picked.at ?? DateTime(day.year, day.month, day.day, _morning);
      _when = _When.picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = _words(l10n);
    final now = ref.watch(clockProvider)();
    final zone = widget.zone;
    // The sheet's own clock and calendar: the Space's, or the phone's.
    final wallNow = spaceWallNow(zone, now);
    final market =
        (ref.watch(marketsProvider).value ?? const [])
            .where((m) => m.id == widget.marketId)
            .firstOrNull ??
        ref.watch(myMarketProvider);
    final tomorrow = DateTime(
      wallNow.year,
      wallNow.month,
      wallNow.day + 1,
      _morning,
    );
    final workday = nextWorkingDay(wallNow, market?.weekend ?? const []);
    final wall = switch (_when) {
      _When.tomorrow => tomorrow,
      _When.workday => workday,
      _When.picked => _picked,
    };
    final at = wall == null ? null : spaceTimeAt(zone, wall);

    return Column(
      key: const Key('later-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s12,
      children: [
        Wrap(
          spacing: BvSpace.s8,
          runSpacing: BvSpace.s8,
          children: [
            BvChip(
              key: const Key('later-tomorrow'),
              label: l10n.rmTomorrowAt(words.time.clock(tomorrow)),
              icon: BvIcons.clock,
              selected: _when == _When.tomorrow,
              onTap: () => setState(() => _when = _When.tomorrow),
            ),
            BvChip(
              key: const Key('later-workday'),
              label: l10n.plDayAt(
                words.weekday(workday),
                words.time.clock(workday),
              ),
              selected: _when == _When.workday,
              onTap: () => setState(() => _when = _When.workday),
            ),
            BvChip(
              key: const Key('later-pick'),
              label: _picked == null
                  ? l10n.rmPick
                  : reminderWhen(l10n, words, _picked!, wallNow),
              icon: BvIcons.calendar,
              selected: _when == _When.picked,
              onTap: () => unawaited(_pick(wallNow)),
            ),
          ],
        ),
        Text(
          l10n.plGoesOut,
          style: type.metadata.copyWith(color: BvColors.textSecondary),
        ),
        BvButton(
          key: const Key('later-schedule'),
          label: l10n.plSchedule,
          icon: BvIcons.clock,
          expand: true,
          onPressed: at == null || !at.isAfter(now)
              ? null
              : () => Navigator.of(context).pop((at: at, wall: wall!)),
        ),
        const SizedBox(height: BvSheetSpec.footerGap),
      ],
    );
  }
}
