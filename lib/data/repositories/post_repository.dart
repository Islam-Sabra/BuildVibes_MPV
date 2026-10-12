import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/market.dart';
import '../models/post.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';
import 'work_repository.dart' show newUuid;

/// Posts, replies, Useful and mute (migration 12). Writes are function
/// calls; the server decides who may see what.
abstract class PostRepository {
  Future<PostPage<FeedEntry>> feed({Map<String, dynamic>? cursor});
  Future<PostPage<Post>> postsBy(
    String profileId, {
    Map<String, dynamic>? cursor,
  });
  Future<PostPage<Post>> postsTagged(
    String projectId, {
    Map<String, dynamic>? cursor,
  });

  /// Null when it is deleted or you may not see it.
  Future<Post?> post(String id);
  Future<List<PostReply>> replies(String postId);

  /// At most two names of people you follow who found it useful.
  Future<List<String>> usefulNames(String postId);

  /// Uploads to `<me>/<post>/<new uuid>.jpg`; returns the path.
  Future<String> uploadPhoto(String postId, File file);
  Future<void> create({
    required String id,
    required String body,
    required String lang,
    String? projectId,
    List<PostPhoto> photos = const [],
  });
  Future<void> edit(String id, String body, String lang);
  Future<void> delete(String id);
  Future<void> addReply({
    required String id,
    required String postId,
    String? replyTo,
    required String body,
  });
  Future<void> deleteReply(String id);
  Future<void> markUseful(String kind, String id, bool on);
  Future<void> mute(String profileId, bool on);
  Future<String> photoUrl(String path);
}

class SupabasePostRepository implements PostRepository {
  const SupabasePostRepository(this._client);

  final SupabaseClient _client;
  static const bucket = 'post-media';

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

  /// Cards for [ids], in that order, with the tag's type and place names.
  Future<List<Post>> _cards(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client.from('post_cards').select().inFilter('id', ids);
    final byId = {for (final r in rows) r['id'] as String: Post.fromJson(r)};
    final projectIds = {
      for (final p in byId.values)
        if (p.project != null) p.project!.id,
    }.toList();
    if (projectIds.isNotEmpty) {
      final projects = await _client
          .from('projects')
          .select('id, type:project_types(name), place:places(name)')
          .inFilter('id', projectIds);
      final names = {
        for (final r in projects)
          r['id'] as String: (
            r['type'] is Map
                ? LocalizedText.fromJson(
                    (r['type'] as Map)['name'] as Map<String, dynamic>,
                  )
                : null,
            r['place'] is Map
                ? LocalizedText.fromJson(
                    (r['place'] as Map)['name'] as Map<String, dynamic>,
                  )
                : null,
          ),
      };
      for (final e in byId.entries.toList()) {
        final pr = e.value.project;
        final n = pr == null ? null : names[pr.id];
        if (n != null) {
          byId[e.key] = e.value.copyWith(
            project: pr!.withNames(typeName: n.$1, placeName: n.$2),
          );
        }
      }
    }
    return [for (final id in ids) ?byId[id]];
  }

  Map<String, dynamic>? _nextCursor(List rows, {bool feed = false}) {
    if (rows.length < 20) return null;
    final last = rows.last as Map<String, dynamic>;
    return {
      if (feed) 'section': last['section'],
      if (feed) 'since': last['since'],
      'created_at': last['created_at'],
      'id': last['post_id'],
    };
  }

  @override
  Future<PostPage<FeedEntry>> feed({Map<String, dynamic>? cursor}) => _guard(
    () async {
      final rows =
          await _client.rpc('feed_page', params: {'p_cursor': cursor}) as List;
      final posts = await _cards([
        for (final r in rows) (r as Map)['post_id'] as String,
      ]);
      final section = {
        for (final r in rows)
          (r as Map)['post_id'] as String: r['section'] == 'home'
              ? FeedSection.home
              : FeedSection.beyond,
      };
      return PostPage(
        items: [
          for (final p in posts) FeedEntry(section: section[p.id]!, post: p),
        ],
        next: _nextCursor(rows, feed: true),
      );
    },
  );

  Future<PostPage<Post>> _list(String fn, Map<String, dynamic> params) =>
      _guard(() async {
        final rows = await _client.rpc(fn, params: params) as List;
        return PostPage(
          items: await _cards([
            for (final r in rows) (r as Map)['post_id'] as String,
          ]),
          next: _nextCursor(rows),
        );
      });

  @override
  Future<PostPage<Post>> postsBy(
    String profileId, {
    Map<String, dynamic>? cursor,
  }) => _list('posts_by', {'p_person': profileId, 'p_cursor': cursor});

  @override
  Future<PostPage<Post>> postsTagged(
    String projectId, {
    Map<String, dynamic>? cursor,
  }) => _list('posts_tagged', {'p_project': projectId, 'p_cursor': cursor});

  @override
  Future<Post?> post(String id) =>
      _guard(() async => (await _cards([id])).firstOrNull);

  @override
  Future<List<PostReply>> replies(String postId) => _guard(() async {
    final rows = await _client
        .from('post_replies')
        .select(
          'id, post_id, author_id, reply_to, body, created_at, '
          'author:profiles!post_replies_author_id_fkey(first_name, last_name, headline)',
        )
        .eq('post_id', postId)
        .order('created_at');
    final replies = [for (final r in rows) PostReply.fromJson(r)];
    if (replies.isEmpty) return replies;
    final marks = await _client
        .from('useful_marks')
        .select('target_id')
        .eq('target_kind', 'reply')
        .inFilter('target_id', [for (final r in replies) r.id]);
    final mine = {for (final m in marks) m['target_id'] as String};
    return [for (final r in replies) r.copyWith(myUseful: mine.contains(r.id))];
  });

  @override
  Future<List<String>> usefulNames(String postId) => _guard(() async {
    final rows =
        await _client.rpc('useful_names', params: {'p_post': postId}) as List;
    return [
      for (final r in rows)
        if ((r as Map)['name'] case final String name) name,
    ];
  });

  @override
  Future<String> uploadPhoto(String postId, File file) => _guard(() async {
    final me = _client.auth.currentUser!.id;
    final path = '$me/$postId/${newUuid()}.jpg';
    await _client.storage
        .from(bucket)
        .upload(
          path,
          file,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return path;
  });

  @override
  Future<void> create({
    required String id,
    required String body,
    required String lang,
    String? projectId,
    List<PostPhoto> photos = const [],
  }) => _guard(
    () => _client.rpc(
      'create_post',
      params: {
        'p_id': id,
        'p_body': body,
        'p_lang': lang,
        'p_project': projectId,
        'p_media': [
          for (final p in photos)
            {'path': p.path, 'width': ?p.width, 'height': ?p.height},
        ],
      },
    ),
  );

  @override
  Future<void> edit(String id, String body, String lang) => _guard(
    () => _client.rpc(
      'edit_post',
      params: {'p_id': id, 'p_body': body, 'p_lang': lang},
    ),
  );

  @override
  Future<void> delete(String id) =>
      _guard(() => _client.rpc('delete_post', params: {'p_id': id}));

  @override
  Future<void> addReply({
    required String id,
    required String postId,
    String? replyTo,
    required String body,
  }) => _guard(
    () => _client.rpc(
      'add_reply',
      params: {
        'p_id': id,
        'p_post': postId,
        'p_reply_to': replyTo,
        'p_body': body,
      },
    ),
  );

  @override
  Future<void> deleteReply(String id) =>
      _guard(() => _client.rpc('delete_reply', params: {'p_id': id}));

  @override
  Future<void> markUseful(String kind, String id, bool on) => _guard(
    () => _client.rpc(
      'mark_useful',
      params: {'p_kind': kind, 'p_id': id, 'p_on': on},
    ),
  );

  @override
  Future<void> mute(String profileId, bool on) => _guard(
    () => _client.rpc('mute', params: {'p_person': profileId, 'p_on': on}),
  );

  @override
  Future<String> photoUrl(String path) => _guard(
    () => _client.storage
        .from(bucket)
        .createSignedUrl(path, const Duration(hours: 1).inSeconds),
  );
}

final postRepositoryProvider = Provider<PostRepository>(
  (ref) => SupabasePostRepository(ref.watch(supabaseClientProvider)),
);

final postProvider = FutureProvider.autoDispose.family<Post?, String>(
  (ref, id) => ref.watch(postRepositoryProvider).post(id),
);

final postRepliesProvider = FutureProvider.autoDispose
    .family<List<PostReply>, String>(
      (ref, id) => ref.watch(postRepositoryProvider).replies(id),
    );

final usefulNamesProvider = FutureProvider.autoDispose
    .family<List<String>, String>(
      (ref, id) => ref.watch(postRepositoryProvider).usefulNames(id),
    );

final postPhotoUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(postRepositoryProvider).photoUrl(path),
);
