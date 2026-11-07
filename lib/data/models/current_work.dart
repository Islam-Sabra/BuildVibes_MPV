import 'package:flutter/foundation.dart';

/// Where someone works now (review 126 P1): their current Experience entry,
/// the one with no end month (the latest start if several). The only
/// source of a person's company; the server shows it only to whoever may
/// read that entry.
@immutable
class CurrentWork {
  const CurrentWork({required this.title, this.companyId, this.companyName});

  /// The `current_work` embed (a list of at most one row), or the object
  /// `space_key_people` sends; null when there is none.
  static CurrentWork? fromJson(Object? json) {
    final row = json is List ? json.firstOrNull : json;
    if (row is! Map<String, dynamic>) return null;
    return CurrentWork(
      title: row['title'] as String? ?? '',
      companyId: row['company_id'] as String?,
      companyName: row['company_name'] as String?,
    );
  }

  final String title;
  final String? companyId;

  /// The registered company's name, or the name as typed (rule 4).
  final String? companyName;

  bool get registered => companyId != null;
}

/// What a select embeds for a person's current work.
const currentWorkSelect = 'current_work(title, company_id, company_name)';
