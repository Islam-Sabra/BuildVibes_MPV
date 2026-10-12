import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/push/push_messaging.dart';
import '../../core/routing/app_routes.dart';
import '../../data/repositories/push_repository.dart';
import '../activity/activity_state.dart';
import '../entry/entry_state.dart';
import '../spaces/space_screen.dart' show SpaceOpen;

/// Whether the phone lets BuildVibes notify (S4 shows when it doesn't).
final pushPermissionProvider = FutureProvider.autoDispose<PushPermission>(
  (ref) => ref.watch(pushMessagingProvider).permission(),
);

/// Asked once, the first time the tabs open after onboarding.
const pushAskedKey = 'push_asked';

/// The language this phone's pushes are written in: the app's.
String pushLocale(WidgetRef ref) =>
    (ref.read(localeControllerProvider) ??
            resolveAppLocale(PlatformDispatcher.instance.locales))
        .languageCode;

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
/// registers this phone (and again when its token or the app language
/// changes), opens what a tapped notification is about, and refreshes Home
/// and Activity when one arrives with the app open.
class PushHost extends ConsumerStatefulWidget {
  const PushHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushHost> createState() => _PushHostState();
}

class _PushHostState extends ConsumerState<PushHost> {
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (!mounted || ref.read(appGateProvider) != AppGate.ready) return;
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
    if (permission == PushPermission.granted) {
      final token = await messaging.token();
      if (token != null) await _register(token);
    }
    if (!mounted) return;
    _subs
      ..add(messaging.tokenRefresh.listen(_register))
      ..add(messaging.taps.listen(_open))
      ..add(
        messaging.foreground.listen((_) {
          if (!mounted) return;
          refreshDay(ref.invalidate);
          ref.invalidate(activityProvider);
        }),
      );
    final first = await messaging.initialTap();
    if (first != null) _open(first);
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
          );
    } on Exception catch (e) {
      debugPrint('register push: $e');
    }
  }

  /// Only the app's own pages: a Space, its item or thread, a post, a
  /// person, or your profile.
  void _open(Map<String, String> data) {
    final route = data['route'];
    if (!mounted || route == null) return;
    final router = GoRouter.of(context);
    if (route == AppRoutes.profile) {
      router.go(route);
    } else if ([
      AppRoutes.spaces,
      AppRoutes.posts,
      AppRoutes.people,
    ].any((p) => route.startsWith('$p/'))) {
      router.push(
        route,
        extra: data['open'] == 'people' ? SpaceOpen.people : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The pushes follow the app language.
    ref.listen(localeControllerProvider, (_, _) async {
      final token = await ref.read(pushMessagingProvider).token();
      if (token != null) await _register(token);
    });
    return widget.child;
  }
}
