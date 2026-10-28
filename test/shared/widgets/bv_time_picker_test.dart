// Review 104 N11 (corrects review 102 N2): one time picker for the whole
// app. The clock face stays and is the default; the mode switch (where
// typed input used to be) goes between the clock and the wheels (hour 1–12,
// minutes in 5-minute steps). Nothing is typed in either. AM / PM is one
// choice above, in both. Both allow only valid times, and grey those
// already passed today. The last mode used is kept on the phone. In
// English and Arabic.
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_segmented.dart';
import 'package:buildvibes/shared/widgets/bv_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_component.dart';

Finder _key(String k) => find.byKey(Key(k));

/// Opens the picker over a button, and gives back what it returned.
Future<List<TimeOfDay?>> _open(
  WidgetTester tester,
  String lang, {
  required TimeOfDay initial,
  TimeOfDay? after,
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final picked = <TimeOfDay?>[];
  await pumpComponent(
    tester,
    Builder(
      builder: (context) => TextButton(
        key: const Key('open'),
        onPressed: () async => picked.add(
          await showBvTimePicker(
            context,
            initial: initial,
            title: 'When',
            after: after,
          ),
        ),
        child: const Text('open'),
      ),
    ),
    lang: lang,
  );
  await tester.tap(_key('open'));
  await tester.pumpAndSettle();
  return picked;
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Color _colour(WidgetTester tester, String key) => tester
    .widget<Text>(find.descendant(of: _key(key), matching: find.byType(Text)))
    .style!
    .color!;

void main() {
  testBoth('it opens on the clock face: AM / PM above, the hours round the '
      'dial, nothing typed', (tester, lang) async {
    final l10n = lookupAppLocalizations(Locale(lang));
    await _open(tester, lang, initial: const TimeOfDay(hour: 9, minute: 5));
    expect(_key('time-clock'), findsOneWidget);
    expect(_key('time-wheel'), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(TimePickerDialog), findsNothing);
    for (var h = 1; h <= 12; h++) {
      expect(
        find.descendant(
          of: _key('time-clock-hour-$h'),
          matching: find.text('$h'),
        ),
        findsOneWidget,
      );
    }
    final period = find.byType(BvSegmented<DayPeriod>);
    expect(
      tester
          .widget<BvSegmented<DayPeriod>>(period)
          .segments
          .map((s) => s.label),
      [l10n.timeWheelAm, l10n.timeWheelPm],
    );
    expect(
      tester.getRect(period).bottom,
      lessThanOrEqualTo(tester.getRect(_key('time-clock')).top),
    );
    // A clock is a clock: 12 at the top, 3 on the right, in both
    // languages.
    final c12 = tester.getCenter(_key('time-clock-hour-12'));
    final c3 = tester.getCenter(_key('time-clock-hour-3'));
    final c9 = tester.getCenter(_key('time-clock-hour-9'));
    expect(c12.dy, lessThan(c3.dy));
    expect(c3.dx, greaterThan(c9.dx));
  });

  testBoth('the hour, then the minutes in 5-minute steps; OK gives the '
      'time back', (tester, lang) async {
    final picked = await _open(
      tester,
      lang,
      initial: const TimeOfDay(hour: 9, minute: 5),
    );
    await _tap(tester, 'time-clock-hour-4');
    // The minutes come next by themselves: 00, 05 … 55.
    for (var m = 0; m < 60; m += 5) {
      expect(
        find.descendant(
          of: _key('time-clock-minute-$m'),
          matching: find.text(m.toString().padLeft(2, '0')),
        ),
        findsOneWidget,
      );
    }
    await _tap(tester, 'time-clock-minute-35');
    await _tap(tester, 'time-wheel-pm');
    await _tap(tester, 'time-picker-ok');
    expect(picked, [const TimeOfDay(hour: 16, minute: 35)]);
  });

  testBoth('a drag round the dial picks too', (tester, lang) async {
    final picked = await _open(
      tester,
      lang,
      initial: const TimeOfDay(hour: 9, minute: 5),
    );
    final from = tester.getCenter(_key('time-clock-hour-9'));
    final to = tester.getCenter(_key('time-clock-hour-11'));
    await tester.dragFrom(from, to - from);
    await tester.pumpAndSettle();
    await _tap(tester, 'time-picker-ok');
    expect(picked.single!.hour, 11);
  });

  testBoth('the clock greys the times passed today and never takes one', (
    tester,
    lang,
  ) async {
    final picked = await _open(
      tester,
      lang,
      initial: const TimeOfDay(hour: 10, minute: 0),
      after: const TimeOfDay(hour: 10, minute: 22),
    );
    // 9 am has passed entirely; 11 is to come.
    expect(
      _colour(tester, 'time-clock-hour-9'),
      isNot(_colour(tester, 'time-clock-hour-11')),
    );
    await _tap(tester, 'time-clock-hour-9');
    // Not taken: still on 10, the minutes not shown.
    expect(_key('time-clock-minute-0'), findsNothing);
    await _tap(tester, 'time-clock-hour-10');
    expect(
      _colour(tester, 'time-clock-minute-20'),
      isNot(_colour(tester, 'time-clock-minute-25')),
    );
    await _tap(tester, 'time-clock-minute-15');
    await _tap(tester, 'time-picker-ok');
    // It opened on the first time to come, and 10:15 wasn't taken.
    expect(picked, [const TimeOfDay(hour: 10, minute: 25)]);
  });

  testBoth('the mode switch goes to the wheels and back; the last mode is '
      'kept on the phone', (tester, lang) async {
    final l10n = lookupAppLocalizations(Locale(lang));
    final semantics = tester.ensureSemantics();
    final picked = await _open(
      tester,
      lang,
      initial: const TimeOfDay(hour: 9, minute: 5),
    );
    expect(
      tester.getSemantics(_key('time-picker-mode')).label,
      l10n.timePickerToWheels,
    );
    await _tap(tester, 'time-picker-mode');
    expect(_key('time-wheel'), findsOneWidget);
    expect(_key('time-clock'), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    // AM / PM stays above, the same one choice.
    expect(find.byType(BvSegmented<DayPeriod>), findsOneWidget);
    expect(
      tester.getSemantics(_key('time-picker-mode')).label,
      l10n.timePickerToClock,
    );
    await _tap(tester, 'time-picker-ok');
    expect(picked, [const TimeOfDay(hour: 9, minute: 5)]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(timePickerModeKey), 'wheels');

    // Opened again: the wheels.
    await _tap(tester, 'open');
    expect(_key('time-wheel'), findsOneWidget);
    await _tap(tester, 'time-picker-mode');
    expect(_key('time-clock'), findsOneWidget);
    await _tap(tester, 'time-picker-cancel');
    expect(prefs.getString(timePickerModeKey), 'clock');
    semantics.dispose();
  });

  testBoth('a time chosen on the clock is the time the wheels show', (
    tester,
    lang,
  ) async {
    final picked = await _open(
      tester,
      lang,
      initial: const TimeOfDay(hour: 9, minute: 5),
    );
    await _tap(tester, 'time-clock-hour-7');
    await _tap(tester, 'time-clock-minute-45');
    await _tap(tester, 'time-picker-mode');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey(('time-wheel-hour', 7))),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
    await _tap(tester, 'time-picker-ok');
    expect(picked, [const TimeOfDay(hour: 7, minute: 45)]);
  });

  testBoth('a screen reader hears each number as a button, the chosen one '
      'selected', (tester, lang) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, lang, initial: const TimeOfDay(hour: 9, minute: 5));
    final nine = tester
        .getSemantics(_key('time-clock-hour-9'))
        .getSemanticsData();
    expect(nine.label, '9');
    expect(nine.flagsCollection.isButton, isTrue);
    expect(nine.flagsCollection.isSelected, Tristate.isTrue);
    expect(
      tester
          .getSemantics(_key('time-clock-hour-10'))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      isNot(Tristate.isTrue),
    );
    semantics.dispose();
  });

  test('one picker for the whole app: no other time dialog in lib/', () {
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (path.contains('/l10n/gen/')) continue;
      final text = f.readAsStringSync();
      if (text.contains('showTimePicker(') ||
          text.contains('showBvTimeWheel(')) {
        found.add(path);
      }
    }
    expect(found, isEmpty);
  });
}
