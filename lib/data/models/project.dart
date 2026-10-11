import 'package:flutter/foundation.dart';

import '../../core/l10n/months.dart';
import 'market.dart';

/// A shared project record with no owner (PJ1).
@immutable
class ProjectRecord {
  const ProjectRecord({
    required this.id,
    required this.name,
    required this.typeId,
    required this.marketId,
    this.typeName,
    this.placeId,
    this.placeName,
    this.locationText,
    this.start,
    this.end,
    this.endExpected = false,
  });

  factory ProjectRecord.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as Map<String, dynamic>?;
    final place = json['place'] as Map<String, dynamic>?;
    return ProjectRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      typeId: json['type_id'] as String,
      marketId: json['market_id'] as String,
      typeName: type == null
          ? null
          : LocalizedText.fromJson(type['name'] as Map<String, dynamic>),
      placeId: json['place_id'] as String?,
      placeName: place == null
          ? null
          : LocalizedText.fromJson(place['name'] as Map<String, dynamic>),
      locationText: json['location_text'] as String?,
      start: parseMonth(json['start_month']),
      end: parseMonth(json['end_month']),
      endExpected: json['end_expected'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String typeId;
  final String marketId;
  final LocalizedText? typeName;
  final String? placeId;
  final LocalizedText? placeName;
  final String? locationText;
  final DateTime? start;
  final DateTime? end;
  final bool endExpected;

  /// The place name, or what was typed as the location.
  String? location(String languageCode) {
    final place = placeName;
    if (place != null) return languageCode == 'ar' ? place.ar : place.en;
    return locationText;
  }
}

enum MatchReason { sameName, sameSite }

/// A record offered by "Is it already here?" (P13).
@immutable
class ProjectMatch {
  const ProjectMatch({required this.project, required this.reason});

  final ProjectRecord project;
  final MatchReason reason;
}

/// What P14 creates.
@immutable
class NewProjectInput {
  const NewProjectInput({
    required this.name,
    required this.typeId,
    required this.marketId,
    this.placeId,
    this.start,
    this.end,
  });

  final String name;
  final String typeId;
  final String marketId;
  final String? placeId;
  final DateTime? start;
  final DateTime? end;

  /// An end month in the future is a forecast.
  bool endExpectedAt(DateTime now) =>
      end != null && end!.isAfter(DateTime(now.year, now.month));
}

/// The person's role and dates on a project (their CV entry).
@immutable
class CvEntryInput {
  const CvEntryInput({
    required this.role,
    this.start,
    this.end,
    this.showOnProfile = true,
  });

  final String role;
  final DateTime? start;

  /// Null means "present".
  final DateTime? end;
  final bool showOnProfile;

  Map<String, dynamic> toJson() => {
    'role_title': role.trim(),
    'start_month': monthToJson(start),
    'end_month': monthToJson(end),
    'show_on_profile': showOnProfile,
  };
}

/// The signed-in person's own CV entry on a project (PJ1 "On your CV").
@immutable
class MyCvEntry {
  const MyCvEntry({
    required this.id,
    required this.role,
    required this.confirmed,
    this.start,
    this.end,
  });

  factory MyCvEntry.fromJson(Map<String, dynamic> json) => MyCvEntry(
    id: json['id'] as String,
    role: json['role_title'] as String,
    confirmed: (json['confirmations'] as List? ?? const []).isNotEmpty,
    start: parseMonth(json['start_month']),
    end: parseMonth(json['end_month']),
  );

  final String id;
  final String role;
  final bool confirmed;
  final DateTime? start;
  final DateTime? end;
}

/// Someone who put the project on their CV and shows it (PJ1).
@immutable
class ProjectPerson {
  const ProjectPerson({
    required this.profileId,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.start,
    this.end,
  });

  final String profileId;
  final String firstName;
  final String lastName;
  final String role;
  final DateTime? start;
  final DateTime? end;

  String get fullName => '$firstName $lastName'.trim();
}

/// What "Suggest an edit" is about (PJ1-E).
enum EditField { name, type, location, dates, duplicate }

/// A reference option such as a project type or a place.
@immutable
class RefOption {
  const RefOption({required this.id, required this.name});

  factory RefOption.fromJson(Map<String, dynamic> json) => RefOption(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
  );

  final String id;
  final LocalizedText name;
}
