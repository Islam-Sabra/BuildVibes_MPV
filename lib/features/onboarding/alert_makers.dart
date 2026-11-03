import 'package:flutter/foundation.dart';

import '../../core/push/alert_settings_phone.dart' show AndroidPage;

export '../../core/push/alert_settings_phone.dart' show AndroidPage;

/// Review 114: the phone makers whose phones need more than the
/// notification permission before urgent alerts reach them, and the pages
/// of their own settings that the alerts setup opens. Kept as data in this
/// one file; the setup and the phone's side read it.

/// One line of the alerts setup (PS1), in the order it shows.
enum AlertLine { notifications, autostart, floating, battery }

/// A maker: the names Android gives (`Build.MANUFACTURER`, `Build.BRAND`,
/// lower case), the lines its phones need, and its pages.
@immutable
class PhoneMaker {
  const PhoneMaker({
    required this.names,
    required this.lines,
    this.autostart = const [],
    this.battery = const [],
  });

  final Set<String> names;
  final List<AlertLine> lines;
  final List<AndroidPage> autostart;
  final List<AndroidPage> battery;
}

const _allFour = AlertLine.values;

const _miuiAutostart = [
  AndroidPage(
    'com.miui.securitycenter',
    'com.miui.permcenter.autostart.AutoStartManagementActivity',
  ),
];

/// MIUI's own battery saver for one app (No restrictions); the phone fills
/// in this app's package and label.
const _miuiBattery = [
  AndroidPage(
    'com.miui.powerkeeper',
    'com.miui.powerkeeper.ui.HiddenAppsConfigActivity',
    action: 'miui.intent.action.HIDDEN_APPS_CONFIG_ACTIVITY',
  ),
];

const _colorOsAutostart = [
  AndroidPage(
    'com.coloros.safecenter',
    'com.coloros.safecenter.permission.startup.StartupAppListActivity',
  ),
  AndroidPage(
    'com.coloros.safecenter',
    'com.coloros.safecenter.startupapp.StartupAppListActivity',
  ),
  AndroidPage(
    'com.oplus.safecenter',
    'com.oplus.safecenter.permission.startup.StartupAppListActivity',
  ),
  AndroidPage(
    'com.oppo.safe',
    'com.oppo.safe.permission.startup.StartupAppListActivity',
  ),
];

const _vivoAutostart = [
  AndroidPage(
    'com.vivo.permissionmanager',
    'com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
  ),
  AndroidPage(
    'com.iqoo.secure',
    'com.iqoo.secure.ui.phoneoptimize.BgStartUpManager',
  ),
  AndroidPage(
    'com.iqoo.secure',
    'com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity',
  ),
];

const _huaweiAutostart = [
  AndroidPage(
    'com.huawei.systemmanager',
    'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
  ),
  AndroidPage(
    'com.huawei.systemmanager',
    'com.huawei.systemmanager.optimize.process.ProtectActivity',
  ),
  AndroidPage(
    'com.huawei.systemmanager',
    'com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity',
  ),
];

const _honorAutostart = [
  AndroidPage(
    'com.hihonor.systemmanager',
    'com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
  ),
  ..._huaweiAutostart,
];

/// The makers the setup knows. Any other Android phone gets Notifications
/// only; an iPhone too (time-sensitive alerts are part of its own popup).
const phoneMakers = <PhoneMaker>[
  PhoneMaker(
    names: {'xiaomi', 'redmi', 'poco'},
    lines: _allFour,
    autostart: _miuiAutostart,
    battery: _miuiBattery,
  ),
  PhoneMaker(
    names: {'oppo', 'realme', 'oneplus'},
    lines: _allFour,
    autostart: _colorOsAutostart,
  ),
  PhoneMaker(
    names: {'vivo', 'iqoo'},
    lines: _allFour,
    autostart: _vivoAutostart,
  ),
  PhoneMaker(names: {'huawei'}, lines: _allFour, autostart: _huaweiAutostart),
  PhoneMaker(names: {'honor'}, lines: _allFour, autostart: _honorAutostart),
  PhoneMaker(
    names: {'samsung'},
    lines: [AlertLine.notifications, AlertLine.battery],
  ),
];

/// The maker of a phone that names itself [makers] (manufacturer and
/// brand), or null for one the setup doesn't know.
PhoneMaker? phoneMakerOf(List<String> makers) {
  final names = {for (final m in makers) m.trim().toLowerCase()};
  return phoneMakers.where((m) => m.names.any(names.contains)).firstOrNull;
}

/// The lines this phone needs.
List<AlertLine> alertLinesFor({
  required bool ios,
  required List<String> makers,
}) => ios
    ? const [AlertLine.notifications]
    : phoneMakerOf(makers)?.lines ?? const [AlertLine.notifications];
