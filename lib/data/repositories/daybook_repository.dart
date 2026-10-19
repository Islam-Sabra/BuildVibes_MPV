import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daybook.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';
import 'work_repository.dart' show newUuid, spaceFilesBucket;

/// A Space's daybook (migrations 18, 19, 23, 26 and 28): its cards, newest
/// activity first, what sits above them, the month's marks and what is due
/// for you; writing a post of any kind in place; ticking a checklist's
/// points and acknowledging. Failures arrive as [SpaceException].
///
/// Days come from the phone: each call sends the phone's own days and
/// midnights, so no time zone is typed in SQL.
abstract class DaybookRepository {
  /// The cards (one per post, migration 26) whose last activity is before
  /// [before] (with [beforeId], cards with the same time aren't skipped),
  /// newest activity first, at most [limit].
  Future<DaybookCardsPage> cards(
    String spaceId, {
    DateTime? before,
    String? beforeId,
    int limit = 30,
  });

  /// "Show earlier": the post's history lines before the line at [before]
  /// and [beforeId], newest first, at most [limit], and whether older ones
  /// are left (post_history's `more`). With no [before], from the newest:
  /// none when the post was deleted or can't be seen (F20).
  Future<DaybookHistoryPage> history(
    String postId, {
    DateTime? before,
    String? beforeId,
    int limit = historyPage,
  });

  /// post_history's page, as daybook_cards' first one.
  static const historyPage = 50;

  /// The days of [month] with posts the caller can see, and with something
  /// due that isn't checked.
  Future<DaybookMonth> month(String spaceId, DateTime month);

  /// The work items due on [day] that are mine to sign or written by me,
  /// in every Space I'm in.
  Future<List<CalendarWorkItem>> dueOn(DateTime day);

  /// What sits above the daybook on [day] (the phone's): the announcements
  /// pinned now and the activities starting that day.
  Future<DaybookExtras> extras(String spaceId, DateTime day);

  /// A checklist's points, in order, with who ticked each when.
  Future<List<DaybookPoint>> points(String postId);

  /// Who acknowledged [postId] (post_acks_for): the server shows Received
  /// to everyone who sees the file, and the rest only to the author.
  Future<List<DaybookAckFace>> acks(String postId);

  /// tick_point: tick ([on]) or untick a point.
  Future<void> tickPoint(String pointId, {required bool on});

  /// ack: Got it, Received, On my way or In my calendar; [on] false takes
  /// your own back.
  Future<void> ack(String postId, DaybookAck kind, {required bool on});

  /// create_space_post: a checklist, an announcement, an activity or a
  /// file. The app chose [NewSpacePost.id], so sending it again is the
  /// same post.
  Future<void> createPost(NewSpacePost post);

  /// attach_library_file: a Library file on a work item ("Used in").
  Future<void> attachFile(String itemId, String libraryFileId);

  /// Uploads a photo for the post [postId] (which may not exist yet) to
  /// `<space>/posts/<post>/<new uuid>.jpg` and returns the path. Every call
  /// uses a new name, so a retry never replaces a file.
  Future<String> uploadPostPhoto(String spaceId, String postId, File file);

  /// create_work_item. The app chose [NewWorkItem.id], so sending it again
  /// is the same post.
  Future<void> createWorkItem(NewWorkItem item);

  /// edit_space_post: only what changed ([PostEdit]); the author only,
  /// while the work item is Open.
  Future<void> editPost(String postId, PostEdit edit);

  /// cancel_space_post: it stays on the daybook, stamped CANCELLED.
  Future<void> cancelPost(String postId);
}

/// One post_history call: the lines, newest first, and whether older ones
/// are left.
typedef DaybookHistoryPage = ({List<DaybookEvent> lines, bool more});

/// A post of another kind written in place, as create_space_post takes
/// it. Only what fits its [kind] is sent: people, points and the due for
/// a checklist; the pin for an announcement; the start, end, place and
/// people for an activity; the Library file for a file post.
@immutable
class NewSpacePost {
  const NewSpacePost({
    required this.id,
    required this.spaceId,
    required this.kind,
    required this.title,
    this.body,
    this.place,
    this.dueDate,
    this.dueAt,
    this.pinnedUntil,
    this.startsAt,
    this.endsAt,
    this.libraryFileId,
    this.people = const [],
    this.points = const [],
    this.photoPaths = const [],
  });

  final String id;
  final String spaceId;

  /// 'checklist', 'announcement', 'activity' or 'file'.
  final String kind;

  /// A file post may leave it empty: the server takes the file's name.
  final String title;
  final String? body;
  final String? place;
  final DateTime? dueDate;
  final DateTime? dueAt;
  final DateTime? pinnedUntil;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? libraryFileId;
  final List<String> people;

  /// Each point with the id the app chose.
  final List<({String id, String text})> points;

  /// Uploaded photos, in the post's folder.
  final List<String> photoPaths;

  /// What create_space_post takes.
  Map<String, Object?> toParams() {
    final checklist = kind == DaybookPost.checklistKind;
    final activity = kind == DaybookPost.activityKind;
    String? text(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();
    return {
      'p_id': id,
      'p_space': spaceId,
      'p_kind': kind,
      'p_title': text(title),
      'p_body': text(body),
      'p_place': activity ? text(place) : null,
      'p_due': checklist && dueDate != null ? _date(dueDate!) : null,
      'p_due_at': checklist && dueAt != null ? _instant(dueAt!) : null,
      'p_pinned_until':
          kind == DaybookPost.announcementKind && pinnedUntil != null
          ? _instant(pinnedUntil!)
          : null,
      'p_starts_at': activity && startsAt != null ? _instant(startsAt!) : null,
      'p_ends_at': activity && endsAt != null ? _instant(endsAt!) : null,
      'p_library_file': kind == DaybookPost.fileKind ? libraryFileId : null,
      'p_people': checklist || activity ? people : const <String>[],
      'p_points': [
        if (checklist)
          for (final p in points) {'id': p.id, 'text': p.text.trim()},
      ],
      'p_files': [
        for (final path in photoPaths) {'path': path, 'mime': _jpeg},
      ],
    };
  }
}

const _jpeg = 'image/jpeg';

/// What an edit changes on a work item (edit_space_post's keys). A field
/// left out stays as it is. [dueChanged] sends the due day and time
/// together; a null [dueDate] takes the due off ("Edited: due removed").
@immutable
class PostEdit {
  const PostEdit({
    this.title,
    this.body,
    this.place,
    this.placeChanged = false,
    this.bodyChanged = false,
    this.dueChanged = false,
    this.dueDate,
    this.dueAt,
  });

  final String? title;
  final String? body;
  final bool bodyChanged;
  final String? place;
  final bool placeChanged;
  final bool dueChanged;
  final DateTime? dueDate;
  final DateTime? dueAt;

  bool get isEmpty =>
      title == null && !bodyChanged && !placeChanged && !dueChanged;

  /// The JSON edit_space_post takes; the due day and time are the phone's
  /// own.
  Map<String, Object?> toJson() => {
    'title': ?title?.trim(),
    if (bodyChanged) 'body': body?.trim() ?? '',
    if (placeChanged) 'place': place?.trim() ?? '',
    if (dueChanged) ...{
      'due': dueDate == null ? null : _date(dueDate!),
      'due_at': dueAt == null ? null : _instant(dueAt!),
    },
  };
}

/// A work item written in place, as create_work_item takes it. The due
/// date and time are the phone's own (review 44, answer 3).
@immutable
class NewWorkItem {
  const NewWorkItem({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.ownerId,
    this.body,
    this.place,
    this.dueDate,
    this.dueAt,
    this.photoPaths = const [],
    this.libraryFileIds = const [],
  });

  final String id;
  final String spaceId;
  final String title;
  final String ownerId;
  final String? body;
  final String? place;
  final DateTime? dueDate;
  final DateTime? dueAt;

  /// Uploaded photos, in the post's folder.
  final List<String> photoPaths;

  /// Library files to put on it once it is made (attach_library_file).
  final List<String> libraryFileIds;
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _instant(DateTime t) => t.toUtc().toIso8601String();

class SupabaseDaybookRepository implements DaybookRepository {
  const SupabaseDaybookRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on StorageException catch (e) {
      throw SpaceException(SpaceFailure.unknown, e.message);
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        '$e',
      );
    }
  }

  List<Map<String, dynamic>> _rows(Object? result) =>
      (result as List? ?? const []).cast<Map<String, dynamic>>();

  @override
  Future<DaybookCardsPage> cards(
    String spaceId, {
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'daybook_cards',
        params: {
          'p_space': spaceId,
          'p_before': before == null ? null : _instant(before),
          'p_limit': limit,
          'p_before_id': beforeId,
        },
      ),
    );
    return DaybookCardsPage.fromRows(rows);
  });

  @override
  Future<DaybookHistoryPage> history(
    String postId, {
    DateTime? before,
    String? beforeId,
    int limit = DaybookRepository.historyPage,
  }) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'post_history',
        params: {
          'p_post': postId,
          'p_before': before == null ? null : _instant(before),
          'p_before_id': beforeId,
          'p_limit': limit,
        },
      ),
    );
    return (
      lines: [
        for (final r in rows)
          DaybookEvent.fromJson(r['event'] as Map<String, dynamic>),
      ],
      // Every row carries the same value; an empty page has none.
      more: rows.firstOrNull?['more'] as bool? ?? false,
    );
  });

  @override
  Future<DaybookMonth> month(String spaceId, DateTime month) =>
      _guard(() async {
        final first = DateTime(month.year, month.month);
        final next = DateTime(month.year, month.month + 1);
        final rows = _rows(
          await _client.rpc<List<dynamic>>(
            'daybook_month',
            params: {
              'p_space': spaceId,
              'p_from_day': _date(first),
              'p_to_day': _date(next.subtract(const Duration(days: 1))),
              'p_from': _instant(first),
              'p_to': _instant(next),
            },
          ),
        );
        return DaybookMonth.fromRows(rows);
      });

  @override
  Future<List<CalendarWorkItem>> dueOn(DateTime day) => _guard(() async {
    final start = DateTime(day.year, day.month, day.day);
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'my_calendar',
        params: {
          'p_from_day': _date(start),
          'p_to_day': _date(start),
          'p_from': _instant(start),
          'p_to': _instant(DateTime(day.year, day.month, day.day + 1)),
        },
      ),
    );
    return [for (final r in rows) ?CalendarWorkItem.fromJson(r)];
  });

  @override
  Future<String> uploadPostPhoto(String spaceId, String postId, File file) =>
      _guard(() async {
        final path = '$spaceId/posts/$postId/${newUuid()}.jpg';
        await _client.storage
            .from(spaceFilesBucket)
            .upload(
              path,
              file,
              fileOptions: const FileOptions(contentType: _jpeg),
            );
        return path;
      });

  @override
  Future<void> createWorkItem(NewWorkItem item) => _guard(
    () => _client.rpc<String>(
      'create_work_item',
      params: {
        'p_id': item.id,
        'p_space': item.spaceId,
        'p_title': item.title.trim(),
        'p_owner': item.ownerId,
        'p_body': item.body?.trim(),
        'p_place': item.place?.trim(),
        'p_due': item.dueDate == null ? null : _date(item.dueDate!),
        'p_due_at': item.dueAt == null ? null : _instant(item.dueAt!),
        'p_files': [
          for (final path in item.photoPaths) {'path': path, 'mime': _jpeg},
        ],
      },
    ),
  );

  @override
  Future<DaybookExtras> extras(String spaceId, DateTime day) =>
      _guard(() async {
        final start = DateTime(day.year, day.month, day.day);
        final rows = _rows(
          await _client.rpc<List<dynamic>>(
            'daybook_extras',
            params: {
              'p_space': spaceId,
              'p_from': _instant(start),
              'p_to': _instant(DateTime(day.year, day.month, day.day + 1)),
            },
          ),
        );
        return DaybookExtras.fromRows(rows);
      });

  @override
  Future<List<DaybookPoint>> points(String postId) => _guard(() async {
    final rows = await _client
        .from('checklist_points')
        .select('id, text, ticked_by, ticked_at')
        .eq('post_id', postId)
        .order('sort')
        .order('id');
    return [for (final r in rows) DaybookPoint.fromJson(r)];
  });

  @override
  Future<List<DaybookAckFace>> acks(String postId) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'post_acks_for',
        params: {'p_post': postId},
      ),
    );
    return [for (final r in rows) DaybookAckFace.fromJson(r)];
  });

  @override
  Future<void> tickPoint(String pointId, {required bool on}) => _guard(
    () => _client.rpc<void>(
      'tick_point',
      params: {'p_point': pointId, 'p_on': on},
    ),
  );

  @override
  Future<void> ack(String postId, DaybookAck kind, {required bool on}) =>
      _guard(
        () => _client.rpc<void>(
          'ack',
          params: {'p_post': postId, 'p_kind': kind.json, 'p_on': on},
        ),
      );

  @override
  Future<void> createPost(NewSpacePost post) => _guard(
    () => _client.rpc<String>('create_space_post', params: post.toParams()),
  );

  @override
  Future<void> attachFile(String itemId, String libraryFileId) => _guard(
    () => _client.rpc<void>(
      'attach_library_file',
      params: {'p_item': itemId, 'p_file': libraryFileId},
    ),
  );

  @override
  Future<void> editPost(String postId, PostEdit edit) => _guard(
    () => _client.rpc<void>(
      'edit_space_post',
      params: {'p_id': postId, 'p_changes': edit.toJson()},
    ),
  );

  @override
  Future<void> cancelPost(String postId) => _guard(
    () => _client.rpc<void>('cancel_space_post', params: {'p_id': postId}),
  );
}

final daybookRepositoryProvider = Provider<DaybookRepository>(
  (ref) => SupabaseDaybookRepository(ref.watch(supabaseClientProvider)),
);
