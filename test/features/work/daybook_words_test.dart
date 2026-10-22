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
    DaybookPost sleeves(String lang) {
      final s = DaybookSamples(lang);
      return s.item(
        id: 'post-sleeves',
        at: _thu,
        title: s.sleeves,
        authorId: DaybookSamples.islam,
        ownerId: DaybookSamples.omar,
        due: DateTime(2026, 10, 15),
      );
    }

    test('for someone, by a date', () {
      final post = sleeves('en');
      final past = DateTime(2026, 10, 13, 9);
      expect(
        en.meta(post, me: me, now: past),
        'For Omar Haddad · by Thu 15 Oct',
      );
      final arPost = sleeves('ar');
      expect(
        ar.meta(arPost, me: me, now: past),
        'لـ عمر حداد · موعده الخميس 15 أكتوبر',
      );
    });

    test('a name in the other script stays whole', () {
      final post = sleeves('en');
      final past = DateTime(2026, 10, 13, 9);
      expect(
        ar.meta(post, me: me, now: past),
        'لـ ${inOwnDirection('Omar Haddad')} · موعده الخميس 15 أكتوبر',
      );
    });

    test('for you, by today at a time: never "before today" in Arabic', () {
      final post = const DaybookSamples('en').rebar().post;
      expect(en.meta(post, me: me, now: _thu), 'For you · by today 14:00');
      expect(ar.meta(post, me: me, now: _thu), 'لك · قبل الساعة 14:00 اليوم');
      expect(
        _words('en', use24: false).meta(post, me: me, now: _thu),
        'For you · by today 2:00\u00A0pm',
      );
    });

    test('today, tomorrow and another day, with and without a time', () {
      DaybookPost due(DateTime day, [DateTime? at]) =>
          const DaybookSamples('en').item(
            id: 'p',
            at: _thu,
            title: 't',
            authorId: DaybookSamples.sara,
            ownerId: me,
            due: day,
            dueAt: at,
          );
      final today = DateTime(2026, 10, 15);
      final tomorrow = DateTime(2026, 10, 16);
      final sunday = DateTime(2026, 10, 18);
      expect(en.meta(due(today), me: me, now: _thu), 'For you · by today');
      expect(ar.meta(due(today), me: me, now: _thu), 'لك · خلال اليوم');
      expect(
        en.meta(due(tomorrow), me: me, now: _thu),
        'For you · by tomorrow',
      );
      expect(ar.meta(due(tomorrow), me: me, now: _thu), 'لك · غدًا');
      expect(
        en.meta(due(tomorrow, DateTime(2026, 10, 16, 9)), me: me, now: _thu),
        'For you · by tomorrow 09:00',
      );
      expect(
        ar.meta(due(tomorrow, DateTime(2026, 10, 16, 9)), me: me, now: _thu),
        'لك · قبل الساعة 09:00 غدًا',
      );
      expect(
        en.meta(due(sunday), me: me, now: _thu),
        'For you · by Sun 18 Oct',
      );
      expect(
        ar.meta(due(sunday), me: me, now: _thu),
        'لك · موعده الأحد 18 أكتوبر',
      );
      expect(
        ar.meta(due(sunday, DateTime(2026, 10, 18, 9)), me: me, now: _thu),
        'لك · قبل الساعة 09:00 يوم الأحد 18 أكتوبر',
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
      final late = s.l1().first.post;
      final fri = DaybookSamples.friday;
      expect(late.isLate(fri), isTrue);
      expect(late.lateDays(fri), 1);
      expect(
        en.meta(late, me: DaybookSamples.omar, now: fri),
        'For you · was due Thu 15 Oct',
      );
      expect(
        ar.meta(late, me: DaybookSamples.omar, now: fri),
        'لك · كان موعده الخميس 15 أكتوبر',
      );
    });
  });

  test('F57: an earlier day on the Due today strip', () {
    final en = DaybookWords(
      lookupAppLocalizations(const Locale('en')),
      'en',
      use24: true,
    );
    final fri = DateTime(2026, 10, 16, 9);
    expect(en.stripDay(DateTime(2026, 10, 16), fri), isNull);
    expect(en.stripDay(DateTime(2026, 10, 14), fri), 'Wed');
    expect(en.stripDay(DateTime(2026, 10, 5), fri), 'Mon 5 Oct');
  });

  group('review 45 B2: every due pattern, in Arabic and English', () {
    const me = DaybookSamples.islam;
    DaybookPost due(DateTime day, [DateTime? at]) =>
        const DaybookSamples('en').item(
          id: 'p',
          at: _thu,
          title: 't',
          authorId: DaybookSamples.sara,
          ownerId: me,
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
      expect(meta('ar', due(today), _thu), 'لك · خلال اليوم');
      expect(meta('en', due(today), _thu), 'For you · by today');
    });

    test('by tomorrow, no time: "غدًا"', () {
      final tomorrow = DateTime(2026, 10, 16);
      expect(meta('ar', due(tomorrow), _thu), 'لك · غدًا');
      expect(meta('en', due(tomorrow), _thu), 'For you · by tomorrow');
    });

    test('by a date: "موعده الأربعاء 21 أكتوبر", never "before"', () {
      expect(meta('ar', due(wednesday), _thu), 'لك · موعده الأربعاء 21 أكتوبر');
      expect(meta('en', due(wednesday), _thu), 'For you · by Wed 21 Oct');
      expect(meta('ar', due(wednesday), _thu), isNot(contains('قبل')));
    });

    test('by a time today: 12-hour as the AR frame, and 24-hour', () {
      expect(
        meta('ar', due(today, twoPm), _thu, use24: false),
        'لك · قبل الساعة ${rtlRun('2:00\u00A0ظهرًا')} اليوم',
      );
      expect(
        meta('ar', due(today, twoPm), _thu),
        'لك · قبل الساعة 14:00 اليوم',
      );
      expect(
        meta('en', due(today, twoPm), _thu, use24: false),
        'For you · by today 2:00\u00A0pm',
      );
      expect(meta('en', due(today, twoPm), _thu), 'For you · by today 14:00');
    });

    test('late: "كان موعده …"', () {
      final friday = DateTime(2026, 10, 16, 9);
      expect(meta('ar', due(today), friday), 'لك · كان موعده الخميس 15 أكتوبر');
      expect(meta('en', due(today), friday), 'For you · was due Thu 15 Oct');
      expect(
        meta('ar', due(today, twoPm), DateTime(2026, 10, 15, 15)),
        'لك · كان موعده الساعة 14:00 اليوم',
      );
    });

    test("the large stamp's line: the short name in capitals, the time", () {
      final at = DateTime(2026, 10, 15, 9, 40);
      // The name in its own direction (F53).
      expect(
        _words('en').stampLine('Omar Haddad', at),
        '${inOwnDirection('OMAR H')} · 09:40',
      );
      expect(
        _words('ar').stampLine('عمر حداد', at),
        '${inOwnDirection('عمر ح')} · 09:40',
      );
      expect(
        _words('en').stampLine('Sara Al-Mutairi', at),
        '${inOwnDirection('SARA A')} · 09:40',
      );
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

  group('history lines and traces (v13)', () {
    final en = _words('en');
    final ar = _words('ar');
    const s = DaybookSamples('en');
    const sAr = DaybookSamples('ar');
    DaybookEvent ev(
      DaybookSamples s,
      DaybookEventKind kind,
      String by, {
      String? note,
      SendBackReason? reason,
      DaybookDueEdit? dueEdit,
    }) => s.event(
      'e',
      kind,
      _thu,
      by,
      note: note,
      reason: reason,
      dueEdit: dueEdit,
      fromId: DaybookSamples.omar,
      toId: DaybookSamples.rakesh,
    );
    const me = DaybookSamples.islam;

    test('each kind, by someone and by you, as the prototype says it', () {
      String line(DaybookEventKind k, String by) =>
          en.eventPhrase(ev(s, k, by), me: me, now: _thu);
      expect(
        line(DaybookEventKind.done, DaybookSamples.omar),
        'Omar Haddad signed as done',
      );
      expect(line(DaybookEventKind.done, me), 'You signed as done');
      expect(line(DaybookEventKind.sentBack, me), 'You sent it back');
      expect(line(DaybookEventKind.checked, me), 'You checked it');
      expect(
        line(DaybookEventKind.checked, DaybookSamples.sara),
        'Sara Al-Mutairi checked it',
      );
      // An update's line is its writer, then the words.
      expect(
        line(DaybookEventKind.comment, DaybookSamples.omar),
        'Omar Haddad',
      );
      expect(line(DaybookEventKind.comment, me), 'You');
      expect(
        line(DaybookEventKind.reassigned, me),
        'You gave it to Rakesh Nair instead of Omar Haddad',
      );
      expect(line(DaybookEventKind.cancelled, me), 'You cancelled it');
      expect(
        line(DaybookEventKind.edited, DaybookSamples.sara),
        'Sara Al-Mutairi edited it',
      );
    });

    test('the due moved: days, or times on the same day, or taken off', () {
      final rebar = s.rebar().history.firstWhere(
        (e) => e.kind == DaybookEventKind.edited,
      );
      expect(
        en.eventPhrase(rebar, me: me, now: _thu),
        'Sara Al-Mutairi moved the due date from Thu to today',
      );
      final rebarAr = sAr.rebar().history.firstWhere(
        (e) => e.kind == DaybookEventKind.edited,
      );
      expect(
        ar.eventPhrase(rebarAr, me: me, now: _thu),
        'سارة المطيري · تعديل الموعد: من الخميس إلى اليوم',
      );
      final timeOnly = ev(
        s,
        DaybookEventKind.edited,
        me,
        dueEdit: DaybookDueEdit(
          from: DateTime(2026, 10, 15),
          to: DateTime(2026, 10, 15),
          fromAt: DateTime(2026, 10, 15, 14),
          toAt: DateTime(2026, 10, 15, 16),
        ),
      );
      expect(
        en.eventPhrase(timeOnly, me: me, now: _thu),
        'You moved the due date from 14:00 to 16:00',
      );
      final removed = ev(
        s,
        DaybookEventKind.edited,
        me,
        dueEdit: DaybookDueEdit(from: DateTime(2026, 10, 15)),
      );
      expect(
        en.eventPhrase(removed, me: me, now: _thu),
        'You took the due date off',
      );
      expect(ar.eventPhrase(removed, me: me, now: _thu), 'أنت · إزالة الموعد');
    });

    test('a trace says what happened; an update is "added an update"', () {
      final update = ev(s, DaybookEventKind.comment, DaybookSamples.omar);
      expect(
        en.eventPhrase(update, me: me, now: _thu, trace: true),
        'Omar Haddad added an update',
      );
      expect(
        ar.eventPhrase(
          ev(sAr, DaybookEventKind.comment, me),
          me: me,
          now: _thu,
          trace: true,
        ),
        'أنت · تحديث',
      );
      expect(
        en.eventPhrase(
          ev(s, DaybookEventKind.raised, me),
          me: me,
          now: _thu,
          trace: true,
        ),
        'You posted it',
      );
    });

    test('the rest of a line: a note, a reason and its note', () {
      expect(
        en.eventDetail(
          ev(s, DaybookEventKind.done, DaybookSamples.omar, note: 'Six.'),
        ),
        inOwnDirection('Six.'),
      );
      expect(
        en.eventDetail(
          ev(
            s,
            DaybookEventKind.sentBack,
            me,
            reason: SendBackReason.photoMissing,
          ),
        ),
        en.reason(SendBackReason.photoMissing),
      );
      expect(
        en.eventDetail(
          ev(
            s,
            DaybookEventKind.sentBack,
            me,
            reason: SendBackReason.notAsAsked,
            note: 'One is short.',
          ),
        ),
        en.sentBackText(SendBackReason.notAsAsked, 'One is short.'),
      );
      expect(en.eventDetail(ev(s, DaybookEventKind.checked, me)), isNull);
      expect(en.eventDetail(ev(s, DaybookEventKind.done, me)), isNull);
    });

    test('F62: a send-back line carries its new date, or says there is '
        'none', () {
      DaybookEvent back(Map<String, dynamic>? newDue) => DaybookEvent.fromJson({
        'id': 'e',
        'kind': 'sent_back',
        'at': '2026-10-15T09:00:00Z',
        'reason': 'photo_missing',
        'new_due': ?newDue,
      });
      final reason = en.reason(SendBackReason.photoMissing);
      // A build before migration 33: no new date, the line as before.
      expect(en.eventDetail(back(null)), reason);
      expect(
        en.eventDetail(back({'date': '2026-10-23'})),
        joinMeta([
          reason,
          lookupAppLocalizations(
            const Locale('en'),
          ).daybookLineNewDate(en.dueProperty(DateTime(2026, 10, 23), null)),
        ]),
      );
      expect(
        en.eventDetail(back({'date': '2026-10-23'})),
        contains('Fri 23 Oct'),
      );
      // {} after strip_nulls: "No new date".
      expect(
        en.eventDetail(back({})),
        joinMeta([
          reason,
          lookupAppLocalizations(const Locale('en')).daybookLineNoNewDate,
        ]),
      );
    });

    test('Arabic names the doer without a gendered verb', () {
      final done = ev(sAr, DaybookEventKind.done, DaybookSamples.sara);
      expect(
        ar.eventPhrase(done, me: me, now: _thu),
        'سارة المطيري · توقيع كمنجز',
      );
      expect(
        ar.eventPhrase(
          ev(sAr, DaybookEventKind.sentBack, me),
          me: me,
          now: _thu,
        ),
        'أنت · إرجاع',
      );
    });

    test('review 54 A3: the Arabic history in the ledger form, the name '
        'first, then the action as a noun (2583:373)', () {
      final l10n = lookupAppLocalizations(const Locale('ar'));
      // The bold lead and the rest, as the card's line joins them.
      // Read by Omar, Islam's lines carry his name; by Islam, "أنت".
      String line(DaybookEvent e, {String reader = me}) {
        final phrase = ar.eventPhrase(e, me: reader, now: _thu);
        final detail = ar.eventDetail(e);
        return detail == null
            ? phrase
            : '${l10n.daybookHistoryLead(phrase)} $detail';
      }

      String plain(String t) => t.replaceAll(RegExp('[\u2066-\u2069]'), '');
      expect(
        plain(
          line(
            ev(
              sAr,
              DaybookEventKind.done,
              DaybookSamples.omar,
              note: 'رُكّبت الست كلها.',
            ),
          ),
        ),
        'عمر حداد · توقيع كمنجز: رُكّبت الست كلها.',
      );
      expect(
        plain(
          line(
            ev(
              sAr,
              DaybookEventKind.sentBack,
              DaybookSamples.islam,
              reason: SendBackReason.photoMissing,
            ),
            reader: DaybookSamples.omar,
          ),
        ),
        'إسلام أحمد · إرجاع: ${l10n.daybookReasonPhotoMissing}',
      );
      expect(
        plain(
          line(
            ev(
              sAr,
              DaybookEventKind.sentBack,
              me,
              reason: SendBackReason.photoMissing,
            ),
          ),
        ),
        'أنت · إرجاع: ${l10n.daybookReasonPhotoMissing}',
      );
      final moved = sAr.rebar().history.firstWhere(
        (e) => e.kind == DaybookEventKind.edited,
      );
      expect(line(moved), 'سارة المطيري · تعديل الموعد: من الخميس إلى اليوم');
      expect(
        plain(
          line(
            ev(
              sAr,
              DaybookEventKind.comment,
              DaybookSamples.omar,
              note: 'وصلت الجلب. أركّبها الآن.',
            ),
          ),
        ),
        'عمر حداد · تحديث: وصلت الجلب. أركّبها الآن.',
      );
      expect(
        line(
          ev(sAr, DaybookEventKind.checked, DaybookSamples.islam),
          reader: DaybookSamples.omar,
        ),
        'إسلام أحمد · تحقّق',
      );
      // No passive "من قِبل" anywhere.
      for (final kind in DaybookEventKind.values) {
        expect(
          ar.eventPhrase(ev(sAr, kind, DaybookSamples.omar), me: me, now: _thu),
          isNot(contains('قِبل')),
        );
      }
    });
  });

  group('space_post_json', () {
    test('a work item: its item, points, cover and due', () {
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
      expect(post.pointsTotal, 2);
      expect(post.coverPath, 's/posts/p1/a.jpg');
    });

    test('a cancelled post, with no author shown', () {
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

    test("F66: the writing card's who row says it as the card does", () {
      final en = _words('en');
      final ar = _words('ar');
      const me = DaybookSamples.islam;
      // Review 79 A2: no › in the words; the row's caret is an icon.
      expect(en.writingFor(me, 'Islam Ahmed', me: me), (
        text: 'For you',
        who: 'you',
      ));
      expect(en.writingFor('o', 'Omar Haddad', me: me), (
        text: 'For Omar Haddad',
        who: 'Omar Haddad',
      ));
      // F52: a Latin name kept whole in an Arabic line ("لـ Islam Ahmed").
      final islam = inOwnDirection('Islam Ahmed');
      expect(ar.writingFor('i', 'Islam Ahmed', me: 'o'), (
        text: 'لـ $islam',
        who: islam,
      ));
      expect(ar.writingFor(me, 'x', me: me).text, 'لك');
    });

    test('my_calendar: work items only', () {
      expect(
        CalendarWorkItem.fromJson({'kind': 'todo', 'note_id': 'n'}),
        isNull,
      );
      final item = CalendarWorkItem.fromJson({
        'kind': 'work_item',
        'post_id': 'p',
        'space_id': 's',
        'title': 'Cable tray hangers, level 4',
        'day': '2026-10-16',
        'starts_at': null,
        'status': 'open',
        'needs_me': true,
      })!;
      expect(item.day, DateTime(2026, 10, 16));
      expect(item.postId, 'p');
      expect(item.status, WorkStatus.open);
      expect(item.needsMe, isTrue);
      expect(item.dueAt, isNull);
    });
  });
}
