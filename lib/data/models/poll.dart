import 'package:flutter/foundation.dart';

import 'daybook.dart' show DaybookPerson;

/// Review 116: one option of a poll, its choices as faces (never a
/// percentage, rule 3), and whether the reader chose it.
@immutable
class PollOption {
  const PollOption({
    required this.id,
    required this.label,
    this.sort = 0,
    this.count = 0,
    this.mine = false,
    this.voters = const [],
  });

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    sort: (json['sort'] as num?)?.toInt() ?? 0,
    count: (json['count'] as num?)?.toInt() ?? 0,
    mine: json['mine'] as bool? ?? false,
    voters: [
      for (final v in json['voters'] as List? ?? const [])
        if (v is Map<String, dynamic>)
          DaybookPerson(id: v['id'] as String, name: v['name'] as String?),
    ],
  );

  final String id;
  final String label;
  final int sort;

  /// How many chose it: only the share bar's length, never shown as a
  /// number.
  final int count;
  final bool mine;

  /// Who chose it, newest first.
  final List<DaybookPerson> voters;
}

/// Review 116: a poll post's own facts (space_post_json "poll").
@immutable
class DaybookPoll {
  const DaybookPoll({
    required this.options,
    this.multi = false,
    this.closesAt,
    this.closedAt,
    this.closedByName,
    this.decidedOption,
    this.tied = false,
    this.voted = false,
    this.notYet = const [],
    this.notYetMore = 0,
  });

  static DaybookPoll? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final notYet = json['not_yet'] as Map<String, dynamic>? ?? const {};
    return DaybookPoll(
      multi: json['multi'] as bool? ?? false,
      closesAt: _time(json['closes_at']),
      closedAt: _time(json['closed_at']),
      closedByName: json['closed_by_name'] as String?,
      decidedOption: json['decided_option'] as String?,
      tied: json['tied'] as bool? ?? false,
      voted: json['voted'] as bool? ?? false,
      options: [
        for (final o in json['options'] as List? ?? const [])
          if (o is Map<String, dynamic>) PollOption.fromJson(o),
      ]..sort((a, b) => a.sort.compareTo(b.sort)),
      notYet: [
        for (final n in notYet['names'] as List? ?? const [])
          if (n is String) n,
      ],
      notYetMore: (notYet['more'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _time(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  final bool multi;
  final DateTime? closesAt;
  final DateTime? closedAt;
  final String? closedByName;
  final String? decidedOption;

  /// Closed with two or more options sharing the most choices: the
  /// creator picks the winner.
  final bool tied;

  /// Someone voted: the question and options no longer change.
  final bool voted;
  final List<PollOption> options;

  /// "Not yet: Lina, Tariq and 2 more": who could answer and hasn't.
  final List<String> notYet;
  final int notYetMore;

  /// Closed, or its closing time passed (the five-minute job may not have
  /// run yet).
  bool isClosed(DateTime now) =>
      closedAt != null || (closesAt != null && !closesAt!.isAfter(now));

  PollOption? get decided =>
      options.where((o) => o.id == decidedOption).firstOrNull;

  Set<String> get mine => {
    for (final o in options)
      if (o.mine) o.id,
  };

  /// The most choices on one option: the bars are drawn against it.
  int get most => options.fold(0, (m, o) => o.count > m ? o.count : m);

  /// As the phone shows it at once after the reader chose [ids] as
  /// [me] (named [myName]): their own choices and faces moved, the rest as
  /// the server last said.
  DaybookPoll chosen(Set<String> ids, {required String me, String? myName}) =>
      DaybookPoll(
        multi: multi,
        closesAt: closesAt,
        closedAt: closedAt,
        closedByName: closedByName,
        decidedOption: decidedOption,
        tied: tied,
        voted: voted || ids.isNotEmpty,
        notYet: notYet,
        notYetMore: notYetMore,
        options: [
          for (final o in options)
            PollOption(
              id: o.id,
              label: o.label,
              sort: o.sort,
              count: o.count - (o.mine ? 1 : 0) + (ids.contains(o.id) ? 1 : 0),
              mine: ids.contains(o.id),
              voters: [
                if (ids.contains(o.id)) DaybookPerson(id: me, name: myName),
                for (final v in o.voters)
                  if (v.id != me) v,
              ],
            ),
        ],
      );
}
