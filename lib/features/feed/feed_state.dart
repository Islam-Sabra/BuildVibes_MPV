import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../data/models/post.dart';
import '../../data/models/space.dart';
import '../../data/repositories/post_repository.dart';
import '../entry/entry_state.dart';
import '../work/work_outbox.dart' show outboxRetryDelaysProvider;

/// A photo kept on the phone until its post is sent; [remote] once
/// uploaded.
@immutable
class PendingPostPhoto {
  const PendingPostPhoto({required this.local, this.remote});

  factory PendingPostPhoto.fromJson(Map<String, dynamic> j) => PendingPostPhoto(
    local: j['local'] as String,
    remote: j['remote'] as String?,
  );

  final String local;
  final String? remote;

  Map<String, dynamic> toJson() => {'local': local, 'remote': remote};
}

/// A post written on this phone that isn't on the server yet: "Posting to
/// your network…", or "Couldn't post. Saved as a draft. · Retry".
@immutable
class PendingPost {
  const PendingPost({
    required this.id,
    required this.body,
    required this.lang,
    this.projectId,
    this.projectName,
    this.photos = const [],
    this.failed = false,
  });

  factory PendingPost.fromJson(Map<String, dynamic> j) => PendingPost(
    id: j['id'] as String,
    body: j['body'] as String,
    lang: j['lang'] as String,
    projectId: j['project_id'] as String?,
    projectName: j['project_name'] as String?,
    photos: [
      for (final p in (j['photos'] as List?) ?? const [])
        PendingPostPhoto.fromJson(p as Map<String, dynamic>),
    ],
    failed: j['failed'] as bool? ?? false,
  );

  final String id;
  final String body;
  final String lang;
  final String? projectId;
  final String? projectName;
  final List<PendingPostPhoto> photos;
  final bool failed;

  PendingPost copyWith({List<PendingPostPhoto>? photos, bool? failed}) =>
      PendingPost(
        id: id,
        body: body,
        lang: lang,
        projectId: projectId,
        projectName: projectName,
        photos: photos ?? this.photos,
        failed: failed ?? this.failed,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'lang': lang,
    'project_id': projectId,
    'project_name': projectName,
    'photos': [for (final p in photos) p.toJson()],
    'failed': failed,
  };
}

final postOutboxProvider = NotifierProvider<PostOutbox, List<PendingPost>>(
  PostOutbox.new,
);

/// Posts waiting to be sent, kept on the phone between app starts. Closing
/// the app loses nothing.
class PostOutbox extends Notifier<List<PendingPost>> {
  static const _key = 'post_outbox';

  @override
  List<PendingPost> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          PendingPost.fromJson(j as Map<String, dynamic>),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _save(List<PendingPost> items) async {
    state = items;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode([for (final i in items) i.toJson()]));
  }

  Future<void> _put(PendingPost p) => _save([
    for (final i in state)
      if (i.id != p.id) i,
    p,
  ]);

  /// Keeps [p], uploads its photos and posts it, trying again on a weak
  /// signal. True when it reached the server. A refusal (not a lost
  /// signal) keeps it as a draft and is rethrown.
  Future<bool> send(PendingPost p) async {
    final repo = ref.read(postRepositoryProvider);
    final delays = ref.read(outboxRetryDelaysProvider);
    var current = p.copyWith(failed: false);
    await _put(current);

    Future<T> withRetries<T>(Future<T> Function() run) async {
      for (var attempt = 0; ; attempt++) {
        try {
          return await run();
        } on SpaceException catch (e) {
          if (e.failure != SpaceFailure.network || attempt >= delays.length) {
            rethrow;
          }
          await Future<void>.delayed(delays[attempt]);
        }
      }
    }

    try {
      final photos = <PendingPostPhoto>[];
      for (final ph in current.photos) {
        if (ph.remote != null) {
          photos.add(ph);
          continue;
        }
        final path = await withRetries(
          () => repo.uploadPhoto(current.id, File(ph.local)),
        );
        photos.add(PendingPostPhoto(local: ph.local, remote: path));
        current = current.copyWith(
          photos: [...photos, ...current.photos.skip(photos.length)],
        );
        await _put(current);
      }
      await withRetries(
        () => repo.create(
          id: current.id,
          body: current.body,
          lang: current.lang,
          projectId: current.projectId,
          photos: [for (final ph in photos) PostPhoto(path: ph.remote!)],
        ),
      );
    } on SpaceException catch (e) {
      await _put(current.copyWith(failed: true));
      if (e.failure == SpaceFailure.network) return false;
      rethrow;
    }
    await _save([
      for (final i in state)
        if (i.id != p.id) i,
    ]);
    for (final ph in p.photos) {
      unawaited(_deleteKept(ph.local));
    }
    // Shown at once at the top of the feed.
    final feed = feedProvider;
    if (ref.exists(feed)) await ref.read(feed.notifier).added(p.id);
    return true;
  }

  Future<bool> retry(String id) async {
    final p = state.where((i) => i.id == id).firstOrNull;
    return p == null ? false : send(p);
  }

  /// "Discard draft": the post and its kept photos go.
  Future<void> discard(String id) async {
    final p = state.where((i) => i.id == id).firstOrNull;
    if (p == null) return;
    await _save([
      for (final i in state)
        if (i.id != id) i,
    ]);
    for (final ph in p.photos) {
      unawaited(_deleteKept(ph.local));
    }
  }

  static Future<void> _deleteKept(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

/// The feed so far, where the next page starts, and whether it is the copy
/// kept on the phone (offline, H6).
@immutable
class FeedState {
  const FeedState({
    this.entries = const [],
    this.next,
    this.offline = false,
    this.loadingMore = false,
  });

  final List<FeedEntry> entries;
  final Map<String, dynamic>? next;
  final bool offline;
  final bool loadingMore;

  bool get hasMore => next != null;

  FeedState copyWith({
    List<FeedEntry>? entries,
    Map<String, dynamic>? next,
    bool clearNext = false,
    bool? offline,
    bool? loadingMore,
  }) => FeedState(
    entries: entries ?? this.entries,
    next: clearNext ? null : (next ?? this.next),
    offline: offline ?? this.offline,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);

class FeedNotifier extends AsyncNotifier<FeedState> {
  /// One copy per person: after a sign-out, the next person on this phone
  /// never sees it.
  String get _cacheKey =>
      'feed_cache_${ref.read(authUserIdProvider).value ?? 'none'}';

  @override
  Future<FeedState> build() async {
    try {
      final page = await ref.read(postRepositoryProvider).feed();
      unawaited(_keep(page.items));
      return FeedState(entries: page.items, next: page.next);
    } on SpaceException catch (e) {
      // No signal: the last page this phone loaded (H6), when there is one.
      final kept = cached();
      if (e.failure == SpaceFailure.network && kept != null) {
        return FeedState(entries: kept, offline: true);
      }
      rethrow;
    }
  }

  /// The last page this phone loaded, or null.
  List<FeedEntry>? cached() {
    final raw = ref.read(sharedPreferencesProvider).getString(_cacheKey);
    if (raw == null) return null;
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          FeedEntry(
            section: (j as Map)['section'] == 'home'
                ? FeedSection.home
                : FeedSection.beyond,
            post: Post.fromCache(j['post'] as Map<String, dynamic>),
          ),
      ];
    } on Object {
      return null;
    }
  }

  Future<void> _keep(List<FeedEntry> entries) => ref
      .read(sharedPreferencesProvider)
      .setString(
        _cacheKey,
        jsonEncode([
          for (final e in entries)
            {'section': e.section.name, 'post': e.post.toCache()},
        ]),
      );

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(postRepositoryProvider)
          .feed(cursor: current.next);
      final seen = {for (final e in current.entries) e.post.id};
      state = AsyncData(
        FeedState(
          entries: [
            ...current.entries,
            for (final e in page.items)
              if (!seen.contains(e.post.id)) e,
          ],
          next: page.next,
        ),
      );
    } on SpaceException {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// A post this phone just sent: on top of the home section.
  Future<void> added(String id) async {
    final post = await ref.read(postRepositoryProvider).post(id);
    final current = state.value;
    if (post == null || current == null) return;
    state = AsyncData(
      current.copyWith(
        entries: [
          FeedEntry(section: FeedSection.home, post: post),
          for (final e in current.entries)
            if (e.post.id != id) e,
        ],
      ),
    );
  }

  /// Puts a changed card in place (Useful, edit).
  void replace(Post post) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        entries: [
          for (final e in current.entries)
            e.post.id == post.id
                ? FeedEntry(section: e.section, post: post)
                : e,
        ],
      ),
    );
  }

  /// A deleted post, or the posts of a person just muted, leave the feed.
  void remove({String? postId, String? authorId}) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        entries: [
          for (final e in current.entries)
            if (e.post.id != postId && e.post.authorId != authorId) e,
        ],
      ),
    );
  }
}
