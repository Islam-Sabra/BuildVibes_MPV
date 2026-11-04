import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/crash/crash_reports.dart';
import 'core/push/push_messaging.dart';
import 'core/l10n/locale_controller.dart';
import 'core/file_cache.dart';
import 'core/storage_report.dart';
import 'data/supabase/supabase_provider.dart';
import 'features/scan/scan.dart' show PhoneDocumentScanner, cleanUpScans;
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
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  // Review 114 B2: measured first, then the cache cleaned and capped.
  unawaited(() async {
    await logStorageReport();
    final saved = [
      for (final key in prefs.getKeys())
        if (prefs.get(key) case final String value) value,
    ];
    await cleanUpFilesAtStart(saved, container.read(fileCacheProvider));
    // Review 103 (the lead's check, D19): scans nothing waits for, and the
    // scanner's own pages.
    try {
      cleanUpScans(
        Directory('${(await getApplicationDocumentsDirectory()).path}/scans'),
        pending: saved,
      );
    } on Object catch (e) {
      debugPrint('scans: ${e.runtimeType}');
    }
    await PhoneDocumentScanner.cleanUp();
  }());
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BuildVibesApp(),
    ),
  );
}
