import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One of a maker's own settings pages, by its Android component: the
/// phone opens the first that it has, else the app's details page.
@immutable
class AndroidPage {
  const AndroidPage(this.package, this.activity, {this.action});

  final String package;
  final String activity;

  /// An intent action the page is opened with, when it needs one.
  final String? action;

  Map<String, String> toJson() => {
    'package': package,
    'activity': activity,
    'action': ?action,
  };
}

/// What the phone itself can confirm about urgent alerts (review 114).
/// Null where it can't tell (an iPhone, an Android before 8, a channel not
/// made yet).
@immutable
class AlertPhoneStatus {
  const AlertPhoneStatus({this.needYouChannelOn, this.batteryUnrestricted});

  /// The Need you now channel is on, at high importance or above.
  final bool? needYouChannelOn;

  /// Battery optimisation is off for BuildVibes.
  final bool? batteryUnrestricted;
}

/// Review 114: the phone's settings pages for urgent alerts, behind one
/// interface so tests use a fake. On Android, one MethodChannel
/// (`buildvibes/alerts`, MainActivity.kt). The notification permission
/// itself stays with PushMessaging.
abstract class AlertSettingsPhone {
  Future<AlertPhoneStatus> status();

  /// The maker's Autostart page: the first of [pages] the phone has, else
  /// the app's details page.
  Future<void> openAutostart(List<AndroidPage> pages);

  /// The app's notification settings on the [channel] category (floating
  /// notifications); the app's notification settings without it.
  Future<void> openChannel(String channel);

  /// The app's battery page: the first of [pages] the phone has, else the
  /// app's details page. Never the battery optimisation popup (Google Play
  /// policy).
  Future<void> openBattery(List<AndroidPage> pages);
}

class MethodChannelAlertSettings implements AlertSettingsPhone {
  const MethodChannelAlertSettings();

  static const _channel = MethodChannel('buildvibes/alerts');

  bool get _android => !kIsWeb && Platform.isAndroid;

  @override
  Future<AlertPhoneStatus> status() async {
    if (!_android) return const AlertPhoneStatus();
    try {
      final s = await _channel.invokeMapMethod<String, Object?>('status');
      return AlertPhoneStatus(
        needYouChannelOn: s?['channel'] as bool?,
        batteryUnrestricted: s?['battery'] as bool?,
      );
    } on Exception catch (e) {
      debugPrint('alerts status: $e');
      return const AlertPhoneStatus();
    }
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<Object?>(method, arguments);
    } on Exception catch (e) {
      debugPrint('$method: $e');
    }
  }

  @override
  Future<void> openAutostart(List<AndroidPage> pages) =>
      _invoke('openAutostart', {
        'pages': [for (final p in pages) p.toJson()],
      });

  @override
  Future<void> openChannel(String channel) =>
      _invoke('openChannel', {'channel': channel});

  @override
  Future<void> openBattery(List<AndroidPage> pages) => _invoke('openBattery', {
    'pages': [for (final p in pages) p.toJson()],
  });
}

final alertSettingsPhoneProvider = Provider<AlertSettingsPhone>(
  (ref) => const MethodChannelAlertSettings(),
);
