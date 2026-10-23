import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/push/push_messaging.dart';
import '../../core/push/push_state.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_quiet_line.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../core/l10n/locale_controller.dart' show sharedPreferencesProvider;
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'push_host.dart' show pushNoTokenFor, pushPermissionProvider;

/// Xiaomi, Redmi and POCO phones stop an app in the background unless
/// Autostart is on and the battery saver leaves it alone, and then its
/// pushes never come (F9).
bool needsBackgroundSteps(List<String> makers) => makers.any(
  (m) => const {'xiaomi', 'redmi', 'poco'}.contains(m.trim().toLowerCase()),
);

/// "Fix it": on a Xiaomi family phone, the short steps and a way to the
/// phone's page for BuildVibes; elsewhere, the phone's notification
/// settings for BuildVibes.
Future<void> fixPush(BuildContext context, WidgetRef ref) async {
  final messaging = ref.read(pushMessagingProvider);
  final makers = await messaging.phoneMakers();
  if (!context.mounted) return;
  if (!needsBackgroundSteps(makers)) {
    await messaging.openSettings();
    return;
  }
  final l10n = AppLocalizations.of(context);
  await showBvSheet<void>(
    context: context,
    title: l10n.pushFixTitle,
    builder: (_) => PushFixSteps(onOpen: messaging.openAppSettings),
  );
}

/// The steps on a Xiaomi family phone, in the phone's own words, and the
/// button to its page for BuildVibes.
class PushFixSteps extends StatelessWidget {
  const PushFixSteps({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final steps = [
      l10n.pushFixAutostart,
      l10n.pushFixBattery,
      l10n.pushFixPlayServices,
      l10n.pushFixRestart,
    ];
    return Column(
      key: const Key('push-fix-steps'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s12,
      children: [
        for (final (i, step) in steps.indexed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvSpace.s12,
            children: [
              Text(
                '${i + 1}',
                style: type.labelMd.copyWith(color: BvColors.textAction),
              ),
              Expanded(child: Text(step, style: type.bodyMd)),
            ],
          ),
        const SizedBox(height: BvSpace.s4),
        BvButton(
          key: const Key('push-fix-open'),
          label: l10n.pushFixOpen,
          onPressed: onOpen,
        ),
      ],
    );
  }
}

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
