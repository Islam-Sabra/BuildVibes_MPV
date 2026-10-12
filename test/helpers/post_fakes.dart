import 'dart:io';

import 'package:buildvibes/data/models/post.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/post_repository.dart';

/// Posts with no network. Tests fill [posts] (newest first), [home] (the ids
/// in the home market), [repliesByPost] and [useful].
class FakePostRepository implements PostRepository {
  FakePostRepository({DateTime? now}) : now = now ?? DateTime(2026, 10, 11);

  final DateTime now;
  final posts = <Post>[];
  final home = <String>{};
  final repliesByPost = <String, List<PostReply>>{};
  final useful = <String, List<String>>{};
  final calls = <String>[];
  final muted = <String>{};
  final uploads = <String>[];

  /// The next calls fail as if the signal dropped.
  int failNext = 0;

  /// The feed fails as if the signal dropped (H5, H6).
  bool feedOffline = false;

  void _maybeFail() {
    if (failNext > 0) {
      failNext--;
      throw const SpaceException(SpaceFailure.network);
    }
  }

  @override
  Future<PostPage<FeedEntry>> feed({Map<String, dynamic>? cursor}) async {
    if (feedOffline) throw const SpaceException(SpaceFailure.network);
    return PostPage(
      items: [
        for (final p in posts.where(
          (p) => home.contains(p.id) && !muted.contains(p.authorId),
        ))
          FeedEntry(section: FeedSection.home, post: p),
        for (final p in posts.where(
          (p) => !home.contains(p.id) && !muted.contains(p.authorId),
        ))
          FeedEntry(section: FeedSection.beyond, post: p),
      ],
    );
  }

  @override
  Future<PostPage<Post>> postsBy(
    String profileId, {
    Map<String, dynamic>? cursor,
  }) async => PostPage(
    items: [
      for (final p in posts)
        if (p.authorId == profileId) p,
    ],
  );

  @override
  Future<PostPage<Post>> postsTagged(
    String projectId, {
    Map<String, dynamic>? cursor,
  }) async => PostPage(
    items: [
      for (final p in posts)
        if (p.project?.id == projectId) p,
    ],
  );

  @override
  Future<Post?> post(String id) async =>
      posts.where((p) => p.id == id).firstOrNull;

  @override
  Future<List<PostReply>> replies(String postId) async =>
      List.of(repliesByPost[postId] ?? const []);

  @override
  Future<List<String>> usefulNames(String postId) async =>
      useful[postId] ?? const [];

  @override
  Future<String> uploadPhoto(String postId, File file) async {
    _maybeFail();
    final path = 'user-1/$postId/photo-${uploads.length + 1}.jpg';
    uploads.add(path);
    return path;
  }

  @override
  Future<void> create({
    required String id,
    required String body,
    required String lang,
    String? projectId,
    List<PostPhoto> photos = const [],
  }) async {
    _maybeFail();
    calls.add('create $lang ${projectId ?? '-'} ${photos.length} $body');
    if (posts.any((p) => p.id == id)) return;
    posts.insert(
      0,
      Post(
        id: id,
        authorId: 'user-1',
        authorName: 'Omar Haddad',
        body: body.isEmpty ? null : body,
        lang: lang,
        createdAt: now,
        photos: photos,
      ),
    );
    home.add(id);
  }

  @override
  Future<void> edit(String id, String body, String lang) async {
    calls.add('edit $id $lang $body');
    final i = posts.indexWhere((p) => p.id == id);
    if (i >= 0) {
      posts[i] = posts[i].copyWith(body: body, lang: lang, editedAt: now);
    }
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    posts.removeWhere((p) => p.id == id);
  }

  @override
  Future<void> addReply({
    required String id,
    required String postId,
    String? replyTo,
    required String body,
  }) async {
    calls.add('reply $postId ${replyTo ?? '-'} $body');
    repliesByPost
        .putIfAbsent(postId, () => [])
        .add(
          PostReply(
            id: id,
            postId: postId,
            authorId: 'user-1',
            authorName: 'Omar Haddad',
            replyTo: replyTo,
            body: body,
            createdAt: now,
          ),
        );
  }

  @override
  Future<void> deleteReply(String id) async {
    calls.add('delete-reply $id');
    for (final list in repliesByPost.values) {
      list.removeWhere((r) => r.id == id);
    }
  }

  @override
  Future<void> markUseful(String kind, String id, bool on) async {
    calls.add('useful $kind $id $on');
    if (kind == 'reply') {
      for (final list in repliesByPost.values) {
        final i = list.indexWhere((r) => r.id == id);
        if (i >= 0) list[i] = list[i].copyWith(myUseful: on);
      }
    } else {
      final i = posts.indexWhere((p) => p.id == id);
      if (i >= 0) posts[i] = posts[i].copyWith(myUseful: on);
    }
  }

  @override
  Future<void> mute(String profileId, bool on) async {
    calls.add('mute $profileId $on');
    if (on) {
      muted.add(profileId);
    } else {
      muted.remove(profileId);
    }
  }

  /// No network in tests: cards show the photo placeholder.
  @override
  Future<String> photoUrl(String path) async =>
      throw const SpaceException(SpaceFailure.network);
}
