import 'package:flutter/foundation.dart';

import 'work_item.dart';

DateTime? _time(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// A date with no time ("2026-10-15"), as the phone's own calendar day.
DateTime? _day(Object? value) {
  if (value == null) return null;
  final d = DateTime.parse(value as String);
  return DateTime(d.year, d.month, d.day);
}

/// The phone's calendar day of [t].
DateTime dayOf(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The work item behind a post (space_post_json "item").
@immutable
class DaybookItem {
  const DaybookItem({
    required this.status,
    this.ownerId,
    this.ownerName,
    this.ref,
  });

  factory DaybookItem.fromJson(Map<String, dynamic> json) => DaybookItem(
    status: WorkStatus.fromJson(json['status']),
    ownerId: json['owner_id'] as String?,
    ownerName: json['owner_name'] as String?,
    ref: json['ref'] as String?,
  );

  final WorkStatus status;

  /// "KCT-021".
  final String? ref;
  final String? ownerId;

  /// Null across a block or for a hidden account: "Former member".
  final String? ownerName;
}

/// A change of due in an edit ("moved the due date from Thu to today", or
/// "took the due date off" when [to] is null). A time-only change has the
/// same [from] and [to] days.
@immutable
class DaybookDueEdit {
  const DaybookDueEdit({this.from, this.to, this.fromAt, this.toAt});

  /// An edit's `changes.due`, or null when the due didn't change.
  static DaybookDueEdit? fromChanges(Map<String, dynamic>? changes) {
    final due = changes?['due'] as Map<String, dynamic>?;
    if (due == null) return null;
    return DaybookDueEdit(
      from: _day(due['from']),
      to: _day(due['to']),
      fromAt: _time(due['from_at']),
      toAt: _time(due['to_at']),
    );
  }

  final DateTime? from;
  final DateTime? to;
  final DateTime? fromAt;
  final DateTime? toAt;

  bool get timeOnly =>
      from != null && from == to && (fromAt != null || toAt != null);

  /// The due was taken off.
  bool get removed => from != null && to == null;
}

/// A Library file on a work item's card ("M-201 Rev C").
@immutable
class DaybookAttachment {
  const DaybookAttachment({required this.name, this.revLabel});

  final String name;
  final String? revLabel;
}

/// A post on a Space's daybook, as space_post_json gives it.
@immutable
class DaybookPost {
  const DaybookPost({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.title,
    this.body,
    this.cancelled = false,
    this.authorId,
    this.authorName,
    this.place,
    this.dueDate,
    this.dueAt,
    this.item,
    this.pointsTotal = 0,
    this.coverPath,
    this.attachments = const [],
    this.attachmentsMore = false,
  });

  factory DaybookPost.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>?;
    final points = json['points'] as Map<String, dynamic>?;
    return DaybookPost(
      id: json['id'] as String,
      kind: json['kind'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      cancelled: json['status'] == 'cancelled',
      authorId: json['author_id'] as String?,
      authorName: json['author_name'] as String?,
      place: json['place'] as String?,
      dueDate: _day(json['due_date']),
      dueAt: _time(json['due_at']),
      item: item == null ? null : DaybookItem.fromJson(item),
      pointsTotal: (points?['total'] as num?)?.toInt() ?? 0,
      coverPath: json['cover_path'] as String?,
      attachments: [
        for (final a in json['attachments'] as List? ?? const [])
          DaybookAttachment(
            name: (a as Map<String, dynamic>)['name'] as String? ?? '',
            revLabel: a['rev_label'] as String?,
          ),
      ],
      attachmentsMore: json['attachments_more'] as bool? ?? false,
    );
  }

  static const workItemKind = 'work_item';

  final String id;

  /// 'work_item', 'checklist', 'announcement', 'activity', 'file' or
  /// 'report'. Slice 1 shows work items only.
  final String kind;
  final DateTime createdAt;
  final String title;

  /// The text under the title, as written.
  final String? body;
  final bool cancelled;
  final String? authorId;

  /// Null across a block or for a hidden account: "Former member".
  final String? authorName;
  final String? place;

  /// The due day, and its time when it has one.
  final DateTime? dueDate;
  final DateTime? dueAt;
  final DaybookItem? item;

  /// Checklist points on the work item.
  final int pointsTotal;

  /// The first photo of the post, in the Space's files.
  final String? coverPath;

  /// The work item's first Library files, and whether it has more.
  final List<DaybookAttachment> attachments;
  final bool attachmentsMore;

  bool get isWorkItem => kind == workItemKind;

  bool get isOpen => !cancelled && item?.status == WorkStatus.open;

  /// The post as the phone shows it while something it did waits to be
  /// sent: checked, signed or cancelled here.
  DaybookPost shownAs({WorkStatus? status, bool cancelled = false}) =>
      DaybookPost(
        id: id,
        kind: kind,
        createdAt: createdAt,
        title: title,
        body: body,
        cancelled: cancelled || this.cancelled,
        authorId: authorId,
        authorName: authorName,
        place: place,
        dueDate: dueDate,
        dueAt: dueAt,
        item: item == null
            ? null
            : DaybookItem(
                status: status ?? item!.status,
                ownerId: item!.ownerId,
                ownerName: item!.ownerName,
                ref: item!.ref,
              ),
        pointsTotal: pointsTotal,
        coverPath: coverPath,
        attachments: attachments,
        attachmentsMore: attachmentsMore,
      );

  /// Late (review 44, answer 3): an open, live item past its time, or, with
  /// no time, from the day after its date.
  bool isLate(DateTime now) {
    if (cancelled || item?.status != WorkStatus.open || dueDate == null) {
      return false;
    }
    if (dueAt != null) return now.isAfter(dueAt!);
    return dayOf(now).isAfter(dueDate!);
  }

  /// Whole calendar days past the due date; 0 on the due day itself.
  int lateDays(DateTime now) => dayOf(now).difference(dueDate!).inDays;
}

List<WorkPhoto> _photos(Object? value) => [
  for (final p in value as List? ?? const [])
    if ((p as Map<String, dynamic>)['path'] != null)
      WorkPhoto(
        path: p['path'] as String,
        takenAt: _time(p['taken_at']),
        place: p['place'] as String?,
      ),
];

/// What came after the latest sign-off (the card's stamp).
enum DaybookOutcomeKind {
  done,
  checked,
  sentBack,
  cancelled;

  static DaybookOutcomeKind fromJson(Object? value) => switch (value) {
    'checked' => checked,
    'sent_back' => sentBack,
    'cancelled' => cancelled,
    _ => done,
  };
}

@immutable
class DaybookOutcome {
  const DaybookOutcome({
    required this.kind,
    this.at,
    this.byId,
    this.byName,
    this.reason,
    this.note,
  });

  factory DaybookOutcome.fromJson(Map<String, dynamic>? json) => DaybookOutcome(
    kind: DaybookOutcomeKind.fromJson(json?['kind']),
    at: _time(json?['at']),
    byId: json?['by_id'] as String?,
    byName: json?['by_name'] as String?,
    reason: SendBackReason.fromJson(json?['reason']),
    note: json?['note'] as String?,
  );

  final DaybookOutcomeKind kind;
  final DateTime? at;

  /// Who signed it, checked it, sent it back or cancelled it.
  final String? byId;
  final String? byName;

  /// A send-back's reason and note.
  final SendBackReason? reason;
  final String? note;
}

/// The latest sign-off on a card (daybook_cards "proof"): its photos or
/// note, who signed and when, and what came after it.
@immutable
class DaybookProof {
  const DaybookProof({
    required this.at,
    required this.outcome,
    this.eventId,
    this.byId,
    this.byName,
    this.note,
    this.photos = const [],
  });

  factory DaybookProof.fromJson(Map<String, dynamic> json) {
    final by = json['by'] as Map<String, dynamic>?;
    return DaybookProof(
      eventId: json['event_id'] as String?,
      at: DateTime.parse(json['at'] as String),
      byId: by?['id'] as String?,
      byName: by?['name'] as String?,
      note: json['note'] as String?,
      photos: _photos(json['photos']),
      outcome: DaybookOutcome.fromJson(
        json['outcome'] as Map<String, dynamic>?,
      ),
    );
  }

  final String? eventId;
  final DateTime at;
  final String? byId;

  /// Null across a block or for a hidden account: "Former member".
  final String? byName;
  final String? note;
  final List<WorkPhoto> photos;
  final DaybookOutcome outcome;

  /// The same proof with another outcome: a check made here, while its
  /// undo bar shows or it waits for a signal.
  DaybookProof withOutcome(DaybookOutcome outcome) => DaybookProof(
    eventId: eventId,
    at: at,
    byId: byId,
    byName: byName,
    note: note,
    photos: photos,
    outcome: outcome,
  );
}

/// One line of a card's history (daybook_cards "history", post_history).
enum DaybookEventKind {
  raised,
  done,
  checked,
  sentBack,
  comment,
  reassigned,
  edited,
  cancelled,

  /// A kind this version doesn't know: kept for paging, never drawn.
  unknown;

  static DaybookEventKind fromJson(Object? value) => switch (value) {
    'raised' => raised,
    'done' => done,
    'checked' => checked,
    'sent_back' => sentBack,
    'comment' => comment,
    'reassigned' => reassigned,
    'edited' => edited,
    'cancelled' => cancelled,
    _ => unknown,
  };
}

/// Something that happened to a post, at its own time.
@immutable
class DaybookEvent {
  const DaybookEvent({
    required this.id,
    required this.kind,
    required this.at,
    this.byId,
    this.byName,
    this.note,
    this.reason,
    this.photos = const [],
    this.fromName,
    this.toName,
    this.dueEdit,
  });

  factory DaybookEvent.fromJson(Map<String, dynamic> json) => DaybookEvent(
    id: json['id'] as String,
    kind: DaybookEventKind.fromJson(json['kind']),
    at: DateTime.parse(json['at'] as String),
    byId: json['by_id'] as String?,
    byName: json['by_name'] as String?,
    note: json['note'] as String?,
    reason: SendBackReason.fromJson(json['reason']),
    photos: _photos(json['photos']),
    fromName: json['from_name'] as String?,
    toName: json['to_name'] as String?,
    dueEdit: DaybookDueEdit.fromChanges(
      json['changes'] as Map<String, dynamic>?,
    ),
  );

  final String id;
  final DaybookEventKind kind;
  final DateTime at;
  final String? byId;

  /// Null across a block or for a hidden account: "Former member".
  final String? byName;
  final String? note;

  /// A send-back's reason.
  final SendBackReason? reason;
  final List<WorkPhoto> photos;

  /// A reassignment: who had it, who has it now.
  final String? fromName;
  final String? toName;

  /// An edit that moved the due.
  final DaybookDueEdit? dueEdit;

  /// Drawn as a line on the card; the card's header already says who
  /// raised it.
  bool get shown =>
      kind != DaybookEventKind.raised && kind != DaybookEventKind.unknown;
}

/// What a card needs from the reader (daybook_cards "needs_me"): the paper
/// clip and the card's one action.
enum DaybookNeed {
  /// The owner, while it is Open: Sign as done.
  toSign,

  /// Whoever may check it, while it is Done: double-tap the photo.
  toCheck,

  /// The author, when the owner can no longer sign: Give to someone else.
  giveTo,

  /// A checklist point to tick (slice 2).
  toTick,

  /// A value this version doesn't know: the clip, with no action.
  unknown;

  static DaybookNeed? fromJson(Object? value) => switch (value) {
    null => null,
    'to_sign' => toSign,
    'to_check' => toCheck,
    'give_to' => giveTo,
    'to_tick' => toTick,
    _ => unknown,
  };
}

/// One card on a Space's daybook (daybook_cards): a post with its latest
/// proof, its history inside, and what it needs from the reader. Cards
/// come newest activity first; [lastActivityAt] and the post's id are the
/// page's cursor.
@immutable
class DaybookCard {
  const DaybookCard({
    required this.post,
    required this.lastActivityAt,
    this.proof,
    this.history = const [],
    this.historyMore = false,
    this.need,
  });

  factory DaybookCard.fromJson(Map<String, dynamic> json) => DaybookCard(
    post: DaybookPost.fromJson(json),
    lastActivityAt: DateTime.parse(json['last_activity_at'] as String),
    proof: json['proof'] == null
        ? null
        : DaybookProof.fromJson(json['proof'] as Map<String, dynamic>),
    history: [
      for (final e in json['history'] as List? ?? const [])
        DaybookEvent.fromJson(e as Map<String, dynamic>),
    ],
    historyMore: json['history_more'] as bool? ?? false,
    need: DaybookNeed.fromJson(json['needs_me']),
  );

  final DaybookPost post;
  final DateTime lastActivityAt;
  final DaybookProof? proof;

  /// Newest first, as the server sends it: the first 50, then
  /// [historyMore].
  final List<DaybookEvent> history;
  final bool historyMore;

  /// Null: nothing for the reader (a Viewer always).
  final DaybookNeed? need;

  String get id => post.id;

  DaybookCard copyWith({
    DaybookPost? post,
    DateTime? lastActivityAt,
    DaybookProof? proof,
    List<DaybookEvent>? history,
    bool? historyMore,
    DaybookNeed? need,
    bool clearNeed = false,
  }) => DaybookCard(
    post: post ?? this.post,
    lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    proof: proof ?? this.proof,
    history: history ?? this.history,
    historyMore: historyMore ?? this.historyMore,
    need: clearNeed ? null : need ?? this.need,
  );
}

/// One daybook_cards call: the cards, newest activity first, and the
/// cursor of the last one.
@immutable
class DaybookCardsPage {
  const DaybookCardsPage(this.cards);

  /// The rows as daybook_cards sends them (`id`, `last_activity_at`,
  /// `card`).
  factory DaybookCardsPage.fromRows(List<Map<String, dynamic>> rows) =>
      DaybookCardsPage([
        for (final r in rows)
          DaybookCard.fromJson(r['card'] as Map<String, dynamic>),
      ]);

  final List<DaybookCard> cards;

  DateTime? get lastAt => cards.lastOrNull?.lastActivityAt;
  String? get lastId => cards.lastOrNull?.id;
}

/// What the month drop-down marks (daybook_month), in the phone's days.
@immutable
class DaybookMonth {
  const DaybookMonth({this.postDays = const {}, this.dueDays = const {}});

  /// 'posts' rows are quarter hours with posts, which the phone puts in its
  /// own days; 'due' rows are days.
  factory DaybookMonth.fromRows(List<Map<String, dynamic>> rows) {
    final posts = <DateTime>{};
    final due = <DateTime>{};
    for (final r in rows) {
      if (r['kind'] == 'posts' && r['at'] != null) {
        posts.add(dayOf(DateTime.parse(r['at'] as String)));
      } else if (r['kind'] == 'due' && r['day'] != null) {
        due.add(_day(r['day'])!);
      }
    }
    return DaybookMonth(postDays: posts, dueDays: due);
  }

  final Set<DateTime> postDays;
  final Set<DateTime> dueDays;
}

/// A work item from my_calendar: due on a day, mine to sign or written by
/// me.
@immutable
class CalendarWorkItem {
  const CalendarWorkItem({
    required this.spaceId,
    required this.title,
    required this.day,
    required this.status,
    this.dueAt,
  });

  /// A my_calendar row of kind 'work_item'; null for other kinds.
  static CalendarWorkItem? fromJson(Map<String, dynamic> json) {
    if (json['kind'] != DaybookPost.workItemKind) return null;
    return CalendarWorkItem(
      spaceId: json['space_id'] as String,
      title: json['title'] as String? ?? '',
      day: _day(json['day'])!,
      status: WorkStatus.fromJson(json['status']),
      dueAt: _time(json['starts_at']),
    );
  }

  final String spaceId;
  final String title;
  final DateTime day;
  final WorkStatus status;
  final DateTime? dueAt;
}
