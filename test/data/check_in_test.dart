// Review 109: a Check-in's card JSON, the person's step at a time (the
// edges of part 2), the server's refusals, and the calls' params.
import 'package:buildvibes/data/models/check_in.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/check_in_repository.dart';
import 'package:buildvibes/features/work/check_in_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

/// 7:00 · 15 min, out 14:00 · 15 min, on 15 Oct 2026 (UTC times).
Map<String, dynamic> _json({
  Map<String, dynamic>? myIn,
  Map<String, dynamic>? myOut,
  bool missed = false,
  bool stopped = false,
  bool runs = true,
  bool asked = true,
  bool withOut = true,
}) => {
  'in_time': '07:00',
  'in_allow': 15,
  'out_time': withOut ? '14:00' : null,
  'out_allow': withOut ? 15 : null,
  'daily': true,
  'teams': [
    {'id': 't-mep', 'name': 'MEP'},
  ],
  'stopped': stopped,
  'site_set': true,
  'sees_list': false,
  'asked': asked,
  'today': {
    'day': '2026-10-15',
    'runs': runs,
    'in_opens_at': '2026-10-15T06:45:00Z',
    'in_until': '2026-10-15T07:15:00Z',
    'in_closes_at': withOut ? '2026-10-15T13:45:00Z' : '2026-10-15T21:00:00Z',
    'out_opens_at': withOut ? '2026-10-15T13:45:00Z' : null,
    'out_until': withOut ? '2026-10-15T14:15:00Z' : null,
    'day_ends_at': '2026-10-15T21:00:00Z',
  },
  'my_in': myIn,
  'my_out': myOut,
  'missed': missed,
  'tz': 'Asia/Kuwait',
};

DateTime _at(int h, int m) => DateTime.utc(2026, 10, 15, h, m);

void main() {
  test('the card JSON reads every field', () {
    final c = CheckInSetup.fromJson(
      _json(
        myIn: {
          'at': '2026-10-15T06:58:00Z',
          'on_time': true,
          'place': 'on_site',
        },
      ),
    )!;
    expect(c.inTime, const DayTime(7, 0));
    expect(c.inAllow, 15);
    expect(c.outTime, const DayTime(14, 0));
    expect(c.outAllow, 15);
    expect(c.daily, isTrue);
    expect(c.teams!.single.name, 'MEP');
    expect(c.asked, isTrue);
    expect(c.today!.day, DateTime(2026, 10, 15));
    expect(c.today!.inUntil, _at(7, 15));
    expect(c.myIn!.place, CheckInPlace.onSite);
    expect(c.myIn!.onTime, isTrue);
    expect(c.myOut, isNull);
    // Y1: the check-in's own clock.
    expect(c.zone, 'Asia/Kuwait');
    expect(CheckInSetup.fromJson({..._json(), 'tz': null})!.zone, isNull);
    expect(CheckInSetup.fromJson(null), isNull);
    expect(
      DaybookPost.fromJson({
        'id': 'p1',
        'kind': 'check_in',
        'created_at': '2026-10-15T05:00:00Z',
        'title': 'Morning, Block B',
        'check_in': _json(),
      }).checkIn?.inAllow,
      15,
    );
    expect(DaybookPost.shownKinds, contains(DaybookPost.checkInKind));
  });

  test('DayTime reads and writes HH:mm, and pads', () {
    expect(DayTime.parse('7:05'), const DayTime(7, 5));
    expect(DayTime.parse('14:00:00'), const DayTime(14, 0));
    expect(const DayTime(7, 5).json, '07:05');
    expect(DayTime.parse('x'), isNull);
  });

  group('the person’s step, at the edges of part 2', () {
    CheckInStep at(int h, int m, [Map<String, dynamic>? json]) =>
        CheckInSetup.fromJson(json ?? _json())!.stepAt(_at(h, m));

    test('before check-in opens: Check in, not yet', () {
      expect(at(6, 44).action, CheckInAction.inSoon);
    });
    test('from the time minus the allowance: Check in', () {
      expect(at(6, 45).action, CheckInAction.checkIn);
      expect(at(7, 15).action, CheckInAction.checkIn);
      expect(at(13, 44).action, CheckInAction.checkIn);
    });
    test('Y5: once check-out opens with no In: In missed, and Check out '
        'is still offered', () {
      final s = at(13, 45);
      expect(s.missed, isTrue);
      expect(s.action, CheckInAction.checkOut);
      expect(at(13, 44).action, CheckInAction.checkIn);
      expect(at(13, 44).missed, isFalse);
    });
    test('Y5: checked out without an In: missed, nothing more to do', () {
      final json = _json(
        myOut: {
          'at': '2026-10-15T14:05:00Z',
          'on_time': true,
          'place': 'on_site',
        },
      );
      final s = at(14, 10, json);
      expect(s.missed, isTrue);
      expect(s.action, CheckInAction.none);
    });
    test('Y5: no check-out and no In after the day: missed only', () {
      final s = at(21, 0, _json(withOut: false));
      expect(s.missed, isTrue);
      expect(s.action, CheckInAction.none);
    });
    test('the server’s missed counts too', () {
      expect(at(8, 0, _json(missed: true)).missed, isTrue);
    });
    test('checked in: Check out, disabled until its time', () {
      final json = _json(
        myIn: {
          'at': '2026-10-15T06:58:00Z',
          'on_time': true,
          'place': 'on_site',
        },
      );
      expect(at(13, 44, json).action, CheckInAction.outSoon);
      expect(at(13, 45, json).action, CheckInAction.checkOut);
      expect(at(20, 59, json).action, CheckInAction.checkOut);
      expect(at(21, 0, json).action, CheckInAction.none);
    });
    test('not at site: Try again while check-in is open', () {
      final json = _json(
        myIn: {'at': '2026-10-15T07:01:00Z', 'on_time': true, 'place': 'away'},
      );
      expect(at(7, 30, json).tryAgain, isTrue);
      expect(at(13, 45, json).tryAgain, isFalse);
    });
    test('checked out: nothing more', () {
      final json = _json(
        myIn: {
          'at': '2026-10-15T06:58:00Z',
          'on_time': true,
          'place': 'on_site',
        },
        myOut: {
          'at': '2026-10-15T14:05:00Z',
          'on_time': true,
          'place': 'on_site',
        },
      );
      expect(at(14, 10, json).action, CheckInAction.none);
    });
    test('without a check-out, check-in stays open to the end of the day', () {
      expect(at(20, 59, _json(withOut: false)).action, CheckInAction.checkIn);
      expect(at(21, 0, _json(withOut: false)).missed, isTrue);
    });
    test('stopped, not a check-in day, or not asked: nothing to do', () {
      expect(at(7, 0, _json(stopped: true)).action, CheckInAction.none);
      expect(at(7, 0, _json(runs: false)).action, CheckInAction.none);
      expect(at(7, 0, _json(asked: false)).action, CheckInAction.none);
    });
  });

  test('a stamp’s tone: green on time on site, amber late or away, grey '
      'not shared', () {
    CheckInMark m(bool onTime, CheckInPlace place) =>
        CheckInMark(at: _at(7, 0), onTime: onTime, place: place);
    expect(m(true, CheckInPlace.onSite).tone, CheckInTone.good);
    expect(m(false, CheckInPlace.onSite).tone, CheckInTone.warn);
    expect(m(true, CheckInPlace.away).tone, CheckInTone.warn);
    expect(m(true, CheckInPlace.notShared).tone, CheckInTone.quiet);
    expect(m(false, CheckInPlace.notShared).tone, CheckInTone.warn);
  });

  test('mark_check_in’s answer reads', () {
    final r = CheckInResult.fromJson({
      'day': '2026-10-15',
      'kind': 'out',
      'at': '2026-10-15T14:05:00Z',
      'on_time': true,
      'place': 'not_shared',
    });
    expect(r.kind, CheckInMarkKind.checkOut);
    expect(r.mark.place, CheckInPlace.notShared);
    expect(r.day, DateTime(2026, 10, 15));
  });

  test('check_in_list rows read', () {
    final l = CheckInLine.fromJson({
      'user_id': 'u1',
      'name': 'Rakesh Nair',
      'team': 'MEP',
      'in_at': '2026-10-15T06:58:00Z',
      'in_on_time': true,
      'in_place': 'on_site',
      'out_at': null,
      'out_on_time': null,
      'out_place': null,
      'missed': false,
    });
    expect(l.inMark!.place, CheckInPlace.onSite);
    expect(l.outMark, isNull);
    expect(l.missed, isFalse);
  });

  test('every refusal of mark_check_in has its own plain line', () {
    CheckInRefusal of(SpaceFailure f, String m) =>
        CheckInRefusal.of(SpaceException(f, m));
    expect(
      of(SpaceFailure.notAllowed, 'not allowed'),
      CheckInRefusal.notAllowed,
    );
    expect(
      of(SpaceFailure.badInput, 'not open yet'),
      CheckInRefusal.notOpenYet,
    );
    expect(of(SpaceFailure.badInput, 'closed'), CheckInRefusal.closed);
    expect(
      of(SpaceFailure.badInput, 'not a check-in day'),
      CheckInRefusal.notToday,
    );
    expect(of(SpaceFailure.badInput, 'stopped'), CheckInRefusal.stopped);
    expect(
      of(SpaceFailure.badInput, 'already checked in'),
      CheckInRefusal.already,
    );
    expect(of(SpaceFailure.badInput, 'too many tries'), CheckInRefusal.tooMany);
    expect(
      of(SpaceFailure.badInput, 'no check-out'),
      CheckInRefusal.noCheckOut,
    );
    expect(of(SpaceFailure.network, 'x'), CheckInRefusal.network);
    expect(of(SpaceFailure.unknown, 'x'), CheckInRefusal.unknown);
  });

  test('post_check_in takes the contract’s params', () {
    const c = NewCheckIn(
      id: 'p1',
      spaceId: 's1',
      title: ' Morning, Block B ',
      body: '',
      teamIds: ['t-mep', 't-site'],
      siteLat: 29.3759,
      siteLng: 47.9774,
      inTime: DayTime(7, 0),
      inAllow: 15,
      outTime: DayTime(15, 0),
      outAllow: 10,
      daily: true,
      timeZone: 'Asia/Kuwait',
    );
    expect(c.toParams(), {
      'p_id': 'p1',
      'p_space': 's1',
      'p_title': 'Morning, Block B',
      'p_body': null,
      'p_teams': ['t-mep', 't-site'],
      'p_site_lat': 29.3759,
      'p_site_lng': 47.9774,
      'p_in_time': '07:00',
      'p_in_allow': 15,
      'p_out_time': '15:00',
      'p_out_allow': 10,
      'p_daily': true,
      // Y1: the phone's time zone, always sent.
      'p_time_zone': 'Asia/Kuwait',
    });
    const whole = NewCheckIn(
      id: 'p2',
      spaceId: 's1',
      title: 'x',
      siteLat: 1,
      siteLng: 2,
      inTime: DayTime(6, 30),
      inAllow: 0,
      timeZone: 'Africa/Cairo',
    );
    expect(whole.toParams()['p_time_zone'], 'Africa/Cairo');
    expect(whole.toParams()['p_teams'], isNull);
    expect(
      whole.toParams().containsKey('p_same_place_as'),
      isFalse,
      reason: 'only when it is used',
    );
    expect(whole.toParams()['p_out_time'], isNull);
    expect(whole.toParams()['p_out_allow'], isNull);
    expect(whole.toParams()['p_daily'], isFalse);
  });

  test('the allowance is one of 0, 10, 15 and 30 minutes; 100 m is fixed', () {
    expect(checkInAllowances, const [0, 10, 15, 30]);
    expect(checkInSiteMetres, 100);
  });

  test('Y10: Arabic minutes: 0 no allowance, 10 دقائق (few), 15 and 30 '
      'دقيقة', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(ar.checkInTimeAllow('7:00', 0), '7:00 · بدون سماح');
    expect(ar.checkInTimeAllow('7:00', 10), '7:00 · سماح 10 دقائق');
    expect(ar.checkInTimeAllow('7:00', 15), '7:00 · سماح 15 دقيقة');
    expect(ar.checkInTimeAllow('7:00', 30), '7:00 · سماح 30 دقيقة');
    expect(ar.checkInOutChip('3:00', 10), 'خروج 3:00 · سماح 10 دقائق');
    expect(ar.checkInOutChip('3:00', 15), 'خروج 3:00 · سماح 15 دقيقة');
    expect(ar.checkInOutChip('3:00', 0), 'خروج 3:00 · بدون سماح');
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.checkInTimeAllow('7:00', 10), '7:00 · 10 min allowance');
    expect(en.checkInTimeAllow('7:00', 0), '7:00 · no allowance');
  });

  test('Y4: too many tries has its own line, in both languages', () {
    for (final lang in ['en', 'ar']) {
      final l10n = lookupAppLocalizations(Locale(lang));
      expect(
        checkInRefusalText(l10n, CheckInRefusal.tooMany),
        l10n.checkInRefusedTooMany,
      );
    }
    expect(
      lookupAppLocalizations(const Locale('en')).checkInRefusedTooMany,
      'Too many tries today. Ask your Lead.',
    );
  });
}
