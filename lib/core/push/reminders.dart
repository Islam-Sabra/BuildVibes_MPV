import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Remind me (slice 10, review 83 Q2): a note's reminder is the phone's
/// own notification, set on this phone at the note's time, even with the
/// app closed. It never goes through the server and never reaches anyone
/// else. Behind an interface so tests use a fake.
abstract class PhoneReminders {
  /// Once, before the first [set]. [onTap] gets the note's id when its
  /// reminder is tapped while the app runs; [launchedBy] gives it when a
  /// tap opened the app.
  Future<void> init({
    required String channel,
    required String channelAbout,
    required void Function(String noteId) onTap,
  });

  Future<String?> launchedBy();

  /// Sets (or moves) [noteId]'s reminder to [at].
  Future<void> set(
    String noteId, {
    required DateTime at,
    required String title,
    required String body,
  });

  Future<void> cancel(String noteId);

  /// Whether reminders go on the minute: on Android 12+ only once the
  /// person allows exact alarms; elsewhere always.
  Future<bool> canBeExact();

  /// Opens the phone's own setting for exact alarms (Android 12+); the
  /// person decides there. Refused, reminders stay inexact.
  Future<void> openExactSetting();
}

final phoneRemindersProvider = Provider<PhoneReminders>(
  (ref) => RoutedReminders(
    LocalReminders(),
    onSpaceItem: ref.read(spaceReminderTapsProvider).add,
  ),
);

/// A Space post's reminder (review 105 Part 2, the Reminder swipe): one
/// person's phone notification, like a note's, under its own id.
typedef SpaceReminder = ({String spaceId, String postId});

const _spacePrefix = 'space-item:';

/// The id a Space post's reminder is set under on the phone.
String spaceReminderId(String spaceId, String postId) =>
    '$_spacePrefix$spaceId:$postId';

/// The Space post a reminder's id is for; null for a note's.
SpaceReminder? spaceReminderOf(String id) {
  if (!id.startsWith(_spacePrefix)) return null;
  final rest = id.substring(_spacePrefix.length).split(':');
  if (rest.length != 2 || rest.any((p) => p.isEmpty)) return null;
  return (spaceId: rest[0], postId: rest[1]);
}

/// Taps on a Space post's reminder, while the app runs or opening it.
final spaceReminderTapsProvider = Provider<StreamController<SpaceReminder>>((
  ref,
) {
  final taps = StreamController<SpaceReminder>.broadcast();
  ref.onDispose(taps.close);
  return taps;
});

/// The phone's reminders, with a Space post's taps sent to [onSpaceItem]
/// (its card) instead of My notebook's.
class RoutedReminders implements PhoneReminders {
  RoutedReminders(this._inner, {required this.onSpaceItem});

  final PhoneReminders _inner;
  final void Function(SpaceReminder item) onSpaceItem;

  @override
  Future<void> init({
    required String channel,
    required String channelAbout,
    required void Function(String noteId) onTap,
  }) => _inner.init(
    channel: channel,
    channelAbout: channelAbout,
    onTap: (id) {
      final item = spaceReminderOf(id);
      item == null ? onTap(id) : onSpaceItem(item);
    },
  );

  @override
  Future<String?> launchedBy() async {
    final id = await _inner.launchedBy();
    final item = id == null ? null : spaceReminderOf(id);
    if (item == null) return id;
    onSpaceItem(item);
    return null;
  }

  @override
  Future<void> set(
    String noteId, {
    required DateTime at,
    required String title,
    required String body,
  }) => _inner.set(noteId, at: at, title: title, body: body);

  @override
  Future<void> cancel(String noteId) => _inner.cancel(noteId);

  @override
  Future<bool> canBeExact() => _inner.canBeExact();

  @override
  Future<void> openExactSetting() => _inner.openExactSetting();
}

/// A note's reminder id on the phone: a stable 31-bit number from its id
/// (FNV-1a), the same on every start.
int reminderId(String noteId) {
  var h = 0x811c9dc5;
  for (final c in noteId.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

class LocalReminders implements PhoneReminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  var _channel = '';
  var _channelAbout = '';

  static const _channelId = 'reminders';

  @override
  Future<void> init({
    required String channel,
    required String channelAbout,
    required void Function(String noteId) onTap,
  }) async {
    _channel = channel;
    _channelAbout = channelAbout;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(
            '@drawable/ic_stat_buildvibes',
          ),
          // Push already asked for notifications.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          final id = r.payload;
          if (id != null) onTap(id);
        },
      );
    } on Object catch (e) {
      // No reminders on this phone; the notes still work.
      debugPrint('reminders: $e');
    }
  }

  @override
  Future<String?> launchedBy() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (!(details?.didNotificationLaunchApp ?? false)) return null;
      return details?.notificationResponse?.payload;
    } on Object catch (e) {
      debugPrint('reminders: $e');
      return null;
    }
  }

  @override
  Future<void> set(
    String noteId, {
    required DateTime at,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: reminderId(noteId),
        // An instant: the phone's clock and zone decide what it shows.
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channel,
            channelDescription: _channelAbout,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_stat_buildvibes',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: await _mode(),
        title: title,
        body: body,
        payload: noteId,
      );
    } on Object catch (e) {
      // A reminder that can't be set never stops the note.
      debugPrint('reminder: $e');
    }
  }

  /// On time when the phone allows exact alarms (F107 B12: Android's
  /// inexact window was up to an hour); inexact otherwise.
  Future<AndroidScheduleMode> _mode() async => await canBeExact()
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> canBeExact() async {
    final android = _android;
    if (android == null) return true;
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } on Object catch (e) {
      debugPrint('reminder exact check: $e');
      return false;
    }
  }

  @override
  Future<void> openExactSetting() async {
    try {
      await _android?.requestExactAlarmsPermission();
    } on Object catch (e) {
      debugPrint('reminder exact setting: $e');
    }
  }

  @override
  Future<void> cancel(String noteId) async {
    try {
      await _plugin.cancel(id: reminderId(noteId));
    } on Object catch (e) {
      debugPrint('reminder cancel: $e');
    }
  }
}
