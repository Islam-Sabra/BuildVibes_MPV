import 'dart:io';

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

    test('12-hour English: "2:00 pm", always with the minutes, on one '
        'line', () {
      final en = _time('en');
      String at(int h, [int m = 0]) => en.clock(DateTime(2026, 10, 15, h, m));
      expect(at(14), '2:00 pm');
      expect(at(8, 14), '8:14 am');
      expect(at(0, 5), '12:05 am');
      expect(at(12), '12:00 pm');
      expect(at(23, 59), '11:59 pm');
      expect(en.parts(DateTime(2026, 10, 15, 14)), (
        time: '2:00 pm',
        period: null,
      ));
    });

    test('12-hour Arabic: the part of the day in words, at every '
        'boundary', () {
      final ar = _time('ar');
      String at(int h, int m) => ar.clock(DateTime(2026, 10, 15, h, m));
      // 00:00–11:59 صباحًا
      expect(at(0, 0), '12:00 صباحًا');
      expect(at(11, 59), '11:59 صباحًا');
      // 12:00–14:59 ظهرًا
      expect(at(12, 0), '12:00 ظهرًا');
      expect(at(14, 0), '2:00 ظهرًا');
      expect(at(14, 59), '2:59 ظهرًا');
      // 15:00–17:59 عصرًا
      expect(at(15, 0), '3:00 عصرًا');
      expect(at(17, 59), '5:59 عصرًا');
      // 18:00–23:59 مساءً
      expect(at(18, 0), '6:00 مساءً');
      expect(at(23, 58), '11:58 مساءً');
      expect(at(8, 14), isNot(contains('٨')));
    });

    test('a two-line slot: Arabic 12-hour puts the period under the time '
        '(F15); one-line places use the same words, never "م" / "ص"', () {
      final ar = _time('ar');
      final t = DateTime(2026, 10, 15, 23, 58);
      expect(ar.parts(t), (time: '11:58', period: 'مساءً'));
      expect(ar.clock(t), '11:58 مساءً');
      expect(ar.clock(t), isNot(endsWith(' م')));
      expect(ar.clock(DateTime(2026, 10, 15, 9)), '9:00 صباحًا');
    });

    test('when something happened: the time today, the weekday this past '
        'week, then the date (H1 v4)', () {
      final now = DateTime(2026, 10, 15, 23, 59);
      final en = _time('en');
      expect(en.moment(DateTime(2026, 10, 15, 13, 44), now), '1:44 pm');
      expect(
        _time('ar').moment(DateTime(2026, 10, 15, 6, 10), now),
        '6:10 صباحًا',
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
