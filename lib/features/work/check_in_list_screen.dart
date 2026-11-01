import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../data/models/check_in.dart';
import '../../data/models/space.dart' show SpaceException;
import '../../data/repositories/check_in_repository.dart';
import '../../data/repositories/daybook_repository.dart'
    show daybookChildCardProvider;
import '../../data/repositories/space_repository.dart' show spaceDetailProvider;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/former_member.dart' show personName;
import '../spaces/space_errors.dart' show showSpaceMessage;
import 'check_in_card.dart' show CheckInStamp;
import 'check_in_words.dart';
import 'daybook_state.dart' show daybookCardsProvider;
import 'daybook_words.dart';

/// Review 109 CI5 (2706:39604): a Check-in's list, for its creator only
/// (and the Space admin once the creator has left; the server decides).
/// One line per person: name, In stamp, Out stamp, or Missed. The day
/// picker under the title goes back through the days it ran. ⋯ → Stop on
/// a repeating one, with a confirmation.
class CheckInListScreen extends ConsumerStatefulWidget {
  const CheckInListScreen({
    super.key,
    required this.spaceId,
    required this.postId,
  });

  final String spaceId;
  final String postId;

  @override
  ConsumerState<CheckInListScreen> createState() => _CheckInListScreenState();
}

enum _Menu { stop }

class _CheckInListScreenState extends ConsumerState<CheckInListScreen> {
  /// The day shown; null: the newest (today, when it runs today).
  DateTime? _day;

  Future<void> _pickDay(List<DateTime> days, DateTime shown) async {
    final l10n = AppLocalizations.of(context);
    final words = _words(context);
    final picked = await showBvSheet<DateTime>(
      context: context,
      title: l10n.checkInDayPicker,
      builder: (sheet) => Column(
        key: const Key('check-in-days'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final d in days)
            BvListRow(
              key: Key('check-in-day-${checkInDayJson(d)}'),
              title: _dayName(l10n, words, d),
              trailing: BvRowTrailing.check(selected: d == shown),
              onTap: () => Navigator.of(sheet).pop(d),
            ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _menu() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showBvScreenMenu<_Menu>(
      context,
      key: const Key('check-in-list-menu'),
      items: [
        BvMenuItem(
          value: _Menu.stop,
          key: const Key('check-in-stop'),
          label: l10n.checkInStop,
          icon: BvIcons.close,
          destructive: true,
        ),
      ],
    );
    if (picked != _Menu.stop || !mounted) return;
    final yes = await showBvDialog(
      context: context,
      title: l10n.checkInStopTitle,
      body: l10n.checkInStopBody,
      cancelLabel: l10n.checkInKeep,
      confirmLabel: l10n.checkInStop,
      destructive: true,
    );
    if (!yes || !mounted) return;
    try {
      await ref.read(checkInRepositoryProvider).stop(widget.postId);
    } on SpaceException catch (e) {
      if (mounted) {
        showSpaceMessage(
          context,
          checkInRefusalText(l10n, CheckInRefusal.of(e)),
        );
      }
      return;
    }
    ref
      ..invalidate(daybookChildCardProvider(widget.postId))
      ..invalidate(daybookCardsProvider);
    if (mounted) showSpaceMessage(context, l10n.checkInStoppedDone);
  }

  static DaybookWords _words(BuildContext context) => DaybookWords(
    AppLocalizations.of(context),
    Localizations.localeOf(context).toLanguageTag(),
    use24: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  String _dayName(AppLocalizations l10n, DaybookWords words, DateTime d) {
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    return d == today ? l10n.checkInListToday : words.shortDate(d);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = _words(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final card = ref.watch(daybookChildCardProvider(widget.postId)).value;
    final post = card?.post;
    final setup = post?.checkIn;
    // Y1: the check-in's own clock, else the Space's.
    final zone =
        setup?.zone ??
        ref.watch(spaceDetailProvider(widget.spaceId)).value?.timeZone;
    final days =
        ref.watch(checkInDaysProvider(widget.postId)).value ??
        const <DateTime>[];
    final now = ref.watch(clockProvider)();
    final today = setup?.today?.day ?? DateTime(now.year, now.month, now.day);
    final shown = _day ?? days.firstOrNull ?? today;
    final lines = ref.watch(
      checkInListProvider((postId: widget.postId, day: shown)),
    );
    // The server decides who may stop it (can_stop).
    final canStop = setup?.canStop ?? false;
    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post?.title ?? '',
              key: const Key('check-in-list-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.titleMd.copyWith(color: BvColors.textPrimary),
            ),
            // The day picker: today, or an earlier day it ran.
            InkWell(
              key: const Key('check-in-list-day'),
              onTap: days.length < 2
                  ? null
                  : () => unawaited(_pickDay(days, shown)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: BvSpace.s4,
                children: [
                  Flexible(
                    child: Text(
                      l10n.checkInListSub(_dayName(l10n, words, shown)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: quiet,
                    ),
                  ),
                  if (days.length > 1)
                    const Icon(
                      BvIcons.caretDown,
                      size: BvSize.iconSm,
                      color: BvColors.iconSecondary,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (canStop)
            IconButton(
              key: const Key('check-in-list-more'),
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              icon: const Icon(BvIcons.more, color: BvColors.iconPrimary),
              onPressed: () => unawaited(_menu()),
            ),
        ],
      ),
      body: switch (lines) {
        AsyncData(:final value) => ListView(
          children: [
            if (value.isEmpty)
              Padding(
                padding: BvCheckInSpec.rowPadding,
                child: Text(l10n.checkInListEmpty, style: quiet),
              ),
            for (final l in value) ...[
              _Line(line: l, words: words, zone: zone),
              const Divider(height: 1, color: BvColors.borderSubtle),
            ],
            Padding(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: Container(
                key: const Key('check-in-list-library'),
                padding: const EdgeInsetsDirectional.all(BvSpace.s12),
                decoration: const BoxDecoration(
                  color: BvColors.surfaceSubtle,
                  borderRadius: BvRadius.controlAll,
                ),
                child: Row(
                  spacing: BvSpace.s12,
                  children: [
                    const Icon(
                      BvIcons.library,
                      size: BvSize.iconMd,
                      color: BvColors.iconSecondary,
                    ),
                    Expanded(
                      child: Text(l10n.checkInListLibrary, style: quiet),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        AsyncError() => Center(child: Text(l10n.errorGeneric, style: quiet)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// One person (CI5): their face and name, then their In and Out stamps,
/// or Missed.
class _Line extends StatelessWidget {
  const _Line({required this.line, required this.words, required this.zone});

  final CheckInLine line;
  final DaybookWords words;
  final String? zone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final name = personName(l10n, line.name);
    final inMark = line.inMark;
    final outMark = line.outMark;
    return Padding(
      key: Key('check-in-line-${line.userId}'),
      padding: BvCheckInSpec.rowPadding,
      child: Row(
        spacing: BvSpace.s12,
        children: [
          BvAvatar(name: name, size: BvAvatarSize.sm),
          Expanded(
            flex: BvCheckInSpec.nameFlex,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.bodyMd.copyWith(color: BvColors.textPrimary),
            ),
          ),
          Flexible(
            flex: BvCheckInSpec.stampsFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: BvSpace.s4,
              children: [
                if (inMark != null)
                  CheckInStamp.of(
                    checkInStampText(
                      l10n,
                      words.time,
                      zone,
                      inMark,
                      CheckInMarkKind.checkIn,
                      short: true,
                    ),
                    inMark,
                    key: Key('check-in-line-in-${line.userId}'),
                  ),
                if (inMark == null && line.missed)
                  CheckInStamp.missed(
                    l10n,
                    inOnly: outMark != null,
                    key: Key('check-in-line-missed-${line.userId}'),
                  ),
                if (outMark != null)
                  CheckInStamp.of(
                    checkInStampText(
                      l10n,
                      words.time,
                      zone,
                      outMark,
                      CheckInMarkKind.checkOut,
                      short: true,
                    ),
                    outMark,
                    key: Key('check-in-line-out-${line.userId}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
