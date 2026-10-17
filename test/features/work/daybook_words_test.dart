import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/daybook_samples.dart';

DaybookWords _words(String lang, {bool use24 = true}) =>
    DaybookWords(lookupAppLocalizations(Locale(lang)), lang, use24: use24);

final _thu = DaybookSamples.thursday;

void main() {
  setUpAll(() => initializeDateFormatting());

  group('the prototype\'s meta lines', () {
    final en = _words('en');
    final ar = _words('ar');
    const me = DaybookSamples.islam;

    test('for someone, by a date', () {
      final post = const DaybookSamples('en').sleevesDone();
      final past = DateTime(2026, 10, 13, 9);
      expect(
        en.meta(post, me: me, now: past),
        'For Omar Haddad, by Thu 15 Oct',
      );
      final arPost = const DaybookSamples('ar').sleevesDone();
      expect(
        ar.meta(arPost, me: me, now: past),
        'لعمر حداد، موعده الخميس 15 أكتوبر',
      );
    });

    test('a name in the other script stays whole', () {
      final post = const DaybookSamples('en').sleevesDone();
      final past = DateTime(2026, 10, 13, 9);
      expect(
        ar.meta(post, me: me, now: past),
        'ل${inOwnDirection('Omar Haddad')}، موعده الخميس 15 أكتوبر',
      );
    });

    test('for you, by today at a time: never "before today" in Arabic', () {
      final post = const DaybookSamples('en').rebar();
      expect(en.meta(post, me: me, now: _thu), 'For you, by today 14:00');
      expect(ar.meta(post, me: me, now: _thu), 'لك، قبل الساعة 14:00 اليوم');
      expect(
        _words('en', use24: false).meta(post, me: me, now: _thu),
        'For you, by today 2 pm',
      );
    });

    test('today, tomorrow and another day, with and without a time', () {
      DaybookPost due(DateTime day, [DateTime? at]) =>
          const DaybookSamples('en').item(
            id: 'p',
            at: _thu,
            title: 't',
            authorId: 'x',
            authorName: 'X',
            ownerId: me,
            ownerName: 'I',
            due: day,
            dueAt: at,
          );
      final today = DateTime(2026, 10, 15);
      final tomorrow = DateTime(2026, 10, 16);
      final sunday = DateTime(2026, 10, 18);
      expect(en.meta(due(today), me: me, now: _thu), 'For you, by today');
      expect(ar.meta(due(today), me: me, now: _thu), 'لك، خلال اليوم');
      expect(en.meta(due(tomorrow), me: me, now: _thu), 'For you, by tomorrow');
      expect(ar.meta(due(tomorrow), me: me, now: _thu), 'لك، غدًا');
      expect(
        en.meta(due(tomorrow, DateTime(2026, 10, 16, 9)), me: me, now: _thu),
        'For you, by tomorrow 09:00',
      );
      expect(
        ar.meta(due(tomorrow, DateTime(2026, 10, 16, 9)), me: me, now: _thu),
        'لك، قبل الساعة 09:00 غدًا',
      );
      expect(en.meta(due(sunday), me: me, now: _thu), 'For you, by Sun 18 Oct');
      expect(
        ar.meta(due(sunday), me: me, now: _thu),
        'لك، موعده الأحد 18 أكتوبر',
      );
      expect(
        ar.meta(due(sunday, DateTime(2026, 10, 18, 9)), me: me, now: _thu),
        'لك، قبل الساعة 09:00 يوم الأحد 18 أكتوبر',
      );
      for (final words in [en, ar]) {
        for (final text in [
          words.meta(due(today), me: me, now: _thu),
          words.meta(due(tomorrow), me: me, now: _thu),
        ]) {
          expect(text, isNot(contains('قبل اليوم')));
        }
      }
    });

    test('late: was due, and how late (L1)', () {
      final s = const DaybookSamples('en');
      final late = s.l1().first;
      final fri = DaybookSamples.friday;
      expect(late.isLate(fri), isTrue);
      expect(late.lateDays(fri), 1);
      expect(
        en.meta(late, me: DaybookSamples.omar, now: fri),
        'For you, was due Thu 15 Oct',
      );
      expect(
        ar.meta(late, me: DaybookSamples.omar, now: fri),
        'لك، كان موعده الخميس 15 أكتوبر',
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(l10n.daybookLate(1), 'Late by 1 day');
      expect(l10n.daybookLate(3), 'Late by 3 days');
      expect(l10n.daybookLate(0), 'Late');
      expect(
        lookupAppLocalizations(const Locale('ar')).daybookLate(1),
        'متأخر يومًا واحدًا',
      );
    });
  });

  group('review 45 B2: every due pattern, in Arabic and English', () {
    const me = DaybookSamples.islam;
    DaybookPost due(DateTime day, [DateTime? at]) =>
        const DaybookSamples('en').item(
          id: 'p',
          at: _thu,
          title: 't',
          authorId: 'x',
          authorName: 'X',
          ownerId: me,
          ownerName: 'I',
          due: day,
          dueAt: at,
        );
    final today = DateTime(2026, 10, 15);
    final wednesday = DateTime(2026, 10, 21);
    final twoPm = DateTime(2026, 10, 15, 14);
    String meta(
      String lang,
      DaybookPost post,
      DateTime now, {
      bool use24 = true,
    }) => _words(lang, use24: use24).meta(post, me: me, now: now);

    test('by today, no time: "خلال اليوم"', () {
      expect(meta('ar', due(today), _thu), 'لك، خلال اليوم');
      expect(meta('en', due(today), _thu), 'For you, by today');
    });

    test('by tomorrow, no time: "غدًا"', () {
      final tomorrow = DateTime(2026, 10, 16);
      expect(meta('ar', due(tomorrow), _thu), 'لك، غدًا');
      expect(meta('en', due(tomorrow), _thu), 'For you, by tomorrow');
    });

    test('by a date: "موعده الأربعاء 21 أكتوبر", never "before"', () {
      expect(meta('ar', due(wednesday), _thu), 'لك، موعده الأربعاء 21 أكتوبر');
      expect(meta('en', due(wednesday), _thu), 'For you, by Wed 21 Oct');
      expect(meta('ar', due(wednesday), _thu), isNot(contains('قبل')));
    });

    test('by a time today: 12-hour as the AR frame, and 24-hour', () {
      expect(
        meta('ar', due(today, twoPm), _thu, use24: false),
        'لك، قبل الساعة 2 ظهرًا اليوم',
      );
      expect(meta('ar', due(today, twoPm), _thu), 'لك، قبل الساعة 14:00 اليوم');
      expect(
        meta('en', due(today, twoPm), _thu, use24: false),
        'For you, by today 2 pm',
      );
      expect(meta('en', due(today, twoPm), _thu), 'For you, by today 14:00');
    });

    test('late: "كان موعده …"', () {
      final friday = DateTime(2026, 10, 16, 9);
      expect(meta('ar', due(today), friday), 'لك، كان موعده الخميس 15 أكتوبر');
      expect(meta('en', due(today), friday), 'For you, was due Thu 15 Oct');
      expect(
        meta('ar', due(today, twoPm), DateTime(2026, 10, 15, 15)),
        'لك، كان موعده الساعة 14:00 اليوم',
      );
    });

    test('the 12-hour clock: the part of the day in words', () {
      String ar(int h, [int m = 0]) =>
          _words('ar', use24: false).clock(DateTime(2026, 10, 15, h, m));
      String en(int h, [int m = 0]) =>
          _words('en', use24: false).clock(DateTime(2026, 10, 15, h, m));
      expect(ar(8, 14), '8:14 صباحًا');
      expect(ar(14), '2 ظهرًا');
      expect(ar(16, 30), '4:30 عصرًا');
      expect(ar(20), '8 مساءً');
      expect(en(0, 5), '12:05 am');
      expect(en(12), '12 pm');
    });

    test("the large stamp's line: the short name in capitals, the time", () {
      final at = DateTime(2026, 10, 15, 9, 40);
      expect(_words('en').stampLine('Omar Haddad', at), 'OMAR H · 09:40');
      expect(_words('ar').stampLine('عمر حداد', at), 'عمر ح · 09:40');
      expect(_words('en').stampLine('Sara Al-Mutairi', at), 'SARA A · 09:40');
    });

    test('the writing card: one line for the day, a due with a time', () {
      expect(_words('en').compactDate(today), 'Thursday 15 October');
      expect(_words('ar').compactDate(today), 'الخميس 15 أكتوبر');
      final sunday = DateTime(2026, 10, 18);
      expect(_words('en').dueProperty(sunday, null), 'Sun 18 Oct');
      expect(
        _words('ar').dueProperty(sunday, DateTime(2026, 10, 18, 14)),
        'الأحد 18 أكتوبر، 14:00',
      );
    });
  });

  group('Late (review 44, answer 3)', () {
    DaybookPost post({
      DateTime? due,
      DateTime? at,
      WorkStatus status = WorkStatus.open,
      bool cancelled = false,
    }) => DaybookPost(
      id: 'p',
      kind: DaybookPost.workItemKind,
      createdAt: _thu,
      title: 't',
      dueDate: due,
      dueAt: at,
      cancelled: cancelled,
      item: DaybookItem(status: status),
    );
    final today = DateTime(2026, 10, 15);

    test('a date-only item is late from the next day', () {
      expect(post(due: today).isLate(DateTime(2026, 10, 15, 23, 59)), isFalse);
      expect(post(due: today).isLate(DateTime(2026, 10, 16, 0, 1)), isTrue);
    });

    test('a timed item is late after its time, the same day', () {
      final p = post(due: today, at: DateTime(2026, 10, 15, 14));
      expect(p.isLate(DateTime(2026, 10, 15, 13, 59)), isFalse);
      expect(p.isLate(DateTime(2026, 10, 15, 14, 1)), isTrue);
      expect(p.lateDays(DateTime(2026, 10, 15, 14, 1)), 0);
    });

    test('only open, live items are late', () {
      final later = DateTime(2026, 10, 20);
      expect(post(due: today, status: WorkStatus.done).isLate(later), isFalse);
      expect(
        post(due: today, status: WorkStatus.checked).isLate(later),
        isFalse,
      );
      expect(post(due: today, cancelled: true).isLate(later), isFalse);
      expect(post().isLate(later), isFalse);
    });
  });

  group('the masthead and the edited line', () {
    test('day N on site counts calendar days, day 1 the start', () {
      final en = _words('en');
      expect(
        en.dateLine(DateTime(2026, 10, 15), DaybookSamples.siteStart),
        '15 October, day 41 on site',
      );
      expect(
        en.dateLine(DateTime(2026, 9, 5), DaybookSamples.siteStart),
        '5 September, day 1 on site',
      );
      expect(
        _words('ar').dateLine(DateTime(2026, 10, 15), DaybookSamples.siteStart),
        '15 أكتوبر، اليوم 41 في الموقع',
      );
      // No start date, or before it: the date only, never a count.
      expect(en.dateLine(DateTime(2026, 10, 15), null), '15 October');
      expect(
        en.dateLine(DateTime(2026, 9, 4), DaybookSamples.siteStart),
        '4 September',
      );
    });

    test('edited: due moved from Thu to today', () {
      final edit = const DaybookSamples('en').rebar().dueEdit;
      expect(
        _words('en').editedDue(edit, _thu),
        'Edited: due moved from Thu to today',
      );
      expect(
        _words('ar').editedDue(edit, _thu),
        'عُدّل: نُقل الموعد من الخميس إلى اليوم',
      );
      final timeOnly = DaybookDueEdit(
        from: DateTime(2026, 10, 15),
        to: DateTime(2026, 10, 15),
        fromAt: DateTime(2026, 10, 15, 14),
        toAt: DateTime(2026, 10, 15, 16),
      );
      expect(
        _words('en').editedDue(timeOnly, _thu),
        'Edited: due moved from 14:00 to 16:00',
      );
      expect(_words('en').editedDue(null, _thu), isNull);
      expect(
        _words(
          'en',
        ).editedDue(DaybookDueEdit(from: DateTime(2026, 10, 15)), _thu),
        isNull,
      );
    });

    test('the clock follows the phone, with Western digits', () {
      final t = DateTime(2026, 10, 15, 8, 14);
      expect(_words('en').clock(t), '08:14');
      expect(_words('ar').clock(t), '08:14');
      expect(_words('en', use24: false).clock(t), '8:14 am');
      expect(_words('ar', use24: false).clock(t), isNot(contains('٨')));
    });
  });

  group('space_post_json', () {
    test('a work item: stamp, clip, points, cover, the due edit', () {
      final post = DaybookPost.fromJson({
        'id': 'p1',
        'space_id': 's',
        'kind': 'work_item',
        'status': 'live',
        'author_id': 'a',
        'author_name': 'Sara Al-Mutairi',
        'title': 'Rebar spacing, level 3 slab',
        'place': 'Level 3',
        'due_date': '2026-10-15',
        'due_at': '2026-10-15T11:00:00+00:00',
        'created_at': '2026-10-15T07:05:00+00:00',
        'item': {
          'ref': 'KCT-021',
          'status': 'done',
          'owner_id': 'o',
          'owner_name': 'Islam Ahmed',
        },
        'points': {'total': 2, 'ticked': 0},
        'stamp': {
          'kind': 'done',
          'at': '2026-10-15T06:40:00+00:00',
          'by_name': 'Omar Haddad',
        },
        'needs_me': true,
        'cover_path': 's/posts/p1/a.jpg',
        'edits': [
          {
            'at': '2026-10-15T07:06:00+00:00',
            'by_name': 'Sara Al-Mutairi',
            'changes': {
              'due': {
                'from': '2026-10-22',
                'to': '2026-10-15',
                'to_at': '2026-10-15T11:00:00+00:00',
              },
            },
          },
        ],
      });
      expect(post.isWorkItem, isTrue);
      expect(post.dueDate, DateTime(2026, 10, 15));
      expect(post.dueAt, DateTime.utc(2026, 10, 15, 11));
      expect(post.item!.status, WorkStatus.done);
      expect(post.item!.ownerName, 'Islam Ahmed');
      expect(post.stamp!.kind, DaybookStampKind.done);
      expect(post.stamp!.byName, 'Omar Haddad');
      expect(post.needsMe, isTrue);
      expect(post.pointsTotal, 2);
      expect(post.coverPath, 's/posts/p1/a.jpg');
      expect(post.dueEdit!.from, DateTime(2026, 10, 22));
      expect(post.dueEdit!.to, DateTime(2026, 10, 15));
      expect(post.dueEdit!.timeOnly, isFalse);
    });

    test('a cancelled post, and an edit that left the due alone', () {
      final post = DaybookPost.fromJson({
        'id': 'p2',
        'kind': 'work_item',
        'status': 'cancelled',
        'title': 'x',
        'created_at': '2026-10-15T07:05:00+00:00',
        'stamp': {'kind': 'cancelled', 'at': '2026-10-15T09:05:00+00:00'},
        'edits': [
          {
            'changes': {
              'title': {'from': 'a', 'to': 'x'},
            },
          },
        ],
      });
      expect(post.cancelled, isTrue);
      expect(post.stamp!.kind, DaybookStampKind.cancelled);
      expect(post.dueEdit, isNull);
      expect(post.authorName, isNull);
    });

    test('the month: post times grouped into the phone\'s days', () {
      final month = DaybookMonth.fromRows([
        {
          'kind': 'posts',
          'at': DateTime(2026, 10, 14, 23, 45).toUtc().toIso8601String(),
          'day': null,
        },
        {
          'kind': 'posts',
          'at': DateTime(2026, 10, 15, 0, 15).toUtc().toIso8601String(),
          'day': null,
        },
        {'kind': 'due', 'at': null, 'day': '2026-10-16'},
      ]);
      expect(month.postDays, {DateTime(2026, 10, 14), DateTime(2026, 10, 15)});
      expect(month.dueDays, {DateTime(2026, 10, 16)});
    });

    test('my_calendar: work items only', () {
      expect(
        CalendarWorkItem.fromJson({'kind': 'todo', 'note_id': 'n'}),
        isNull,
      );
      final item = CalendarWorkItem.fromJson({
        'kind': 'work_item',
        'space_id': 's',
        'title': 'Cable tray hangers, level 4',
        'day': '2026-10-16',
        'starts_at': null,
        'status': 'open',
      })!;
      expect(item.day, DateTime(2026, 10, 16));
      expect(item.status, WorkStatus.open);
      expect(item.dueAt, isNull);
    });
  });
}
