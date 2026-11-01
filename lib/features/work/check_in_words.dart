import '../../core/l10n/bv_time.dart';
import '../../data/models/check_in.dart';
import '../../l10n/gen/app_localizations.dart';
import 'space_day.dart' show spaceWallNow;

/// Review 109: a Check-in's words. Plain functions of the app's words, so
/// a notification shown with the app closed says them too.

/// [at] (an instant) on the Space's clock in [zone]; with none known, the
/// phone's.
DateTime checkInWall(String? zone, DateTime at) =>
    zone == null ? at.toLocal() : spaceWallNow(zone, at);

/// [at] as a time on the Space's clock ("6:58").
String checkInTimeOf(BvTime time, String? zone, DateTime at) =>
    time.clock(checkInWall(zone, at));

/// What a mark says after its time (CI4): "on time · on site", "late",
/// "not at site", "location not shared". [short]: the list's words
/// ("no location", CI5).
String checkInHow(
  AppLocalizations l10n,
  CheckInMark mark, {
  bool short = false,
}) {
  final notShared = short ? l10n.checkInNoLocation : l10n.checkInNotShared;
  if (mark.onTime && mark.place == CheckInPlace.onSite) {
    return [l10n.checkInOnTime, l10n.checkInOnSite].join(' · ');
  }
  return [
    if (!mark.onTime) l10n.checkInLate,
    switch (mark.place) {
      CheckInPlace.away => l10n.checkInAway,
      CheckInPlace.notShared => notShared,
      CheckInPlace.onSite => null,
    },
  ].nonNulls.join(' · ');
}

/// A stamp (CI4): "In 6:58 · on time · on site", "In 7:24 · late". An Out
/// on time says only its time on the list ("Out 15:05", CI5).
String checkInStampText(
  AppLocalizations l10n,
  BvTime time,
  String? zone,
  CheckInMark mark,
  CheckInMarkKind kind, {
  bool short = false,
}) {
  final clock = checkInTimeOf(time, zone, mark.at);
  final head = kind == CheckInMarkKind.checkIn
      ? l10n.checkInIn(clock)
      : l10n.checkInOut(clock);
  if (short && mark.tone == CheckInTone.good) return head;
  final how = checkInHow(l10n, mark, short: short);
  return how.isEmpty ? head : '$head · $how';
}

/// "Checked in 6:58 · on site" (CI2): the result, as a notification and a
/// line on the screen.
String checkInResultText(
  AppLocalizations l10n,
  BvTime time,
  String? zone,
  CheckInResult r,
) {
  final clock = checkInTimeOf(time, zone, r.mark.at);
  final how = checkInHow(l10n, r.mark);
  return r.kind == CheckInMarkKind.checkIn
      ? l10n.checkInResultIn(clock, how)
      : l10n.checkInResultOut(clock, how);
}

/// The plain line for each refusal.
String checkInRefusalText(AppLocalizations l10n, CheckInRefusal r) =>
    switch (r) {
      CheckInRefusal.notAllowed => l10n.checkInRefusedNotAllowed,
      CheckInRefusal.notOpenYet => l10n.checkInRefusedNotOpen,
      CheckInRefusal.closed => l10n.checkInRefusedClosed,
      CheckInRefusal.notToday => l10n.checkInRefusedNotToday,
      CheckInRefusal.stopped => l10n.checkInRefusedStopped,
      CheckInRefusal.already => l10n.checkInRefusedAlready,
      CheckInRefusal.tooMany => l10n.checkInRefusedTooMany,
      CheckInRefusal.noCheckOut => l10n.checkInRefusedNoCheckOut,
      CheckInRefusal.network => l10n.checkInRefusedNetwork,
      CheckInRefusal.unknown => l10n.errorGeneric,
    };
