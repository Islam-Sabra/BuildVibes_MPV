import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/locale_controller.dart' show sharedPreferencesProvider;
import '../../core/push/alert_settings_phone.dart';
import '../../core/push/push_messaging.dart';
import '../../core/routing/app_routes.dart';
import '../../data/repositories/alert_test_repository.dart';
import '../../data/repositories/push_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_pill_button.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart' show ProfileCard;
import '../settings/push_host.dart'
    show pushAskedKey, pushInstallId, pushLocale, pushPermissionProvider;
import '../spaces/need_you_notice.dart' show needYouChannelId;
import '../spaces/need_you_phone.dart' show needYouNotifierProvider;
import 'alert_makers.dart';
import 'alerts_setup.dart';

/// Review 114 PS1 (2732:40001) and PS2 (2732:40067): so urgent alerts
/// reach you. Only the lines this phone's maker needs, each with one
/// button that opens its exact page in the phone's settings; "On" where
/// the phone confirms it, or after the person came back from the page.
/// Send me a test until the test arrives, then Done; Later skips. After
/// sign-up, [next] is where Later and Done go.
class AlertsSetupScreen extends ConsumerStatefulWidget {
  const AlertsSetupScreen({super.key, this.next});

  final String? next;

  /// How many are open: a tap on the test push opens one only when none
  /// is.
  static int open = 0;

  @override
  ConsumerState<AlertsSetupScreen> createState() => _AlertsSetupScreenState();
}

class _AlertsSetupScreenState extends ConsumerState<AlertsSetupScreen> {
  late final AppLifecycleListener _life;
  final _subs = <StreamSubscription<Map<String, String>>>[];

  /// The line whose page was opened; "On" once the person is back.
  AlertLine? _away;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: () => unawaited(_back()));
    final messaging = ref.read(pushMessagingProvider);
    void test(Map<String, String> data) {
      if (data['kind'] == alertTestKind && mounted) {
        ref.read(alertTestArrivedProvider.notifier).arrived();
      }
    }

    _subs
      ..add(messaging.foreground.listen(test))
      ..add(messaging.taps.listen(test));
    AlertsSetupScreen.open++;
  }

  @override
  void dispose() {
    _life.dispose();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    AlertsSetupScreen.open--;
    super.dispose();
  }

  /// Back from the phone's settings: the line just visited counts, the
  /// phone is read again, and a test that arrived meanwhile shows.
  Future<void> _back() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final away = _away;
    _away = null;
    if (away != null && away != AlertLine.notifications) {
      await prefs.setBool(alertVisitedKey(away), true);
    }
    await ref.read(alertTestArrivedProvider.notifier).readMark(prefs);
    if (!mounted) return;
    ref
      ..invalidate(alertsSetupProvider)
      ..invalidate(pushPermissionProvider);
  }

  Future<void> _turnOn(AlertLine line, AlertsSetup setup) async {
    final messaging = ref.read(pushMessagingProvider);
    final phone = ref.read(alertSettingsPhoneProvider);
    final maker = setup.maker;
    switch (line) {
      case AlertLine.notifications:
        if (await messaging.permission() == PushPermission.notAsked) {
          // The phone's own popup (Android 13+, an iPhone); asked here, so
          // the tabs don't ask again.
          await ref.read(sharedPreferencesProvider).setBool(pushAskedKey, true);
          await messaging.requestPermission();
        } else {
          _away = line;
          await messaging.openSettings();
        }
      case AlertLine.autostart:
        _away = line;
        await phone.openAutostart(maker?.autostart ?? const []);
      case AlertLine.floating:
        _away = line;
        // Made first, so the phone has the Need you now category to show.
        await ref.read(needYouNotifierProvider).ensureChannel();
        await phone.openChannel(needYouChannelId);
      case AlertLine.battery:
        _away = line;
        await phone.openBattery(maker?.battery ?? const []);
    }
    if (!mounted) return;
    ref
      ..invalidate(alertsSetupProvider)
      ..invalidate(pushPermissionProvider);
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(text)));

  /// Send me a test: this phone's token goes to the server first (with
  /// none there, the server sends nothing), then send_test_alert.
  Future<void> _sendTest() async {
    final l10n = AppLocalizations.of(context);
    final messaging = ref.read(pushMessagingProvider);
    if (await messaging.permission() != PushPermission.granted) {
      if (mounted) _say(l10n.alertsTestAllowFirst);
      return;
    }
    setState(() => _sending = true);
    try {
      String? token;
      try {
        token = await messaging.token();
      } on Exception catch (e) {
        debugPrint('push token: $e');
      }
      if (!mounted) return;
      if (token == null) {
        _say(l10n.pushNotReaching);
        return;
      }
      await ref
          .read(pushRepositoryProvider)
          .register(
            token,
            messaging.platform,
            pushLocale(ref),
            installId: pushInstallId(ref.read(sharedPreferencesProvider)),
          );
      ref
          .read(alertTestArrivedProvider.notifier)
          .sent(ref.read(clockProvider)().toUtc());
      await ref.read(alertTestRepositoryProvider).send();
      if (mounted) _say(l10n.alertsTestSent);
    } on AlertTestException catch (e) {
      if (mounted) {
        _say(switch (e.failure) {
          AlertTestFailure.tooMany => l10n.alertsTestTooMany,
          AlertTestFailure.network => l10n.errorNetwork,
          AlertTestFailure.other => l10n.errorGeneric,
        });
      }
    } on Exception catch (e) {
      debugPrint('send test: $e');
      if (mounted) _say(l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Later and Done: where sign-up was going, or back.
  void _leave() {
    final router = GoRouter.of(context);
    final next = widget.next;
    if (next != null) {
      router.go(next);
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final setup = ref.watch(alertsSetupProvider).value;
    final arrived = ref.watch(alertTestArrivedProvider);

    return Scaffold(
      key: const Key('alerts-setup'),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  BvSpace.gutter,
                  BvSpace.s32,
                  BvSpace.gutter,
                  BvSpace.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        width: BvSize.avatarLg,
                        height: BvSize.avatarLg,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: BvColors.surfaceBrandSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          BvIcons.alertsNotifications,
                          size: BvSize.iconLg,
                          color: BvColors.iconAction,
                        ),
                      ),
                    ),
                    const SizedBox(height: BvSpace.s16),
                    Text(l10n.alertsTitle, style: type.titleLg),
                    const SizedBox(height: BvSpace.s4),
                    if (setup != null) ...[
                      Text(
                        l10n.alertsSub(setup.lines.length),
                        style: type.bodySm.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: BvSpace.s12),
                      ProfileCard(
                        padding: false,
                        child: BvListGroup(
                          rows: [
                            for (final line in setup.lines)
                              _row(context, line, setup),
                          ],
                        ),
                      ),
                      const SizedBox(height: BvSpace.s16),
                      if (arrived)
                        const _Arrived()
                      else
                        Text(
                          l10n.alertsHint,
                          style: type.bodySm.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvSpace.s8,
                BvSpace.gutter,
                BvSpace.s16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BvSpace.s8,
                children: arrived
                    ? [
                        BvButton(
                          key: const Key('alerts-done'),
                          label: l10n.alertsDone,
                          expand: true,
                          onPressed: _leave,
                        ),
                      ]
                    : [
                        BvButton(
                          key: const Key('alerts-send-test'),
                          label: _sending
                              ? l10n.obSending
                              : l10n.alertsSendTest,
                          style: BvButtonStyle.secondary,
                          expand: true,
                          onPressed: _sending ? null : _sendTest,
                        ),
                        BvButton(
                          key: const Key('alerts-later'),
                          label: l10n.alertsLater,
                          style: BvButtonStyle.tertiary,
                          expand: true,
                          onPressed: _leave,
                        ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BvListRow _row(BuildContext context, AlertLine line, AlertsSetup setup) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final (icon, title, sub) = switch (line) {
      AlertLine.notifications => (
        BvIcons.alertsNotifications,
        l10n.alertsNotifications,
        l10n.alertsNotificationsSub,
      ),
      AlertLine.autostart => (
        BvIcons.alertsAutostart,
        l10n.alertsAutostart,
        l10n.alertsAutostartSub,
      ),
      AlertLine.floating => (
        BvIcons.alertsFloating,
        l10n.alertsFloating,
        l10n.alertsFloatingSub,
      ),
      AlertLine.battery => (
        BvIcons.alertsBattery,
        l10n.alertsBattery,
        l10n.alertsBatterySub,
      ),
    };
    final on = setup.on.contains(line);
    return BvListRow(
      key: Key('alerts-line-${line.name}'),
      leading: BvRowIcon(icon, ink: true),
      title: title,
      subtitle: sub,
      trailing: BvRowTrailing.badge(
        on
            ? Row(
                key: Key('alerts-on-${line.name}'),
                mainAxisSize: MainAxisSize.min,
                spacing: BvSpace.s4,
                children: [
                  const Icon(
                    BvIcons.check,
                    size: BvSize.iconSm,
                    color: BvColors.iconAction,
                  ),
                  Text(
                    l10n.alertsOn,
                    style: type.bodySm.copyWith(color: BvColors.textAction),
                  ),
                ],
              )
            : BvPillButton(
                key: Key('alerts-turn-on-${line.name}'),
                label: l10n.alertsTurnOn,
                onTap: () => unawaited(_turnOn(line, setup)),
              ),
      ),
      onTap: on ? null : () => unawaited(_turnOn(line, setup)),
    );
  }
}

/// PS2: "The test arrived. Urgent alerts will reach you."
class _Arrived extends StatelessWidget {
  const _Arrived();

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Container(
      key: const Key('alerts-arrived'),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvSpace.s12,
        vertical: BvSpace.s12,
      ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceBrandSoft,
        borderRadius: BvRadius.controlAll,
      ),
      child: Row(
        spacing: BvSpace.s8,
        children: [
          const Icon(
            BvIcons.checkCircle,
            size: BvSize.iconMd,
            color: BvColors.iconAction,
          ),
          Expanded(
            child: Text(
              AppLocalizations.of(context).alertsArrived,
              style: type.bodySm.copyWith(color: BvColors.textAction),
            ),
          ),
        ],
      ),
    );
  }
}
