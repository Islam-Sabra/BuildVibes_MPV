import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post_page.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// Someone saved the page in between (save_blocks' 40001): the author's
/// other phone. The page is read again and the edit applied once more.
class PageStaleException implements Exception {
  const PageStaleException();
}

/// A post's full page (slice 5, review 76): reading it (post_page), saving
/// its blocks by version (save_blocks), its points and words
/// (edit_space_post), a work item under it (create_work_item with
/// p_parent) and Turn into in one step (turn_point_into_item, migration
/// 36). Every rule is the server's: the author edits, while editable.
abstract class PageRepository {
  /// Null when it's gone or you may not see it.
  Future<PostPage?> page(String postId);

  /// Saves [blocks] if the page is still at [baseVersion]; [addFiles]
  /// (post_files, as add_post_files takes them) go on first. The new
  /// version. Throws [PageStaleException] when it changed in between.
  Future<int> save(
    String postId,
    List<PageBlock> blocks, {
    required int baseVersion,
    List<Map<String, Object?>> addFiles = const [],
  });

  /// edit_space_post: [changes] as it takes them (title, body, points).
  Future<void> edit(String postId, Map<String, Object?> changes);

  /// A work item under [parentId], for [ownerId], under the id the app
  /// chose (the same item however often it is sent).
  Future<void> addItemUnder({
    required String spaceId,
    required String parentId,
    required String id,
    required String title,
    required String ownerId,
  });

  /// turn_point_into_item: [pointId] becomes the work item [itemId] for
  /// [ownerId], titled [title] (the sheet's words, review 79 C1), in one
  /// step. The page's new version.
  Future<int> turnPointIntoItem({
    required String postId,
    required String pointId,
    required String itemId,
    required String ownerId,
    required String title,
    required int baseVersion,
  });

  /// tick_task_row (review 105C-B): [on] on [rowId] of the table of tasks
  /// [blockId]; the owner or a Lead, while the item is Open. The page's new
  /// version.
  Future<int> tickTaskRow({
    required String postId,
    required String blockId,
    required String rowId,
    required bool on,
  });

  /// add_task_row: "Add a row" at the end of [blockId], under the id the
  /// app chose (the same row however often it is sent). The page's new
  /// version.
  Future<int> addTaskRow({
    required String postId,
    required String blockId,
    required String rowId,
    required String text,
    String note = '',
  });

  /// space_task_tables: the tables of tasks on [spaceId]'s work items, by
  /// post, for the cards.
  Future<Map<String, List<PageTaskTable>>> taskTables(String spaceId);
}

class SupabasePageRepository implements PageRepository {
  const SupabasePageRepository(this._client);

  final SupabaseClient _client;

  static const _stale = '40001';

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      if (e.code == _stale) throw const PageStaleException();
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        '$e',
      );
    }
  }

  @override
  Future<PostPage?> page(String postId) => _guard(() async {
    final json = await _client.rpc<Map<String, dynamic>?>(
      'post_page',
      params: {'p_id': postId},
    );
    return json == null ? null : PostPage.fromJson(json);
  });

  @override
  Future<int> save(
    String postId,
    List<PageBlock> blocks, {
    required int baseVersion,
    List<Map<String, Object?>> addFiles = const [],
  }) => _guard(() async {
    final version = await _client.rpc<int>(
      'save_blocks',
      params: {
        'p_id': postId,
        'p_blocks': [for (final b in blocks) b.toJson()],
        'p_base_version': baseVersion,
        'p_add_files': addFiles.isEmpty ? null : addFiles,
      },
    );
    return version;
  });

  @override
  Future<void> edit(String postId, Map<String, Object?> changes) => _guard(
    () => _client.rpc<void>(
      'edit_space_post',
      params: {'p_id': postId, 'p_changes': changes},
    ),
  );

  @override
  Future<void> addItemUnder({
    required String spaceId,
    required String parentId,
    required String id,
    required String title,
    required String ownerId,
  }) => _guard(() async {
    try {
      await _client.rpc<String>(
        'create_work_item',
        params: {
          'p_space': spaceId,
          'p_title': title,
          'p_owner': ownerId,
          'p_id': id,
          'p_parent': parentId,
        },
      );
    } on PostgrestException catch (e) {
      // Sent before and only the answer was lost: the item is there.
      if (e.code == '42501' && e.message.contains('this id is taken')) return;
      rethrow;
    }
  });

  @override
  Future<int> turnPointIntoItem({
    required String postId,
    required String pointId,
    required String itemId,
    required String ownerId,
    required String title,
    required int baseVersion,
  }) => _guard(
    () => _client.rpc<int>(
      'turn_point_into_item',
      params: {
        'p_post': postId,
        'p_point': pointId,
        'p_item_id': itemId,
        'p_owner': ownerId,
        'p_base_version': baseVersion,
        'p_title': title,
      },
    ),
  );

  @override
  Future<int> tickTaskRow({
    required String postId,
    required String blockId,
    required String rowId,
    required bool on,
  }) => _guard(
    () => _client.rpc<int>(
      'tick_task_row',
      params: {
        'p_post': postId,
        'p_block': blockId,
        'p_row': rowId,
        'p_on': on,
      },
    ),
  );

  @override
  Future<int> addTaskRow({
    required String postId,
    required String blockId,
    required String rowId,
    required String text,
    String note = '',
  }) => _guard(
    () => _client.rpc<int>(
      'add_task_row',
      params: {
        'p_post': postId,
        'p_block': blockId,
        'p_row': rowId,
        'p_text': text.trim(),
        'p_note': note.trim().isEmpty ? null : note.trim(),
      },
    ),
  );

  @override
  Future<Map<String, List<PageTaskTable>>> taskTables(String spaceId) =>
      _guard(() async {
        final rows = await _client.rpc<List<dynamic>>(
          'space_task_tables',
          params: {'p_space': spaceId},
        );
        return {
          for (final r in rows.cast<Map<String, dynamic>>())
            r['post_id'] as String: [
              for (final b in r['blocks'] as List? ?? const [])
                if (PageBlock.fromJson(b as Map<String, dynamic>)
                    case final PageTaskTable t)
                  t,
            ],
        };
      });
}

final pageRepositoryProvider = Provider<PageRepository>(
  (ref) => SupabasePageRepository(ref.watch(supabaseClientProvider)),
);

/// The tables of tasks on a Space's cards (review 105C-B), read again
/// after a tick, a new row or a save.
final taskTablesProvider = FutureProvider.autoDispose
    .family<Map<String, List<PageTaskTable>>, String>(
      (ref, spaceId) => ref.watch(pageRepositoryProvider).taskTables(spaceId),
    );

/// A post's page, read again after each save.
final postPageProvider = FutureProvider.autoDispose.family<PostPage?, String>(
  (ref, postId) => ref.watch(pageRepositoryProvider).page(postId),
);
