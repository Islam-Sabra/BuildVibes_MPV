import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/push/push_messaging.dart';
import '../../core/push/push_state.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_quiet_line.dart';
import '../../core/l10n/locale_controller.dart' show sharedPreferencesProvider;
import '../onboarding/late_alert_sheet.dart' show openAlertsSetup;
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'push_host.dart' show pushNoTokenFor, pushPermissionProvider;

/// "Fix it" (F9): the alerts setup (review 114), the one place for it.
/// It shows only the lines this phone's maker needs.
void fixPush(BuildContext context, WidgetRef ref) =>
    openAlertsSetup(context, ref);

/// F9: "Notifications aren't reaching this phone · Fix it", while
/// notifications are allowed but the phone has no push token. With them
/// off, Settings → Notifications says so instead (S4).
///
/// [afterADay] (Settings, F96): after a day without a token, the line says
/// to restart the phone, then open BuildVibes.
class PushNotReachingLine extends ConsumerWidget {
  const PushNotReachingLine({super.key, this.afterADay = false});

  final bool afterADay;

  static const day = Duration(hours: 24);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final off =
        ref.watch(pushPermissionProvider).value == PushPermission.denied;
    if (off || ref.watch(pushHealthProvider) != PushHealth.notReaching) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final without = afterADay
        ? pushNoTokenFor(
            ref.watch(sharedPreferencesProvider),
            ref.read(clockProvider)(),
          )
        : null;
    final long = without != null && without >= day;
    return BvQuietLine(
      key: Key(long ? 'push-not-yet' : 'push-not-reaching'),
      icon: BvIcons.notificationsOff,
      text: long ? l10n.pushNotYet : l10n.pushNotReaching,
      actionLabel: l10n.pushFixIt,
      onAction: () => fixPush(context, ref),
    );
  }
}
