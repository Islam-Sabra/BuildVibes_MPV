import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../entry/entry_state.dart';

/// The work item being written in place (E1–E4). The app chose its [id]
/// when the card opened, so it is the same post however often it is sent.
@immutable
class WorkItemDraft {
  const WorkItemDraft({
    required this.id,
    this.title = '',
    this.body = '',
    this.ownerId,
    this.ownerName,
    this.place,
    this.dueDate,
    this.dueAt,
    this.photo,
  });

  factory WorkItemDraft.fromJson(Map<String, dynamic> json) => WorkItemDraft(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    ownerId: json['owner_id'] as String?,
    ownerName: json['owner_name'] as String?,
    place: json['place'] as String?,
    dueDate: _day(json['due_date']),
    dueAt: _time(json['due_at']),
    photo: json['photo'] as String?,
  );

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  static DateTime? _day(Object? value) {
    final d = _time(value);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  /// The title's length on the server (create_work_item).
  static const titleMin = 2;
  static const titleMax = 140;
  static const bodyMax = 5000;

  /// The place's length on the server (space_posts.place_text).
  static const placeMax = 80;

  final String id;
  final String title;
  final String body;
  final String? ownerId;

  /// Kept with the id, so the card shows the owner before the Space's
  /// people load.
  final String? ownerName;
  final String? place;

  /// The phone's own due date, and its time when one was chosen.
  final DateTime? dueDate;
  final DateTime? dueAt;

  /// The cover photo: a copy kept in the app's folder, so it outlives the
  /// camera's cache and the app being closed.
  final String? photo;

  /// Nothing typed: no draft (the card just closes).
  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  /// A title the server takes (2 to 140 characters).
  bool get titleFits {
    final length = title.trim().length;
    return length >= titleMin && length <= titleMax;
  }

  /// Post is on: a title that fits, and someone to do it.
  bool get canPost => titleFits && ownerId != null;

  WorkItemDraft copyWith({
    String? title,
    String? body,
    String? ownerId,
    String? ownerName,
    String? Function()? place,
    DateTime? Function()? dueDate,
    DateTime? Function()? dueAt,
    String? Function()? photo,
  }) => WorkItemDraft(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    ownerId: ownerId ?? this.ownerId,
    ownerName: ownerName ?? this.ownerName,
    place: place == null ? this.place : place(),
    dueDate: dueDate == null ? this.dueDate : dueDate(),
    dueAt: dueAt == null ? this.dueAt : dueAt(),
    photo: photo == null ? this.photo : photo(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'owner_id': ownerId,
    'owner_name': ownerName,
    'place': place,
    'due_date': dueDate?.toIso8601String(),
    'due_at': dueAt?.toUtc().toIso8601String(),
    'photo': photo,
  };
}

/// The card being written in one Space, or null. While it holds text it is
/// saved on the phone as it changes, per account and Space, so a killed
/// app comes back to it as a Draft that only its author sees (E4). Drafts
/// never go to the server (data-model §14).
final daybookDraftProvider =
    NotifierProvider.family<DaybookDraft, WorkItemDraft?, String>(
      DaybookDraft.new,
    );

class DaybookDraft extends Notifier<WorkItemDraft?> {
  DaybookDraft(this.spaceId);

  final String spaceId;
  String? _key;

  @override
  WorkItemDraft? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authUserIdProvider).value;
    _key = userId == null ? null : 'daybook_draft:$userId:$spaceId';
    final raw = _key == null ? null : prefs.getString(_key!);
    if (raw == null) return null;
    try {
      return WorkItemDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  /// Opens a new card with [id], or keeps the one being written.
  void open(String id) => state ??= WorkItemDraft(id: id);

  /// Sets the card and saves it while it has text.
  Future<void> put(WorkItemDraft draft) async {
    state = draft;
    final key = _key;
    if (key == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    if (draft.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(draft.toJson()));
    }
  }

  /// The card closes: an empty one is gone, with its photo; one with text
  /// stays as the Draft.
  Future<void> close() async {
    final draft = state;
    if (draft != null && draft.isEmpty) await discard();
  }

  /// Gone for good. [keepPhoto] when the photo went to the outbox with the
  /// post.
  Future<void> discard({bool keepPhoto = false}) async {
    final photo = state?.photo;
    state = null;
    final key = _key;
    if (key != null) {
      await ref.read(sharedPreferencesProvider).remove(key);
    }
    if (!keepPhoto && photo != null) unawaited(deleteKept(photo));
  }

  static Future<void> deleteKept(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}
