import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/routing/app_router.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../settings/language_sheet.dart';

/// Placeholder until the profile is built (week 3). Holds the language
/// switch for testing and, in debug builds only, the Components gallery.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageName = Localizations.localeOf(context).languageCode == 'ar'
        ? l10n.languageArabic
        : l10n.languageEnglish;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile)),
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
              if (kDebugMode)
                BvListRow(
                  key: const Key('row-components'),
                  leading: const BvRowIcon(BvIcons.settings),
                  title: l10n.componentsGallery,
                  onTap: () => context.push(AppRoutes.components),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
