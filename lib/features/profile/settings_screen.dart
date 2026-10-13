import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/routing/app_routes.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../entry/entry_state.dart';
import '../settings/language_sheet.dart';
import '../settings/push_host.dart';

/// Settings from the profile's gear: language, notifications, sign out and, in debug
/// builds only, the Components gallery.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    final languageName = Localizations.localeOf(context).languageCode == 'ar'
        ? l10n.languageArabic
        : l10n.languageEnglish;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          BvListGroup(
            rows: [
              BvListRow(
                key: const Key('row-language'),
                leading: const BvRowIcon(BvIcons.language),
                title: l10n.settingsLanguage,
                trailing: BvRowTrailing.value(languageName),
                onTap: () => showLanguageSheet(context),
              ),
              if (!guest)
                BvListRow(
                  key: const Key('row-notifications'),
                  leading: const BvRowIcon(BvIcons.notifications),
                  title: l10n.settingsNotifications,
                  onTap: () => context.push(AppRoutes.profileNotifications),
                ),
              if (!guest)
                BvListRow(
                  key: const Key('row-blocked'),
                  leading: const BvRowIcon(BvIcons.block),
                  title: l10n.blockedTitle,
                  onTap: () => context.push(AppRoutes.profileBlocked),
                ),
              if (kDebugMode)
                BvListRow(
                  key: const Key('row-components'),
                  leading: const BvRowIcon(BvIcons.settings),
                  title: l10n.componentsGallery,
                  onTap: () => context.push(AppRoutes.components),
                ),
              if (!guest)
                BvListRow(
                  key: const Key('row-sign-out'),
                  leading: const BvRowIcon(BvIcons.signOut),
                  title: l10n.signOut,
                  trailing: const BvRowTrailing.none(),
                  onTap: () async {
                    // This phone stops getting pushes for the account first.
                    await unregisterPush(ref);
                    await ref.read(authRepositoryProvider).signOut();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
