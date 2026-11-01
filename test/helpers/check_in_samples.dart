import 'package:buildvibes/data/models/check_in.dart';
import 'package:buildvibes/data/models/daybook.dart';

import 'daybook_samples.dart';

/// Review 109's samples: "Morning, Block B", 7:00 · 15 min, out 14:00 ·
/// 15 min, every day, in a Space on Kuwait's clock (UTC+3). Its instants
/// are UTC, so the tests don't depend on the machine's zone.
abstract final class CheckInSamples {
  static const id = 'post-check-in';
  static const zone = 'Asia/Kuwait';

  /// 15 Oct 2026 at [h]:[m] on the Space's clock.
  static DateTime at(int h, int m) =>
      DateTime.utc(2026, 10, 15, h, m).subtract(const Duration(hours: 3));

  static String _z(int h, int m) => at(h, m).toIso8601String();

  static Map<String, dynamic> mark(
    int h,
    int m, {
    bool onTime = true,
    String place = 'on_site',
  }) => {'at': _z(h, m), 'on_time': onTime, 'place': place};

  static DaybookCard card(
    String lang, {
    String authorId = DaybookSamples.sara,
    Map<String, dynamic>? myIn,
    Map<String, dynamic>? myOut,
    bool missed = false,
    bool seesList = false,
    bool canStop = false,
    bool asked = true,
    bool daily = true,
    bool stopped = false,
    bool runs = true,

    /// Y1: the check-in's own clock (the card JSON's "tz").
    String? tz = zone,
  }) {
    final s = DaybookSamples(lang);
    final post = DaybookPost.fromJson({
      'id': id,
      'kind': DaybookPost.checkInKind,
      'created_at': _z(5, 30),
      'title': s.t('Morning, Block B', 'صباح المبنى B'),
      'author_id': authorId,
      'author_name': s.nameOf(authorId),
      'ref': 'KCT-040',
      'check_in': {
        'in_time': '07:00',
        'in_allow': 15,
        'out_time': '14:00',
        'out_allow': 15,
        'daily': daily,
        'teams': null,
        'stopped': stopped,
        'site_set': true,
        'sees_list': seesList,
        'can_stop': canStop,
        'asked': asked,
        'today': {
          'day': '2026-10-15',
          'runs': runs,
          'in_opens_at': _z(6, 45),
          'in_until': _z(7, 15),
          'in_closes_at': _z(13, 45),
          'out_opens_at': _z(13, 45),
          'out_until': _z(14, 15),
          'day_ends_at': _z(23, 59),
        },
        'my_in': myIn,
        'my_out': myOut,
        'missed': missed,
        'tz': tz,
      },
    });
    return DaybookCard(post: post, lastActivityAt: at(5, 30));
  }

  /// The creator's list (CI5), as the prototype draws it.
  static List<CheckInLine> lines(String lang) {
    final s = DaybookSamples(lang);
    CheckInMark m(
      int h,
      int min, {
      bool onTime = true,
      CheckInPlace place = CheckInPlace.onSite,
    }) => CheckInMark(at: at(h, min), onTime: onTime, place: place);
    return [
      CheckInLine(
        userId: DaybookSamples.rakesh,
        name: s.rakeshName,
        inMark: m(6, 58),
        outMark: m(15, 5),
      ),
      CheckInLine(
        userId: 'p-khalid',
        name: s.t('Khalid Al-Mansour', 'خالد المنصور'),
        inMark: m(7, 24, onTime: false),
        outMark: m(15, 2),
      ),
      CheckInLine(
        userId: 'p-noura',
        name: s.t('Noura Al-Sabah', 'نورة الصباح'),
        inMark: m(7, 1, place: CheckInPlace.away),
      ),
      CheckInLine(
        userId: DaybookSamples.omar,
        name: s.omarName,
        inMark: m(7, 3, place: CheckInPlace.notShared),
        outMark: m(14, 50),
      ),
      CheckInLine(userId: DaybookSamples.sara, name: s.saraName, missed: true),
      // Y5: checked out without checking in.
      CheckInLine(
        userId: DaybookSamples.lina,
        name: s.linaName,
        outMark: m(14, 55),
        missed: true,
      ),
    ];
  }
}
