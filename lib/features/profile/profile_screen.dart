import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../settings/language_sheet.dart';

/// Placeholder until the profile is built (week 3). Holds the language
/// switch for testing.
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
          ListTile(
            key: const Key('row-language'),
            leading: const Icon(Icons.translate),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(languageName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLanguageSheet(context),
          ),
        ],
      ),
    );
  }
}
