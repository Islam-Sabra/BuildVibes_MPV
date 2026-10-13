import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/crash/crash_reports.dart';
import 'core/push/push_messaging.dart';
import 'core/l10n/locale_controller.dart';
import 'data/supabase/supabase_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  await initPush();
  // Crash reports in release builds only, with no personal text.
  try {
    await initCrashReports();
  } on Exception catch (e) {
    debugPrint('Crash reports off: $e');
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BuildVibesApp(),
    ),
  );
}
