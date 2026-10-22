import 'dart:io';

import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/core/l10n/bv_time.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

BvTime _time(String lang, {bool use24 = false}) =>
    BvTime(lookupAppLocalizations(Locale(lang)), lang, use24: use24);

void main() {
  setUpAll(() => initializeDateFormatting());

  group('review 54 A1: one time format', () {
    test('24-hour: "14:00" in both languages, with Western digits', () {
      for (final lang in ['en', 'ar']) {
        final t = _time(lang, use24: true);
        expect(t.clock(DateTime(2026, 10, 15, 14)), '14:00');
        expect(t.clock(DateTime(2026, 10, 15, 8, 14)), '08:14');
        expect(t.clock(DateTime(2026, 10, 15, 0, 5)), '00:05');
        // Nothing to put on a second line.
        expect(t.parts(DateTime(2026, 10, 15, 14)), (
          time: '14:00',
          period: null,
        ));
      }
    });

    test('12-hour English: "2:00\u00A0pm", always with the minutes, on one '
        'line', () {
      final en = _time('en');
      String at(int h, [int m = 0]) => en.clock(DateTime(2026, 10, 15, h, m));
      expect(at(14), '2:00\u00A0pm');
      expect(at(8, 14), '8:14\u00A0am');
      expect(at(0, 5), '12:05\u00A0am');
      expect(at(12), '12:00\u00A0pm');
      expect(at(23, 59), '11:59\u00A0pm');
      expect(en.parts(DateTime(2026, 10, 15, 14)), (
        time: '2:00\u00A0pm',
        period: null,
      ));
    });

    test('12-hour Arabic: the part of the day in words, at every '
        'boundary', () {
      final ar = _time('ar');
      String at(int h, int m) => ar.clock(DateTime(2026, 10, 15, h, m));
      // 00:00–11:59\u00A0صباحًا
      expect(at(0, 0), rtlRun('12:00\u00A0صباحًا'));
      expect(at(11, 59), rtlRun('11:59\u00A0صباحًا'));
      // 12:00–14:59\u00A0ظهرًا
      expect(at(12, 0), rtlRun('12:00\u00A0ظهرًا'));
      expect(at(14, 0), rtlRun('2:00\u00A0ظهرًا'));
      expect(at(14, 59), rtlRun('2:59\u00A0ظهرًا'));
      // 15:00–17:59\u00A0عصرًا
      expect(at(15, 0), rtlRun('3:00\u00A0عصرًا'));
      expect(at(17, 59), rtlRun('5:59\u00A0عصرًا'));
      // 18:00–23:59\u00A0مساءً
      expect(at(18, 0), rtlRun('6:00\u00A0مساءً'));
      expect(at(23, 58), rtlRun('11:58\u00A0مساءً'));
      expect(at(8, 14), isNot(contains('٨')));
    });

    test('review 50 F53: an Arabic time and its part of the day are one '
        'unit, kept whole beside a Latin name', () {
      final ar = _time('ar');
      final clock = ar.clock(DateTime(2026, 10, 15, 22, 58));
      expect(clock, rtlRun('10:58\u00A0مساءً'));
      // Opened right to left (RLI) and closed (PDI).
      expect(clock.codeUnits.first, 0x2067);
      expect(clock.codeUnits.last, 0x2069);
      // English and 24-hour need no unit: nothing changes.
      expect(
        _time('en').clock(DateTime(2026, 10, 15, 22, 58)),
        '10:58\u00A0pm',
      );
      expect(
        _time('ar', use24: true).clock(DateTime(2026, 10, 15, 22, 58)),
        '22:58',
      );
    });

    test(
      'review 82 S1: a time is one line everywhere, its part of the day '
      'beside it after a no-break space; the same words, never "م" / "ص"',
      () {
        final ar = _time('ar');
        final t = DateTime(2026, 10, 15, 23, 58);
        // A history line's time column too (the two-line slot is gone).
        expect(ar.parts(t), (time: ar.clock(t), period: null));
        expect(ar.clock(t), isNot(contains(' ')));
        expect(_time('en').clock(t), '11:58\u00A0pm');
        expect(ar.clock(t), rtlRun('11:58\u00A0مساءً'));
        expect(ar.clock(t), isNot(endsWith(' م')));
        expect(ar.clock(DateTime(2026, 10, 15, 9)), rtlRun('9:00\u00A0صباحًا'));
      },
    );

    test('when something happened: the time today, the weekday this past '
        'week, then the date (H1 v4)', () {
      final now = DateTime(2026, 10, 15, 23, 59);
      final en = _time('en');
      expect(en.moment(DateTime(2026, 10, 15, 13, 44), now), '1:44\u00A0pm');
      expect(
        _time('ar').moment(DateTime(2026, 10, 15, 6, 10), now),
        rtlRun('6:10\u00A0صباحًا'),
      );
      expect(
        _time('en', use24: true).moment(DateTime(2026, 10, 15, 6, 10), now),
        '06:10',
      );
      expect(en.moment(DateTime(2026, 10, 14, 23, 58), now), 'Wed');
      expect(en.moment(DateTime(2026, 10, 2, 9), now), '2 Oct');
      expect(_time('ar').moment(DateTime(2026, 10, 2, 9), now), '2 أكتوبر');
    });

    test('no other time formatting path in the app', () {
      // A clock time is written only by BvTime: no DateFormat for hours
      // and minutes anywhere else in lib/ (the phone's own time picker
      // follows the phone's clock setting by itself).
      final hits = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final path = f.path.replaceAll(r'\', '/');
        if (path.contains('/l10n/gen/') ||
            path.endsWith('core/l10n/bv_time.dart')) {
          continue;
        }
        final text = f.readAsStringSync();
        for (final pattern in [
          'DateFormat.Hm',
          'DateFormat.jm',
          'DateFormat.j(',
          'DateFormat.Hms',
          "'HH:mm'",
          "'h:mm",
          'formatShortAgo',
          'formatRowAgo',
        ]) {
          if (text.contains(pattern)) hits.add('$path: $pattern');
        }
      }
      expect(hits, isEmpty);
    });
  });
}
