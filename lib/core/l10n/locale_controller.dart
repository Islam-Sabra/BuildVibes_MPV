import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/gen/app_localizations.dart';

/// Set in main() with the loaded instance, so reads are synchronous.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main()'),
);

/// The app language the person chose. Null means "follow the phone".
final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  static const _key = 'app_language';

  @override
  Locale? build() {
    final code = ref.watch(sharedPreferencesProvider).getString(_key);
    if (code == null) return null;
    final locale = Locale(code);
    return AppLocalizations.delegate.isSupported(locale) ? locale : null;
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, locale.languageCode);
  }
}

/// Picks the app language from the phone's languages when nothing is chosen.
/// Falls back to English.
Locale resolveAppLocale(List<Locale>? phoneLocales) {
  for (final locale in phoneLocales ?? const <Locale>[]) {
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
  }
  return AppLocalizations.supportedLocales.firstWhere(
    (l) => l.languageCode == 'en',
  );
}
