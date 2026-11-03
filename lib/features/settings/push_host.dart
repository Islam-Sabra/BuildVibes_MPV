import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/network/signal_state.dart';
import '../../core/push/push_messaging.dart';
import '../../core/push/push_state.dart';
import '../../core/routing/app_routes.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/push_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../activity/activity_state.dart';
import '../entry/entry_state.dart';
import '../onboarding/alerts_setup.dart'
    show
        alertTestArrivedProvider,
        alertTestKind,
        alertsSetupRoute,
        lateAlertProvider,
        urgentAlertKinds;
import '../onboarding/alerts_setup_screen.dart' show AlertsSetupScreen;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/space_screen.dart' show SpaceOpen;
import '../work/check_in_notice.dart'
    show checkInNudgeOpen, checkInPushRoute, fillFromLastCheckIn;
import '../work/daybook_draft.dart' show daybookDraftProvider;
import '../../core/routing/open_thread.dart';

/// Whether the phone lets BuildVibes notify (S4 shows when it doesn't).
final pushPermissionProvider = FutureProvider.autoDispose<PushPermission>(
  (ref) => ref.watch(pushMessagingProvider).permission(),
);

/// The push kind that opens Scheduled whatever its route says.
const scheduledExpiringKind = 'scheduled_expiring';

/// Asked once, the first time the tabs open after onboarding.
const pushAskedKey = 'push_asked';

/// The language this phone's pushes are written in: the app's.
String pushLocale(WidgetRef ref) =>
    (ref.read(localeControllerProvider) ??
            resolveAppLocale(PlatformDispatcher.instance.locales))
        .languageCode;

/// This install's own id (F81), made once and kept on the phone: the
/// server replaces only this install's old token when a new one comes.
String pushInstallId(SharedPreferences prefs) {
  final kept = prefs.getString(pushInstallKey);
  if (kept != null) return kept;
  final id = newUuid();
  unawaited(prefs.setString(pushInstallKey, id));
  return id;
}

const pushInstallKey = 'push_install_id';

/// When this install first failed to get a push token (F96), kept until
/// one comes: after a day, Settings → Notifications says to restart the
/// phone.
const pushNoTokenSinceKey = 'push_no_token_since';

/// F96: how long the phone has gone without a push token, or null while
/// it has one (or hasn't tried).
Duration? pushNoTokenFor(SharedPreferences prefs, DateTime now) {
  final since = DateTime.tryParse(prefs.getString(pushNoTokenSinceKey) ?? '');
  return since == null ? null : now.difference(since);
}

/// Signing out: this phone gets no more pushes for the account. Never
/// stops the sign-out.
Future<void> unregisterPush(WidgetRef ref) async {
  try {
    final token = await ref.read(pushMessagingProvider).token();
    if (token != null) await ref.read(pushRepositoryProvider).unregister(token);
  } on Exception catch (e) {
    debugPrint('unregister push: $e');
  }
}

/// Push while signed in, around the tabs: asks for permission once,
/// registers this phone on every start (and again when its token or the
/// app language changes), opens what a tapped notification is about, and
/// tells open pages when one arrives with the app open.
///
/// Some phones fail to get a push token at first and Firebase doesn't try
/// again (F9, a Xiaomi in the pilot): the token is tried again with waits
/// between. With none after the tries, Home and Settings → Notifications
/// say notifications aren't reaching this phone ([pushHealthProvider]),
/// and the phone keeps trying (F96) until this install's token is
/// registered: on each return to the app, when the signal comes back, and
/// every [pushKeepTryingProvider] while the app is open.
class PushHost extends ConsumerStatefulWidget {
  const PushHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushHost> createState() => _PushHostState();
}

class _PushHostState extends ConsumerState<PushHost> {
  final _subs = <StreamSubscription<Object?>>[];
  late final AppLifecycleListener _life;

  /// This phone's token once known, and the one the server has.
  String? _token;
  String? _registered;
  var _gettingToken = false;

  /// The "no token" count is sent once per app start.
  var _reported = false;

  /// F96: the tries while the app is open, after the first ones failed.
  Timer? _keepTrying;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: () => unawaited(_resumed()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _life.dispose();
    _keepTrying?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  bool get _ready => mounted && ref.read(appGateProvider) == AppGate.ready;

  Future<void> _start() async {
    if (!_ready) return;
    final messaging = ref.read(pushMessagingProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    var permission = await messaging.permission();
    if (permission == PushPermission.notAsked &&
        !(prefs.getBool(pushAskedKey) ?? false)) {
      await prefs.setBool(pushAskedKey, true);
      permission = await messaging.requestPermission();
    }
    if (!mounted) return;
    ref.invalidate(pushPermissionProvider);
    _subs
      ..add(messaging.tokenRefresh.listen(_gotToken))
      ..add(messaging.taps.listen(_open))
      ..add(messaging.foreground.listen(_arrived));
    final first = await messaging.initialTap();
    if (first != null) _open(first);
    if (permission == PushPermission.granted) await _getToken();
  }

  /// Asks the phone for its token until it gives one, waiting longer
  /// between tries; then registers it. [once]: one more try (F96).
  Future<void> _getToken({bool once = false}) async {
    if (_gettingToken) return;
    _gettingToken = true;
    try {
      final messaging = ref.read(pushMessagingProvider);
      final delays = once
          ? const <Duration>[]
          : ref.read(pushTokenRetryDelaysProvider);
      for (var attempt = 0; ; attempt++) {
        String? token;
        try {
          token = await messaging.token();
        } on Exception catch (e) {
          debugPrint('push token: $e');
        }
        if (!mounted) return;
        if (token != null) {
          await _gotToken(token);
          return;
        }
        if (attempt >= delays.length) break;
        await Future<void>.delayed(delays[attempt]);
        if (!mounted) return;
      }
      final prefs = ref.read(sharedPreferencesProvider);
      if (!prefs.containsKey(pushNoTokenSinceKey)) {
        await prefs.setString(
          pushNoTokenSinceKey,
          ref.read(clockProvider)().toUtc().toIso8601String(),
        );
      }
      if (!mounted) return;
      ref.read(pushHealthProvider.notifier).set(PushHealth.notReaching);
      _keepTrying ??= Timer.periodic(
        ref.read(pushKeepTryingProvider),
        (_) => unawaited(_tryAgain()),
      );
      if (!_reported) {
        _reported = true;
        messaging.reportNoToken();
      }
    } finally {
      _gettingToken = false;
    }
  }

  Future<void> _gotToken(String token) async {
    if (!mounted) return;
    _token = token;
    _keepTrying?.cancel();
    _keepTrying = null;
    unawaited(ref.read(sharedPreferencesProvider).remove(pushNoTokenSinceKey));
    ref.read(pushHealthProvider.notifier).set(PushHealth.working);
    await _register(token);
  }

  /// F96: the timer's try, or the signal's return: one more ask for the
  /// token, or the server is given the one it missed.
  Future<void> _tryAgain() async {
    if (!_ready) return;
    final token = _token;
    if (token == null) {
      if (ref.read(pushHealthProvider) == PushHealth.notReaching) {
        await _getToken(once: true);
      }
    } else if (_registered != token) {
      await _register(token);
    }
  }

  /// Back in the app: notifications may have been turned on, or the phone
  /// fixed (Autostart, battery): try for the token again, and register it
  /// if the server didn't get it.
  Future<void> _resumed() async {
    if (!_ready) return;
    final messaging = ref.read(pushMessagingProvider);
    final PushPermission permission;
    try {
      permission = await messaging.permission();
    } on Exception catch (e) {
      debugPrint('push permission: $e');
      return;
    }
    if (!mounted) return;
    ref.invalidate(pushPermissionProvider);
    if (permission != PushPermission.granted) return;
    final token = _token;
    if (token == null) {
      await _getToken();
    } else if (_registered != token) {
      await _register(token);
    }
  }

  void _arrived(Map<String, String> data) {
    if (!mounted) return;
    // Review 114 PS2: Send me a test came through.
    if (data['kind'] == alertTestKind) {
      ref.read(alertTestArrivedProvider.notifier).arrived();
    }
    refreshDay(ref.invalidate);
    ref.invalidate(activityProvider);
    ref.read(pushArrivalProvider.notifier).add(data);
  }

  Future<void> _register(String token) async {
    if (!mounted) return;
    try {
      await ref
          .read(pushRepositoryProvider)
          .register(
            token,
            ref.read(pushMessagingProvider).platform,
            pushLocale(ref),
            installId: pushInstallId(ref.read(sharedPreferencesProvider)),
          );
      _registered = token;
    } on Exception catch (e) {
      // Tried again on the next return to the app.
      _registered = null;
      debugPrint('register push: $e');
    }
  }

  /// Only the app's own pages: a Space, its item or thread, a post, a
  /// person, a direct message thread, your profile, or Scheduled.
  void _open(Map<String, String> data) {
    if (!mounted) return;
    // Review 114: the test push opens the alerts setup with "The test
    // arrived" (one setup, never two).
    if (data['kind'] == alertTestKind) {
      ref.read(alertTestArrivedProvider.notifier).arrived();
      if (AlertsSetupScreen.open == 0) {
        unawaited(GoRouter.of(context).push(alertsSetupRoute()));
      }
      return;
    }
    // Review 114 PS3: an urgent alert opened late.
    if (urgentAlertKinds.contains(data['kind'])) {
      ref.read(lateAlertProvider.notifier).opened(data);
    }
    if (data['open'] == checkInNudgeOpen) {
      unawaited(_openNudge(data));
      return;
    }
    // Review 109: a check-in's push opens its card, or the creator's list.
    // Review 113: a scheduled post about to be cancelled opens Scheduled.
    final sent = data['kind'] == scheduledExpiringKind
        ? AppRoutes.scheduledPosts
        : checkInPushRoute(data) ?? data['route'] ?? postPushRoute(data);
    if (!mounted || sent == null) return;
    final route = pushRoute(sent, eventId: data['event_id']);
    final router = GoRouter.of(context);
    if (route == AppRoutes.profile) {
      router.go(route);
    } else if (route == AppRoutes.scheduledPosts) {
      // Review 108 PL2: "Couldn't post: …".
      unawaited(router.push(route));
    } else if ([
      AppRoutes.spaces,
      AppRoutes.posts,
      AppRoutes.people,
      AppRoutes.messages,
    ].any((p) => route.startsWith('$p/'))) {
      openRoute(
        router,
        route,
        extra: data['open'] == 'people' ? SpaceOpen.people : null,
      );
    }
  }

  /// Review 113 (17): "No check-in posted for today": the composer opens
  /// filled from the last check-in.
  Future<void> _openNudge(Map<String, String> data) async {
    final space = data['space_id'];
    if (space == null) return;
    final router = GoRouter.of(context);
    await fillFromLastCheckIn(
      ref.read(daybookDraftProvider(space).notifier),
      ref.read(daybookRepositoryProvider),
      fromPostId: data['from_post_id'],
      newId: newUuid(),
    );
    if (!mounted) return;
    unawaited(
      openRoute(router, AppRoutes.space(space), extra: SpaceOpen.write),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The pushes follow the app language.
    ref.listen(localeControllerProvider, (_, _) {
      final token = _token;
      if (token != null) unawaited(_register(token));
    });
    // F96: the signal is back (the outbox got through).
    ref.listen(signalProvider, (was, has) {
      if (was == false && has) unawaited(_tryAgain());
    });
    return widget.child;
  }
}

/// Review 113: a reaction's push (`post_reaction`) and an archived work
/// item's (`work_item_archived`) open the post, at its card in its Space,
/// when the push names no route of its own.
String? postPushRoute(Map<String, String> data) {
  final space = data['space_id'];
  final post = data['post_id'];
  if (space == null || post == null) return null;
  return switch (data['kind']) {
    'post_reaction' || 'work_item_archived' => AppRoutes.spaceCard(space, post),
    _ => null,
  };
}

/// Where a push's route opens. A work item's push names its card
/// (`/spaces/<space>/items/<item>`): the Space's daybook opens at that card
/// (F20), and at the line of [eventId] when the push carries one (today's
/// pushes don't: they open at the card).
String pushRoute(String route, {String? eventId}) {
  final item = RegExp(r'^/spaces/([^/]+)/items/([^/]+)$').firstMatch(route);
  return item == null
      ? route
      : AppRoutes.spaceCard(item.group(1)!, item.group(2)!, eventId: eventId);
}
