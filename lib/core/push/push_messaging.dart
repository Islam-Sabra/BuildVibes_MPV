import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crash/crash_reports.dart';

/// Whether the phone lets BuildVibes show notifications.
enum PushPermission { granted, denied, notAsked }

/// The phone's side of push (FCM), behind an interface so tests use a fake.
abstract class PushMessaging {
  Future<PushPermission> permission();

  /// Android 13+ shows the system prompt; no extra screen (review 16 §4).
  Future<PushPermission> requestPermission();

  /// This phone's push token. Null, or an error, when the phone couldn't
  /// register (F9): the caller tries again.
  Future<String?> token();
  Stream<String> get tokenRefresh;

  /// The data of a notification tapped while the app was closed.
  Future<Map<String, String>?> initialTap();

  /// Taps while the app runs in the background.
  Stream<Map<String, String>> get taps;

  /// Pushes that arrive while the app is open (no banner; screens refresh).
  Stream<Map<String, String>> get foreground;

  /// S4: the phone's notification settings for BuildVibes.
  Future<void> openSettings();

  /// F9: the phone's own page for BuildVibes (Autostart, battery).
  Future<void> openAppSettings();

  /// F102: takes a conversation's notification off the phone when it is
  /// opened. Android draws message pushes itself (FCM), tagged with the
  /// conversation's id ([tag]: the DM thread or the Space chat thread).
  Future<void> clearNotification(String tag);

  /// Who made the phone and its brand, lower case ("xiaomi", "redmi").
  Future<List<String>> phoneMakers();

  /// F9: counts a phone that got no push token, with nothing about the
  /// person.
  void reportNoToken();

  String get platform;
}

/// Firebase is set up in main(); without it (a build with no Firebase
/// file) push stays off and nothing else changes.
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging();

  static const _settings = MethodChannel('buildvibes/settings');

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  bool get _ready => Firebase.apps.isNotEmpty;

  static PushPermission _of(AuthorizationStatus s) => switch (s) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notAsked,
  };

  static Map<String, String> _data(RemoteMessage m) => {
    for (final e in m.data.entries) e.key: '${e.value}',
  };

  @override
  Future<PushPermission> permission() async => !_ready
      ? PushPermission.denied
      : _of((await _fcm.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async => !_ready
      ? PushPermission.denied
      : _of((await _fcm.requestPermission()).authorizationStatus);

  @override
  Future<String?> token() async => _ready ? _fcm.getToken() : null;

  @override
  Stream<String> get tokenRefresh =>
      _ready ? _fcm.onTokenRefresh : const Stream.empty();

  @override
  Future<Map<String, String>?> initialTap() async {
    if (!_ready) return null;
    final m = await _fcm.getInitialMessage();
    return m == null ? null : _data(m);
  }

  @override
  Stream<Map<String, String>> get taps => _ready
      ? FirebaseMessaging.onMessageOpenedApp.map(_data)
      : const Stream.empty();

  /// With what the notification says, for the in-app banner (F81).
  @override
  Stream<Map<String, String>> get foreground => _ready
      ? FirebaseMessaging.onMessage.map(
          (m) => {
            ..._data(m),
            '_title': ?m.notification?.title,
            '_body': ?m.notification?.body,
          },
        )
      : const Stream.empty();

  @override
  Future<void> openSettings() => _invoke('openNotificationSettings');

  @override
  Future<void> openAppSettings() => _invoke('openAppSettings');

  /// FCM shows a notification message under its tag with id 0, so the
  /// phone cancels (tag, 0). Never fails the screen that asked.
  @override
  Future<void> clearNotification(String tag) async {
    if (!_ready || !Platform.isAndroid) return;
    try {
      await _settings.invokeMethod<void>('cancelNotification', {'tag': tag});
    } on Exception catch (e) {
      debugPrint('cancelNotification: $e');
    }
  }

  Future<void> _invoke(String method) async {
    try {
      await _settings.invokeMethod<void>(method);
    } on PlatformException catch (e) {
      debugPrint('$method: $e');
    }
  }

  @override
  Future<List<String>> phoneMakers() async {
    if (!Platform.isAndroid) return const [];
    try {
      final makers = await _settings.invokeListMethod<String>('phoneMakers');
      return [for (final m in makers ?? const <String>[]) m.toLowerCase()];
    } on PlatformException catch (e) {
      debugPrint('phoneMakers: $e');
      return const [];
    }
  }

  @override
  void reportNoToken() => reportNoPushToken();

  @override
  String get platform => Platform.isIOS ? 'ios' : 'android';
}

/// Called before runApp. Push is optional: a failure leaves it off.
Future<void> initPush() async {
  try {
    await Firebase.initializeApp();
  } on Exception catch (e) {
    debugPrint('Firebase not set up, push off: $e');
  }
}

final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => FirebasePushMessaging(),
);
