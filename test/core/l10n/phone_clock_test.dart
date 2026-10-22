import 'package:buildvibes/core/l10n/bv_time.dart';
import 'package:buildvibes/core/l10n/phone_clock.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('review 50 F37: a change to the 24-hour setting shows when the '
      'app comes back to the front, without a restart', (tester) async {
    // Android still reports 12-hour (the old value) until a restart; the
    // phone's own setting is what the platform call reads.
    tester.platformDispatcher.alwaysUse24HourFormatTestValue = false;
    addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
    var phone = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readPhoneClockProvider.overrideWithValue(() async => phone),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => PhoneClockScope(child: child!),
          home: Builder(
            builder: (context) =>
                Text(BvTime.of(context).clock(DateTime(2026, 10, 15, 14))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2:00\u00A0pm'), findsOneWidget);

    // Switched to 24-hour while the app was in the background.
    phone = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('14:00'), findsOneWidget);
  });
}
