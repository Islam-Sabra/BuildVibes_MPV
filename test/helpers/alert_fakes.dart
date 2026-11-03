import 'package:buildvibes/core/push/alert_settings_phone.dart';
import 'package:buildvibes/data/repositories/alert_test_repository.dart';

/// Review 114: the phone's alert settings pages, in memory. Tests set what
/// the phone confirms and read which pages were opened.
class FakeAlertSettingsPhone implements AlertSettingsPhone {
  FakeAlertSettingsPhone({this.current = const AlertPhoneStatus()});

  AlertPhoneStatus current;

  /// Each page opened: "autostart" and its first activity, "channel" and
  /// its id, "battery" and its first activity.
  final opened = <String>[];

  @override
  Future<AlertPhoneStatus> status() async => current;

  @override
  Future<void> openAutostart(List<AndroidPage> pages) async =>
      opened.add('autostart ${pages.firstOrNull?.activity ?? 'app'}');

  @override
  Future<void> openChannel(String channel) async =>
      opened.add('channel $channel');

  @override
  Future<void> openBattery(List<AndroidPage> pages) async =>
      opened.add('battery ${pages.firstOrNull?.activity ?? 'app'}');
}

/// send_test_alert, with no network.
class FakeAlertTestRepository implements AlertTestRepository {
  var sent = 0;

  /// The next send fails with this.
  AlertTestException? refuse;

  @override
  Future<void> send() async {
    if (refuse case final e?) throw e;
    sent++;
  }
}
