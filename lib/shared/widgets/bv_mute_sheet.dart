import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import 'bv_list_row.dart';
import 'bv_sheet.dart';

/// How long a mute holds (F102, as WhatsApp's "Mute notifications").
enum MuteFor {
  eightHours,
  oneWeek,
  always;

  /// When the mute ends, from [now]; null = always.
  DateTime? until(DateTime now) => switch (this) {
    MuteFor.eightHours => now.add(const Duration(hours: 8)),
    MuteFor.oneWeek => now.add(const Duration(days: 7)),
    MuteFor.always => null,
  };

  String label(AppLocalizations l10n) => switch (this) {
    MuteFor.eightHours => l10n.muteFor8Hours,
    MuteFor.oneWeek => l10n.muteFor1Week,
    MuteFor.always => l10n.muteForAlways,
  };
}

/// "For how long?": 8 hours / 1 week / Always, one single choice (rule 6).
/// A tap picks and closes; null when dismissed (nothing changes). Used by
/// Space info → Notifications (Off or Needs you only), a conversation's
/// Mute, and the long-press Mute on the Spaces and Messages lists.
Future<MuteFor?> showMuteSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<MuteFor>(
    context: context,
    title: l10n.muteForHowLong,
    builder: (sheet) => ClipRRect(
      key: const Key('mute-sheet'),
      borderRadius: BvRadius.cardAll,
      child: BvListGroup(
        rows: [
          for (final m in MuteFor.values)
            BvListRow(
              key: Key('mute-for-${m.name}'),
              title: m.label(l10n),
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(m),
            ),
        ],
      ),
    ),
  );
}

/// The long-press menu of a Space or a conversation row (F102): one
/// action, Mute or Unmute. True when it was chosen.
Future<bool> showMuteMenu(BuildContext context, {required bool muted}) async {
  final l10n = AppLocalizations.of(context);
  final chosen = await showBvSheet<bool>(
    context: context,
    builder: (sheet) => ClipRRect(
      key: const Key('mute-menu'),
      borderRadius: BvRadius.cardAll,
      child: BvListGroup(
        rows: [
          BvListRow(
            key: Key(muted ? 'mute-menu-unmute' : 'mute-menu-mute'),
            leading: BvRowIcon(muted ? BvIcons.notifications : BvIcons.muted),
            title: muted ? l10n.muteUnmute : l10n.muteMute,
            trailing: const BvRowTrailing.none(),
            onTap: () => Navigator.of(sheet).pop(true),
          ),
        ],
      ),
    ),
  );
  return chosen ?? false;
}

/// The bell-slash beside a muted row's name (F102).
class BvMutedMark extends StatelessWidget {
  const BvMutedMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).muteMutedLabel,
      child: const Padding(
        padding: EdgeInsetsDirectional.only(start: BvSpace.s4),
        child: Icon(
          BvIcons.muted,
          size: BvSize.iconSm,
          color: BvColors.iconSecondary,
        ),
      ),
    );
  }
}
