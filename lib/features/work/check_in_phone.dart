import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/location/location_reader.dart';
import '../../core/push/push_state.dart';
import '../../core/push/reaction_channel.dart';
import '../../core/push/reminders.dart' show PhoneNotificationHooks;
import '../../data/repositories/check_in_repository.dart';
import '../../data/repositories/push_repository.dart';
import '../../data/supabase/supabase_provider.dart' show initSupabase;
import '../../l10n/gen/app_localizations.dart';
import 'check_in_marking.dart';
import 'check_in_notice.dart';

/// Review 109 CI2 on the phone: the "Check-in" channel and its iOS
/// categories, the notification drawn from a check_in_open push (in the
/// foreground and with the app closed), and the Check in action.
///
/// - Android: Check in runs without opening the app, in a background
///   isolate ([checkInNotificationResponse]); the location is read in a
///   short foreground service of type location (geolocator's), never
///   with a background permission. Only when the person accepted the
///   warning on this phone; otherwise Check in opens the app, where the
///   warning comes first.
/// - iPhone: the actions open the app (Apple requires it to read the
///   location), which marks then.
///
/// What can only be tried on a phone (the isolates, the service, the OS
/// prompt) is kept thin here; the decisions are in check_in_notice.dart,
/// tested with fakes.

/// The plugin's notifications for check-ins.
class LocalCheckInNotifier implements CheckInNotifier {
  LocalCheckInNotifier(this.l10n);

  final AppLocalizations l10n;
  static final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> ensureChannel() async {
    try {
      // Review 113: the quiet Reactions channel, made with this one.
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(reactionsChannel(l10n));
    } on Object catch (e) {
      debugPrint('reactions channel: ${e.runtimeType}');
    }
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              checkInChannelId,
              l10n.checkInChannel,
              description: l10n.checkInChannelAbout,
              importance: Importance.max,
              playSound: true,
            ),
          );
    } on Object catch (e) {
      debugPrint('check-in channel: ${e.runtimeType}');
    }
  }

  @override
  Future<void> show(CheckInNotice n) async {
    try {
      await _plugin.show(
        id: n.id,
        title: n.title,
        body: n.body,
        payload: n.payload,
        notificationDetails: checkInNotificationDetails(l10n, n),
      );
    } on Object catch (e) {
      // A notification that can't show never stops the app.
      debugPrint('check-in notification: ${e.runtimeType}');
    }
  }
}

/// What the plugin draws for [n]: on Android the "check_in" channel (max
/// importance, sound), under [CheckInNotice.tag] (with id 0 it replaces
/// FCM's own notification), with its actions; on iOS time-sensitive,
/// with its category's buttons.
NotificationDetails checkInNotificationDetails(
  AppLocalizations l10n,
  CheckInNotice n,
) => NotificationDetails(
  android: AndroidNotificationDetails(
    checkInChannelId,
    l10n.checkInChannel,
    channelDescription: l10n.checkInChannelAbout,
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    tag: n.tag,
    icon: '@drawable/ic_stat_buildvibes',
    actions: [
      for (final a in n.actions)
        AndroidNotificationAction(
          a.id,
          a.label,
          showsUserInterface: a.opensApp,
          // The result takes its place (the same tag and id).
          cancelNotification: a.opensApp,
        ),
    ],
  ),
  iOS: DarwinNotificationDetails(
    categoryIdentifier: n.category,
    interruptionLevel: InterruptionLevel.timeSensitive,
  ),
);

/// iOS: the buttons on the server's alert (CHECK_IN_IN, CHECK_IN_OUT).
/// Both open the app: Check in to read the location, Open to look.
List<DarwinNotificationCategory> checkInDarwinCategories(
  AppLocalizations l10n,
) {
  DarwinNotificationCategory category(String id, String mark) =>
      DarwinNotificationCategory(
        id,
        actions: [
          DarwinNotificationAction.plain(
            checkInActionMark,
            mark,
            options: {DarwinNotificationActionOption.foreground},
          ),
          DarwinNotificationAction.plain(
            checkInActionOpen,
            l10n.checkInActionOpen,
            options: {DarwinNotificationActionOption.foreground},
          ),
        ],
      );
  return [
    category(checkInCategoryIn, l10n.checkInButton),
    category(checkInCategoryOut, l10n.checkOutButton),
  ];
}

/// A tap on a check-in notification that opened the app: Open, the
/// notification itself, or Check in when the warning must come first.
typedef CheckInTap = ({CheckInPush push, bool mark});

/// Taps that came before anyone listened (the app opening from one).
final _pendingTaps = Queue<CheckInTap>();
final _taps = StreamController<CheckInTap>.broadcast();

/// Its claim on the plugin's taps (PhoneNotificationHooks.claim).
bool claimCheckInTap(NotificationResponse r) {
  final push = CheckInPush.fromPayload(r.payload);
  if (push == null) return false;
  final tap = (push: push, mark: r.actionId == checkInActionMark);
  _taps.hasListener ? _taps.add(tap) : _pendingTaps.add(tap);
  return true;
}

/// Before runApp: the hooks of the one notification start, and FCM's
/// handler for a data push with the app closed.
void registerCheckInNotifications(SharedPreferences prefs) {
  final l10n = lookupAppLocalizations(_appLocale(prefs));
  PhoneNotificationHooks.categories = () => checkInDarwinCategories(l10n);
  PhoneNotificationHooks.background = checkInNotificationResponse;
  PhoneNotificationHooks.claim = claimCheckInTap;
  if (Firebase.apps.isNotEmpty) {
    FirebaseMessaging.onBackgroundMessage(checkInBackgroundPush);
  }
}

Locale _appLocale(SharedPreferences prefs) {
  final code = prefs.getString('app_language');
  if (code != null && AppLocalizations.delegate.isSupported(Locale(code))) {
    return Locale(code);
  }
  return resolveAppLocale(PlatformDispatcher.instance.locales);
}

/// The person on this phone, in a background isolate: Supabase started
/// there, its session read from the phone. Null when signed out.
Future<String?> _backgroundUser() async {
  try {
    await initSupabase();
  } on Object {
    // Already started in this isolate.
  }
  return Supabase.instance.client.auth.currentUser?.id;
}

/// FCM, app in the background or closed (Android data push): draws the
/// check-in notification from the server's words.
@pragma('vm:entry-point')
Future<void> checkInBackgroundPush(RemoteMessage message) async {
  final data = {for (final e in message.data.entries) e.key: '${e.value}'};
  final push = CheckInPush.fromData(data);
  if (push == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final l10n = lookupAppLocalizations(_appLocale(prefs));
  final user = await _backgroundUser();
  final accepted =
      user != null && (prefs.getBool(checkInConsentKey(user)) ?? false);
  await FlutterLocalNotificationsPlugin().initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_buildvibes'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
    onDidReceiveBackgroundNotificationResponse: checkInNotificationResponse,
  );
  final notifier = LocalCheckInNotifier(l10n);
  await notifier.ensureChannel();
  await notifier.show(checkInOpenNotice(l10n, push, accepted: accepted));
}

/// Android's Check in, without opening the app (a background isolate):
/// the mark, the location read once in a short foreground service, then
/// the result in place of the notification.
@pragma('vm:entry-point')
Future<void> checkInNotificationResponse(NotificationResponse r) async {
  if (r.actionId != checkInActionMark) return;
  final push = CheckInPush.fromPayload(r.payload);
  if (push == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final l10n = lookupAppLocalizations(_appLocale(prefs));
  final user = await _backgroundUser();
  if (user == null) return;
  final client = Supabase.instance.client;
  await markFromNotice(
    push: push,
    marker: CheckInMarker(
      repository: SupabaseCheckInRepository(client),
      reader: ServiceLocationReader(l10n),
      prefs: prefs,
      userId: user,
    ),
    notifier: LocalCheckInNotifier(l10n),
    l10n: l10n,
    time: checkInBackgroundTime(l10n, prefs),
    showText: () async =>
        (await SupabasePushRepository(client).settings()).messageText,
  );
}

/// The location from a notification's action on Android: geolocator's
/// foreground service of type location runs for the one reading, with
/// its own small notice, then stops. Never asks a permission (no screen
/// to ask on): refused, off or weak come back as a miss, and the mark
/// says "location not shared".
class ServiceLocationReader implements LocationReader {
  const ServiceLocationReader(this.l10n);

  final AppLocalizations l10n;

  @override
  Future<LocationRead> readOnce() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationRead.miss(LocationMiss.off);
      }
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return const LocationRead.miss(LocationMiss.refused);
      }
      final p = await Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: GeolocatorLocationReader.timeLimit,
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: l10n.checkInChannel,
            notificationText: l10n.checkInReadingOnce,
            notificationChannelName: l10n.checkInChannel,
          ),
        ),
      ).first;
      return LocationRead.point(
        p.latitude,
        p.longitude,
        p.accuracy,
        mocked: p.isMocked,
      );
    } on Object {
      return const LocationRead.miss(LocationMiss.weak);
    }
  }
}

/// Around the tabs: a check_in_open push with the app open is drawn as
/// its notification, as when closed; a tap on one opens the post's card
/// in its Space, and its Check in (when the warning must come first, or
/// on iPhone) runs the card's check-in there.
class CheckInHost extends ConsumerStatefulWidget {
  const CheckInHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CheckInHost> createState() => _CheckInHostState();
}

class _CheckInHostState extends ConsumerState<CheckInHost> {
  StreamSubscription<CheckInTap>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _taps.stream.listen(_tapped);
    unawaited(ref.read(checkInNotifierProvider).ensureChannel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      while (_pendingTaps.isNotEmpty && mounted) {
        _tapped(_pendingTaps.removeFirst());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Future<void> _tapped(CheckInTap tap) async {
    if (!mounted) return;
    final route = checkInPushRoute({
      'kind': checkInOpenKind,
      'post_id': tap.push.postId,
      'space_id': tap.push.spaceId,
    });
    if (route != null) GoRouter.of(context).go(route);
    if (!tap.mark) return;
    await checkInFromCard(
      context,
      ref,
      postId: tap.push.postId,
      spaceId: tap.push.spaceId,
      kind: tap.push.kind,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Y11: the phone's 24-hour setting, for notifications drawn with the
    // app closed.
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(checkInClock24Key) != use24) {
      unawaited(prefs.setBool(checkInClock24Key, use24));
    }
    ref.listen(pushArrivalProvider, (_, arrival) {
      final push = arrival == null ? null : CheckInPush.fromData(arrival.data);
      if (push == null) return;
      final marker = ref.read(checkInMarkerProvider);
      unawaited(
        ref
            .read(checkInNotifierProvider)
            .show(
              checkInOpenNotice(
                AppLocalizations.of(context),
                push,
                accepted: marker?.accepted ?? false,
              ),
            ),
      );
    });
    return widget.child;
  }
}

/// The phone's check-in notifications; a fake in tests.
final checkInNotifierProvider = Provider<CheckInNotifier>(
  (ref) => LocalCheckInNotifier(
    lookupAppLocalizations(
      ref.watch(localeControllerProvider) ??
          resolveAppLocale(PlatformDispatcher.instance.locales),
    ),
  ),
);
