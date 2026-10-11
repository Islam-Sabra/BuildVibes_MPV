import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/l10n/locale_controller.dart';
import '../../l10n/gen/app_localizations.dart';

/// One single-choice list for the app language (rule 6: no separate switches).
Future<void> showLanguageSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  builder: (_) => const LanguageSheet(),
);

class LanguageSheet extends ConsumerWidget {
  const LanguageSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = Localizations.localeOf(context).languageCode;
    final options = {
      'en': l10n.languageEnglish,
      'ar': l10n.languageArabic,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.gutter,
                vertical: BvSpace.s8,
              ),
              child: Text(
                l10n.settingsLanguage,
                style: BvType.of(context).headingMd,
              ),
            ),
            RadioGroup<String>(
              groupValue: current,
              onChanged: (code) {
                if (code == null) return;
                ref.read(localeControllerProvider.notifier).set(Locale(code));
                Navigator.of(context).pop();
              },
              child: Column(
                children: [
                  for (final entry in options.entries)
                    RadioListTile<String>(
                      key: Key('language-${entry.key}'),
                      value: entry.key,
                      title: Text(entry.value),
                      activeColor: BvColors.brandEnergy,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
