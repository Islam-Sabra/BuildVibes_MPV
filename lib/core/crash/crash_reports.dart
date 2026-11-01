import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
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

/// F9: a phone that got no push token after all its tries, as one
/// non-fatal report with no message, no user id and no keys, so the pilot
/// shows how many phones are affected (Crashlytics counts them by model).
/// Release builds only, like every crash report.
void reportNoPushToken() {
  if (Firebase.apps.isEmpty || !kReleaseMode) return;
  unawaited(
    FirebaseCrashlytics.instance.recordError(
      const ScrubbedError('PushNoToken'),
      null,
      fatal: false,
      printDetails: false,
    ),
  );
}

/// Review 110 A: an error the app shows rather than crashes on (the share
/// card's Space list), as one non-fatal report with its stack and
/// [reason] (W2: the error's first line, cut by characters, and how many
/// times the list ran). Release builds only.
void reportNonFatal(Object error, StackTrace? stack, {String? reason}) {
  if (Firebase.apps.isEmpty || !kReleaseMode) return;
  unawaited(
    FirebaseCrashlytics.instance.recordError(
      ScrubbedError(crashSummary(error)),
      stack,
      reason: reason,
      fatal: false,
      printDetails: false,
    ),
  );
}

/// Review 110 W2: the short code shown on screen: the error's type only,
/// never what it says.
String errorCode(Object error) => '${error.runtimeType}';

/// Review 110 W2: the error's first line, at most [most] characters
/// (never cut inside a character), for Crashlytics only.
String errorFirstLine(Object error, {int most = 120}) {
  final first = '$error'.split('\n').first.trim().characters;
  return first.length <= most ? first.toString() : '${first.take(most - 1)}…';
}
