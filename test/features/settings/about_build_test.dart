// Review 53 Part D: Settings → About shows which build is on the phone.
import 'package:buildvibes/core/config/build_info.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _channel = MethodChannel('buildvibes/settings');

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

String _shown(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('about-build')))
    .data!
    // The parts keep their own direction (isolates) inside Arabic.
    .replaceAll(RegExp('[\u2066-\u2069]'), '');

void main() {
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('About shows the version, the build number and the commit; '
        'a build with no commit says "dev" [$lang]', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _channel,
            (call) async => call.method == 'buildInfo'
                ? {'version': '0.9.0', 'build': '295'}
                : null,
          );
      await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-settings');
      await _tap(tester, 'row-about');
      // Tests pass no BV_COMMIT: "dev".
      expect(buildCommit, buildUnknown);
      expect(_shown(tester), l10n.aboutBuild('0.9.0', '295', buildUnknown));
    });

    testWidgets('with no answer from the phone, the parts it can\'t read say '
        '"dev" [$lang]', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async => null);
      await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-settings');
      await _tap(tester, 'row-about');
      expect(
        _shown(tester),
        l10n.aboutBuild(buildUnknown, buildUnknown, buildUnknown),
      );
    });
  }
}
