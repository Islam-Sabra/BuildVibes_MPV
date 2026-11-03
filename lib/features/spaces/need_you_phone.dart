import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/open_thread.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/push/push_state.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/need_you.dart';
import '../../data/repositories/need_you_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../work/check_in_notice.dart' show CheckInNotice, CheckInNotifier;
import '../onboarding/alerts_setup.dart' show lateAlertOf, lateAlertProvider;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../work/check_in_phone.dart' show appLocaleOf, backgroundUser;
import 'need_you_notice.dart';

/// Review 113 NN2 on the phone: the `need_you` channel, its iOS category,
/// the notification drawn from a need_you push, and its answers.
///
/// - Android: On my way · Can't now answer without opening the app, in a
///   background isolate ([needYouNotificationResponse], reached through
///   check-in's one handler).
/// - iPhone: the actions open the app, which answers then.
///
/// What can only be tried on a phone is kept thin here; the decisions are
/// in need_you_notice.dart, tested with fakes.

class LocalNeedYouNotifier implements CheckInNotifier {
  LocalNeedYouNotifier(this.l10n);

  final AppLocalizations l10n;
  static final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> ensureChannel() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              needYouChannelId,
              l10n.needYouNow,
              description: l10n.needYouChannelAbout,
              importance: Importance.max,
              playSound: true,
            ),
          );
    } on Object catch (e) {
      debugPrint('need-you channel: ${e.runtimeType}');
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
        notificationDetails: needYouNotificationDetails(l10n, n),
      );
    } on Object catch (e) {
      debugPrint('need-you notification: ${e.runtimeType}');
    }
  }
}

/// On Android the "need_you" channel (max importance, sound), under the
/// notice's tag (with id 0 it replaces FCM's own), with its actions; on
/// iOS time-sensitive, with its category's buttons.
NotificationDetails needYouNotificationDetails(
  AppLocalizations l10n,
  CheckInNotice n,
) => NotificationDetails(
  android: AndroidNotificationDetails(
    needYouChannelId,
    l10n.needYouNow,
    channelDescription: l10n.needYouChannelAbout,
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
          cancelNotification: false,
        ),
    ],
  ),
  iOS: DarwinNotificationDetails(
    categoryIdentifier: n.category,
    interruptionLevel: InterruptionLevel.timeSensitive,
  ),
);

/// iOS: On my way · Can't now on the server's alert; both open the app.
List<DarwinNotificationCategory> needYouDarwinCategories(
  AppLocalizations l10n,
) => [
  DarwinNotificationCategory(
    needYouCategory,
    actions: [
      DarwinNotificationAction.plain(
        needYouActionComing,
        l10n.needYouOnMyWay,
        options: {DarwinNotificationActionOption.foreground},
      ),
      DarwinNotificationAction.plain(
        needYouActionCant,
        l10n.needYouCantNow,
        options: {DarwinNotificationActionOption.foreground},
      ),
    ],
  ),
];

/// A tap that opened the app: the notification, or an answer on iPhone.
typedef NeedYouTap = ({NeedYouPush push, NeedYouAnswer? answer});

final _pendingTaps = Queue<NeedYouTap>();
final _taps = StreamController<NeedYouTap>.broadcast();

/// Its claim on the plugin's taps (PhoneNotificationHooks.claim).
bool claimNeedYouTap(NotificationResponse r) {
  final push = NeedYouPush.fromPayload(r.payload);
  if (push == null) return false;
  final tap = (push: push, answer: needYouAnswerOfAction(r.actionId));
  _taps.hasListener ? _taps.add(tap) : _pendingTaps.add(tap);
  return true;
}

/// FCM with the app in the background or closed: draws the notification
/// with its buttons, from the server's words.
Future<void> needYouBackgroundPush(
  NeedYouPush push,
  SharedPreferences prefs,
) async {
  final l10n = lookupAppLocalizations(appLocaleOf(prefs));
  final notifier = LocalNeedYouNotifier(l10n);
  await notifier.ensureChannel();
  await notifier.show(needYouNotice(l10n, push));
}

/// Android's On my way · Can't now, without opening the app (a background
/// isolate). False when the response isn't one of them.
Future<bool> needYouNotificationResponse(NotificationResponse r) async {
  final answer = needYouAnswerOfAction(r.actionId);
  final push = NeedYouPush.fromPayload(r.payload);
  if (answer == null || push == null) return false;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final l10n = lookupAppLocalizations(appLocaleOf(prefs));
  if (await backgroundUser() == null) return true;
  await answerFromNotice(
    push: push,
    answer: answer,
    repository: SupabaseNeedYouRepository(Supabase.instance.client),
    notifier: LocalNeedYouNotifier(l10n),
    l10n: l10n,
  );
  return true;
}

/// The phone's Need you now notifications; a fake in tests.
final needYouNotifierProvider = Provider<CheckInNotifier>(
  (ref) => LocalNeedYouNotifier(
    lookupAppLocalizations(
      ref.watch(localeControllerProvider) ??
          resolveAppLocale(PlatformDispatcher.instance.locales),
    ),
  ),
);

/// Around the tabs: a need_you push with the app open is drawn as with it
/// closed; an answer to my call reads the calls again and says so; a tap
/// opens the Space, where the call shows; an answer from iPhone goes.
class NeedYouHost extends ConsumerStatefulWidget {
  const NeedYouHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NeedYouHost> createState() => _NeedYouHostState();
}

class _NeedYouHostState extends ConsumerState<NeedYouHost> {
  StreamSubscription<NeedYouTap>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _taps.stream.listen(_tapped);
    unawaited(ref.read(needYouNotifierProvider).ensureChannel());
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

  Future<void> _tapped(NeedYouTap tap) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    // Review 114 B1: over the tabs, so ← has them to go back to.
    unawaited(
      openRoute(GoRouter.of(context), AppRoutes.space(tap.push.spaceId)),
    );
    unawaited(_late(tap.push));
    final answer = tap.answer;
    if (answer == null) return;
    await answerFromNotice(
      push: tap.push,
      answer: answer,
      repository: ref.read(needYouRepositoryProvider),
      notifier: ref.read(needYouNotifierProvider),
      l10n: l10n,
    );
    if (mounted) ref.invalidate(needYouCallsProvider(tap.push.spaceId));
  }

  /// Review 114 PS3: a call opened late. The payload holds no words, so
  /// the caller's name comes from the calls.
  Future<void> _late(NeedYouPush push) async {
    final data = {'kind': needYouKind, 'sent_at': push.sentAt};
    if (lateAlertOf(data, ref.read(clockProvider)()) == null) return;
    String? name;
    try {
      final calls = await ref.read(needYouRepositoryProvider).calls();
      name = calls.where((c) => c.id == push.callId).firstOrNull?.fromName;
    } on Exception {
      name = null;
    }
    if (!mounted) return;
    ref.read(lateAlertProvider.notifier).opened({...data, 'from_name': name});
  }

  /// [data] is a need_you_answer push: the Space's line reads again, and
  /// the person hears who answered.
  Future<void> _answered(Map<String, String> data) async {
    final space = data['space_id'];
    if (space != null) ref.invalidate(needYouCallsProvider(space));
    final answer = NeedYouAnswer.fromJson(data['answer']);
    if (answer == null) return;
    var name = data['name'];
    if (name == null) {
      try {
        final calls = await ref.read(needYouRepositoryProvider).calls();
        name = calls.where((c) => c.id == data['call_id']).firstOrNull?.toName;
      } on Exception {
        name = null;
      }
    }
    if (!mounted || name == null) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        key: const Key('need-you-answered'),
        content: Text(
          l10n.needYouAnswerLine(name, needYouAnswerWord(l10n, answer)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pushArrivalProvider, (_, arrival) {
      if (arrival == null) return;
      final push = NeedYouPush.fromData(arrival.data);
      if (push != null) {
        ref.invalidate(needYouCallsProvider(push.spaceId));
        unawaited(
          ref
              .read(needYouNotifierProvider)
              .show(needYouNotice(AppLocalizations.of(context), push)),
        );
      } else if (arrival.data['kind'] == needYouAnswerKind) {
        unawaited(_answered(arrival.data));
      }
    });
    return widget.child;
  }
}
