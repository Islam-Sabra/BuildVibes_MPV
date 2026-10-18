import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daybook.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';
import 'work_repository.dart' show newUuid, spaceFilesBucket;

/// A Space's daybook (migrations 18, 19, 23 and 26): its cards, newest
/// activity first, the month's marks and what is due for you; and writing
/// a work item in place. Failures arrive as [SpaceException].
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
  /// and [beforeId], newest first, at most [limit].
  Future<List<DaybookEvent>> history(
    String postId, {
    required DateTime before,
    required String beforeId,
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
  Future<List<DaybookEvent>> history(
    String postId, {
    required DateTime before,
    required String beforeId,
    int limit = DaybookRepository.historyPage,
  }) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'post_history',
        params: {
          'p_post': postId,
          'p_before': _instant(before),
          'p_before_id': beforeId,
          'p_limit': limit,
        },
      ),
    );
    return [
      for (final r in rows)
        DaybookEvent.fromJson(r['event'] as Map<String, dynamic>),
    ];
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

  static const _jpeg = 'image/jpeg';

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
