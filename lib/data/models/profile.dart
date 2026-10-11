import 'package:flutter/foundation.dart';

import '../../core/l10n/months.dart';
import 'market.dart';
import 'people.dart';

/// Who can see a part of a profile: one single choice (rule 6).
enum ShowTo { everyone, connections, onlyMe }

ShowTo showToFromJson(String? v) => switch (v) {
  'connections' => ShowTo.connections,
  'only_me' => ShowTo.onlyMe,
  _ => ShowTo.everyone,
};

String showToToJson(ShowTo v) => switch (v) {
  ShowTo.everyone => 'everyone',
  ShowTo.connections => 'connections',
  ShowTo.onlyMe => 'only_me',
};

/// What a person is open to (R1 "Open to"). The server hides it from people
/// its visibility does not include.
@immutable
class OpenTo {
  const OpenTo({
    this.options = const [],
    this.note,
    this.visibility = ShowTo.everyone,
  });

  factory OpenTo.fromJson(Map<String, dynamic> json) => OpenTo(
    options: [
      for (final o in (json['options'] as List? ?? const [])) o as String,
    ],
    note: json['note'] as String?,
    visibility: showToFromJson(json['visibility'] as String?),
  );

  /// Ids stored in the database; labels live in the ARB files.
  static const allOptions = [
    'contract',
    'consulting',
    'full_time',
    'part_time',
    'mentoring',
  ];

  final List<String> options;
  final String? note;
  final ShowTo visibility;

  bool get isEmpty => options.isEmpty && (note ?? '').trim().isEmpty;

  Map<String, dynamic> toJson() => {
    'options': options,
    'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
    'visibility': showToToJson(visibility),
  };
}

@immutable
class ExperienceEntry {
  const ExperienceEntry({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.companyId,
    this.companyLabel,
    this.visibility = ShowTo.everyone,
  });

  factory ExperienceEntry.fromJson(Map<String, dynamic> json) {
    final company = json['company'] as Map<String, dynamic>?;
    return ExperienceEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      start: parseMonth(json['start_month'])!,
      end: parseMonth(json['end_month']),
      companyId: json['company_id'] as String?,
      companyLabel:
          company?['name'] as String? ?? json['company_name_text'] as String?,
      visibility: showToFromJson(json['visibility'] as String?),
    );
  }

  final String id;
  final String title;
  final DateTime start;

  /// Null means "present".
  final DateTime? end;
  final String? companyId;
  final String? companyLabel;
  final ShowTo visibility;
}

/// What the person typed for one experience entry.
@immutable
class ExperienceInput {
  const ExperienceInput({
    required this.title,
    required this.start,
    this.end,
    this.companyId,
    this.companyNameText,
    this.visibility = ShowTo.everyone,
  });

  final String title;
  final DateTime start;
  final DateTime? end;
  final String? companyId;
  final String? companyNameText;
  final ShowTo visibility;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'start_month': monthToJson(start),
    'end_month': monthToJson(end),
    'company_id': companyId,
    'company_name_text': companyId == null ? companyNameText?.trim() : null,
    'visibility': showToToJson(visibility),
  };
}

/// A project on someone's CV, with its project's title block summary.
@immutable
class CvProjectEntry {
  const CvProjectEntry({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.role,
    required this.showOnProfile,
    required this.confirmed,
    this.projectType,
    this.placeName,
    this.start,
    this.end,
  });

  factory CvProjectEntry.fromJson(Map<String, dynamic> json) {
    final project = json['project'] as Map<String, dynamic>;
    final type = project['type'] as Map<String, dynamic>?;
    final place = project['place'] as Map<String, dynamic>?;
    final confirmations = json['confirmations'] as List? ?? const [];
    return CvProjectEntry(
      id: json['id'] as String,
      projectId: project['id'] as String,
      projectName: project['name'] as String,
      role: json['role_title'] as String,
      showOnProfile: json['show_on_profile'] as bool? ?? true,
      confirmed: confirmations.isNotEmpty,
      projectType: type == null
          ? null
          : LocalizedText.fromJson(type['name'] as Map<String, dynamic>),
      placeName: place == null
          ? null
          : LocalizedText.fromJson(place['name'] as Map<String, dynamic>),
      start: parseMonth(json['start_month']),
      end: parseMonth(json['end_month']),
    );
  }

  final String id;
  final String projectId;
  final String projectName;
  final String role;
  final bool showOnProfile;

  /// A teammate confirmed it ("Confirmed"), or not yet ("Waiting").
  final bool confirmed;
  final LocalizedText? projectType;
  final LocalizedText? placeName;
  final DateTime? start;
  final DateTime? end;
}

/// Everything a profile screen shows. Parts the viewer may not see come
/// back empty from the server (RLS).
@immutable
class ProfileView {
  const ProfileView({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.followerCount,
    required this.followingCount,
    this.headline,
    this.tradeId,
    this.tradeName,
    this.placeId,
    this.placeName,
    this.homeMarketId,
    this.companyId,
    this.companyName,
    this.companyNameText,
    this.photoUrl,
    this.photoPath,
    this.about,
    this.openTo,
    this.experience = const [],
    this.projects = const [],
  });

  final String id;
  final String firstName;
  final String lastName;
  final int followerCount;
  final int followingCount;
  final String? headline;
  final String? tradeId;
  final LocalizedText? tradeName;
  final String? placeId;
  final LocalizedText? placeName;
  final String? homeMarketId;
  final String? companyId;
  final String? companyName;
  final String? companyNameText;
  final String? photoUrl;
  final String? photoPath;
  final String? about;
  final OpenTo? openTo;
  final List<ExperienceEntry> experience;
  final List<CvProjectEntry> projects;

  String get fullName => '$firstName $lastName'.trim();

  String? get companyLabel => companyName ?? companyNameText;

  /// The headline when set, otherwise the trade.
  String? roleLabel(String languageCode) {
    if ((headline ?? '').trim().isNotEmpty) return headline;
    final name = tradeName;
    if (name == null || tradeId == Trade.otherId) return null;
    return languageCode == 'ar' ? name.ar : name.en;
  }

  /// "Finish your profile": photo, headline, about, experience, a project.
  (int done, int total) get completion {
    final steps = [
      photoPath != null,
      (headline ?? '').trim().isNotEmpty,
      (about ?? '').trim().isNotEmpty,
      experience.isNotEmpty,
      projects.isNotEmpty,
    ];
    return (steps.where((s) => s).length, steps.length);
  }
}

/// What "Name, photo and headline" saves.
@immutable
class BasicsInput {
  const BasicsInput({
    required this.firstName,
    required this.lastName,
    this.headline,
    this.placeId,
    this.tradeId,
    this.companyId,
    this.companyNameText,
  });

  final String firstName;
  final String lastName;
  final String? headline;
  final String? placeId;
  final String? tradeId;
  final String? companyId;
  final String? companyNameText;

  Map<String, dynamic> toJson() => {
    'first_name': firstName.trim(),
    'last_name': lastName.trim(),
    'headline': (headline ?? '').trim().isEmpty ? null : headline!.trim(),
    'place_id': placeId,
    'trade_id': ?tradeId,
    'company_id': companyId,
    'company_name_text': companyId == null
        ? ((companyNameText ?? '').trim().isEmpty
              ? null
              : companyNameText!.trim())
        : null,
  };
}
