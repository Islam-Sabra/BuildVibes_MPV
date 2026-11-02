import 'package:flutter/foundation.dart';

/// Review 113 (18): Need you now, one person calling another in a shared
/// Space. The server keeps who may call whom (send_need_you).

/// The answer: On my way, or Can't now.
enum NeedYouAnswer {
  coming('coming'),
  cant('cant');

  const NeedYouAnswer(this.json);
  final String json;

  static NeedYouAnswer? fromJson(Object? v) =>
      values.where((a) => a.json == v).firstOrNull;
}

/// The server's lengths (need_you_calls).
abstract final class NeedYouRules {
  static const reasonMax = 120;
  static const placeMax = 80;
}

/// A call I sent or got in the last 24 hours (my_need_you_calls).
@immutable
class NeedYouCall {
  const NeedYouCall({
    required this.id,
    required this.spaceId,
    required this.fromId,
    required this.toId,
    required this.createdAt,
    this.fromName,
    this.toName,
    this.reason,
    this.place,
    this.answer,
    this.answeredAt,
  });

  factory NeedYouCall.fromJson(Map<String, dynamic> json) => NeedYouCall(
    id: json['id'] as String,
    spaceId: json['space_id'] as String,
    fromId: json['from_id'] as String,
    toId: json['to_id'] as String,
    fromName: json['from_name'] as String?,
    toName: json['to_name'] as String?,
    reason: json['reason'] as String?,
    place: json['place'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    answer: NeedYouAnswer.fromJson(json['answer']),
    answeredAt: json['answered_at'] == null
        ? null
        : DateTime.parse(json['answered_at'] as String),
  );

  final String id;
  final String spaceId;
  final String fromId;
  final String toId;
  final String? fromName;
  final String? toName;
  final String? reason;
  final String? place;
  final DateTime createdAt;
  final NeedYouAnswer? answer;
  final DateTime? answeredAt;
}
