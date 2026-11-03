import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/locale_controller.dart' show sharedPreferencesProvider;
import '../../core/push/alert_settings_phone.dart';
import '../../core/push/push_messaging.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../entry/entry_state.dart' show authUserIdProvider;
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'alerts_setup.dart';

/// Opens the alerts setup afresh (Fix it, Fix now): an earlier test's
/// arrival doesn't count for what the phone is now.
void openAlertsSetup(BuildContext context, WidgetRef ref) {
  ref
      .read(alertTestArrivedProvider.notifier)
      .reset(ref.read(clockProvider)().toUtc());
  unawaited(GoRouter.of(context).push(alertsSetupRoute()));
}

/// Review 114 PS3 (2732:40140), around the tabs: when an urgent alert was
/// opened late ([lateAlertProvider]) and a line of the setup is still off,
/// "An urgent alert arrived late" once per account. Fix now opens the
/// setup; Not now closes. Never again after that.
class LateAlertHost extends ConsumerStatefulWidget {
  const LateAlertHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LateAlertHost> createState() => _LateAlertHostState();
}

class _LateAlertHostState extends ConsumerState<LateAlertHost> {
  var _asking = false;

  Future<void> _late(LateAlert late) async {
    final user = ref.read(authUserIdProvider).value;
    if (user == null || _asking) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final key = alertLateAskedKey(user);
    if (prefs.getBool(key) ?? false) return;
    _asking = true;
    try {
      final AlertsSetup setup;
      try {
        setup = await loadAlertsSetup(
          messaging: ref.read(pushMessagingProvider),
          phone: ref.read(alertSettingsPhoneProvider),
          prefs: prefs,
        );
      } on Exception catch (e) {
        debugPrint('late alert: $e');
        return;
      }
      if (setup.offCount == 0 || !mounted) return;
      await prefs.setBool(key, true);
      // Over the page the alert opened (its Space): the router puts that
      // page in place a frame or two after the tap, and a sheet shown
      // before it would sit under it.
      for (var i = 0; i < 2; i++) {
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted) return;
      final fix = await showBvSheet<bool>(
        context: context,
        builder: (_) => LateAlertSheet(late: late, off: setup.offCount),
      );
      if (fix == true && mounted) openAlertsSetup(context, ref);
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(lateAlertProvider, (_, late) {
      if (late != null) unawaited(_late(late));
    });
    return widget.child;
  }
}

/// PS3's words and its two buttons; pops true for Fix now.
class LateAlertSheet extends StatelessWidget {
  const LateAlertSheet({super.key, required this.late, required this.off});

  final LateAlert late;

  /// How many lines of the setup are off.
  final int off;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final name = late.name;
    final by = name == null
        ? l10n.alertsLateByPlain(late.minutes)
        : l10n.alertsLateBy(inOwnDirection(name), late.minutes);
    return Column(
      key: const Key('alerts-late'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        Row(
          spacing: BvSpace.s8,
          children: [
            const Icon(
              BvIcons.warning,
              size: BvSize.iconMd,
              color: BvColors.iconAction,
            ),
            Expanded(child: Text(l10n.alertsLate, style: type.titleLg)),
          ],
        ),
        Text(
          '$by ${l10n.alertsOffCount(off)}',
          style: type.bodySm.copyWith(color: BvColors.textSecondary),
        ),
        const SizedBox(height: BvSpace.s4),
        BvButton(
          key: const Key('alerts-fix-now'),
          label: l10n.alertsFixNow,
          expand: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        BvButton(
          key: const Key('alerts-not-now'),
          label: l10n.alertsNotNow,
          style: BvButtonStyle.tertiary,
          expand: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
