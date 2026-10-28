// Review 102 N1, N2: one time picker for the whole app. Scroll wheels for
// the hour (1–12) and the minutes in 5-minute steps, AM / PM as one single
// choice above, no clock face and nothing typed; times already passed today
// greyed and never chosen. In English and Arabic.
import 'dart:io';

import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_segmented.dart';
import 'package:buildvibes/shared/widgets/bv_time_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

Finder _row(String wheel, int value) =>
    find.byKey(ValueKey(('time-wheel-$wheel', value)));

/// Opens the picker over a button, and gives back what it returned.
Future<List<TimeOfDay?>> _open(
  WidgetTester tester,
  String lang, {
  required TimeOfDay initial,
  TimeOfDay? after,
  String? cancelLabel,
}) async {
  final picked = <TimeOfDay?>[];
  await pumpComponent(
    tester,
    Builder(
      builder: (context) => TextButton(
        key: const Key('open'),
        onPressed: () async => picked.add(
          await showBvTimeWheel(
            context,
            initial: initial,
            title: 'When',
            cancelLabel: cancelLabel,
            after: after,
          ),
        ),
        child: const Text('open'),
      ),
    ),
    lang: lang,
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return picked;
}

/// Turns [wheel] by [steps] rows (up the list is later).
Future<void> _turn(WidgetTester tester, String wheel, int steps) async {
  await tester.drag(
    find.byKey(Key('time-wheel-$wheel')),
    Offset(0, -steps * BvTimeWheelSpec.rowHeight),
  );
  await tester.pumpAndSettle();
}

Future<void> _ok(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('time-wheel-ok')));
  await tester.pumpAndSettle();
}

void main() {
  testBoth('hours 1 to 12 and minutes in 5-minute steps; AM / PM one '
      'choice above; no clock face, nothing typed', (tester, lang) async {
    final l10n = lookupAppLocalizations(Locale(lang));
    await _open(tester, lang, initial: const TimeOfDay(hour: 9, minute: 5));
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    // Every row of each wheel (a wheel builds only those near its middle).
    List<Object?> rows(String wheel) => [
      for (final c
          in (tester
                      .widget<ListWheelScrollView>(
                        find.byKey(Key('time-wheel-$wheel')),
                      )
                      .childDelegate
                  as ListWheelChildListDelegate)
              .children)
        (c.key! as ValueKey<(String, int)>).value.$2,
    ];
    expect(rows('hour'), [for (var h = 1; h <= 12; h++) h]);
    expect(rows('minute'), [for (var m = 0; m < 60; m += 5) m]);
    // Western digits, two for the minutes.
    expect(
      find.descendant(of: _row('minute', 5), matching: find.text('05')),
      findsOneWidget,
    );
    final period = find.byType(BvSegmented<DayPeriod>);
    expect(period, findsOneWidget);
    expect(
      tester
          .widget<BvSegmented<DayPeriod>>(period)
          .segments
          .map((s) => s.label),
      [l10n.timeWheelAm, l10n.timeWheelPm],
    );
    // Above the wheels.
    expect(
      tester.getRect(period).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('time-wheel-hour'))).top,
      ),
    );
  });

  testBoth('the hour wheel sits before the minutes as the time is read: '
      'left in English, right of the minutes in Arabic reading', (
    tester,
    lang,
  ) async {
    await _open(tester, lang, initial: const TimeOfDay(hour: 9, minute: 5));
    final hour = tester.getCenter(find.byKey(const Key('time-wheel-hour')));
    final minute = tester.getCenter(find.byKey(const Key('time-wheel-minute')));
    // 9:05 reads the same way round in both: the hour on the left.
    expect(hour.dx, lessThan(minute.dx));
  });

  testBoth('turning the wheels picks the time; OK gives it back', (
    tester,
    lang,
  ) async {
    final picked = await _open(
      tester,
      lang,
      initial: const TimeOfDay(hour: 9, minute: 5),
    );
    await _turn(tester, 'hour', 2);
    await _turn(tester, 'minute', 3);
    await tester.tap(find.byKey(const Key('time-wheel-pm')));
    await tester.pumpAndSettle();
    await _ok(tester);
    expect(picked, [const TimeOfDay(hour: 23, minute: 20)]);
  });

  testBoth('a time between the steps opens on the next step', (
    tester,
    lang,
  ) async {
    final picked = await _open(
      tester,
      lang,
      initial: const TimeOfDay(hour: 14, minute: 7),
    );
    await _ok(tester);
    expect(picked, [const TimeOfDay(hour: 14, minute: 10)]);
  });

  testBoth('times already passed today are greyed and never chosen', (
    tester,
    lang,
  ) async {
    final picked = await _open(
      tester,
      lang,
      initial: const TimeOfDay(hour: 10, minute: 0),
      after: const TimeOfDay(hour: 10, minute: 22),
    );
    Color colour(String wheel, int v) => tester
        .widget<Text>(
          find.descendant(of: _row(wheel, v), matching: find.byType(Text)),
        )
        .style!
        .color!;
    // 9 am has passed entirely; at 10, the minutes up to 20.
    expect(colour('hour', 9), isNot(colour('hour', 11)));
    expect(colour('minute', 20), isNot(colour('minute', 25)));
    // It opened on the first time still to come.
    await _ok(tester);
    expect(picked, [const TimeOfDay(hour: 10, minute: 25)]);
  });

  testBoth('turned onto a passed time, the wheel goes on to the first one '
      'to come', (tester, lang) async {
    final picked = await _open(
      tester,
      lang,
      initial: const TimeOfDay(hour: 11, minute: 30),
      after: const TimeOfDay(hour: 10, minute: 22),
    );
    await _turn(tester, 'hour', -2); // 9 am: gone
    await _ok(tester);
    expect(picked, [const TimeOfDay(hour: 10, minute: 25)]);
  });

  testBoth('each step gives a light haptic', (tester, lang) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _open(tester, lang, initial: const TimeOfDay(hour: 9, minute: 5));
    await _turn(tester, 'minute', 3);
    expect(haptics, isNotEmpty);
    expect(haptics.toSet(), {'HapticFeedbackType.selectionClick'});
  });

  testBoth('the chosen row shows between two lines in the main text size', (
    tester,
    lang,
  ) async {
    await _open(tester, lang, initial: const TimeOfDay(hour: 9, minute: 5));
    expect(find.byKey(const Key('time-wheel-lines')), findsOneWidget);
    final chosen = tester.widget<Text>(
      find.descendant(of: _row('hour', 9), matching: find.byType(Text)),
    );
    // The two-size rule's main size: 15, Arabic 16.
    expect(chosen.style!.fontSize, lang == 'ar' ? 16 : 15);
  });

  testBoth('a screen reader changes each wheel as an adjustable control', (
    tester,
    lang,
  ) async {
    final l10n = lookupAppLocalizations(Locale(lang));
    final semantics = tester.ensureSemantics();
    final picked = await _open(
      tester,
      lang,
      initial: const TimeOfDay(hour: 9, minute: 5),
    );
    final hour = find.bySemanticsLabel(l10n.timeWheelHour);
    expect(tester.getSemantics(hour).value, '9');
    expect(
      tester
          .getSemantics(hour)
          .getSemanticsData()
          .hasAction(SemanticsAction.increase),
      isTrue,
    );
    tester.semantics.performAction(
      find.semantics.byLabel(l10n.timeWheelHour),
      SemanticsAction.increase,
    );
    await tester.pumpAndSettle();
    expect(tester.getSemantics(hour).value, '10');
    expect(
      tester.getSemantics(find.bySemanticsLabel(l10n.timeWheelMinutes)).value,
      '05',
    );
    await _ok(tester);
    expect(picked, [const TimeOfDay(hour: 10, minute: 5)]);
    semantics.dispose();
  });

  testBoth('at the first and last rows of a wheel a screen reader only '
      'goes the way there is', (tester, lang) async {
    final l10n = lookupAppLocalizations(Locale(lang));
    final semantics = tester.ensureSemantics();
    await _open(tester, lang, initial: const TimeOfDay(hour: 12, minute: 0));
    final hour = tester
        .getSemantics(find.bySemanticsLabel(l10n.timeWheelHour))
        .getSemanticsData();
    final minute = tester
        .getSemantics(find.bySemanticsLabel(l10n.timeWheelMinutes))
        .getSemanticsData();
    expect(hour.value, '12');
    expect(hour.hasAction(SemanticsAction.increase), isFalse);
    expect(hour.hasAction(SemanticsAction.decrease), isTrue);
    expect(minute.value, '00');
    expect(minute.hasAction(SemanticsAction.decrease), isFalse);
    expect(minute.hasAction(SemanticsAction.increase), isTrue);
    semantics.dispose();
  });

  testBoth('its own cancel words, and null back', (tester, lang) async {
    final picked = await _open(
      tester,
      lang,
      initial: const TimeOfDay(hour: 9, minute: 5),
      cancelLabel: 'No time',
    );
    await tester.tap(find.text('No time'));
    await tester.pumpAndSettle();
    expect(picked, [null]);
  });

  test('the next 5-minute mark an hour on', () {
    expect(
      nextFiveMinutesAfterAnHour(DateTime(2026, 10, 15, 10, 22)),
      DateTime(2026, 10, 15, 11, 25),
    );
    expect(
      nextFiveMinutesAfterAnHour(DateTime(2026, 10, 15, 10, 25)),
      DateTime(2026, 10, 15, 11, 30),
    );
    expect(
      nextFiveMinutesAfterAnHour(DateTime(2026, 10, 15, 23, 58)),
      DateTime(2026, 10, 16, 1),
    );
  });

  test('every time picker in the app is the wheel, and the "in the morning" '
      'line is gone', () {
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.replaceAll(r'\', '/').contains('/l10n/gen/')) continue;
      final text = f.readAsStringSync();
      if (text.contains('showTimePicker(') ||
          text.contains('notebookRemindMorning')) {
        found.add(f.path);
      }
    }
    expect(found, isEmpty);
    for (final arb in ['lib/l10n/app_en.arb', 'lib/l10n/app_ar.arb']) {
      expect(File(arb).readAsStringSync(), isNot(contains('RemindMorning')));
    }
  });
}
