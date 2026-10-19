import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which build is on this phone, for Settings → About (review 53 Part D),
/// so the founder and the lead can tell builds apart.
@immutable
class BuildInfo {
  const BuildInfo({
    required this.version,
    required this.build,
    required this.commit,
  });

  /// "0.9.0", from pubspec.yaml.
  final String version;

  /// The build number: Android's versionCode, the git commit count when
  /// the APK was built (android/app/build.gradle.kts, docs/release.md).
  final String build;

  /// The short git commit, passed at build time with
  /// `--dart-define=BV_COMMIT=<short sha>`; "dev" without it.
  final String commit;
}

/// What a part of the build reads when it isn't known.
const buildUnknown = 'dev';

/// `--dart-define=BV_COMMIT=<short sha>` (docs/release.md).
const buildCommit = String.fromEnvironment(
  'BV_COMMIT',
  defaultValue: buildUnknown,
);

/// The phone's own record of the installed app (the Android package), with
/// the commit from the build. Off Android, or with no answer, the version
/// and build read "dev" too.
final buildInfoProvider = FutureProvider<BuildInfo>((ref) async {
  const channel = MethodChannel('buildvibes/settings');
  String version = buildUnknown;
  String build = buildUnknown;
  try {
    final info = await channel.invokeMapMethod<String, Object?>('buildInfo');
    version = '${info?['version'] ?? buildUnknown}';
    build = '${info?['build'] ?? buildUnknown}';
  } on PlatformException catch (e) {
    debugPrint('build info: $e');
  } on MissingPluginException {
    // Not Android (or a test): nothing to read.
  }
  return BuildInfo(version: version, build: build, commit: buildCommit);
});
