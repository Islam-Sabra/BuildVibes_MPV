import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../data/models/post.dart';
import '../work/daybook_writing.dart' show newPostIdProvider;
import '../entry/entry_state.dart';
import 'feed_state.dart';

/// The post language: found from the letters, or chosen (L6). One single
/// choice (rule 6).
enum PostLang {
  auto,
  en,
  ar;

  static PostLang of(String? code) => switch (code) {
    'en' => en,
    'ar' => ar,
    _ => auto,
  };
}

/// A post being written in place on Home (H2 2555:35388), or a posted one
/// being edited. The app chose its [id] when the card opened, so it is the
/// same post however often it is sent.
@immutable
class PostDraft {
  const PostDraft({
    required this.id,
    this.body = '',
    this.lang = PostLang.auto,
    this.project,
    this.photos = const [],
    this.couldNotSend = false,
  });

  factory PostDraft.fromJson(Map<String, dynamic> j) => PostDraft(
    id: j['id'] as String,
    body: j['body'] as String? ?? '',
    lang: PostLang.of(j['lang'] as String?),
    project: j['project'] == null
        ? null
        : PostProject.fromCache(j['project'] as Map<String, dynamic>),
    photos: [for (final p in j['photos'] as List? ?? const []) p as String],
    couldNotSend: j['could_not_send'] as bool? ?? false,
  );

  /// A post the server refused, back as the Draft it was (review 46).
  factory PostDraft.refused(PendingPost p) => PostDraft(
    id: p.id,
    body: p.body,
    lang: PostLang.of(p.lang),
    project: p.project,
    photos: [for (final ph in p.photos) ph.local],
    couldNotSend: true,
  );

  /// A posted one, to edit: its text and language only (edit_post).
  factory PostDraft.of(Post post) => PostDraft(
    id: post.id,
    body: post.body ?? '',
    lang: PostLang.of(post.lang),
  );

  /// What create_post takes: up to 3,000 characters and four photos.
  static const bodyMax = 3000;
  static const photosMax = 4;

  final String id;
  final String body;
  final PostLang lang;

  /// A project from the writer's profile with a confirmed role (C10).
  final PostProject? project;

  /// Photos kept in the app's folder, so they outlive the camera's cache
  /// and the app being closed.
  final List<String> photos;

  /// The server refused it when it was posted: "Couldn't send. Tap to fix".
  final bool couldNotSend;

  /// Nothing entered: no draft (the card just closes). A photo or a
  /// project alone is kept (review 46: the photo often comes first).
  bool get isEmpty => body.trim().isEmpty && photos.isEmpty && project == null;

  /// Text or a photo: Post turns on (create_post).
  bool get canPost => body.trim().isNotEmpty || photos.isNotEmpty;

  /// The language it goes up with: the one chosen, or the one its letters
  /// show.
  String get postLang => switch (lang) {
    PostLang.en => 'en',
    PostLang.ar => 'ar',
    PostLang.auto => detectLang(body),
  };

  PostDraft copyWith({
    String? body,
    PostLang? lang,
    PostProject? Function()? project,
    List<String>? photos,
  }) => PostDraft(
    id: id,
    body: body ?? this.body,
    lang: lang ?? this.lang,
    project: project == null ? this.project : project(),
    photos: photos ?? this.photos,
    couldNotSend: couldNotSend,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'lang': lang.name,
    'project': project?.toJson(),
    'photos': photos,
    'could_not_send': couldNotSend,
  };
}

/// The card in place: a new post's ([PostDrafts]) or an edit's
/// ([PostEdits]).
abstract class PostCardState extends Notifier<PostDraft?> {
  Future<void> put(PostDraft draft);
}

/// The post being written on Home, or null. As soon as anything is
/// entered it is saved on the phone as it changes, per account, so a
/// killed app comes back to it as a Draft that only its author sees.
/// Drafts never go to the server.
final postDraftProvider = NotifierProvider<PostDrafts, PostDraft?>(
  PostDrafts.new,
);

class PostDrafts extends PostCardState {
  String? _key;

  @override
  PostDraft? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authUserIdProvider).value;
    _key = userId == null ? null : 'post_draft:$userId';
    final raw = _key == null ? null : prefs.getString(_key!);
    if (raw == null) return null;
    try {
      return PostDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  /// Opens a new card with [id], or keeps the one being written.
  void open(String id) => state ??= PostDraft(id: id);

  @override
  Future<void> put(PostDraft draft) async {
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
  Future<bool> restoreRefused(PendingPost p) async {
    final current = state;
    if (current != null && !current.isEmpty) return false;
    await put(PostDraft.refused(p));
    return true;
  }

  /// The card is put down: an empty one is gone; one with anything in it
  /// stays as the Draft.
  Future<void> close() async {
    final draft = state;
    if (draft != null && draft.isEmpty) await discard();
  }

  /// Gone for good. [keepPhotos] when they went to the outbox with the
  /// post.
  Future<void> discard({bool keepPhotos = false}) async {
    final photos = state?.photos ?? const [];
    state = null;
    final key = _key;
    if (key != null) await ref.read(sharedPreferencesProvider).remove(key);
    if (!keepPhotos) {
      for (final p in photos) {
        unawaited(deleteKept(p));
      }
    }
  }

  static Future<void> deleteKept(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

/// A posted one being edited in place at Now: only on the screen; putting
/// it down leaves the post as it was.
final postEditProvider = NotifierProvider<PostEdits, PostDraft?>(PostEdits.new);

class PostEdits extends PostCardState {
  /// The post as it was: its photos and tag show, and stay (edit_post).
  Post? original;

  @override
  PostDraft? build() => null;

  void start(Post post) {
    original = post;
    state = PostDraft.of(post);
  }

  @override
  Future<void> put(PostDraft draft) async => state = draft;

  void stop() {
    original = null;
    state = null;
  }
}

/// Whether Home's card is open: writing a new post, or editing one.
enum PostWriting { none, writing, editing }

/// Create (from every tab), a Draft's tap and a post's Edit open the card
/// on Home; Home shows its Feed while it is open.
final postWritingProvider = NotifierProvider<PostWritingMode, PostWriting>(
  PostWritingMode.new,
);

class PostWritingMode extends Notifier<PostWriting> {
  @override
  PostWriting build() => PostWriting.none;

  /// A new post, or the Draft left from before.
  void write() {
    ref.read(postEditProvider.notifier).stop();
    ref.read(postDraftProvider.notifier).open(ref.read(newPostIdProvider)());
    state = PostWriting.writing;
  }

  void edit(Post post) {
    ref.read(postEditProvider.notifier).start(post);
    state = PostWriting.editing;
  }

  void stop() => state = PostWriting.none;
}
