import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/crash/crash_reports.dart';
import 'core/push/push_messaging.dart';
import 'core/l10n/locale_controller.dart';
import 'core/storage_report.dart';
import 'data/supabase/supabase_provider.dart';
import 'features/work/check_in_phone.dart';

Future<void> main() async {
  // Review 91: the native splash stays until start-up knows the first
  // screen; SplashHandover (app.dart) then removes it.
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await initSupabase();
  await initPush();
  // Crash reports in release builds only, with no personal text.
  try {
    await initCrashReports();
  } on Exception catch (e) {
    debugPrint('Crash reports off: $e');
  }
  final prefs = await SharedPreferences.getInstance();
  // Review 109 CI2: the check-in notifications' part of the one start,
  // and FCM's handler for a data push with the app closed.
  registerCheckInNotifications(prefs);
  unawaited(logStorageReport());
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BuildVibesApp(),
    ),
  );
}
