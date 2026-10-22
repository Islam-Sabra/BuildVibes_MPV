import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/core/l10n/bv_time.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

DaybookWords _words(String lang, {bool use24 = false}) =>
    DaybookWords(lookupAppLocalizations(Locale(lang)), lang, use24: use24);

/// Thursday 15 October, 6:30 in the morning (K3 v13 is the next day).
final _thu = DateTime(2026, 10, 15, 6, 30);

DaybookEvent _line(DaybookEventKind kind, {String? by, String? point}) =>
    DaybookEvent(
      id: 'e',
      kind: kind,
      at: _thu,
      byId: by ?? 'p-sara',
      byName: by == 'me' ? 'Islam Ahmed' : 'Sara Al-Mutairi',
      point: point,
    );

void main() {
  setUpAll(() => initializeDateFormatting());

  group('history lines for the new kinds, in the ledger form', () {
    test('English: "Sara Al-Mutairi · ticked: Ceiling paint touch-up"', () {
      final w = _words('en');
      final tick = _line(DaybookEventKind.ticked, point: 'Ceiling paint');
      expect(
        w.eventPhrase(tick, me: 'me', now: _thu),
        'Sara Al-Mutairi · ticked',
      );
      expect(w.eventDetail(tick), contains('Ceiling paint'));
      expect(
        w.eventPhrase(_line(DaybookEventKind.unticked), me: 'me', now: _thu),
        'Sara Al-Mutairi · unticked',
      );
      expect(
        w.eventPhrase(_line(DaybookEventKind.onMyWay), me: 'me', now: _thu),
        'Sara Al-Mutairi · On my way',
      );
      expect(
        w.eventPhrase(_line(DaybookEventKind.gotIt), me: 'me', now: _thu),
        'Sara Al-Mutairi · Got it',
      );
      expect(
        w.eventPhrase(_line(DaybookEventKind.received), me: 'me', now: _thu),
        'Sara Al-Mutairi · Received',
      );
      expect(
        w.eventPhrase(
          _line(DaybookEventKind.inMyCalendar, by: 'me'),
          me: 'me',
          now: _thu,
        ),
        'You · In my calendar',
      );
      // A trace on an earlier day says it as a sentence.
      expect(
        w.eventPhrase(tick, me: 'me', now: _thu, trace: true),
        'Sara Al-Mutairi ticked a point',
      );
      // Acknowledgements carry nothing after the phrase.
      expect(w.eventDetail(_line(DaybookEventKind.received)), isNull);
    });

    test('Arabic: "سارة المطيري · تأشير: …", "عمر حداد · في الطريق"', () {
      final w = _words('ar');
      DaybookEvent ar(DaybookEventKind kind, String name) =>
          DaybookEvent(id: 'e', kind: kind, at: _thu, byId: 'p', byName: name);
      expect(
        w.eventPhrase(
          ar(DaybookEventKind.ticked, 'سارة المطيري'),
          me: 'me',
          now: _thu,
        ),
        'سارة المطيري · تأشير',
      );
      expect(
        w.eventPhrase(
          ar(DaybookEventKind.onMyWay, 'عمر حداد'),
          me: 'me',
          now: _thu,
        ),
        'عمر حداد · في الطريق',
      );
      expect(
        w.eventPhrase(
          ar(DaybookEventKind.gotIt, 'عمر حداد'),
          me: 'me',
          now: _thu,
        ),
        'عمر حداد · فهمت',
      );
    });
  });

  group('names, never a count', () {
    test('every name in the list, in each language', () {
      expect(_words('en').names(['A', 'B', 'C']), 'A, B and C');
      expect(_words('ar').names(['سارة', 'عمر']), 'سارة وعمر');
    });

    test('the first two, then "and others"', () {
      final en = _words('en');
      expect(
        en.someNames(['Omar Haddad', 'Rakesh Nair']),
        'Omar Haddad and Rakesh Nair',
      );
      expect(en.someNames(['A', 'B', 'C', 'D']), 'A, B and others');
      expect(_words('ar').someNames(['أ', 'ب', 'ج']), 'أ، ب وآخرون');
    });

    test('who a checklist is for, the reader as "you"', () {
      final en = _words('en');
      const sara = DaybookPerson(id: 'p-sara', name: 'Sara Al-Mutairi');
      const omar = DaybookPerson(id: 'p-omar', name: 'Omar Haddad');
      expect(
        en.peopleFor([sara, omar], me: 'p-islam'),
        'For Sara Al-Mutairi and Omar Haddad',
      );
      expect(
        en.peopleFor([sara, omar], me: 'p-sara'),
        'For you and Omar Haddad',
      );
      expect(en.peopleFor([sara], me: 'p-sara'), 'For you');
      expect(
        _words('ar').peopleFor(const [
          DaybookPerson(id: 'a', name: 'سارة المطيري'),
          DaybookPerson(id: 'b', name: 'عمر حداد'),
        ], me: null),
        'لـ سارة المطيري وعمر حداد',
      );
    });
  });

  group('when an activity is (K2, K3 v13)', () {
    final start = DateTime(2026, 10, 16, 7);
    final end = DateTime(2026, 10, 16, 8);

    test('tomorrow, the time once with its part of the day', () {
      expect(
        _words('en').activityWhen(start, end, _thu),
        'Tomorrow, 7:00 to 8:00 am',
      );
      expect(
        _words('ar').activityWhen(start, end, _thu),
        'غدًا، من 7:00 إلى ${rtlRun('8:00 صباحًا')}',
      );
    });

    test('on its day: "starts in 30 min" in its last hour, then "on now"', () {
      final friday = DateTime(2026, 10, 16, 6, 30);
      expect(
        _words('en').activityWhen(start, end, friday),
        '7:00 to 8:00 am · starts in 30 min',
      );
      expect(
        _words('ar').activityWhen(start, end, friday),
        'من 7:00 إلى ${rtlRun('8:00 صباحًا')} · يبدأ بعد 30 دقيقة',
      );
      expect(
        _words('en').activityWhen(start, end, DateTime(2026, 10, 16, 7, 10)),
        '7:00 to 8:00 am · on now',
      );
      expect(
        _words('en').activityWhen(start, end, DateTime(2026, 10, 16, 5)),
        '7:00 to 8:00 am',
      );
    });

    test('later: the date; no end: the start only', () {
      expect(
        _words('en').activityWhen(DateTime(2026, 10, 20, 14), null, _thu),
        'Tue 20 Oct, 2:00 pm',
      );
    });

    test('a span across parts of the day says each', () {
      final t = BvTime(
        lookupAppLocalizations(const Locale('en')),
        'en',
        use24: false,
      );
      expect(
        t.range(DateTime(2026, 10, 16, 11, 30), DateTime(2026, 10, 16, 13)),
        '11:30 am to 1:00 pm',
      );
      final t24 = BvTime(
        lookupAppLocalizations(const Locale('ar')),
        'ar',
        use24: true,
      );
      expect(
        t24.range(DateTime(2026, 10, 16, 14), DateTime(2026, 10, 16, 15, 30)),
        'من 14:00 إلى 15:30',
      );
    });
  });

  test('a pin to midnight shows the day before: "Until Fri"', () {
    final en = _words('en');
    // Pinned to Saturday's midnight: Friday is its last day.
    expect(en.pinnedDay(DateTime(2026, 10, 17), _thu), 'Fri');
    // More than a week on: the date.
    expect(en.pinnedDay(DateTime(2026, 11, 3), _thu), '2 Nov');
    expect(_words('ar').pinnedDay(DateTime(2026, 10, 17), _thu), 'الجمعة');
  });

  test('F82, F85: a pin until a time, short and on the facts line', () {
    final en = _words('en');
    final ar = _words('ar');
    final friday2pm = DateTime(2026, 10, 16, 14);
    final today2pm = DateTime(_thu.year, _thu.month, _thu.day, 14);
    final endOfToday = DateTime(_thu.year, _thu.month, _thu.day + 1);
    expect(en.pinnedShort(friday2pm, _thu), 'Fri 2:00 pm');
    expect(en.pinnedShort(today2pm, _thu), '2:00 pm');
    expect(en.pinnedShort(DateTime(2026, 10, 17), _thu), 'Fri');
    expect(en.pinnedDay(endOfToday, _thu), 'today');
    expect(en.pinnedUntil(DateTime(2026, 10, 17), _thu), 'Until Friday 16 Oct');
    expect(en.pinnedUntil(friday2pm, _thu), 'Until Friday 16 Oct · 2:00 pm');
    expect(en.pinnedUntil(today2pm, _thu), 'Until today · 2:00 pm');
    expect(en.pinnedUntil(endOfToday, _thu), 'Until today');
    expect(
      ar.pinnedUntil(DateTime(2026, 10, 17), _thu),
      'حتى الجمعة 16 أكتوبر',
    );
    expect(ar.pinnedUntil(endOfToday, _thu), 'حتى اليوم');
    expect(
      ar.pinnedShort(friday2pm, _thu),
      allOf(startsWith('الجمعة '), contains('2:00')),
    );
  });

  test('the calendar leaf and the file fact', () {
    final en = _words('en');
    final leaf = en.leaf(DateTime(2026, 10, 16, 7));
    expect((leaf.weekday, leaf.day, leaf.month), ('FRI', '16', 'Oct'));
    final ar = _words('ar').leaf(DateTime(2026, 10, 16, 7));
    expect((ar.weekday, ar.day), ('الجمعة', '16'));
    expect(
      en.fileFact(
        const DaybookFile(
          id: 'f',
          name: 'M-201.pdf',
          mime: 'application/pdf',
          bytes: 2400000,
        ),
      ),
      'PDF · 2.3 MB',
    );
  });
}
