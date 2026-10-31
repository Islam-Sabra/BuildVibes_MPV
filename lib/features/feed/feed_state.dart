import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/sound/sent_chime.dart';
import '../../data/models/post.dart';
import '../../data/models/space.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import '../entry/entry_state.dart';
import '../work/work_outbox.dart'
    show OutboxRetry, outboxRetryDelaysProvider, outboxRetryLaterProvider;
import 'post_draft.dart';
import 'post_list.dart' show postListProvider;

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

  /// Back to the phone copy only, to upload again.
  PendingPostPhoto get notUploaded => PendingPostPhoto(local: local);

  Map<String, dynamic> toJson() => {'local': local, 'remote': remote};
}

/// A post written on this phone that isn't on the server yet. The app
/// chose its [id] when the card opened, so sending it again is the same
/// post. On Home it hangs at [madeAt] with "Waiting to send" (H5).
@immutable
class PendingPost {
  const PendingPost({
    required this.id,
    required this.body,
    required this.lang,
    required this.madeAt,
    this.project,
    this.photos = const [],
    this.refused = false,
    this.sent = false,
    this.scheduleAt,
  });

  factory PendingPost.fromJson(Map<String, dynamic> j) => PendingPost(
    id: j['id'] as String,
    body: j['body'] as String,
    lang: j['lang'] as String,
    madeAt: DateTime.parse(j['made_at'] as String).toLocal(),
    project: j['project'] == null
        ? null
        : PostProject.fromCache(j['project'] as Map<String, dynamic>),
    photos: [
      for (final p in (j['photos'] as List?) ?? const [])
        PendingPostPhoto.fromJson(p as Map<String, dynamic>),
    ],
    refused: j['refused'] as bool? ?? false,
    sent: j['sent'] as bool? ?? false,
    scheduleAt: j['schedule_at'] == null
        ? null
        : DateTime.parse(j['schedule_at'] as String).toLocal(),
  );

  final String id;
  final String body;
  final String lang;
  final DateTime madeAt;
  final PostProject? project;
  final List<PendingPostPhoto> photos;

  /// The server said no (not a lost signal): it isn't tried again by
  /// itself. It waits, "Couldn't send. Tap to fix", while another post is
  /// being written; otherwise it is back in the Draft at once.
  final bool refused;

  /// It reached the server: its card no longer says "Waiting to send",
  /// and it stays only until the feed has the server's copy (F17), so the
  /// card never blinks.
  final bool sent;

  /// Post later (review 108 PL1): the server makes it at this time
  /// (schedule_post), not now. It is never a card on Home meanwhile.
  final DateTime? scheduleAt;

  PendingPost copyWith({
    List<PendingPostPhoto>? photos,
    bool? refused,
    bool? sent,
  }) => PendingPost(
    id: id,
    body: body,
    lang: lang,
    madeAt: madeAt,
    project: project,
    photos: photos ?? this.photos,
    refused: refused ?? this.refused,
    sent: sent ?? this.sent,
    scheduleAt: scheduleAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'lang': lang,
    'made_at': madeAt.toUtc().toIso8601String(),
    'project': project?.toJson(),
    'photos': [for (final p in photos) p.toJson()],
    'refused': refused,
    'sent': sent,
    'schedule_at': ?scheduleAt?.toUtc().toIso8601String(),
  };

  /// Only what this version wrote is read back (older ones had no time).
  static bool isKnown(Map<String, dynamic> j) => j['made_at'] is String;
}

final postOutboxProvider = NotifierProvider<PostOutbox, List<PendingPost>>(
  PostOutbox.new,
);

/// Posts waiting to be sent, kept on the phone between app starts, so a
/// weak site signal never loses one or its photos. Each account has its
/// own: on a phone a crew shares, the next person never sees (or sends)
/// someone else's post.
class PostOutbox extends Notifier<List<PendingPost>> {
  /// Before accounts had their own; whose posts they were is unknown.
  static const _sharedKey = 'post_outbox';

  String? _key;

  /// The ones in flight now, so a flush never sends one twice at once.
  final _sending = <String>{};

  late final _retry = OutboxRetry(flushAll);

  @override
  List<PendingPost> build() {
    ref.onDispose(_retry.cancel);
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authUserIdProvider).value;
    if (prefs.containsKey(_sharedKey)) unawaited(prefs.remove(_sharedKey));
    _key = userId == null ? null : 'post_outbox:$userId';
    final raw = _key == null ? null : prefs.getString(_key!);
    if (raw == null) return const [];
    try {
      return [
        for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          if (PendingPost.isKnown(j)) PendingPost.fromJson(j),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _save(List<PendingPost> items) async {
    state = items;
    final key = _key;
    if (key == null) return;
    await ref
        .read(sharedPreferencesProvider)
        .setString(key, jsonEncode([for (final i in items) i.toJson()]));
  }

  Future<void> _put(PendingPost p) => _save([
    for (final i in state)
      if (i.id != p.id) i,
    p,
  ]);

  Future<void> _drop(String id) => _save([
    for (final i in state)
      if (i.id != id) i,
  ]);

  /// Sends everything still waiting for a signal (not what the server
  /// refused). Called when the app opens, when Home comes back to the
  /// front, and every little while.
  Future<void> flushAll() async {
    for (final p in state.toList()) {
      if (!p.refused && !_sending.contains(p.id)) await send(p);
    }
  }

  /// Keeps [p], uploads its photos first and posts it, trying again on a
  /// weak signal. True when it reached the server; otherwise it stays here
  /// ("Waiting to send"), unless the server refused it: then it goes back
  /// to the Draft ("Couldn't send. Tap to fix", review 46).
  Future<bool> send(PendingPost p) async {
    if (!_sending.add(p.id)) return false;
    try {
      return await _send(p);
    } finally {
      _sending.remove(p.id);
    }
  }

  Future<bool> _send(PendingPost p) async {
    // On the server already: only the feed has to catch up.
    if (p.sent) return _settle(p);
    final repo = ref.read(postRepositoryProvider);
    final delays = ref.read(outboxRetryDelaysProvider);
    var current = p.copyWith(refused: false);
    await _put(current);

    Future<T> withRetries<T>(Future<T> Function() run) async {
      for (var attempt = 0; ; attempt++) {
        try {
          return await run();
        } on SpaceException catch (e) {
          // Only a lost connection is worth another try.
          if (e.failure != SpaceFailure.network || attempt >= delays.length) {
            rethrow;
          }
          await Future<void>.delayed(delays[attempt]);
        }
      }
    }

    // Photos uploaded by an earlier try. After a long wait the nightly
    // cleanup may have claimed them; the phone copies are still here.
    var reused = current.photos.any((ph) => ph.remote != null);
    for (;;) {
      try {
        final photos = <PendingPostPhoto>[];
        for (final ph in current.photos) {
          if (ph.remote != null) {
            photos.add(ph);
            continue;
          }
          // A new name on every try: nothing is ever overwritten.
          final path = await withRetries(
            () => repo.uploadPhoto(current.id, File(ph.local)),
          );
          photos.add(PendingPostPhoto(local: ph.local, remote: path));
          current = current.copyWith(
            photos: [...photos, ...current.photos.skip(photos.length)],
          );
          await _put(current);
        }
        final media = [for (final ph in photos) PostPhoto(path: ph.remote!)];
        if (current.scheduleAt case final at?) {
          // Post later: create_post's arguments, made as me at [at].
          final scheduled = current;
          await withRetries(
            () => ref
                .read(scheduleRepositoryProvider)
                .schedule(
                  id: scheduled.id,
                  call: ScheduledCall.feedPost,
                  params: createPostParams(
                    id: scheduled.id,
                    body: scheduled.body,
                    lang: scheduled.lang,
                    projectId: scheduled.project?.id,
                    photos: media,
                  ),
                  at: at,
                  title: scheduled.body,
                ),
          );
          break;
        }
        await withRetries(
          () => repo.create(
            id: current.id,
            body: current.body,
            lang: current.lang,
            projectId: current.project?.id,
            photos: media,
          ),
        );
        break;
      } on SpaceException catch (e) {
        // Refused photos from an earlier try: upload them again, once.
        if (reused && e.failure == SpaceFailure.badInput) {
          reused = false;
          current = current.copyWith(
            photos: [for (final ph in current.photos) ph.notUploaded],
          );
          await _put(current);
          continue;
        }
        if (e.failure == SpaceFailure.network) {
          await _put(current);
          _retry.later(ref.read(outboxRetryLaterProvider));
        } else if (!await reopenRefused(current)) {
          // A new post is being written: this one waits, refused, until
          // the card is free.
          await _put(current.copyWith(refused: true));
        }
        return false;
      }
    }

    // Post later: the server has it; nothing comes on Home now.
    if (current.scheduleAt != null) {
      _retry.reached();
      await _drop(current.id);
      for (final ph in current.photos) {
        unawaited(PostDrafts.deleteKept(ph.local));
      }
      ref.invalidate(myScheduledProvider);
      return true;
    }

    // "Waiting to send" goes at once (F17); the card stays until the
    // feed has the server's copy.
    _retry.reached();
    unawaited(ref.read(sentChimeProvider).play());
    await _put(current.copyWith(sent: true));
    ref.invalidate(postListProvider);
    return _settle(current);
  }

  /// A sent [p] leaves the phone once the feed has the server's copy of
  /// it (matched by its id), so the card never blinks and is never there
  /// twice. With no signal for that read, it waits, without the label, and
  /// is settled on the next try.
  Future<bool> _settle(PendingPost p) async {
    final feed = feedProvider;
    if (ref.exists(feed)) {
      try {
        await ref.read(feed.notifier).added(p.id);
      } on SpaceException {
        _retry.later(ref.read(outboxRetryLaterProvider));
        return true;
      }
    }
    await _drop(p.id);
    for (final ph in p.photos) {
      unawaited(PostDrafts.deleteKept(ph.local));
    }
    return true;
  }

  /// A refused post back into the Draft, unless a card is being written.
  /// True when it moved; its photos go with it.
  Future<bool> reopenRefused(PendingPost p) async {
    if (!await ref.read(postDraftProvider.notifier).restoreRefused(p)) {
      return false;
    }
    await _drop(p.id);
    return true;
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

  /// Reads the first page again, quietly (F11, F18): new posts come in at
  /// the top of their section, changed and deleted ones are as the server
  /// has them, and older pages already loaded stay below. Nothing changes
  /// with no signal.
  Future<void> refreshNewest() async {
    final current = state.value;
    if (current == null) {
      // It couldn't load: try again.
      if (state.hasError) ref.invalidate(feedProvider);
      return;
    }
    if (current.loadingMore) return;
    final PostPage<FeedEntry> page;
    try {
      page = await ref.read(postRepositoryProvider).feed();
    } on SpaceException {
      return;
    }
    final now = state.value;
    if (now == null || now.loadingMore) return;
    unawaited(_keep(page.items));
    final firstPage = {for (final e in page.items) e.post.id};
    // Older pages loaded: what isn't on the first page any more stays
    // below it, in its order (a post pushed down by new ones is never
    // lost). With one page, the server's page is the whole list.
    final below = now.entries.length <= page.items.length
        ? const <FeedEntry>[]
        : [
            for (final e in now.entries)
              if (!firstPage.contains(e.post.id)) e,
          ];
    state = AsyncData(
      FeedState(
        entries: [...page.items, ...below],
        next: below.isEmpty ? page.next : now.next,
      ),
    );
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

/// The latest replies to you that you have seen, by opening their post
/// (review 50 F30): until then the card's reply line is bold. Kept on the
/// phone, per account, the newest [keep] only.
final seenRepliesProvider = NotifierProvider<SeenReplies, Set<String>>(
  SeenReplies.new,
);

class SeenReplies extends Notifier<Set<String>> {
  static const keep = 200;

  String? _key;

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authUserIdProvider).value;
    _key = userId == null ? null : 'seen_replies:$userId';
    return {...?(_key == null ? null : prefs.getStringList(_key!))};
  }

  /// The post was opened: its latest reply has been seen.
  void seen(String replyId) {
    if (state.contains(replyId)) return;
    final ids = [...state, replyId];
    state = ids.skip(ids.length > keep ? ids.length - keep : 0).toSet();
    final key = _key;
    if (key != null) {
      unawaited(
        ref.read(sharedPreferencesProvider).setStringList(key, [...state]),
      );
    }
  }
}
