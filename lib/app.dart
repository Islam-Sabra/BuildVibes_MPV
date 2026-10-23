import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/locale_controller.dart';
import 'core/l10n/phone_clock.dart';
import 'core/routing/app_router.dart';
import 'core/theme/bv_theme.dart';
import 'features/messages/dm_banner.dart';
import 'l10n/gen/app_localizations.dart';

class BuildVibesApp extends ConsumerWidget {
  const BuildVibesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale =
        ref.watch(localeControllerProvider) ??
        resolveAppLocale(PlatformDispatcher.instance.locales);

    return MaterialApp.router(
      routerConfig: ref.watch(appRouterProvider),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: BvTheme.forLocale(locale),
      // F37: times follow the phone's 24-hour setting without a restart.
      // F99: the direct-message banner sits over every screen.
      builder: (context, child) =>
          PhoneClockScope(child: DmBannerHost(child: child!)),
    );
  }
}
