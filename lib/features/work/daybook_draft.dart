import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../data/models/daybook.dart';
import '../entry/entry_state.dart';
import 'work_outbox.dart';

/// The work item being written in place (E1–E4), or a posted one being
/// edited (X1 Edit). The app chose its [id] when the card opened, so it is
/// the same post however often it is sent.
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
    this.couldNotSend = false,
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
    couldNotSend: json['could_not_send'] as bool? ?? false,
  );

  /// A post the server refused, back as the Draft it was (review 46).
  factory WorkItemDraft.refused(PendingItem item) => WorkItemDraft(
    id: item.id,
    title: item.title,
    body: item.body ?? '',
    ownerId: item.ownerId,
    ownerName: item.ownerName,
    place: item.place,
    dueDate: item.dueDate,
    dueAt: item.dueAt,
    photo: item.photos.firstOrNull?.local,
    couldNotSend: true,
  );

  /// A posted work item, to edit.
  factory WorkItemDraft.of(DaybookPost post) => WorkItemDraft(
    id: post.id,
    title: post.title,
    body: post.body ?? '',
    ownerId: post.item?.ownerId,
    ownerName: post.item?.ownerName,
    place: post.place,
    dueDate: post.dueDate,
    dueAt: post.dueAt,
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

  /// The server refused it when it was posted: "Couldn't send. Tap to fix".
  final bool couldNotSend;

  /// Nothing entered at all: no draft (the card just closes). A photo, an
  /// owner, a date or a place alone is kept (review 46: the photo often
  /// comes first).
  bool get isEmpty =>
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      ownerId == null &&
      place == null &&
      dueDate == null &&
      photo == null;

  /// A title the server takes (2 to 140 characters): Post turns on.
  bool get titleFits {
    final length = title.trim().length;
    return length >= titleMin && length <= titleMax;
  }

  /// Ready to send: a title that fits, and someone to do it.
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
    couldNotSend: couldNotSend,
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
    'could_not_send': couldNotSend,
  };
}

/// The card in place: a new work item's ([DaybookDraft]) or an edit's
/// ([DaybookEdit]).
abstract class DaybookWritingNotifier extends Notifier<WorkItemDraft?> {
  Future<void> put(WorkItemDraft draft);
}

/// The card being written in one Space, or null. As soon as anything is
/// entered it is saved on the phone as it changes, per account and Space,
/// so a killed app comes back to it as a Draft that only its author sees
/// (E4). Drafts never go to the server (data-model §14).
final daybookDraftProvider =
    NotifierProvider.family<DaybookDraft, WorkItemDraft?, String>(
      DaybookDraft.new,
    );

class DaybookDraft extends DaybookWritingNotifier {
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

  /// Sets the card and saves it once anything is entered.
  @override
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

  /// A post the server refused comes back as the Draft, unless another
  /// card holds something. True when it did.
  Future<bool> restoreRefused(PendingItem item) async {
    final current = state;
    if (current != null && !current.isEmpty) return false;
    await put(WorkItemDraft.refused(item));
    return true;
  }

  /// The card closes: an empty one is gone, with its photo; one with
  /// anything in it stays as the Draft.
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

/// A posted work item being edited in place (X1 Edit → 2524:33577): its
/// card at Now, filled with what it says. Only on the screen; putting it
/// down leaves the post as it was.
final daybookEditProvider =
    NotifierProvider.family<DaybookEdit, WorkItemDraft?, String>(
      DaybookEdit.new,
    );

class DaybookEdit extends DaybookWritingNotifier {
  DaybookEdit(this.spaceId);

  final String spaceId;

  /// The post as it was, to send only what changed.
  DaybookPost? original;

  @override
  WorkItemDraft? build() => null;

  void start(DaybookPost post) {
    original = post;
    state = WorkItemDraft.of(post);
  }

  @override
  Future<void> put(WorkItemDraft draft) async => state = draft;

  void stop() {
    original = null;
    state = null;
  }
}
