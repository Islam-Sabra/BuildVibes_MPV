import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/join_wall.dart';
import '../settings/language_sheet.dart';

/// Placeholder until the profile is built (week 3). Holds the language
/// switch, sign out and, in debug builds only, the Components gallery.
/// Guests see a prompt to join.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    final languageName = Localizations.localeOf(context).languageCode == 'ar'
        ? l10n.languageArabic
        : l10n.languageEnglish;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile)),
      body: ListView(
        children: [
          if (guest)
            Padding(
              key: const Key('guest-card'),
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BvSpace.s12,
                children: [
                  Text(l10n.guestProfileTitle, style: type.titleLg),
                  Text(
                    l10n.joinWallBody,
                    style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                  ),
                  const JoinButtons(),
                ],
              ),
            ),
          BvListGroup(
            rows: [
              BvListRow(
                key: const Key('row-language'),
                leading: const BvRowIcon(BvIcons.language),
                title: l10n.settingsLanguage,
                trailing: BvRowTrailing.value(languageName),
                onTap: () => showLanguageSheet(context),
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
                  onTap: () => ref.read(authRepositoryProvider).signOut(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
