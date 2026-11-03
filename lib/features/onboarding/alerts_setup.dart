import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/locale_controller.dart' show sharedPreferencesProvider;
import '../../core/push/alert_settings_phone.dart';
import '../../core/push/push_messaging.dart';
import '../../core/routing/app_routes.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'alert_makers.dart';

/// Review 114: the alerts setup after sign-up (PS1, PS2) and the one ask
/// again when an urgent alert came late (PS3). The decisions are here,
/// tested without a phone; the phone's side is [AlertSettingsPhone].

/// The test push's kind (send_test_alert).
const alertTestKind = 'need_you_test';

/// The urgent pushes whose lateness counts: Need you now, a check-in
/// opening.
const urgentAlertKinds = {'need_you', 'check_in_open'};

/// An urgent alert opened later than this after it was sent was late.
const alertLateAfter = Duration(minutes: 5);

/// The person came back from the Autostart or floating notifications page
/// (no phone reports these): kept on this phone.
String alertVisitedKey(AlertLine line) => 'alerts_visited_${line.name}';

/// The background handler's mark that the test push reached this phone
/// with the app in the background (ISO 8601 UTC).
const alertTestArrivedKey = 'alerts_test_arrived_at';

/// The setup was offered after this account's sign-up.
String alertSetupShownKey(String userId) => 'alerts_setup_shown:$userId';

/// PS3 was shown to this account (never again).
String alertLateAskedKey(String userId) => 'alerts_late_asked:$userId';

/// Whether [line] shows "On": only where the phone can confirm it
/// (notifications allowed, the channel's importance, battery optimisation
/// off). Autostart and floating notifications, which no phone reports, are
/// on once the person came back from their page; a channel the phone says
/// is low or off turns floating off again.
bool alertLineOn(
  AlertLine line, {
  required PushPermission permission,
  required AlertPhoneStatus status,
  required Set<AlertLine> visited,
}) => switch (line) {
  AlertLine.notifications => permission == PushPermission.granted,
  AlertLine.autostart => visited.contains(AlertLine.autostart),
  AlertLine.floating =>
    status.needYouChannelOn != false && visited.contains(AlertLine.floating),
  AlertLine.battery =>
    status.batteryUnrestricted ?? visited.contains(AlertLine.battery),
};

/// The setup for this phone: its lines, and which are on.
@immutable
class AlertsSetup {
  const AlertsSetup({
    required this.lines,
    required this.on,
    required this.permission,
    this.maker,
  });

  final List<AlertLine> lines;
  final Set<AlertLine> on;
  final PushPermission permission;
  final PhoneMaker? maker;

  int get offCount => lines.where((l) => !on.contains(l)).length;
}

Set<AlertLine> alertsVisited(SharedPreferences prefs) => {
  for (final l in AlertLine.values)
    if (prefs.getBool(alertVisitedKey(l)) ?? false) l,
};

/// Reads the phone: its maker, the permission, what it can confirm.
Future<AlertsSetup> loadAlertsSetup({
  required PushMessaging messaging,
  required AlertSettingsPhone phone,
  required SharedPreferences prefs,
}) async {
  final ios = messaging.platform == 'ios';
  final makers = ios ? const <String>[] : await messaging.phoneMakers();
  final lines = alertLinesFor(ios: ios, makers: makers);
  final permission = await messaging.permission();
  final status = await phone.status();
  final visited = alertsVisited(prefs);
  return AlertsSetup(
    lines: lines,
    maker: phoneMakerOf(makers),
    permission: permission,
    on: {
      for (final l in lines)
        if (alertLineOn(
          l,
          permission: permission,
          status: status,
          visited: visited,
        ))
          l,
    },
  );
}

final alertsSetupProvider = FutureProvider.autoDispose<AlertsSetup>(
  (ref) => loadAlertsSetup(
    messaging: ref.watch(pushMessagingProvider),
    phone: ref.watch(alertSettingsPhoneProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  ),
);

/// The alerts setup's route; [next] is where Later and Done go when there
/// is nothing under it (after sign-up).
String alertsSetupRoute({String? next}) => Uri(
  path: AppRoutes.alertsSetup,
  queryParameters: next == null ? null : {AppRoutes.alertsNextParam: next},
).toString();

/// After sign-up: the setup once per account, before the first Space,
/// unless every line this phone needs is already on. [next] is where it
/// would have gone.
Future<String> routeAfterSignUp({
  required String userId,
  required String next,
  required PushMessaging messaging,
  required AlertSettingsPhone phone,
  required SharedPreferences prefs,
}) async =>
    await offerAlertsSetup(
      userId: userId,
      messaging: messaging,
      phone: phone,
      prefs: prefs,
    )
    ? alertsSetupRoute(next: next)
    : next;

/// Whether the setup comes now, after this account's sign-up (once):
/// not when every line this phone needs is on already.
Future<bool> offerAlertsSetup({
  required String userId,
  required PushMessaging messaging,
  required AlertSettingsPhone phone,
  required SharedPreferences prefs,
}) async {
  final key = alertSetupShownKey(userId);
  if (prefs.getBool(key) ?? false) return false;
  final AlertsSetup setup;
  try {
    setup = await loadAlertsSetup(
      messaging: messaging,
      phone: phone,
      prefs: prefs,
    );
  } on Exception catch (e) {
    debugPrint('alerts setup: $e');
    return false;
  }
  if (setup.offCount == 0) return false;
  await prefs.setBool(key, true);
  return true;
}

/// Whether the test push has reached this phone since the last Send me a
/// test (PS2). Set by the setup screen, the push host, and on return from
/// the background (the background handler's mark).
final alertTestArrivedProvider = NotifierProvider<AlertTestArrived, bool>(
  AlertTestArrived.new,
);

class AlertTestArrived extends Notifier<bool> {
  @override
  bool build() => false;

  /// When the last test was asked for; a background mark before it is an
  /// older test's.
  DateTime? _sentAt;

  void sent(DateTime at) {
    _sentAt = at;
    state = false;
  }

  void arrived() => state = true;

  /// The setup opened afresh (Fix it, Fix now): an earlier test's arrival
  /// no longer speaks for the phone.
  void reset(DateTime now) {
    _sentAt = now;
    state = false;
  }

  /// Back from the background: the background handler's mark, if newer
  /// than the last test asked for.
  Future<void> readMark(SharedPreferences prefs) async {
    if (state) return;
    try {
      await prefs.reload();
    } on Object catch (e) {
      debugPrint('prefs reload: $e');
    }
    final at = DateTime.tryParse(prefs.getString(alertTestArrivedKey) ?? '');
    final sent = _sentAt;
    if (at != null && (sent == null || !at.isBefore(sent))) state = true;
  }
}

/// An urgent alert opened late (PS3): who sent it, when known, and by how
/// many minutes.
typedef LateAlert = ({String? name, int minutes});

/// [data] is an urgent push's data (or its notification's payload, with
/// its `kind`, `sent_at` and `from_name`): late when opened at [openedAt]
/// more than [alertLateAfter] after it was sent. Null otherwise.
LateAlert? lateAlertOf(Map<String, String?> data, DateTime openedAt) {
  if (!urgentAlertKinds.contains(data['kind'])) return null;
  final sent = DateTime.tryParse(data['sent_at'] ?? '');
  if (sent == null) return null;
  final late = openedAt.toUtc().difference(sent.toUtc());
  if (late <= alertLateAfter) return null;
  final name = data['kind'] == 'need_you' ? data['from_name']?.trim() : null;
  return (
    name: name == null || name.isEmpty ? null : name,
    minutes: late.inMinutes,
  );
}

/// The last urgent alert that was opened late; the shell's host decides
/// whether PS3 shows.
final lateAlertProvider = NotifierProvider<LateAlerts, LateAlert?>(
  LateAlerts.new,
);

class LateAlerts extends Notifier<LateAlert?> {
  @override
  LateAlert? build() => null;

  /// An urgent push was opened (its [data]).
  void opened(Map<String, String?> data) {
    final late = lateAlertOf(data, ref.read(clockProvider)());
    if (late != null) state = late;
  }

  void clear() => state = null;
}
