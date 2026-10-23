import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/push/push_messaging.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/push_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../profile/widgets/profile_parts.dart';
import '../spaces/space_errors.dart';
import 'push_fix.dart';
import 'push_host.dart';

final pushSettingsProvider = FutureProvider.autoDispose<PushSettings>(
  (ref) => ref.watch(pushRepositoryProvider).settings(),
);

/// Settings → Notifications (S3), MVP rows only. With the phone's
/// permission off, the S4 banner on top. Work items and requests to join
/// have no switch here: they follow each Space's level.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  /// Shown at once while saving; the server's copy after.
  PushSettings? _local;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the phone's settings: read the permission again (PushHost
  // tries for the token again).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(pushPermissionProvider);
    }
  }

  Future<void> _set(PushSettings next) async {
    final before = _local;
    setState(() => _local = next);
    try {
      await ref.read(pushRepositoryProvider).setSettings(next);
    } on SpaceException catch (e) {
      if (!mounted) return;
      setState(() => _local = before);
      showSpaceError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final off =
        ref.watch(pushPermissionProvider).value == PushPermission.denied;
    final loaded = ref.watch(pushSettingsProvider).value;
    final s = _local ?? loaded;

    Widget header(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s16,
        BvSpace.gutter,
        BvSpace.s8,
      ),
      child: Text(
        text,
        style: type.overline.copyWith(color: BvColors.textSecondary),
      ),
    );
    Widget faded(Widget child) =>
        off ? Opacity(opacity: BvPushSpec.offOpacity, child: child) : child;
    BvListRow toggle(
      String key,
      String title,
      bool value,
      PushSettings Function(bool) change,
    ) => BvListRow(
      key: Key(key),
      title: title,
      trailing: BvRowTrailing.toggle(
        value: value,
        onChanged: s == null ? null : (v) => _set(change(v)),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsNotifications),
        centerTitle: true,
      ),
      body: ListView(
        key: const Key('notifications'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
        children: [
          // F9: allowed, but the phone has no push token.
          const PushNotReachingLine(afterADay: true),
          if (off)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvSpace.s16,
                BvSpace.gutter,
                0,
              ),
              child: ProfileCard(
                child: Column(
                  key: const Key('push-off'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s8,
                  children: [
                    Row(
                      spacing: BvSpace.s8,
                      children: [
                        const Icon(
                          BvIcons.notifications,
                          size: BvSize.iconMd,
                          color: BvColors.iconPrimary,
                        ),
                        Expanded(
                          child: Text(l10n.pushOffTitle, style: type.titleMd),
                        ),
                      ],
                    ),
                    Text(
                      l10n.pushOffBody,
                      style: type.bodySm.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: BvSpace.s4),
                    BvButton(
                      key: const Key('push-open-settings'),
                      label: l10n.pushOpenSettings,
                      style: BvButtonStyle.secondary,
                      size: BvButtonSize.medium,
                      onPressed: () =>
                          ref.read(pushMessagingProvider).openSettings(),
                    ),
                  ],
                ),
              ),
            ),
          header(l10n.notifPeople),
          faded(
            BvListGroup(
              rows: [
                toggle(
                  'notif-followers',
                  l10n.notifFollowers,
                  s?.followers ?? true,
                  (v) => s!.copyWith(followers: v),
                ),
              ],
            ),
          ),
          header(l10n.notifPosts),
          faded(
            BvListGroup(
              rows: [
                toggle(
                  'notif-replies',
                  l10n.notifReplies,
                  s?.replies ?? true,
                  (v) => s!.copyWith(replies: v),
                ),
              ],
            ),
          ),
          header(l10n.notifMessages),
          faded(
            BvListGroup(
              rows: [
                toggle(
                  'notif-lock-text',
                  l10n.notifLockText,
                  s?.messageText ?? false,
                  (v) => s!.copyWith(messageText: v),
                ),
              ],
            ),
          ),
          header(l10n.notifSpaces),
          BvListGroup(
            rows: [
              BvListRow(
                key: const Key('notif-spaces'),
                title: l10n.notifSpacesLine,
                onTap: () => context.push(AppRoutes.spaces),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.gutter,
              BvSpace.s16,
              BvSpace.gutter,
              0,
            ),
            child: Text(
              l10n.notifFooter,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
