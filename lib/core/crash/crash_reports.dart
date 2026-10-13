import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// What a crash report says about an error: its type only, never its
/// message. A message can hold what someone typed (a post, a chat message,
/// a name), and review 30 says crash reports never carry personal text.
/// The stack trace (file and function names) is sent as it is.
String crashSummary(Object error) => error.runtimeType.toString();

/// The error Crashlytics receives instead of the real one.
@immutable
class ScrubbedError {
  const ScrubbedError(this.type);

  final String type;

  @override
  String toString() => type;
}

/// Called after Firebase starts. Release builds only: debug and profile
/// builds send nothing. No user id, no custom keys, no logs are set.
Future<void> initCrashReports() async {
  if (Firebase.apps.isEmpty) return;
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);
  if (!kReleaseMode) return;

  // UI errors (a layout overflow, say) don't close the app: not fatal
  // (review 31).
  FlutterError.onError = (details) {
    crashlytics.recordError(
      ScrubbedError(crashSummary(details.exception)),
      details.stack,
      fatal: false,
      printDetails: false,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(
      ScrubbedError(crashSummary(error)),
      stack,
      fatal: true,
      printDetails: false,
    );
    return true;
  };
}
