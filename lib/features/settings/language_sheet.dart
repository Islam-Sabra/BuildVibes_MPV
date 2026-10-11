import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_choice_card.dart';
import '../../shared/widgets/bv_sheet.dart';

/// One single-choice list for the app language (rule 6: no separate switches).
Future<void> showLanguageSheet(BuildContext context) => showBvSheet(
  context: context,
  title: AppLocalizations.of(context).settingsLanguage,
  builder: (_) => const LanguageSheet(),
);

class LanguageSheet extends ConsumerWidget {
  const LanguageSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return BvChoiceList<String>(
      value: Localizations.localeOf(context).languageCode,
      options: [
        BvChoiceOption(
          key: const Key('language-en'),
          value: 'en',
          title: l10n.languageEnglish,
        ),
        BvChoiceOption(
          key: const Key('language-ar'),
          value: 'ar',
          title: l10n.languageArabic,
        ),
      ],
      onChanged: (code) {
        ref.read(localeControllerProvider.notifier).set(Locale(code));
        Navigator.of(context).pop();
      },
    );
  }
}
